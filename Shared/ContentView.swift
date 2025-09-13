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

    @State var showingEditMetadataModal: Bool = false
    
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
                        .focusable()
                        .contextMenu {
                            Button {
                                showingEditMetadataModal = true
                            } label: {
                                Label("Edit Metadata", systemImage: "pencil")
                            }
                        }
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
                        #endif
                    }.padding(20)
                }.padding(20)
                .preferredColorScheme(.dark)
                Spacer()
            }
        }
        .background(alignment: .center) {
            ZStack {
                HSSMeshGradient(image: nil)
                if metadataStore.albumImage != Image("NoInfo") {
                    HSSMeshGradient(image: UIImage(cgImage: metadataStore.albumImageData))
                }
                Rectangle().foregroundColor(.black).opacity(0.25)
            }.edgesIgnoringSafeArea(.all)
        }
        .onAppear {
            metadataStore.multipeerManager = multipeerManager
            multipeerManager.metadataStore = metadataStore
            multipeerManager.streamSource = streamSource
            streamSource.multipeerManager = multipeerManager
        }
        .sheet(isPresented: $showingEditMetadataModal) {
            SearchForAlbumView()
        }
    }
    
    var albumArtCornerRadius: CGFloat {
        #if os(tvOS)
        return 12.0
        #else
        return 6.0
        #endif
    }
    
    var albumArtSize: CGFloat {
        #if os(tvOS)
        return 600.0
        #else
        return 200.0
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
                    .padding(6)
                    .frame(width: 44, height: 44)
                #else
                Image(systemName: "stop.fill")
                #endif
            } else {
                #if os(tvOS)
                Image(systemName: "play.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(6)
                    .frame(width: 44, height: 44)
                #else
                Image(systemName: "play.fill")
                #endif
            }
        }
        #if os(tvOS)
        .buttonBorderShape(.circle)
        .buttonStyle(.glass)
        #endif
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
