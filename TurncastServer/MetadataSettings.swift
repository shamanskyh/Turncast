//
//  MetadataSettings.swift
//  Turncast Server
//
//  Created by Harry Shamansky on 6/20/21.
//  Copyright © 2021 Harry Shamansky. All rights reserved.
//

import Foundation
import SwiftUI

struct MetadataSettings: View {
    
    @AppStorage("MetadataOverrides") var metadataOverrides: [MetadataOverride] = []
    @State var selectedMetadataOverride: MetadataOverride.ID? = nil
    
    var body: some View {
        VStack {
            Table($metadataOverrides, selection: $selectedMetadataOverride) {
                TableColumn("ISRC") { metadataOverride in
                    TextField("ISRC", text: metadataOverride.isrc)
                }
                TableColumn("Album") { metadataOverride in
                    TextField("Album", text: metadataOverride.album)
                }
                TableColumn("Artist") { metadataOverride in
                    TextField("Artist", text: metadataOverride.artist)
                }
                TableColumn("Artwork") { metadataOverride in
                    TextField("Image URL of Artwork", text: metadataOverride.imageURL)
                }
                TableColumn("Notes") { metadataOverride in
                    TextField("Notes", text: metadataOverride.notes)
                }
            }
            HStack {
                Spacer()
                Button {
                    // do deletion here
                    if let selected = selectedMetadataOverride, let index = metadataOverrides.firstIndex(where: { selected == $0.isrc }) {
                        selectedMetadataOverride = nil
                        metadataOverrides.remove(at: index)
                    }
                } label: {
                    Image(systemName: "trash")
                }.disabled(selectedMetadataOverride == nil)
            }.padding()
        }
    }
}
