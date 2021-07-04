//
//  AudioListener.swift
//  Turncast
//
//  Created by Harry Shamansky on 11/29/20.
//  Copyright © 2020 Harry Shamansky. All rights reserved.
//

import AVFoundation
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
    @AppStorage("launchAppleTV") var launchAppleTV: Bool = false
    @AppStorage("pathToAtvRemote") var pathToATVRemote: String = ""
    @AppStorage("appleTVID") var appleTVID: String = ""
    @AppStorage("appleTVCredentials") var appleTVCredentials: String = ""
    @AppStorage("MetadataOverrides") var metadataOverrides: [MetadataOverride] = []
    
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
    
    internal var recognize = false
    
    internal var blockBroadcast = false
    fileprivate static let unknownAlbumImageName = "UnknownAlbum"
    var albumImage = Image(unknownAlbumImageName) {
        willSet {
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
    fileprivate static let notPlayingArtist = ""
    var albumArtist = notPlayingArtist {
        willSet {
            objectWillChange.send()
            if !blockBroadcast {
                multipeerManager?.broadcast(message: .artist(newValue))
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
            let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInMicrophone], mediaType: nil, position: AVCaptureDevice.Position.unspecified)
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
                
                captureSession.commitConfiguration()
                captureSession.startRunning()
                print("Began running capture session")
            } else {
                captureSession.commitConfiguration()
                errorMessage = "Cannot find audio device containing \"\(inputName)\""
            }
        }
        
        // start streaming
        httpStream = HTTPStream()
        if let device = captureDevice, let stream = httpStream {
            
            stream.attachAudio(device)
            stream.publish("turntable")

            httpService = HLSService(domain: "", type: "_http._tcp", name: "HaishinKit", port: 8080)
            httpService?.addHTTPStream(stream)
            httpService?.startRunning()
        }
    }

    /// must be called on main
    func audioDetected() {
        recognize = true
        
        // connect to our apple tv if we have one
        if !pathToATVRemote.isEmpty && !appleTVID.isEmpty && !appleTVCredentials.isEmpty {
            AppleTVUtilities.openTurncast(atvRemotePath: pathToATVRemote,
                                          appleTVID: appleTVID,
                                          appleTVCredentials: appleTVCredentials)
        }
        
        // broadcast temporary data
        albumTitle = "Listening…"
        albumArtist = ""
        albumImageURL = nil
        albumImage = Image(AudioListener.unknownAlbumImageName)
        
        audioDetectionStatus = .detectingAudio
    }
    
    /// Must be called on main
    func audioNotDetected() {
        // stop recognizing
        recognize = false
        
        // reset metadata
        albumTitle = Self.notPlayingAlbum
        albumArtist = Self.notPlayingArtist
        albumImageURL = nil
        
        audioDetectionStatus = .notDetectingAudio
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
                
                // see if we have an override -- if we do, return early
                if let isrc = mediaItem.isrc, let metadataOverride = strongSelf.metadataOverrides.filter({ $0.isrc == isrc }).first {
                    strongSelf.albumTitle = metadataOverride.album
                    strongSelf.albumArtist = metadataOverride.artist
                    if let artworkURL = URL(string: metadataOverride.imageURL) {
                        strongSelf.albumImageURL = artworkURL
                        DispatchQueue.global(qos: .background).async { [weak self] in
                            if let nsImage = NSImage(contentsOf: artworkURL) {
                                let swiftImage = Image(nsImage: nsImage)
                                DispatchQueue.main.async { [weak self] in
                                    guard let strongSelf = self else { return }
                                    strongSelf.albumImage = swiftImage
                                }
                            }
                        }
                    }
                    return
                }
                
                defer {
                    // at the end of it all, grab whatever we set and store it
                    let metadataOverride = MetadataOverride(isrc: mediaItem.isrc ?? "\(Date())",
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
                    strongSelf.albumImageURL = artworkURL
                    DispatchQueue.global(qos: .background).async { [weak self] in
                        if let nsImage = NSImage(contentsOf: artworkURL) {
                            let swiftImage = Image(nsImage: nsImage)
                            DispatchQueue.main.async { [weak self] in
                                guard let strongSelf = self else { return }
                                strongSelf.albumImage = swiftImage
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
            if let unknownAlbumImage = NSImage(named: Self.unknownAlbumImageName) {
                strongSelf.albumImage = Image(nsImage: unknownAlbumImage)
                strongSelf.albumImageURL = nil
            }
        }
    }
}
