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
        Form {
            HStack {
                Text("Path to atvremote")
                TextField("Path to atvremote", text: $listener.pathToATVRemote)
                    .help("executable for atvremote")
            }
            HStack {
                Text("Apple TV ID")
                TextField("Apple TV ID", text: $listener.appleTVID)
                    .help("ID for the Apple TV to connect to. Get this value using `atvremote scan`")
            }
            HStack {
                Text("Apple TV Credentials")
                TextField("Apple TV Credentials", text: $listener.appleTVCredentials)
                    .help("Credentials for the Apple TV to connect to. Get this value using `atvremote -i <AppleTVID> --protocol companion pair`")
            }
            Button("Test Launch") {
                AppleTVUtilities.openTurncast(atvRemotePath: listener.pathToATVRemote,
                                              appleTVID: listener.appleTVID,
                                              appleTVCredentials: listener.appleTVCredentials)
            }
            Text("Use the commands `atvremote scan` and `atvremote -i <AppleTVID> --protocol companion pair` to capture ID and credentials.").italic().lineLimit(nil).frame(height: 50)
        }
    }
}
