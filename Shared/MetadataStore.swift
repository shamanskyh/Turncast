//
//  MetadataStore.swift
//  Turncast
//
//  Created by Harry Shamansky on 12/31/20.
//  Copyright © 2020 Harry Shamansky. All rights reserved.
//

import Foundation
import MediaPlayer
import MultipeerMessages
import SwiftUI

class MetadataStore: ObservableObject {
    
    weak var multipeerManager: MultipeerManager?
    
    var blockUpdates: Bool = false
    
    var albumImageData: CGImage = UIImage(named: "NoInfo")!.cgImage! {
        willSet {
            objectWillChange.send()
            if !blockUpdates {
                multipeerManager?.sendMessageToServer(message: .imageData(newValue.png!))
            }
        }
        didSet {
            updateNowPlayingInfoCenter()
        }
    }
    
    var albumImage: Image = Image("NoInfo") {
        willSet {
            objectWillChange.send()
        }
    }
    var albumTitle: String = "Unknown Album" {
        willSet {
            objectWillChange.send()
            if !blockUpdates {
                multipeerManager?.sendMessageToServer(message: .albumTitle(newValue))
            }
        }
        didSet {
            updateNowPlayingInfoCenter()
        }
    }
    var artist: String = "Unknown Artist" {
        willSet {
            objectWillChange.send()
            if !blockUpdates {
                multipeerManager?.sendMessageToServer(message: .artist(newValue))
            }
        }
        didSet {
            updateNowPlayingInfoCenter()
        }
    }
    var canEdit: Bool = false {
        willSet {
            objectWillChange.send()
            if !blockUpdates {
                multipeerManager?.sendMessageToServer(message: .canEdit(newValue))
            }
        }
    }
    
    func updateNowPlayingInfoCenter() {
        let artworkCGImage = albumImageData
        let artwork = MPMediaItemArtwork(boundsSize: CGSize(width: albumImageData.width, height: albumImageData.height)) { (size) -> UIImage in
            return UIImage(cgImage: artworkCGImage).copy(newSize: size)!
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [MPNowPlayingInfoPropertyIsLiveStream: true,
                                                           MPMediaItemPropertyTitle: albumTitle,
                                                           MPMediaItemPropertyArtist: artist,
                                                           MPMediaItemPropertyArtwork: artwork]
    }
}

public extension UIImage {
    func copy(newSize: CGSize, retina: Bool = true) -> UIImage? {
        // In next line, pass 0 to use the current device's pixel scaling factor (and thus account for Retina resolution).
        // Pass 1 to force exact pixel size.
        UIGraphicsBeginImageContextWithOptions(
            /* size: */ newSize,
            /* opaque: */ false,
            /* scale: */ retina ? 0 : 1
        )
        defer { UIGraphicsEndImageContext() }

        self.draw(in: CGRect(origin: .zero, size: newSize))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
