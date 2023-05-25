//
//  SettingsView.swift
//  Turncast Server
//
//  Created by Harry Shamansky on 4/24/21.
//  Copyright © 2021 Harry Shamansky. All rights reserved.
//

import Foundation
import SwiftUI

struct SettingsView: View {
    
    @ObservedObject var listener: AudioListener
    
    private enum Tabs: Hashable {
        case input, metadata, appleTV
    }
    
    var body: some View {
        TabView {
            InputSettingsView(listener: listener)
                .tabItem {
                    Label("Input", systemImage: "waveform")
                }
                .tag(Tabs.input)
            MetadataSettings(listener: listener)
                .tabItem {
                    Label("Metadata", systemImage: "music.note.list")
                }
                .tag(Tabs.metadata)
            AutomationSettingsView(listener: listener)
                .tabItem {
                    Label("Automation", systemImage: "sparkles.tv")
                }
                .tag(Tabs.appleTV)
        }
    }
}
