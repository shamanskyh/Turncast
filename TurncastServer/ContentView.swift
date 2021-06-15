//
//  ContentView.swift
//  Turncast
//
//  Created by Harry Shamansky on 4/26/20.
//  Copyright © 2020 Harry Shamansky. All rights reserved.
//

import Foundation
import SwiftUI

struct ContentView: View {
    
    @ObservedObject var listener: AudioListener
    let formatter = NumberFormatter()

    var body: some View {
        VStack(spacing: 20.0) {
            if listener.errorMessage != nil {
                Text(listener.errorMessage!)
                    .lineLimit(nil)
                    .foregroundColor(.red)
                    .padding()
                Button(action: {
                    self.listener.beginListening()
                }, label: { Text("Reconnect") }).padding()
            } else {
                switch listener.connectionStatus {
                case .connected:
                    Text("Connected".uppercased())
                        .foregroundColor(.white)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 12.0, style: .continuous)
                            .foregroundColor(.green))
                case .disconnected:
                    Text("Not Connected".uppercased())
                        .foregroundColor(.white)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 12.0, style: .continuous)
                            .foregroundColor(.red))
                case .waitingToDisconnect:
                    Text("Waiting to Disconnect".uppercased())
                        .foregroundColor(.white)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 12.0, style: .continuous)
                            .foregroundColor(.orange))
                }
                if listener.averagePowerLevel == Float.leastNormalMagnitude {
                    Text("Audio Level: -∞ dB")
                } else {
                    Text("Audio Level: \(formatter.string(from: NSNumber(value: listener.averagePowerLevel)) ?? "") dB").font(Font.body.monospacedDigit())
                }
            }
        }
        .frame(width: 200, height: 100, alignment: .center)
        .onAppear {
            self.listener.beginListening()
        }
    }
    
    init(listener: AudioListener) {
        self.listener = listener
        self.formatter.maximumFractionDigits = 2
        self.formatter.minimumFractionDigits = 2
        self.formatter.numberStyle = .decimal
    }
}
