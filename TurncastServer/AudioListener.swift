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
    @AppStorage("disconnectDelay") var disconnectDelay: Double = 1200.0
    @AppStorage("sampleLength") var sampleLength: Double = 5.0
    @AppStorage("sampleDelay") var sampleDelay: Double = 10.0
    @AppStorage("onLength") var onLength: Double = 2.0
    @AppStorage("offLength") var offLength: Double = 4.0
    @AppStorage("maxFiles") var maxFiles: Int = 8
    @AppStorage("pathToAtvRemote") var pathToATVRemote: String = ""
    @AppStorage("appleTVID") var appleTVID: String = ""
    @AppStorage("appleTVCredentials") var appleTVCredentials: String = ""
    
    let sampleRate: Int = 16000
    @Published var connectionStatus = ConnectionStatus.disconnected
    @Published var averagePowerLevel: Float = Float.leastNormalMagnitude
    @Published var errorMessage: String? = nil
    var nextUIUpdateDate = Date()
    var onDate: Date?
    var offDate: Date?
    
    var captureDevice: AVCaptureDevice?
    var httpStream: HTTPStream?
    var httpService: HLSService?
    
    internal var recognize = true {
        didSet {
            if !recognize {
                // reset our session
                shazamSession = SHSession()
            }
        }
    }
    
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
                                                     AVFormatIDKey: NSNumber(integerLiteral: existingFormatID)]
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
    }
    
    /// must be called on main
    func beginStreaming() {
        recognize = true
        
        if connectionStatus == .waitingToDisconnect {
            connectionStatus = .connected
        }
        
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
        
        // Stream
        httpStream = HTTPStream()
        
        if let device = captureDevice, let stream = httpStream {
            
            stream.attachAudio(device)
            stream.publish("turntable")

            httpService = HLSService(domain: "", type: "_http._tcp", name: "HaishinKit", port: 8080)
            httpService?.addHTTPStream(stream)
            httpService?.startRunning()
            
            connectionStatus = .connected
        } else {
            connectionStatus = .disconnected
            errorMessage = "Could not start HTTP stream/service"
        }
    }
    
    /// Must be called on main
    func endStreaming() {
        let service = httpService
        let stream = httpStream
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(Int(disconnectDelay))) { [weak self] in
            guard let strongSelf = self else { return }
            if strongSelf.connectionStatus == .waitingToDisconnect {
                if let stream = stream {
                    stream.attachAudio(nil)
                    service?.removeHTTPStream(stream)
                    service?.stopRunning()
                    stream.publish(nil)
                }
                strongSelf.httpStream = nil
                strongSelf.connectionStatus = .disconnected
            }
        }
        
        // set our connectionStatus
        connectionStatus = .waitingToDisconnect
        
        // prepare to recognize again
        recognize = true
    }
}

extension AudioListener: AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        
        // generate a signature if we're connected
        if connectionStatus == .connected && recognize {
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
                if channel.averagePowerLevel > Float(onThreshold) && (connectionStatus == .disconnected || connectionStatus == .waitingToDisconnect) {
                    
                    // check time constraint
                    offDate = nil   // flip our offDate to nil, just in case
                    if let prevOnDate = onDate {
                        if prevOnDate.timeIntervalSinceNow <= (-1.0 * onLength) {
                            beginStreaming()
                            onDate = nil
                        } else {
                            // do nothing; keep waiting
                        }
                    } else {
                        onDate = Date()
                    }
                } else if channel.averagePowerLevel < Float(offThreshold) && connectionStatus == .connected {
                    if let prevOffDate = offDate {
                        
                        // check time constraint
                        onDate = nil    // flip our onDate to nil, just in case
                        if prevOffDate.timeIntervalSinceNow <= (-1.0 * offLength) {
                            endStreaming()
                            offDate = nil
                        } else {
                            // do nothing; keep waiting
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
                let shAlbumKey: SHMediaItemProperty = SHMediaItemProperty("sh_albumName")
                if let matchedAlbumName = mediaItem[shAlbumKey] as? String {
                    strongSelf.albumTitle = matchedAlbumName
                    strongSelf.albumArtist = mediaItem.artist ?? "Unknown Artist"
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
                            DispatchQueue.main.async {
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

extension CGImage {
    
    enum CGImageWritingError: Error {
        case imageDestinationCreationError
        case imageFinalizationError
    }
    
    func write(to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypePNG, 1, nil) else { throw CGImageWritingError.imageDestinationCreationError }
        CGImageDestinationAddImage(destination, self, nil)
        if !CGImageDestinationFinalize(destination) {
            throw CGImageWritingError.imageFinalizationError
        }
    }
}
