//
//  ContentView.swift
//  Tinfoil
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
            Spacer(minLength: 40.0)
            if listener.errorMessage != nil {
                Text(listener.errorMessage!)
                    .lineLimit(nil)
                    .foregroundColor(.red)
                    .padding()
                Button(action: {
                    self.listener.beginListening()
                }, label: { Text("Reconnect") }).padding()
            } else {
                if listener.connectionStatus == .connected {
                    Text("Connected".uppercased())
                        .foregroundColor(.white)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 12.0, style: .continuous)
                            .foregroundColor(.green))
                } else {
                    Text("Disconnected".uppercased())
                        .foregroundColor(.white)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 12.0, style: .continuous)
                            .foregroundColor(.red))
                }
                if listener.averagePowerLevel == Float.leastNormalMagnitude {
                    Text("Audio Level: -∞ dB")
                } else {
                    Text("Audio Level: \(formatter.string(from: NSNumber(value: listener.averagePowerLevel)) ?? "") dB").font(Font.body.monospacedDigit())
                }
            }
            Form {
                HStack {
                    Text("Input Name")
                    TextField("Input Name", text: $listener.inputName)
                        .help("What input source should Airfoil select when Tinfoil detects input? This is usually the name of your USB audio input. Leave blank if this should go unchanged.")
                }
                HStack {
                    Text("Output Name(s)")
                    TextField("Output Name(s)", text: $listener.outputNames)
                        .help("What output(s) should Airfoil select when Tinfoil detects audio? To add multiple outputs, use a group in Airfoil or comma separate individual speaker/group names in Tinfoil.")
                }
                HStack {
                    Text("On Threshold")
                    DecimalField("On Threshold", value: $listener.onThreshold, formatter: decibelFormatter)
                        .help("At what volume level (or greater than) should Tinfoil trigger Airfoil to connect?")
                    Text("dB")
                }
                HStack {
                    Text("Off Threshold")
                    DecimalField("Off Threshold", value: $listener.offThreshold, formatter: decibelFormatter)
                        .help("At what volume level (or less than) should Tinfoil trigger Airfoil to disconnect?")
                    Text("dB")
                }
                Toggle("Update Volume on Connection", isOn: $listener.changeVolume)
                Slider(value: $listener.initialVolume, in: 0...1).disabled(!listener.changeVolume)
            }.padding()
        }
        .onAppear {
            self.listener.beginListening()
        }
    }
    
    var decibelFormatter: NumberFormatter {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.isLenient = true
        return nf
    }
    
    init(listener: AudioListener) {
        self.listener = listener
        self.formatter.maximumFractionDigits = 2
        self.formatter.minimumFractionDigits = 2
        self.formatter.numberStyle = .decimal
    }
}

extension Float {
    func truncate(places : Int)-> Float {
        return Float(floor(pow(10.0, Float(places)) * self)/pow(10.0, Float(places)))
    }
}
