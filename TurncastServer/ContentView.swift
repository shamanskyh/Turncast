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
            switch listener.recognitionStatus {
            case .waitingToRecognize:
                HStack(alignment: .center, spacing: 12.0) {
                    ZStack {
                        listener.albumImage.resizable().cornerRadius(6.0).frame(width: 100, height: 100)
                        if listener.downloadingImage {
                            ProgressView()
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        Text(listener.albumTitle).font(.headline)
                        Text(listener.albumArtist).font(.subheadline)
                    }
                }
            case .unknownAlbum:
                HStack(alignment: .center, spacing: 12.0) {
                    ZStack(alignment: Alignment(horizontal: .center, vertical: .bottom)) {
                        listener.albumImage.resizable().cornerRadius(6.0).frame(width: 100, height: 100)
                        if listener.downloadingImage {
                            ProgressView()
                        } else {
                            Button("Upload") {
                                self.showingImageImporter = true
                            }.padding(.bottom, 8.0)
                        }
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
                    ZStack {
                        listener.albumImage.resizable().cornerRadius(6.0).frame(width: 100, height: 100)
                        if listener.downloadingImage {
                            ProgressView()
                        }
                    }
                    VStack(alignment: .leading) {
                        Text(listener.albumTitle).font(.headline)
                        Text(listener.albumArtist).font(.subheadline)
                    }
                }
            }
            
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
        }
        .frame(width: 375, height: 250, alignment: .center)
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
    
    init(listener: AudioListener) {
        self.listener = listener
        self.formatter.maximumFractionDigits = 2
        self.formatter.minimumFractionDigits = 2
        self.formatter.numberStyle = .decimal
    }
}
