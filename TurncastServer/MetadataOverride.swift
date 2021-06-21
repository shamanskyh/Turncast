//
//  MetadataOverride.swift
//  Turncast Server
//
//  Created by Harry Shamansky on 6/20/21.
//  Copyright © 2021 Harry Shamansky. All rights reserved.
//

import Foundation

public struct MetadataOverride: Codable {
    var isrc: String
    var album: String
    var artist: String
    var imageURL: String
    var notes: String
}

extension MetadataOverride: Identifiable {
    public var id: String {
        return isrc
    }
}

extension Array: RawRepresentable where Iterator.Element == MetadataOverride {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
            let result = try? JSONDecoder().decode([MetadataOverride].self, from: data)
        else {
            return nil
        }
        self = result
    }

    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
            let result = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return result
    }
}
