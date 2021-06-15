//
//  SettingsView.swift
//  Turncast
//
//  Created by Harry Shamansky on 12/27/20.
//  Copyright © 2020 Harry Shamansky. All rights reserved.
//

import Foundation
import SwiftUI

struct SettingsView: View {
    
    @AppStorage("wiFiSSID") var wiFiSSID: String = "😈"
    @AppStorage("serverIP") var serverIP: String = "192.168.68.80"
    
    var body: some View {
        VStack {
            HStack {
                Text("WiFi SSID")
                TextField("WiFi SSID", text: $wiFiSSID).textFieldStyle(RoundedBorderTextFieldStyle())
            }
            HStack {
                Text("Server IP Address")
                TextField("Server IP Address", text: $serverIP).textFieldStyle(RoundedBorderTextFieldStyle())
            }
        }
        .padding()
        .tabItem {
            Image(systemName: "gear")
            Text("Settings")
        }
    }
}
