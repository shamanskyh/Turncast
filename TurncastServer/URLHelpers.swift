//
//  URLHelpers.swift
//  Turncast Server
//
//  Created by Harry Shamansky on 12/29/20.
//  Copyright © 2020 Harry Shamansky. All rights reserved.
//

import Foundation

class URLHelpers {
    
    private static let classificationDirectoryName = "classification"
    private static let trainingDataDirectoryName = "training_data"
    private static let albumClassifierModelFileName = "album_classifier"
    private static let mlModelExtension = "mlmodel"
    private static let mlCompiledModelExtension = "mlmodelc"
    private static let m4aExtension = "m4a"
    private static let metadataFileName = "metadata"
    private static let imageFileName = "image"
    private static let currentItemDirectoryName = "current_item"
    private static let currentSampleFileName = "sample"
    private static let currentRecordingFileName = "recording"
    
    static func identifierForAlbum(artist: String, album: String) -> String {
        return "\(artist) - \(album)"
    }
    
    static func urlForApplicationSupportDirectory() throws -> URL {
        return try FileManager.default.url(for: .applicationSupportDirectory,
                                           in: .userDomainMask,
                                           appropriateFor: nil,
                                           create: true)
    }
    
    static func urlForClassificationAndMetadataInfo() throws -> URL {
        let appSupportDir = try urlForApplicationSupportDirectory()
        
        try FileManager.default.createDirectory(at: appSupportDir.appendingPathComponent(classificationDirectoryName),
                                                withIntermediateDirectories: true)
        
        return appSupportDir.appendingPathComponent(classificationDirectoryName)
    }
    
    static func urlForTrainingData() throws -> URL {
        let classificationDir = try urlForClassificationAndMetadataInfo()
        try FileManager.default.createDirectory(at: classificationDir.appendingPathComponent(trainingDataDirectoryName),
                                                withIntermediateDirectories: true)
        return classificationDir.appendingPathComponent(trainingDataDirectoryName)
    }
    
    static func urlForAlbumClassifier() throws -> URL {
        return try urlForClassificationAndMetadataInfo()
            .appendingPathComponent(albumClassifierModelFileName)
            .appendingPathExtension(mlModelExtension)
    }
    
    static func urlForCompiledAlbumClassifier() throws -> URL {
        return try urlForClassificationAndMetadataInfo()
            .appendingPathComponent(albumClassifierModelFileName)
            .appendingPathExtension(mlCompiledModelExtension)
    }
    
    static func urlForAlbumDirectory(artist: String, album: String) throws -> URL {
        let urlForTraining = try urlForTrainingData()
        
        try FileManager.default.createDirectory(at: urlForTraining.appendingPathComponent(identifierForAlbum(artist: artist, album: album)),
                                            withIntermediateDirectories: true)
        
        return urlForTraining
            .appendingPathComponent(identifierForAlbum(artist: artist, album: album))
    }
    
    static func urlForAlbumMetadata(artist: String, album: String) throws -> URL {
        return try urlForAlbumDirectory(artist: artist, album: album)
            .appendingPathComponent(metadataFileName)
            .appendingPathExtension(for: .json)
    }
    
    static func urlForAlbumMetadata(modelIdentifier: String) throws -> URL {
        let urlForTraining = try urlForTrainingData()
        
        try FileManager.default.createDirectory(at: urlForTraining.appendingPathComponent(modelIdentifier),
                                            withIntermediateDirectories: true)
        
        return urlForTraining
            .appendingPathComponent(modelIdentifier)
            .appendingPathComponent(metadataFileName)
            .appendingPathExtension(for: .json)
    }
    
    static func urlForAlbumImage(artist: String, album: String) throws -> URL {
        return try urlForAlbumDirectory(artist: artist, album: album)
            .appendingPathComponent(imageFileName)
            .appendingPathExtension(for: .png)
    }
    
    static func urlForCurrentItemDirectory() throws -> URL {
        let classificationDir = try urlForClassificationAndMetadataInfo()
        
        try FileManager.default.createDirectory(at: classificationDir.appendingPathComponent(currentItemDirectoryName),
                                                withIntermediateDirectories: true)
        
        return classificationDir
            .appendingPathComponent(currentItemDirectoryName, isDirectory: true)
    }
    
    static func urlForCurrentSample() throws -> URL {
        return try urlForCurrentItemDirectory()
            .appendingPathComponent(currentSampleFileName)
            .appendingPathExtension(m4aExtension)
    }
    
    static func urlForCurrentRecording() throws -> URL {
        return try urlForCurrentItemDirectory()
            .appendingPathComponent(currentRecordingFileName)
            .appendingPathExtension(m4aExtension)
    }
}
