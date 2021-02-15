//
//  PhotoPicker.swift
//  Turncast
//
//  Created by Harry Shamansky on 1/1/21.
//  Copyright © 2021 Harry Shamansky. All rights reserved.
//

import Foundation
import PhotosUI
import SwiftUI

#if canImport(UIKit)
// From https://developer.apple.com/forums/thread/651743
struct PhotoPicker: UIViewControllerRepresentable {
    let configuration: PHPickerConfiguration
    @Binding var isPresented: Bool
    @Binding var albumImage: Image
    @Binding var albumImageData: CGImage
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        let controller = PHPickerViewController(configuration: configuration)
        controller.delegate = context.coordinator
        return controller
    }
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) { }
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // Use a Coordinator to act as your PHPickerViewControllerDelegate
    class Coordinator: PHPickerViewControllerDelegate {
      
        private let parent: PhotoPicker
        
        init(_ parent: PhotoPicker) {
            self.parent = parent
        }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            print(results)
            parent.isPresented = false // Set isPresented to false because picking has finished.
            if let result = results.first {
                result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] (object, error) in
                    guard let image = object as? UIImage else { return }
                    guard let strongSelf = self else { return }
                    DispatchQueue.main.async { [weak strongSelf] in
                        guard let strongStrongSelf = strongSelf else { return }
                        strongStrongSelf.parent.albumImageData = image.cgImage!
                        strongStrongSelf.parent.albumImage = Image(uiImage: image)
                    }
                }
            }
        }
    }
}
#endif
