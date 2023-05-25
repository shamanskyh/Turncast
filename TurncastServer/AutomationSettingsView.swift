//
//  ShortcutSettingsView.swift
//  Turncast Server
//
//  Created by Harry Shamansky on 4/24/21.
//  Copyright © 2021 Harry Shamansky. All rights reserved.
//

import Foundation
import SwiftUI

struct AutomationSettingsView: View {
    
    @ObservedObject var listener: AudioListener
    
    var body: some View {
        VStack {
            Form {
                Toggle(isOn: $listener.launchShortcut) {
                    Text("Run Shortcut when audio detected")
                }
                TextField("Shortcut Name", text: $listener.shortcutName)
                    .disabled(!listener.launchShortcut)
                    .help("The name of the Shortcut to run when Turncast detects audio.")
            }
        }.padding()
    }
}
