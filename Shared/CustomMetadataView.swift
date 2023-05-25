//
//  CustomMetadataView.swift
//  Turncast
//
//  Created by Harry Shamansky on 5/24/23.
//  Copyright © 2023 Harry Shamansky. All rights reserved.
//

import Foundation
import SwiftUI

struct CustomMetadataView: View {
    
    @State var album: String
    @State var artist: String
    @State var imageURL: String
    @State var notes: String
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Album", text: $album)
                TextField("Artist", text: $artist)
                TextField("Image URL", text: $imageURL)
                TextField("Notes", text: $notes)
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        MultipeerManager.shared.sendMessageToServer(message: .overrideMetadata(albumTitle: album,
                                                                                               artist: artist,
                                                                                               imageURL: imageURL,
                                                                                               notes: notes.isEmpty ? nil : notes))
                        dismiss()
                    }
                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                }
            }
            .navigationTitle("Correct Metadata")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}
