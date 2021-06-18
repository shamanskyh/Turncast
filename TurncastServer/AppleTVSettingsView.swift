//
//  AppleTVSettingsView.swift
//  Turncast Server
//
//  Created by Harry Shamansky on 4/24/21.
//  Copyright © 2021 Harry Shamansky. All rights reserved.
//

import Foundation
import SwiftUI

struct AppleTVSettingsView: View {
    
    @ObservedObject var listener: AudioListener
    
    var body: some View {
        VStack {
            Form {
                Toggle(isOn: $listener.launchAppleTV) {
                    Text("Launch Apple TV when audio detected")
                }
                TextField("Path to atvremote", text: $listener.pathToATVRemote)
                    .disabled(!listener.launchAppleTV)
                    .help("executable for atvremote")
                TextField("Apple TV ID", text: $listener.appleTVID)
                    .disabled(!listener.launchAppleTV)
                    .help("ID for the Apple TV to connect to. Get this value using atvremote scan")
                TextField("Apple TV Credentials", text: $listener.appleTVCredentials)
                    .disabled(!listener.launchAppleTV)
                    .help("Credentials for the Apple TV to connect to. Get this value using atvremote -i <AppleTVID> --protocol companion pair")
                Button("Test Launch") {
                    AppleTVUtilities.openTurncast(atvRemotePath: listener.pathToATVRemote,
                                                  appleTVID: listener.appleTVID,
                                                  appleTVCredentials: listener.appleTVCredentials)
                }.disabled(!listener.launchAppleTV)
            }
            Text("Use the commands `atvremote scan` and `atvremote -i <AppleTVID> --protocol companion pair` to capture ID and credentials.").italic().lineLimit(5).frame(height: 50)
        }
    }
}
