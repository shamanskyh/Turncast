//
//  ContentView.swift
//  Shared
//
//  Created by Harry Shamansky on 12/27/20.
//  Copyright © 2020 Harry Shamansky. All rights reserved.
//

import AVFoundation
import SwiftUI

struct ContentView: View {
    
    @StateObject var streamSource = StreamSource()
    @StateObject var metadataStore = MetadataStore()
    
    @State var backgroundOpacity: Double = 0.0
    @State var backgroundPlaceholderOpacity: Double = 1.0
    
    let multipeerManager = MultipeerManager.shared
    
    var body: some View {
        // we want to expand
        GeometryReader { _ in
            HStack {
                Spacer()
                VStack(alignment: .center) {
                    metadataStore.albumImage
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(12.0)
                        .shadow(color: Color.black.opacity(0.4), radius: 8)
                        .padding(30.0)
                    Text(metadataStore.albumTitle).font(.headline)
                    Text(metadataStore.artist).font(.subheadline)
                    HStack {
                        #if os(iOS)
                        playStopButton
                            .font(.title)
                            .frame(width: 50, height: 50)
                        AirPlayRoutePickerView()
                            .frame(width: 50, height: 50)
                        #elseif os(tvOS)
                        playStopButton
                        AirPlayRoutePickerView()
                            .frame(width: 50, height: 50)
                        #endif
                    }.padding(20)
                }.padding(20)
                .preferredColorScheme(.dark)
                Spacer()
            }
        }
        .background(alignment: .center) {
            ZStack {
                MeshGradient(image: nil, opacity: $backgroundPlaceholderOpacity)
                if metadataStore.albumImage != Image("NoInfo") {
                    MeshGradient(image: UIImage(cgImage: metadataStore.albumImageData), opacity: $backgroundOpacity)
                }
                Rectangle().foregroundColor(.black).opacity(0.2)
            }.edgesIgnoringSafeArea(.all)
        }
        .onAppear {
            metadataStore.multipeerManager = multipeerManager
            multipeerManager.metadataStore = metadataStore
            multipeerManager.streamSource = streamSource
            streamSource.multipeerManager = multipeerManager
        }
    }
    
    var albumArtCornerRadius: CGFloat {
        #if os(tvOS)
        return 12.0
        #else
        return 6.0
        #endif
    }
    
    var playStopButton: some View {
        Button(action: {
            streamSource.playing.toggle()
        }) {
            if streamSource.playing {
                #if os(tvOS)
                Image(systemName: "stop.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 30)
                    .padding(EdgeInsets(top: 9, leading: 0, bottom: 8, trailing: 0))
                #else
                Image(systemName: "stop.fill")
                #endif
            } else {
                #if os(tvOS)
                Image(systemName: "play.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 30)
                    .padding(EdgeInsets(top: 9, leading: 0, bottom: 8, trailing: 0))
                #else
                Image(systemName: "play.fill")
                #endif
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
