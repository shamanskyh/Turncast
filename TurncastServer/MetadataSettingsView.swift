//
//  MetadataSettingsView.swift
//  Turncast Server
//
//  Created by Harry Shamansky on 4/24/21.
//  Copyright © 2021 Harry Shamansky. All rights reserved.
//

import Foundation
import SwiftUI

struct MetadataSettingsView: View {
    
    @ObservedObject var listener: AudioListener
    
    var body: some View {
        Form {
            HStack {
                Text("Sample Length")
                TextField("Sample Length", text: Binding(
                    get: { String(listener.sampleLength) },
                    set: { listener.sampleLength = Double($0) ?? 0.0 }
                ))
                    .help("How long a sample should Turncast record before performing audio analysis?")
                Text("seconds")
            }
            HStack {
                Text("Sample Delay")
                TextField("Sample Delay", text: Binding(
                    get: { String(listener.sampleDelay) },
                    set: { listener.sampleDelay = Double($0) ?? 0.0 }
                ))
                    .help("How long after connection should Turncast begin sampling for recognition?")
                Text("seconds")
            }
            HStack {
                Text("Max Files per Album to Train").layoutPriority(1)
                TextField("Max Files per Album to Train", text: Binding(
                    get: { String(listener.maxFiles) },
                    set: { listener.maxFiles = Int($0) ?? 0 }
                ))
                    .help("How long after connection should Turncast begin sampling for recognition?")
            }
            HStack {
                if listener.training {
                    Button(action: {
                        self.listener.cancelTraining()
                    }) {
                        Text("Cancel Training")
                    }
                    if let progress = listener.currentTrainingJob?.progress {
                        ProgressView(progress).labelsHidden()
                    }
                } else {
                    Button(action: {
                        self.listener.trainAndSaveClassifier()
                    }) {
                        Text("Retrain Model")
                    }
                }
            }
        }
    }
}
