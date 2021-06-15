//
//  RecognitionStatus.swift
//  Turncast Server
//
//  Created by Harry Shamansky on 12/30/20.
//  Copyright © 2020 Harry Shamansky. All rights reserved.
//

import Foundation

enum RecognitionStatus {
    case waitingToRecognize
    case knownAlbum(Metadata)
    case unknownAlbum
}
