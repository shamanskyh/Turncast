//
//  AppleTVUtilities.swift
//  Turncast Server
//
//  Created by Harry Shamansky on 4/25/21.
//  Copyright © 2021 Harry Shamansky. All rights reserved.
//

import Foundation

struct AppleTVUtilities {
    static func openTurncast(atvRemotePath: String, appleTVID: String, appleTVCredentials: String) {
        do {
            try Shell.command("\(atvRemotePath) -i \(appleTVID) --companion-credentials \(appleTVCredentials) turn_on")
            try Shell.command("\(atvRemotePath) -i \(appleTVID) --companion-credentials \(appleTVCredentials) launch_app=com.harryshamansky.Turncast")
        } catch Shell.ShellError.shellError(let message) {
            print(message)
        } catch {
            print("Unknown Error Connecting to Apple TV")
        }
    }
}
