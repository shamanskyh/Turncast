//
//  MediaPicker.swift
//  Turncast (iOS)
//
//  Created by Harry Shamansky on 2/15/21.
//  Copyright © 2021 Harry Shamansky. All rights reserved.
//

import Foundation
import MediaPlayer
import SwiftUI
#if HOME_USE
import CupertinoJWT
#endif

// From https://stackoverflow.com/questions/63125173/mpmediapickercontroller-in-swiftui
struct MediaPicker: UIViewControllerRepresentable {

    @Binding var currentPresentation: CurrentPresentation?
    @ObservedObject var metadataStore: MetadataStore

    class Coordinator: NSObject, UINavigationControllerDelegate, MPMediaPickerControllerDelegate {
    
        var parent: MediaPicker
        

        init(_ parent: MediaPicker) {
            self.parent = parent
        }
        
        var token: String?
        var tokenGenerationDate: Date?
        func resignKeyIfNecessary() {
            if token == nil || tokenGenerationDate == nil || tokenGenerationDate!.timeIntervalSinceNow <= (-1.0 * 60.0 * 50.0) {
                let p8 = """
                -----BEGIN PRIVATE KEY-----
                MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQgUfJzWcveSxU+Ouyk
                1mKezyfi3H+p0p1E9D9fDRCcc4ygCgYIKoZIzj0DAQehRANCAARsYcEBcvFyK1U7
                KLdr1njc9gQGHjSpzFhDHKLCJawmtN4CZcS2nsvMca7/xoG30fLK/HOxV9fYNNPk
                iaDkLifk
                -----END PRIVATE KEY-----
                """
                
                let keyID = "TVX32F47MJ"
                let teamID = "B5TXHQBF3Z"
                let issueDate = Date()
                tokenGenerationDate = issueDate
                let jwt = JWT(keyID: keyID, teamID: teamID, issueDate: issueDate, expireDuration: 60 * 60)
                do {
                    token = try jwt.sign(with: p8)
                } catch {
                    print(error)
                }
            }
        }
    
        func mediaPicker(_ mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
            defer { mediaPicker.dismiss(animated: true, completion: nil) }
            guard let representativeItem = mediaItemCollection.representativeItem else { return }
            
            if let artworkImage = representativeItem.artwork?.image(at: CGSize(width: 120.0, height: 120.0)) {
                parent.metadataStore.albumImage = Image(uiImage: artworkImage)
                if let cgImage = artworkImage.cgImage {
                    parent.metadataStore.albumImageData = cgImage
                }
            } else {
                // request the artwork async
                resignKeyIfNecessary()
                guard let token = token else { print("No token"); return }
                var urlRequest = URLRequest(url: URL(string: "https://api.music.apple.com/v1/catalog/us/songs/\(representativeItem.playbackStoreID)")!)
                urlRequest.addValue("bearer \(token)", forHTTPHeaderField: "authorization")
                
                let metadataStore = self.parent.metadataStore
                let dataTask = URLSession.shared.dataTask(with: urlRequest) { (data, response, error) in
                    guard let data = data else { return }
                    
                    if let jsonData = try? JSONSerialization.jsonObject(with: data, options: []),
                       let jsonDict = jsonData as? [String: Any],
                       let dataArray = jsonDict["data"] as? [Any],
                       let dataDict = dataArray.first as? [String: Any],
                       let attributesDict = dataDict["attributes"] as? [String: Any],
                       let artworkDict = attributesDict["artwork"] as? [String: Any],
                       let artworkURL = artworkDict["url"] as? String,
                       let artworkWidth = artworkDict["width"] as? Int,
                       let artworkHeight = artworkDict["height"] as? Int {
                        let replacedArtworkURL = artworkURL
                            .replacingOccurrences(of: "{w}", with: String(artworkWidth))
                            .replacingOccurrences(of: "{h}", with: String(artworkHeight))
                        
                        let secondaryDataTask = URLSession.shared.dataTask(with: URL(string: replacedArtworkURL)!) { (data, response, error) in
                            guard let data = data else { return }
                            if let uiImage = UIImage(data: data), let cgImage = uiImage.cgImage {
                                DispatchQueue.main.async {
                                    metadataStore.albumImage = Image(uiImage: uiImage)
                                    metadataStore.albumImageData = cgImage
                                }
                            }
                        }
                        secondaryDataTask.resume()
                    }
                }
                dataTask.resume()
            }
            
            if let title = representativeItem.albumTitle {
                parent.metadataStore.albumTitle = title
            }
            if let artist = representativeItem.albumArtist ?? representativeItem.artist {
                parent.metadataStore.artist = artist
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: UIViewControllerRepresentableContext<MediaPicker>) -> MPMediaPickerController {
        let picker = MPMediaPickerController(mediaTypes: .anyAudio)
        picker.showsCloudItems = true
        picker.delegate = context.coordinator
        picker.prompt = "Select Album"
        #if HOME_USE
        picker.setValue(true, forKey: "showsCatalogContent")
        let loader = picker.loader() as AnyObject
        let _ = loader.perform(NSSelectorFromString("requestRemoteViewController"))
        #endif
        return picker
    }

    func updateUIViewController(_ uiViewController: MPMediaPickerController, context: UIViewControllerRepresentableContext<MediaPicker>) {
    }

}
