//
//  StreamSource.swift
//  Turncast
//
//  Created by Harry Shamansky on 12/27/20.
//  Copyright © 2020 Harry Shamansky. All rights reserved.
//

import Foundation
import MediaPlayer
import MediaToolbox.MTAudioProcessingTap
import SwiftUI

class StreamSource: ObservableObject {
    
    @Published var albumArt = Image("NoInfo")
    @Published var title = "Not Playing"
    @Published var artist = ""
    
    var playing: Bool = false {
        willSet {
            objectWillChange.send()
            if newValue {

                let url = URL(string: "http://192.168.68.80:8080/turntable/playlist.m3u8")!

                // error check the case where we don't have anything to play
                // if this happens, retry the player in a second
                url.verify { [weak self] (valid) in
                    guard let strongSelf = self else { return }
                    if valid {
                        DispatchQueue.main.async {
                            SAPlayer.shared.startAudioStreamed(withRemoteUrl: url, bitrate: .low)
                            SAPlayer.shared.rate = 1.0
                            SAPlayer.shared.volume = 1.0
                            SAPlayer.shared.play()
                        }
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) { [weak strongSelf] in
                            guard let strongStrongSelf = strongSelf else { return }
                            if strongStrongSelf.playing {
                                // call the setter again to try to recreate the player. This will not call if we've
                                // stopped already
                                strongStrongSelf.playing = true
                            }
                        }
                    }
                }
            } else {
                SAPlayer.shared.pause()
            }
        }
    }
    
    init() {
        
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.defaultToSpeaker, .allowBluetooth, .allowAirPlay])
            try session.setActive(true)
        } catch {
            print(error)
        }
        UIApplication.shared.beginReceivingRemoteControlEvents()
        #elseif os(tvOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.allowAirPlay])
            try session.setActive(true)
        } catch {
            print(error)
        }
        UIApplication.shared.beginReceivingRemoteControlEvents()
        #endif
        
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.togglePlayPauseCommand.isEnabled = false
        commandCenter.stopCommand.isEnabled = true
        commandCenter.stopCommand.addTarget { [weak self] (event) -> MPRemoteCommandHandlerStatus in
            self?.playing = false
            return .success
        }
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] (event) -> MPRemoteCommandHandlerStatus in
            self?.playing = true
            return .success
        }
        commandCenter.pauseCommand.isEnabled = false
        commandCenter.skipForwardCommand.isEnabled = false
        commandCenter.skipBackwardCommand.isEnabled = false
        commandCenter.seekForwardCommand.isEnabled = false
        commandCenter.seekBackwardCommand.isEnabled = false
        
//        // Tap the audio here
//        SAPlayer.shared.engine!.mainMixerNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { buffer, time in
//            print("Buffer called with time of \(time)")
//        }
    }
}
