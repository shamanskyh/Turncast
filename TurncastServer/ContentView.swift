//
//  ContentView.swift
//  Turncast
//
//  Created by Harry Shamansky on 4/26/20.
//  Copyright © 2020 Harry Shamansky. All rights reserved.
//

import Foundation
import SwiftUI
import QuartzCore

struct ContentView: View {
    
    @ObservedObject var listener: AudioListener
    let formatter = NumberFormatter()
    
    @State var isFullscreenPresentation = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .center) {
                VStack(spacing: isFullscreenPresentation ? 0.0 : 20.0) {
                    if isFullscreenPresentation {
                        listener.albumImage
                            .resizable()
                            .cornerRadius(20.0)
                            .frame(width: proxy.size.height / 2.0, height: proxy.size.height / 2.0)
                            .tag("AlbumImage")
                        Text(listener.albumTitle)
                            .font(.largeTitle)
                            .foregroundStyle(.white)
                            .bold()
                            .tag("AlbumTitle")
                            .padding(.top, proxy.size.height / 10.0)
                        Text(listener.albumArtist)
                            .font(.title)
                            .foregroundStyle(.white)
                            .opacity(0.75)
                            .tag("AlbumArtist")
                            .padding(.top, 5.0)
                    } else {
                        HStack(alignment: .center, spacing: 12.0) {
                            listener.albumImage
                                .resizable()
                                .cornerRadius(6.0)
                                .frame(width: 100, height: 100)
                                .tag("AlbumImage")
                            VStack(alignment: .leading) {
                                Text(listener.albumTitle)
                                    .font(.headline)
                                    .tag("AlbumTitle")
                                Text(listener.albumArtist)
                                    .font(.subheadline)
                                    .opacity(0.75)
                                    .tag("AlbumArtist")
                            }.foregroundStyle(.white)
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
                            switch listener.audioDetectionStatus {
                            case .detectingAudio:
                                Text("Playing".uppercased())
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(RoundedRectangle(cornerRadius: 12.0, style: .continuous)
                                        .foregroundColor(.green))
                            case .notDetectingAudio:
                                Text("Not Playing".uppercased())
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(RoundedRectangle(cornerRadius: 12.0, style: .continuous)
                                        .foregroundColor(.red))
                            }
                            if listener.averagePowerLevel == Float.leastNormalMagnitude {
                                Text("Audio Level: -∞ dB")
                            } else {
                                Text("Audio Level: \(formatter.string(from: NSNumber(value: listener.averagePowerLevel)) ?? "") dB").font(Font.body.monospacedDigit())
                            }
                        }
                    }
                }.frame(width: 375, height: 250, alignment: .center)
            }.frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
        }
        .background {
            MeshGradient(image: NSImage(cgImage: listener.albumImageData, size: CGSize(width: listener.albumImageData.height, height: listener.albumImageData.width)))
                .edgesIgnoringSafeArea(.all)
                .id(listener.albumImageData.hashValue)
        }
        .onAppear {
            self.listener.beginListening()
        }
        .onChange(of: listener.audioDetectionStatus) { oldValue, newValue in
            if oldValue == .notDetectingAudio &&
                newValue == .detectingAudio &&
                listener.enterFullscreenWhenListening {
                withAnimation {
                    CGDisplayHideCursor(CGMainDisplayID())
                    NSApplication.shared.mainWindow?.toggleFullScreen(nil)
                }
            } else if oldValue == .detectingAudio &&
                        newValue == .notDetectingAudio &&
                        listener.exitFullscreenWhenStopped {
                withAnimation {
                    CGDisplayShowCursor(CGMainDisplayID())
                    NSApplication.shared.mainWindow?.toggleFullScreen(nil)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willEnterFullScreenNotification)) { notification in
            // note: we don't need to check window here because we only have one for the entire app
            isFullscreenPresentation = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willExitFullScreenNotification)) { notification in
            isFullscreenPresentation = false
        }
    }
    
    init(listener: AudioListener) {
        self.listener = listener
        self.formatter.maximumFractionDigits = 2
        self.formatter.minimumFractionDigits = 2
        self.formatter.numberStyle = .decimal
    }
}
