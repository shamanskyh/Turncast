//
//  AudioListener.swift
//  Tinfoil
//
//  Created by Harry Shamansky on 11/29/20.
//  Copyright © 2020 Harry Shamansky. All rights reserved.
//

import AVFoundation
import Foundation
import SwiftUI

class AudioListener: NSObject, ObservableObject {
    
    let captureSession = AVCaptureSession()
    let audioOutput = AVCaptureAudioDataOutput()
    
    @AppStorage("inputName") var inputName: String = "Turntable"
    @AppStorage("outputNames") var outputNames: String = "Main Area"
    @AppStorage("offThreshold") var offThreshold: Double = -40.0
    @AppStorage("onThreshold") var onThreshold: Double = -45.0
    @AppStorage("changeVolume") var changeVolume: Bool = true {
        willSet {
            objectWillChange.send()
        }
    }
    @AppStorage("initialVolume") var initialVolume: Double = 0.2
    
    let sampleRate: Int = 8000
    @Published var connectionStatus = ConnectionStatus.disconnected
    @Published var averagePowerLevel: Float = Float.leastNormalMagnitude
    @Published var errorMessage: String? = nil
    var nextUIUpdateDate = Date()
    
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
    
    func connectToHomePods() {
        print("\nConnecting to HomePods")
        connectionStatus = .connected
        
        // build the connection string
        var connectionScriptSource = "tell Application \"Airfoil\"\n"
        if !inputName.isEmpty {
            connectionScriptSource += "    set inputSource to first device source whose name contains \"\(inputName)\"\n"
            connectionScriptSource += "    set current audio source to inputSource\n"
        }
        
        for (index, speakerName) in outputNames.split(separator: ",").enumerated() {
            connectionScriptSource += "    set speaker\(index) to first speaker whose name is \"\(speakerName)\"\n"
            if changeVolume, let decimalVolume = AudioListener.numberFormatter.string(from: NSNumber(floatLiteral: initialVolume)) {
                connectionScriptSource += "    set (volume of speaker\(index)) to \(decimalVolume)\n"
            }
            connectionScriptSource += "    connect to speaker\(index)\n"
        }
        
        connectionScriptSource += "end tell\n"
        
        let connectionScript = NSAppleScript(source: connectionScriptSource)
        var errorDictionary: NSDictionary? = nil
        connectionScript?.executeAndReturnError(&errorDictionary)
        if let _ = errorDictionary {
            connectionStatus = .disconnected
        }
    }
    
    func disconnectFromHomePods() {
        print("\nDisconnecting from HomePods")
        connectionStatus = .disconnected
        
        var disconnectScriptSource = "tell application \"Airfoil\"\n"
        
        for (index, speakerName) in outputNames.split(separator: ",").enumerated() {
            disconnectScriptSource += "    set speaker\(index) to first speaker whose name is \"\(speakerName)\"\n"
            disconnectScriptSource += "    disconnect from speaker\(index)\n"
        }
        
        disconnectScriptSource += "end tell\n"
        
        let disconnectScript = NSAppleScript(source: disconnectScriptSource)
        var errorDictionary: NSDictionary? = nil
        disconnectScript?.executeAndReturnError(&errorDictionary)
        if let _ = errorDictionary {
            connectionStatus = .connected
        }
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
                if channel.averagePowerLevel > Float(onThreshold) && connectionStatus == .disconnected {
                    connectToHomePods()
                } else if channel.averagePowerLevel < Float(offThreshold) && connectionStatus == .connected {
                    disconnectFromHomePods()
                }
            }
            nextUIUpdateDate = Date(timeIntervalSinceNow: 1.0)
        }
    }
}
