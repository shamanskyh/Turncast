//
//  ResultsObserver.swift
//  Turncast Server
//
//  Created by Harry Shamansky on 12/30/20.
//  Copyright © 2020 Harry Shamansky. All rights reserved.
//

import AppKit
import Foundation
import os
import SoundAnalysis

class ResultsObserver: NSObject, SNResultsObserving {
    
    let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "results-observer")
    
    let callbackBlock: (Metadata?, CGImage?, Double) -> ()
    
    var previousConfidence: Double? = nil
    var previousIdentifier: String? = nil
    
    init(callback: @escaping (Metadata?, CGImage?, Double) -> ()) {
        self.callbackBlock = callback
        super.init()
    }
    
    func debugPrintClassifications(_ classifications: [SNClassification], timeRange: CMTimeRange) -> String {
        var output = "========== CLASSIFICATIONS ==========\ntime range: \(timeRange.start.value)-\(timeRange.start.value + timeRange.duration.value)\n"
        for classification in classifications.sorted(by: { (c1, c2) -> Bool in
            return c1.confidence > c2.confidence
        }) {
            output += "LABEL: \(classification.identifier), CONFIDENCE: \(classification.confidence)\n"
        }
        return output
    }
    
    func request(_ request: SNRequest, didProduce result: SNResult) {
        
        // Get the top classification.
        guard let result = result as? SNClassificationResult, let classification = result.classifications.sorted(by: { (c1, c2) -> Bool in
            return c1.confidence > c2.confidence
        }).first else { return }
        
        // Return early if we're not any more confident
        if let prevConfidence = previousConfidence, classification.confidence <= prevConfidence {
            // if our new confidence is no higher than our previous one, just return; no need to pump out another update
            return
        } else {
            previousConfidence = classification.confidence
        }
        
        // Return early if we're more confident but our result wouldn't change
        if let prevIdentifier = previousIdentifier, classification.identifier == prevIdentifier {
            // if our classification wouldn't change, just return; no need to pump out an update
            return
        } else {
            previousIdentifier = classification.identifier
        }
        
        // If we've made it here, we have a reason to change our classification (or this is our first one)
        let debugClassifications = debugPrintClassifications(result.classifications, timeRange: result.timeRange)
        logger.debug("\(debugClassifications, privacy: .public)")
        
        if classification.confidence > 0.9 {
            // get our actual metadata
            let decoder = JSONDecoder()
            if let metadataURL = try? URLHelpers.urlForAlbumMetadata(modelIdentifier: classification.identifier),
               let metadataData = try? Data(contentsOf: metadataURL),
               let metadata = try? decoder.decode(Metadata.self, from: metadataData) {
                if let imageURL = try? URLHelpers.urlForAlbumImage(artist: metadata.artist, album: metadata.albumTitle) {
                    let nsImage = NSImage(contentsOf: imageURL)
                    let cgImage = nsImage?.cgImage(forProposedRect: nil, context: nil, hints: nil)
                    DispatchQueue.main.async { [weak self] in
                        self?.callbackBlock(metadata, cgImage, classification.confidence)
                    }
                    return
                } else {
                    DispatchQueue.main.async { [weak self] in
                        self?.callbackBlock(metadata, nil, classification.confidence)
                    }
                    return
                }
            }
        }
        // capture anything that didn't return a result
        DispatchQueue.main.async { [weak self] in
            self?.callbackBlock(nil, nil, 0.0)
        }
    }
}
