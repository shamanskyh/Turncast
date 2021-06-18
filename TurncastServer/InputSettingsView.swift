//
//  InputSettingsView.swift
//  Turncast Server
//
//  Created by Harry Shamansky on 4/24/21.
//  Copyright © 2021 Harry Shamansky. All rights reserved.
//

import Foundation
import SwiftUI

struct InputSettingsView: View {
    
    @ObservedObject var listener: AudioListener
    
    var body: some View {
        Form {
            TextField("Input Name", text: $listener.inputName)
                .help("What input source should Airfoil select when Turncast detects input? This is usually the name of your USB audio input. Leave blank if this should go unchanged.")
            HStack {
                TextField("On Threshold", text: Binding(
                    get: { String(listener.onThreshold) },
                    set: { listener.onThreshold = Double($0) ?? 0.0 }
                ))
                    .help("At what volume level (or greater) should Turncast begin the HTTP stream?")
                Text("dB")
            }
            HStack {
                TextField("On Delay", text: Binding(
                    get: { String(listener.onLength) },
                    set: { listener.onLength = Double($0) ?? 0.0 }
                ))
                    .help("How long, in seconds, should Turncast detect audio above the 'On Threshold' before beginning?")
                Text("seconds")
            }
            HStack {
                TextField("Off Threshold", text: Binding(
                    get: { String(listener.offThreshold) },
                    set: { listener.offThreshold = Double($0) ?? 0.0 }
                ))
                    .help("At what volume level (or less) should Turncast schedule disconnection?")
                Text("dB")
            }
            HStack {
                TextField("Off Delay", text: Binding(
                    get: { String(listener.offLength) },
                    set: { listener.offLength = Double($0) ?? 0.0 }
                ))
                    .help("How long, in seconds, should Turncast detect audio below the 'Off Threshold' before stopping?")
                Text("seconds")
            }
            HStack {
                TextField("Disconnect Delay", text: Binding(
                    get: { String(listener.disconnectDelay) },
                    set: { listener.disconnectDelay = Double($0) ?? 0.0 }
                ))
                    .help("How long, in seconds, after Turncast turns off should it disconnect the stream? Note that this value refers to the HTTP streaming capability and not the audio threshold levels defined by the 'Off Delay'")
                Text("seconds")
            }
        }
    }
}
