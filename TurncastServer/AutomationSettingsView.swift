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
                Group {
                    Toggle(isOn: $listener.launchStartShortcut) {
                        Text("Run Shortcut when audio begins")
                    }
                    TextField("Shortcut Name", text: $listener.startShortcutName)
                        .disabled(!listener.launchStartShortcut)
                        .help("The name of the Shortcut to run when Turncast detects audio.")
                }
                Spacer(minLength: 20.0)
                Divider()
                Spacer(minLength: 20.0)
                Group {
                    Toggle(isOn: $listener.launchStopShortcut) {
                        Text("Run Shortcut when audio ends")
                    }
                    TextField("Shortcut Name", text: $listener.stopShortcutName)
                        .disabled(!listener.launchStopShortcut)
                        .help("The name of the Shortcut to run when Turncast stops detecting audio.")
                }
                Spacer(minLength: 20.0)
                Divider()
                Spacer(minLength: 20.0)
                Group {
                    Toggle(isOn: listener.$enterFullscreenWhenListening) {
                        Text("Enter fullscreen when audio detected")
                    }
                    Toggle(isOn: listener.$exitFullscreenWhenStopped) {
                        Text("Exit fullscreen when audio stopped")
                    }
                }
            }
        }.padding()
    }
}
