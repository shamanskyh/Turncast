//
//  MediaPickerView.swift
//  Turncast Client
//
//  Created by Harry Shamansky on 5/29/23.
//  Copyright © 2023 Harry Shamansky. All rights reserved.
//

import Foundation
import MediaPlayer
import MusicKit
import SwiftUI

@available(iOS 16, *)
struct MediaPickerView: UIViewControllerRepresentable {
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> MPMediaPickerController {
        let mediaPicker = MPMediaPickerController(mediaTypes: .music)
        mediaPicker.delegate = context.coordinator
        mediaPicker.allowsPickingMultipleItems = false
        return mediaPicker
    }
    
    func updateUIViewController(_ uiViewController: MPMediaPickerController, context: Context) {
        // No update needed
    }
    
    class Coordinator: NSObject, MPMediaPickerControllerDelegate {
        let parent: MediaPickerView
        
        init(_ parent: MediaPickerView) {
            self.parent = parent
        }
        
        func mediaPicker(_ mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
            if let mediaItem = mediaItemCollection.items.first {
                let albumTitle = mediaItem.albumTitle ?? "Unknown Album"
                let artistName = mediaItem.artist ?? "Unknown Artist"
                
                Task {
                    // get the image URL using music kit
                    let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID("\(mediaItem.playbackStoreID)"))
                    if let response = try? await request.response(),
                       let song = response.items.first,
                       let artworkURL = song.artwork?.url(width: 2000, height: 2000) {
                        MultipeerManager.shared.sendMessageToServer(message: .overrideMetadata(albumTitle: albumTitle, artist: artistName, imageURL: artworkURL.absoluteString, notes: nil))
                    } else {
                        MultipeerManager.shared.sendMessageToServer(message: .overrideMetadata(albumTitle: albumTitle, artist: artistName, imageURL: nil, notes: nil))
                    }
                }
            }
            mediaPicker.dismiss(animated: true, completion: nil)
        }
        
        func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
            mediaPicker.dismiss(animated: true, completion: nil)
        }
    }
}
