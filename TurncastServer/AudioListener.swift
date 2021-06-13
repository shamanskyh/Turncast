//
//  AudioListener.swift
//  Turncast
//
//  Created by Harry Shamansky on 11/29/20.
//  Copyright © 2020 Harry Shamansky. All rights reserved.
//

import AVFoundation
import Combine
import CreateML
import Foundation
import HaishinKit
import MultipeerMessages
import SoundAnalysis
import SwiftUI

class AudioListener: NSObject, ObservableObject, MetadataSource {
    
    let captureSession = AVCaptureSession()
    let audioOutput = AVCaptureAudioDataOutput()
    let recordingFileOutput = AVCaptureAudioFileOutput()
    let sampleFileOutput = AVCaptureAudioFileOutput()
    
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
    
    let sampleRate: Int = 8000
    @Published var connectionStatus = ConnectionStatus.disconnected
    @Published var averagePowerLevel: Float = Float.leastNormalMagnitude
    @Published var errorMessage: String? = nil
    @Published var training: Bool = false
    @Published var downloadingImage: Bool = false
    var nextUIUpdateDate = Date()
    var onDate: Date?
    var offDate: Date?
    var needsRetrain: Bool = false
    
    var captureDevice: AVCaptureDevice?
    var httpStream: HTTPStream?
    var httpService: HLSService?
    
    // metadata
    var shouldAllowEditing: Bool {
        switch self.recognitionStatus {
        case .unknownAlbum:
            return true
        case .knownAlbum(_):
            fallthrough
        case .waitingToRecognize:
            return false
        }
    }
    
    func beginImageDownload() {
        downloadingImage = true
    }
    
    func endImageDownload() {
        downloadingImage = false
    }
    
    internal var blockBroadcast = false
    let mlAnalysisQueue = DispatchQueue(label: "com.harryshamansky.turncastserver.ml_analysis_queue", qos: .background)
    var currentTrainingJob: MLJob<MLSoundClassifier>?
    var currentTrainingJobCancellable: AnyCancellable?
    private var resultsObserver: ResultsObserver?
    @Published var recognitionStatus = RecognitionStatus.waitingToRecognize
    fileprivate static let unknownAlbumImageName = "UnknownAlbum"
    var albumImageData: CGImage = NSImage(named: unknownAlbumImageName)!.cgImage(forProposedRect: nil, context: nil, hints: nil)! {
        willSet {
            objectWillChange.send()
            if !blockBroadcast {
                multipeerManager?.broadcast(message: .imageData(newValue.png!))
            }
        }
    }
    var albumImage = Image(unknownAlbumImageName) {
        willSet {
            objectWillChange.send()
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
    
    func updateRecognitionStateToNewMetadata() {
        recognitionStatus = .knownAlbum(Metadata(albumTitle: albumTitle, artist: albumArtist))
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
                
                // record locally to a file buffer too
                if captureSession.canAddOutput(recordingFileOutput) {
                    captureSession.addOutput(recordingFileOutput)
                }
                if captureSession.canAddOutput(sampleFileOutput) {
                    captureSession.addOutput(sampleFileOutput)
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
        if !pathToATVRemote.isEmpty && !appleTVID.isEmpty && !appleTVCredentials.isEmpty {
            AppleTVUtilities.openTurncast(atvRemotePath: pathToATVRemote,
                                          appleTVID: appleTVID,
                                          appleTVCredentials: appleTVCredentials)
        }
        
        // broadcast temporary data
        albumTitle = "Listening…"
        albumArtist = ""
        albumImageData = NSImage(named: AudioListener.unknownAlbumImageName)!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
        albumImage = Image(AudioListener.unknownAlbumImageName)
        
        // start by making our (long) recording
        if let currentRecordingURL = try? URLHelpers.urlForCurrentRecording() {
            try? FileManager.default.removeItem(at: currentRecordingURL)
            recordingFileOutput.audioSettings = [AVFormatIDKey: kAudioFormatMPEG4AAC_HE,
                                                 AVSampleRateKey: 16000.0,
                                                 AVNumberOfChannelsKey: 1]
            recordingFileOutput.startRecording(to: currentRecordingURL, outputFileType: .m4a, recordingDelegate: self)
        }
        
        // also start our sample recording, but wait `sampleDelay` seconds before doing so, so that we get more of the
        // meat of the song
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(Int(sampleDelay))) { [weak self] in
            self?.startSampleRecording()
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
    
    func startSampleRecording() {
        if let sampleRecordingURL = try? URLHelpers.urlForCurrentSample() {
            try? FileManager.default.removeItem(at: sampleRecordingURL)
            sampleFileOutput.audioSettings = [AVFormatIDKey: kAudioFormatMPEG4AAC_HE,
                                              AVSampleRateKey: 16000.0,
                                              AVNumberOfChannelsKey: 1]
            sampleFileOutput.startRecording(to: sampleRecordingURL, outputFileType: .m4a, recordingDelegate: self)
        }
        // prepare to stop our sample recording in `sampleLength` seconds.
        // We'll use the callback in our delegate to process it
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(Int(sampleLength))) { [weak self] in
            self?.sampleFileOutput.stopRecording()
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
                if strongSelf.needsRetrain {
                    strongSelf.trainAndSaveClassifier()
                    strongSelf.needsRetrain = false
                }
                strongSelf.httpStream = nil
                strongSelf.connectionStatus = .disconnected
            }
        }
        
        // set our connectionStatus
        connectionStatus = .waitingToDisconnect
        
        // stop our recordings
        sampleFileOutput.stopRecording()
        recordingFileOutput.stopRecording()
        
        // NOTE: do *not* call resetMetadata() here since that will also change our connectionStatus.
        // The calls above that end the recordings will call through to resetMetadata() where appropriate.
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

extension AudioListener: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        guard let sampleURL = try? URLHelpers.urlForCurrentSample(),
              let recordingURL = try? URLHelpers.urlForCurrentRecording() else { return }
        
        // if this is the sample that's finished, see if we have a good confidence level.
        if outputFileURL == sampleURL {
            checkForKnownAudio(url: outputFileURL) { [weak self] (metadata, image, confidence) in
                guard let strongSelf = self else { return }
                if let metadata = metadata {
                    // if we have a match, display the metadata
                    strongSelf.recognitionStatus = .knownAlbum(metadata)
                    strongSelf.albumTitle = metadata.albumTitle
                    strongSelf.albumArtist = metadata.artist
                    if let image = image {
                        strongSelf.albumImageData = image
                        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
                        strongSelf.albumImage = Image(nsImage: nsImage)
                    }
                    strongSelf.multipeerManager?.broadcast(message: confidence > 0.95 ? .canEdit(false) : .canEdit(true))
                } else {
                    // if we don't, open up the prompt to add metadata.
                    strongSelf.recognitionStatus = .unknownAlbum
                    strongSelf.albumTitle = Self.unknownAlbum
                    strongSelf.albumArtist = Self.unknownArtist
                    strongSelf.multipeerManager?.broadcast(message: .canEdit(true))
                }
            }
        } else if outputFileURL == recordingURL {
            // if this is the longer recording...
            switch recognitionStatus {
            case .knownAlbum(let metadata):
                // if we knew what the song was, save the sample alongside the others
                if let albumDirectory = try? URLHelpers.urlForAlbumDirectory(artist: metadata.artist, album: metadata.albumTitle) {
                    let newFileURL = albumDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
                    var otherSoundFiles = [URL]()
                    do {
                        otherSoundFiles = try FileManager.default.contentsOfDirectory(at: albumDirectory, includingPropertiesForKeys: nil)
                    } catch {
                        print("Could not determine other sound files in directory")
                    }

                    if otherSoundFiles.filter({ $0.pathExtension == "m4a" }).count <= maxFiles {
                        do {
                           try FileManager.default.moveItem(at: outputFileURL, to: newFileURL)
                        } catch {
                            print(error)
                        }
                    }
                    
                    // update image and metadata just in case
                    let encoder = JSONEncoder()
                    if let metadataData = try? encoder.encode(metadata),
                       let urlForMetadata = try? URLHelpers.urlForAlbumMetadata(artist: albumArtist, album: albumTitle),
                       let urlForImageData = try? URLHelpers.urlForAlbumImage(artist: albumArtist, album: albumTitle) {
                        do {
                            try metadataData.write(to: urlForMetadata)
                            try albumImageData.write(to: urlForImageData)
                        } catch {
                            print(error)
                        }
                    }
                    
                    resetMetadata()
                    needsRetrain = true
                }
            case .unknownAlbum:
                // new album - save the info. Should be fine if these directories already exist (like this is the b-side)
                
                if albumArtist != AudioListener.unknownArtist &&
                    albumTitle != AudioListener.unknownAlbum {
                    let metadata = Metadata(albumTitle: albumTitle, artist: albumArtist)
                    let encoder = JSONEncoder()
                    if let metadataData = try? encoder.encode(metadata),
                       let urlForMetadata = try? URLHelpers.urlForAlbumMetadata(artist: albumArtist, album: albumTitle),
                       let urlForImageData = try? URLHelpers.urlForAlbumImage(artist: albumArtist, album: albumTitle),
                       let albumDirectory = try? URLHelpers.urlForAlbumDirectory(artist: albumArtist, album: albumTitle) {
                        do {
                            try metadataData.write(to: urlForMetadata)
                            try albumImageData.write(to: urlForImageData)
                            let newFileURL = albumDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
                            try FileManager.default.moveItem(at: outputFileURL, to: newFileURL)
                        } catch {
                            print(error)
                        }
                        
                        resetMetadata()
                        needsRetrain = true
                    }
                } else {
                    resetMetadata()
                }
            case .waitingToRecognize:
                break
            }
        } else {
            fatalError("Unknown recording finished")
        }
    }
    
    func checkForKnownAudio(url: URL, completion: @escaping (Metadata?, CGImage?, Double) -> ()) {
        mlAnalysisQueue.async { [weak self] in
            do {
                guard let strongSelf = self else { return }
                let audioFileAnalyzer = try SNAudioFileAnalyzer(url: url)
                strongSelf.resultsObserver = ResultsObserver(callback: completion)
                let urlForModel = try URLHelpers.urlForCompiledAlbumClassifier()
                let model = try MLModel(contentsOf: urlForModel)
                let request = try SNClassifySoundRequest(mlModel: model)
                if let observer = strongSelf.resultsObserver {
                    try audioFileAnalyzer.add(request, withObserver: observer)
                }
                audioFileAnalyzer.analyze()
            } catch {
                print(error)
                DispatchQueue.main.async {
                    completion(nil, nil, 0.0)
                }
            }
        }
    }
    
    func resetMetadata() {
        objectWillChange.send()
        recognitionStatus = .waitingToRecognize
        multipeerManager?.broadcast(message: .canEdit(false))
        albumTitle = AudioListener.notPlayingAlbum
        albumArtist = AudioListener.notPlayingArtist
        albumImage = Image(AudioListener.unknownAlbumImageName)
        albumImageData = NSImage(named: AudioListener.unknownAlbumImageName)!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
    }
    
    func trainAndSaveClassifier() {
        if let trainingDataURL = try? URLHelpers.urlForTrainingData(),
           let modelURL = try? URLHelpers.urlForAlbumClassifier(),
           let compiledModelURL = try? URLHelpers.urlForCompiledAlbumClassifier() {
            do {
                training = true
                print("Starting to train model")
                currentTrainingJob?.cancel()
                currentTrainingJob = try MLSoundClassifier.train(trainingData: .labeledDirectories(at: trainingDataURL))
                currentTrainingJobCancellable = currentTrainingJob?.result
                    .receive(on: RunLoop.main)
                    .sink(receiveCompletion: { completion in
                        print(completion)
                    }, receiveValue: { [weak self] classifier in
                        try? classifier.write(to: modelURL)
                        if let tempCompiledURL = try? MLModel.compileModel(at: modelURL) {
                            let _ = try? FileManager.default.replaceItemAt(compiledModelURL, withItemAt: tempCompiledURL)
                        }
                        self?.training = false
                    })
            } catch {
                print(error)
            }
        }
    }
    
    func cancelTraining() {
        currentTrainingJobCancellable?.cancel()
        currentTrainingJob?.cancel()
        currentTrainingJobCancellable = nil
        currentTrainingJob = nil
        training = false
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
