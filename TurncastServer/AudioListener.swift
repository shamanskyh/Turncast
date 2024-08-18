//
//  AudioListener.swift
//  Turncast
//
//  Created by Harry Shamansky on 11/29/20.
//  Copyright © 2020 Harry Shamansky. All rights reserved.
//

import AVFoundation
import AudioToolbox
import Combine
import Foundation
import HaishinKit
import MultipeerMessages
import ShazamKit
import SwiftUI

class AudioListener: NSObject, ObservableObject, MetadataSource {
    
    let captureSession = AVCaptureSession()
    let audioOutput = AVCaptureAudioDataOutput()
    var shazamSession = SHSession()
    
    @AppStorage("inputName") var inputName: String = "iMic"
    @AppStorage("offThreshold") var offThreshold: Double = -47.0
    @AppStorage("onThreshold") var onThreshold: Double = -30.0
    @AppStorage("onLength") var onLength: Double = 2.0
    @AppStorage("offLength") var offLength: Double = 4.0
    @AppStorage("launchShortcut") var launchStartShortcut: Bool = false
    @AppStorage("shortcutName") var startShortcutName: String = ""
    @AppStorage("launchStopShortcut") var launchStopShortcut: Bool = false
    @AppStorage("stopShortcutName") var stopShortcutName: String = ""
    @AppStorage("MetadataOverrides") var metadataOverrides: [MetadataOverride] = []
    @AppStorage("streamLocally") var streamLocally: Bool = false
    @AppStorage("streamOverNetwork") var streamOverNetwork: Bool = true
    @AppStorage("enterFullscreenWhenListening") var enterFullscreenWhenListening: Bool = false
    @AppStorage("exitFullscreenWhenStopped") var exitFullscreenWhenStopped: Bool = false
    
    let sampleRate: Int = 16000
    @Published var audioDetectionStatus = AudioDetectionStatus.notDetectingAudio
    @Published var averagePowerLevel: Float = Float.leastNormalMagnitude
    @Published var errorMessage: String? = nil
    var nextUIUpdateDate = Date()
    var onDate: Date?
    var offDate: Date?
    
    var captureDevice: AVCaptureDevice?
    var httpStream: HTTPStream?
    var httpService: HLSService?
    
    let localAudioEngine = AVAudioEngine()
    
    internal var recognize = false
    
    internal var blockBroadcast = false
    fileprivate static let unknownAlbumImageName = "UnknownAlbum"
    var albumImage = Image(unknownAlbumImageName) {
        willSet {
            objectWillChange.send()
        }
    }
    
    var albumImageData = NSImage(named: unknownAlbumImageName)!.cgImage(forProposedRect: nil, context: nil, hints: nil)! {
        willSet {
            print("Setting album image data")
            objectWillChange.send()
        }
    }
    
    var albumImageURL: URL? {
        willSet {
            objectWillChange.send()
            if newValue == nil {
                // reset
                albumImage = Image(Self.unknownAlbumImageName)
                if !blockBroadcast {
                    multipeerManager?.broadcast(message: .clearImageURL)
                }
            }
            if let imageURL = newValue, !blockBroadcast {
                multipeerManager?.broadcast(message: .imageURL(imageURL))
            }
        }
    }
    
    fileprivate static let unknownAlbum = "Unknown Album"
    fileprivate static let notPlayingAlbum = "Not Playing"
    var albumTitle = notPlayingAlbum {
        willSet {
            objectWillChange.send()
            if !blockBroadcast {
                multipeerManager?.broadcast(message: .albumTitle(newValue))
            }
        }
    }
    fileprivate static let unknownArtist = "Unknown Artist"
    fileprivate static let notPlayingArtist = " "
    var albumArtist = notPlayingArtist {
        willSet {
            objectWillChange.send()
            if !blockBroadcast {
                multipeerManager?.broadcast(message: .artist(newValue))
            }
        }
    }
    
    /// The ISRC of the currently playing song, if detected
    var isrc: String?
    
    @MainActor
    func updateMetadata(albumTitle: String?, artist: String?, imageURL: String?, notes: String?) {
        guard let isrc = isrc else { return }
        if let metadata = metadataOverrides.first(where: { $0.isrc == isrc }) {
            let newMetadata = MetadataOverride(isrc: isrc,
                                               album: albumTitle ?? metadata.album,
                                               artist: artist ?? metadata.artist,
                                               imageURL: imageURL ?? metadata.imageURL,
                                               notes: notes ?? metadata.notes)
            if let index = metadataOverrides.firstIndex(where: { $0.isrc == isrc }) {
                metadataOverrides.remove(at: index)
                metadataOverrides.insert(newMetadata, at: index)
            }
            
            self.albumTitle = newMetadata.album
            self.albumArtist = newMetadata.artist
            if let artworkURL = URL(string: newMetadata.imageURL) {
                if artworkURL != self.albumImageURL {
                    self.albumImageURL = artworkURL
                    DispatchQueue.global(qos: .background).async { [weak self] in
                        if let nsImage = NSImage(contentsOf: artworkURL) {
                            let swiftImage = Image(nsImage: nsImage)
                            let imageData = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
                            DispatchQueue.main.async { [weak self] in
                                guard let strongSelf = self else { return }
                                withAnimation {
                                    strongSelf.albumImage = swiftImage
                                    if let data = imageData {
                                        strongSelf.albumImageData = data
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Multipeer
    var multipeerManager: MultipeerManager?
    
    static var numberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }
    
    func beginListening() {
        multipeerManager = MultipeerManager(delegate: self)
        shazamSession.delegate = self
        
        if captureSession.isRunning {
            captureSession.stopRunning()
            captureSession.beginConfiguration()
            captureSession.inputs.forEach({ captureSession.removeInput($0) })
            captureSession.outputs.forEach({ captureSession.removeOutput($0) })
            captureSession.commitConfiguration()
            DispatchQueue.main.async { [weak self] in
                self?.beginListening()
            }
        } else {
            captureSession.beginConfiguration()
            let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.microphone], mediaType: nil, position: AVCaptureDevice.Position.unspecified)
            if let device = discoverySession.devices.filter({ $0.localizedName.contains(inputName) }).first, let deviceInput = try? AVCaptureDeviceInput(device: device) {
                captureDevice = deviceInput.device
                captureSession.addInput(deviceInput)
                if captureSession.canAddOutput(audioOutput) {
                    captureSession.addOutput(audioOutput)
                    audioOutput.setSampleBufferDelegate(self, queue: DispatchQueue.main)
                    if let existingFormatID = audioOutput.audioSettings[AVFormatIDKey] as? Int {
                        audioOutput.audioSettings = [AVSampleRateKey: NSNumber(integerLiteral: sampleRate),
                                                     AVFormatIDKey: NSNumber(integerLiteral: existingFormatID),
                                               AVNumberOfChannelsKey: NSNumber(integerLiteral: 1)]
                    } else {
                        errorMessage = "Could not find existing audio settings"
                    }
                    
                } else {
                    errorMessage = "Cannot add output"
                }
                
                if streamLocally {
                    startLocalAudioConnection()
                }
                
                captureSession.commitConfiguration()
                captureSession.startRunning()
                print("Began running capture session")
            } else {
                captureSession.commitConfiguration()
                errorMessage = "Cannot find audio device containing \"\(inputName)\""
            }
        }
        
        // start streaming
        if streamOverNetwork {
            httpStream = HTTPStream()
            if let device = captureDevice, let stream = httpStream {
                
                stream.attachAudio(device)
                stream.publish("turntable")

                httpService = HLSService(domain: "", type: "_http._tcp", name: "HaishinKit", port: 8080)
                httpService?.addHTTPStream(stream)
                httpService?.startRunning()
            }
        }
    }

    /// must be called on main
    func audioDetected() {
        recognize = true
        
        // run our shortcut if we have one
        if launchStartShortcut && !startShortcutName.isEmpty, let percentEncodedShortcutName = startShortcutName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed), let shortcutURL = URL(string: "shortcuts://run-shortcut?name=\(percentEncodedShortcutName)") {
            let config = NSWorkspace.OpenConfiguration()
            config.hides = true
            config.promptsUserIfNeeded = false
            NSWorkspace.shared.open(shortcutURL, configuration: config) { [weak self] app, error in
                guard let strongSelf = self else { return }
                // broadcast temporary data
                strongSelf.albumTitle = "Listening…"
                strongSelf.albumArtist = " "
                strongSelf.albumImageURL = nil
                strongSelf.albumImage = Image(AudioListener.unknownAlbumImageName)
                
                strongSelf.audioDetectionStatus = .detectingAudio
                
                strongSelf.multipeerManager?.broadcast(message: .startPlayback)
            }
        } else {
            // broadcast temporary data
            albumTitle = "Listening…"
            albumArtist = " "
            albumImageURL = nil
            albumImage = Image(AudioListener.unknownAlbumImageName)
            
            audioDetectionStatus = .detectingAudio
            
            multipeerManager?.broadcast(message: .startPlayback)
        }
    }
    
    /// Must be called on main
    func audioNotDetected() {
        // stop recognizing
        recognize = false
        
        // run our shortcut if we have one
        if launchStopShortcut && !stopShortcutName.isEmpty, let percentEncodedShortcutName = stopShortcutName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed), let shortcutURL = URL(string: "shortcuts://run-shortcut?name=\(percentEncodedShortcutName)") {
            let config = NSWorkspace.OpenConfiguration()
            config.hides = true
            config.promptsUserIfNeeded = false
            NSWorkspace.shared.open(shortcutURL, configuration: config) { [weak self] app, error in
                guard let strongSelf = self else { return }
                // reset metadata
                strongSelf.albumTitle = Self.notPlayingAlbum
                strongSelf.albumArtist = Self.notPlayingArtist
                strongSelf.albumImageURL = nil
                strongSelf.isrc = nil
                
                strongSelf.audioDetectionStatus = .notDetectingAudio
                
                strongSelf.multipeerManager?.broadcast(message: .stopPlayback)
            }
        } else {
            // reset metadata
            albumTitle = Self.notPlayingAlbum
            albumArtist = Self.notPlayingArtist
            albumImageURL = nil
            isrc = nil
            
            audioDetectionStatus = .notDetectingAudio
            
            multipeerManager?.broadcast(message: .stopPlayback)
        }
    }
    
    func startLocalAudioConnection() {
        let systemInput = localAudioEngine.inputNode
        let systemOutput = localAudioEngine.outputNode
        localAudioEngine.connect(systemInput, to: systemOutput, format: systemInput.outputFormat(forBus: 0))
        var ioBufferFrameSize: UInt32 = 32
        setCurrentIOBufferFrameSize(inAUHAL: systemInput.audioUnit!, inIOBufferFrameSize: &ioBufferFrameSize);
        do {
            try localAudioEngine.start()
        } catch let error {
            print(error)
        }
    }
    
    func stopLocalAudioConnection() {
        localAudioEngine.stop()
    }
    
    func setCurrentIOBufferFrameSize(inAUHAL: AudioUnit,
                                     inIOBufferFrameSize: inout UInt32) -> OSStatus {
        return AudioUnitSetProperty(inAUHAL,
                                    kAudioDevicePropertyBufferFrameSize,
                                    kAudioUnitScope_Global,
                                    0,
                                    &inIOBufferFrameSize,
                                    UInt32(MemoryLayout<UInt32>.size));
    }
}

extension AudioListener: AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        
        // generate a signature if we're connected
        if audioDetectionStatus == .detectingAudio && recognize {
            // need to make a PCM buffer here
            let numSamples = CMSampleBufferGetNumSamples(sampleBuffer)
            if let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) {
                let avFormat = AVAudioFormat(cmAudioFormatDescription: formatDescription)
                if let pcmBuffer = AVAudioPCMBuffer(pcmFormat: avFormat, frameCapacity: AVAudioFrameCount(numSamples)) {
                    pcmBuffer.frameLength = AVAudioFrameCount(numSamples)
                    CMSampleBufferCopyPCMDataIntoAudioBufferList(sampleBuffer, at: 0, frameCount: Int32(numSamples), into: pcmBuffer.mutableAudioBufferList)
                    shazamSession.matchStreamingBuffer(pcmBuffer, at: nil)
                }
            }
        }
        
        // downsample for perf
        if Date() > nextUIUpdateDate {
            if let channel = connection.audioChannels.first {
                    averagePowerLevel = channel.averagePowerLevel
                if channel.averagePowerLevel > Float(onThreshold) && audioDetectionStatus == .notDetectingAudio {
                    
                    // check time constraint
                    offDate = nil   // flip our offDate to nil, just in case
                    if let prevOnDate = onDate {
                        if prevOnDate.timeIntervalSinceNow <= (-1.0 * onLength) {
                            audioDetected()
                            onDate = nil
                        } else {
                            // do nothing; keep waiting
                        }
                    } else {
                        onDate = Date()
                    }
                } else if channel.averagePowerLevel < Float(offThreshold) && audioDetectionStatus == .detectingAudio {
                    if let prevOffDate = offDate {
                        
                        // check time constraint
                        onDate = nil    // flip our onDate to nil, just in case
                        if prevOffDate.timeIntervalSinceNow <= (-1.0 * offLength) {
                            audioNotDetected()
                            offDate = nil
                        }
                    } else {
                        offDate = Date()
                    }
                }
            }
            nextUIUpdateDate = Date(timeIntervalSinceNow: 1.0)
        }
    }
}

extension AudioListener: SHSessionDelegate {
    func session(_ session: SHSession, didFind match: SHMatch) {
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }
            if let mediaItem = match.mediaItems.first {
                
                let identifier = mediaItem.isrc ?? mediaItem.shazamID ?? "UNKNOWN-\(mediaItem.title?.replacingOccurrences(of: " ", with: "") ?? "UNKNOWN")"
                strongSelf.isrc = identifier
                
                // see if we have an override -- if we do, return early
                if let isrc = mediaItem.isrc, let metadataOverride = strongSelf.metadataOverrides.filter({ $0.isrc == isrc }).first {
                    strongSelf.albumTitle = metadataOverride.album
                    strongSelf.albumArtist = metadataOverride.artist
                    if let artworkURL = URL(string: metadataOverride.imageURL) {
                        if strongSelf.albumImageURL != artworkURL {
                            strongSelf.albumImageURL = artworkURL
                            DispatchQueue.global(qos: .background).async { [weak self] in
                                if let nsImage = NSImage(contentsOf: artworkURL) {
                                    let swiftImage = Image(nsImage: nsImage)
                                    let imageData = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
                                    DispatchQueue.main.async { [weak self] in
                                        guard let strongSelf = self else { return }
                                        withAnimation {
                                            strongSelf.albumImage = swiftImage
                                            if let data = imageData {
                                                strongSelf.albumImageData = data
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    return
                }
                
                defer {
                    // at the end of it all, grab whatever we set and store it
                    let metadataOverride = MetadataOverride(isrc: identifier,
                                                            album: strongSelf.albumTitle,
                                                            artist: strongSelf.albumArtist,
                                                            imageURL: strongSelf.albumImageURL?.absoluteString ?? "",
                                                            notes: "")
                    // prepend
                    strongSelf.metadataOverrides.insert(metadataOverride, at: 0)
                }
                
                let shAlbumKey: SHMediaItemProperty = SHMediaItemProperty("sh_albumName")
                if let matchedAlbumName = mediaItem[shAlbumKey] as? String {
                    strongSelf.albumTitle = matchedAlbumName
                    // Heuristic: Try to strip anything after "Feat." if the artist contains that
                    if let mediaItemArtist = mediaItem.artist, let featRange = mediaItemArtist.range(of: " feat.", options: .caseInsensitive) {
                        strongSelf.albumArtist = String(mediaItemArtist[mediaItemArtist.startIndex..<featRange.lowerBound])
                    } else {
                        strongSelf.albumArtist = mediaItem.artist ?? "Unknown Artist"
                    }
                    
                    strongSelf.recognize = false
                } else {
                    strongSelf.albumTitle = mediaItem.title ?? "Unknown Album"
                    strongSelf.albumArtist = mediaItem.subtitle ?? "Unknown Artist"
                    strongSelf.recognize = false
                }
                if let artworkURL = mediaItem.artworkURL {
                    if artworkURL != strongSelf.albumImageURL {
                        strongSelf.albumImageURL = artworkURL
                        DispatchQueue.global(qos: .background).async { [weak self] in
                            if let nsImage = NSImage(contentsOf: artworkURL) {
                                let swiftImage = Image(nsImage: nsImage)
                                DispatchQueue.main.async { [weak self] in
                                    guard let strongSelf = self else { return }
                                    withAnimation {
                                        strongSelf.albumImage = swiftImage
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                strongSelf.albumTitle = "Unknown Album"
                strongSelf.albumArtist = "Unknown Artist"
                strongSelf.albumImageURL = nil
            }
        }
    }
    
    func session(_ session: SHSession, didNotFindMatchFor signature: SHSignature, error: Error?) {
        if let description = error?.localizedDescription {
            print("Error Matching: " + description)
        }
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.albumTitle = "Unknown Album"
            strongSelf.albumArtist = "Unknown Artist"
            strongSelf.isrc = nil
            if let unknownAlbumImage = NSImage(named: Self.unknownAlbumImageName) {
                strongSelf.albumImage = Image(nsImage: unknownAlbumImage)
                strongSelf.albumImageURL = nil
            }
        }
    }
}
