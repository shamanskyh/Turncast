//
//  ContentView.swift
//  Shared
//
//  Created by Harry Shamansky on 12/27/20.
//  Copyright © 2020 Harry Shamansky. All rights reserved.
//

import AVFoundation
import MediaPlayer
import ShazamKit
import SwiftUI

struct ContentView: View {
    
    @StateObject var streamSource = StreamSource()
    
    var body: some View {
        VStack(alignment: .center) {
            streamSource.albumArt
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: albumArtSize)
                .cornerRadius(12.0)
                .padding()
            Text(streamSource.title).font(.headline)
            Text(streamSource.artist).font(.subheadline)
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
            }.padding(.top, 40)
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
