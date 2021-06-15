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
import SwiftUI

class AudioListener: NSObject, ObservableObject {
    
    let captureSession = AVCaptureSession()
    let audioOutput = AVCaptureAudioDataOutput()
    
    @AppStorage("inputName") var inputName: String = "iMic"
    @AppStorage("offThreshold") var offThreshold: Double = -47.0
    @AppStorage("onThreshold") var onThreshold: Double = -30.0
    @AppStorage("disconnectDelay") var disconnectDelay: Double = 1200.0
    @AppStorage("onLength") var onLength: Double = 2.0
    @AppStorage("offLength") var offLength: Double = 4.0
    @AppStorage("startAppleTV") var startAppleTV: Bool = false
    @AppStorage("pathToAtvRemote") var pathToATVRemote: String = ""
    @AppStorage("appleTVID") var appleTVID: String = ""
    @AppStorage("appleTVCredentials") var appleTVCredentials: String = ""
    
    let sampleRate: Int = 8000
    @Published var connectionStatus = ConnectionStatus.disconnected
    @Published var averagePowerLevel: Float = Float.leastNormalMagnitude
    @Published var errorMessage: String? = nil
    var nextUIUpdateDate = Date()
    var onDate: Date?
    var offDate: Date?
    
    var captureDevice: AVCaptureDevice?
    var httpStream: HTTPStream?
    var httpService: HLSService?
    
    static var numberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }
    
    func beginListening() {
        
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
    
    func beginStreaming() {
        if connectionStatus == .waitingToDisconnect {
            connectionStatus = .connected
        }
        
        // connect to our apple tv if we have one
        if startAppleTV && !pathToATVRemote.isEmpty && !appleTVID.isEmpty && !appleTVCredentials.isEmpty {
            AppleTVUtilities.openTurncast(atvRemotePath: pathToATVRemote,
                                          appleTVID: appleTVID,
                                          appleTVCredentials: appleTVCredentials)
        }
        
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
    }
}

extension AudioListener: AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        
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
