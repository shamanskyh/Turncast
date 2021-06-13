//
//  TurncastServerApp.swift
//  Turncast Server
//
//  Created by Harry Shamansky on 4/24/21.
//  Copyright © 2021 Harry Shamansky. All rights reserved.
//

import Foundation
import SwiftUI

@main
struct TurncastServerApp: App {
    
    let listener = AudioListener()
    
    var body: some Scene {
        WindowGroup {
            ContentView(listener: listener).onDisappear {
                exit(0)
            }
        }.commands {
            CommandGroup(replacing: .newItem, addition: { })
        }
        Settings {
            SettingsView(listener: listener)
        }
    }
}
