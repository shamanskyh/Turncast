//
//  SearchForAlbumView.swift
//  Turncast Client
//
//  Created by Harry Shamansky on 6/10/23.
//  Copyright © 2023 Harry Shamansky. All rights reserved.
//

import DebouncedOnChange
import Foundation
import MusicKit
import SwiftUI

struct SearchForAlbumView: View {
    
    @State var searchTerm: String = ""
    @State var albums = MusicItemCollection<Album>()
    
    @Environment(\.defaultMinListRowHeight) private var listRowHeight: CGFloat
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                if !searchTerm.isEmpty {
                    ForEach(albums) { album in
                        Button {
                            MultipeerManager.shared.sendMessageToServer(message: .overrideMetadata(albumTitle: album.title,
                                                                                                   artist: album.artistName,
                                                                                                   imageURL: album.artwork?.url(width: 2000, height: 2000)?.absoluteString,
                                                                                                   notes: nil))
                            dismiss()
                        } label: {
                            HStack {
                                if let artwork = album.artwork {
                                    ArtworkImage(artwork, height: listRowHeight)
                                        .clipShape(RoundedRectangle(cornerRadius: listRowHeight / 8.0, style: .continuous))
                                }
                                #if os(iOS)
                                let alignment = .listRowSeparatorLeading
                                #else
                                let alignment = HorizontalAlignment.leading
                                #endif
                                VStack(alignment: alignment) {
                                    Text(album.title)
                                        .font(.body)
                                        .lineLimit(1)
                                    if let releaseDate = album.releaseDate {
                                        Text(album.artistName + " • " + String(Calendar.current.component(.year, from: releaseDate)))
                                            .font(.caption)
                                            .lineLimit(1)
                                            .foregroundStyle(Color.secondary)
                                    } else {
                                        Text(album.artistName)
                                            .font(.caption)
                                            .lineLimit(1)
                                            .foregroundStyle(Color.secondary)
                                    }
                                }
                            }
                        }
                    }
                    NavigationLink {
                        CustomMetadataView(album: searchTerm, artist: "", imageURL: "", notes: "")
                    } label: {
                        HStack {
                            Image(systemName: "plus.square.fill")
                            Text("Add Custom Album")
                        }
                    }
                }
            }
            .searchable(text: $searchTerm,
                        prompt: Text("Search for an album"))
            .overlay {
                if searchTerm.isEmpty {
                    ContentUnavailableView.search
                }
            }
        }
        .task(id: searchTerm, debounceTime: .milliseconds(100)) {
            //let _ = await MusicAuthorization.request()
            var request = MusicCatalogSearchRequest(term: searchTerm, types: [Album.self])
            request.includeTopResults = true
            if let response = try? await request.response() {
                albums = response.albums
            }
        }
    }
}

struct SearchForAlbumView_Preview: PreviewProvider {
    static var previews: some View {
        SearchForAlbumView()
    }
}
