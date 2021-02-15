//
//  ContentView.swift
//  Turncast
//
//  Created by Harry Shamansky on 4/26/20.
//  Copyright © 2020 Harry Shamansky. All rights reserved.
//

import Foundation
import SwiftUI

struct ContentView: View {
    
    @ObservedObject var listener: AudioListener
    let formatter = NumberFormatter()
    
    @State var showingImageImporter = false

    var body: some View {
        VStack(spacing: 20.0) {
            Spacer(minLength: 20.0)
            
            switch listener.recognitionStatus {
            case .waitingToRecognize:
                HStack(alignment: .center, spacing: 12.0) {
                    listener.albumImage.resizable().cornerRadius(6.0).frame(width: 100, height: 100)
                    VStack(alignment: .leading) {
                        Text(listener.albumTitle).font(.headline)
                        Text(listener.albumArtist).font(.subheadline)
                    }
                }
            case .unknownAlbum:
                HStack(alignment: .center, spacing: 12.0) {
                    ZStack(alignment: Alignment(horizontal: .center, vertical: .bottom)) {
                        listener.albumImage.resizable().cornerRadius(6.0).frame(width: 100, height: 100)
                        Button("Upload") {
                            self.showingImageImporter = true
                        }.padding(.bottom, 8.0)
                    }
                    VStack(alignment: .leading) {
                        TextField("Unknown Album", text: $listener.albumTitle)
                            .font(.headline)
                            .frame(width: 200.0)
                        TextField("Unknown Artist", text: $listener.albumArtist)
                            .font(.subheadline)
                            .frame(width: 200.0)
                    }
                }
            default:
                HStack(alignment: .center, spacing: 12.0) {
                    listener.albumImage.resizable().cornerRadius(6.0).frame(width: 100, height: 100)
                    VStack(alignment: .leading) {
                        Text(listener.albumTitle).font(.headline)
                        Text(listener.albumArtist).font(.subheadline)
                    }
                }
            }
            
            Spacer(minLength: 20.0)
            if listener.errorMessage != nil {
                Text(listener.errorMessage!)
                    .lineLimit(nil)
                    .foregroundColor(.red)
                    .padding()
                Button(action: {
                    self.listener.beginListening()
                }, label: { Text("Reconnect") }).padding()
            } else {
                switch listener.connectionStatus {
                case .connected:
                    Text("Connected".uppercased())
                        .foregroundColor(.white)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 12.0, style: .continuous)
                            .foregroundColor(.green))
                case .disconnected:
                    Text("Not Connected".uppercased())
                        .foregroundColor(.white)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 12.0, style: .continuous)
                            .foregroundColor(.red))
                case .waitingToDisconnect:
                    Text("Waiting to Disconnect".uppercased())
                        .foregroundColor(.white)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 12.0, style: .continuous)
                            .foregroundColor(.orange))
                }
                if listener.averagePowerLevel == Float.leastNormalMagnitude {
                    Text("Audio Level: -∞ dB")
                } else {
                    Text("Audio Level: \(formatter.string(from: NSNumber(value: listener.averagePowerLevel)) ?? "") dB").font(Font.body.monospacedDigit())
                }
            }
            Form {
                HStack {
                    Text("Input Name")
                    TextField("Input Name", text: $listener.inputName)
                        .help("What input source should Airfoil select when Turncast detects input? This is usually the name of your USB audio input. Leave blank if this should go unchanged.")
                }
                HStack {
                    Text("On Threshold")
                    DecimalField("On Threshold", value: $listener.onThreshold, formatter: decibelFormatter)
                        .help("At what volume level (or greater) should Turncast begin the HTTP stream?")
                    Text("dB")
                }
                HStack {
                    Text("On Delay")
                    DecimalField("On Delay", value: $listener.onLength, formatter: secondsFormatter)
                        .help("How long, in seconds, should Turncast detect audio above the 'On Threshold' before beginning?")
                    Text("seconds")
                }
                HStack {
                    Text("Off Threshold")
                    DecimalField("Off Threshold", value: $listener.offThreshold, formatter: decibelFormatter)
                        .help("At what volume level (or less) should Turncast schedule disconnection?")
                    Text("dB")
                }
                HStack {
                    Text("Off Delay")
                    DecimalField("Off Delay", value: $listener.offLength, formatter: secondsFormatter)
                        .help("How long, in seconds, should Turncast detect audio below the 'Off Threshold' before stopping?")
                    Text("seconds")
                }
                HStack {
                    Text("Disconnect Delay")
                    DecimalField("Disconnect Delay", value: $listener.disconnectDelay, formatter: secondsFormatter)
                        .help("How long, in seconds, after Turncast turns off should it disconnect the stream? Note that this value refers to the HTTP streaming capability and not the audio threshold levels defined by the 'Off Delay'")
                    Text("seconds")
                }
                HStack {
                    Text("Sample Length")
                    DecimalField("Sample Length", value: $listener.sampleLength, formatter: secondsFormatter)
                        .help("How long a sample should Turncast record before performing audio analysis?")
                    Text("seconds")
                }
                HStack {
                    Text("Sample Delay")
                    DecimalField("Sample Delay", value: $listener.sampleDelay, formatter: secondsFormatter)
                        .help("How long after connection should Turncast begin sampling for recognition?")
                    Text("seconds")
                }
                HStack {
                    Text("Max Files per Album to Train").layoutPriority(1)
                    IntegerField("Max Files per Album to Train", value: $listener.maxFiles, formatter: secondsFormatter)
                        .help("How long after connection should Turncast begin sampling for recognition?")
                }
                HStack {
                    if listener.training {
                        Button(action: {
                            self.listener.cancelTraining()
                        }) {
                            Text("Cancel Training")
                        }
                        if let progress = listener.currentTrainingJob?.progress {
                            ProgressView(progress).labelsHidden()
                        }
                    } else {
                        Button(action: {
                            self.listener.trainAndSaveClassifier()
                        }) {
                            Text("Retrain Model")
                        }
                    }
                }
            }.padding()
        }
        .onAppear {
            self.listener.beginListening()
        }
        .fileImporter(isPresented: $showingImageImporter, allowedContentTypes: [.image]) { (result) in
            do {
                let selectedFile: URL = try result.get()
                if let nsImage = NSImage(contentsOf: selectedFile) {
                    let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
                    listener.albumImage = Image(nsImage: nsImage)
                    listener.albumImageData = cgImage!
                }
            } catch {
                print(error)
            }
        }
    }
    
    var decibelFormatter: NumberFormatter {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.isLenient = true
        return nf
    }
    
    var secondsFormatter: NumberFormatter {
        let nf = NumberFormatter()
        nf.numberStyle = .none
        nf.isLenient = true
        return nf
    }
    
    init(listener: AudioListener) {
        self.listener = listener
        self.formatter.maximumFractionDigits = 2
        self.formatter.minimumFractionDigits = 2
        self.formatter.numberStyle = .decimal
    }
}

extension Float {
    func truncate(places : Int)-> Float {
        return Float(floor(pow(10.0, Float(places)) * self)/pow(10.0, Float(places)))
    }
}
