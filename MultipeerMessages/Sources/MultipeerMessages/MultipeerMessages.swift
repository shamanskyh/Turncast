//
//  MultipeerMessages.swift
//  MultipeerMessages
//
//  Created by Harry Shamansky on 4/26/20.
//  Copyright © 2020 Harry Shamansky. All rights reserved.
//

import Foundation
import CoreGraphics
import ImageIO

public let turncastServiceType = "turncast"

public enum MultipeerMessage {
    /// A request to broadcast an update to all connected clients
    case broadcastUpdate
    case albumTitle(String)
    case artist(String)
    case imageURL(URL)
    case clearImageURL
}

extension MultipeerMessage {
    enum CodingKeys: CodingKey {
        case broadcastUpdate
        case albumTitle
        case artist
        case imageURL
        case clearImageURL
    }
}

extension MultipeerMessage: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .broadcastUpdate:
            try container.encode(true, forKey: .broadcastUpdate)
        case .albumTitle(let title):
            try container.encode(title, forKey: .albumTitle)
        case .artist(let artist):
            try container.encode(artist, forKey: .artist)
        case .imageURL(let url):
            try container.encode(url, forKey: .imageURL)
        case .clearImageURL:
            try container.encode(true, forKey: .clearImageURL)
        }
    }
}

extension MultipeerMessage: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let key = container.allKeys.first
        switch key {
        case .broadcastUpdate:
            self = .broadcastUpdate
        case .albumTitle:
            let title = try container.decode(String.self, forKey: .albumTitle)
            self = .albumTitle(title)
        case .artist:
            let artist = try container.decode(String.self, forKey: .artist)
            self = .artist(artist)
        case .imageURL:
            let url = try container.decode(URL.self, forKey: .imageURL)
            self = .imageURL(url)
        case .clearImageURL:
            self = .clearImageURL
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Unable to decode enum."
                )
            )
        }
    }
}

extension CGImage {
    public var png: Data? {
        guard let mutableData = CFDataCreateMutable(nil, 0),
            let destination = CGImageDestinationCreateWithData(mutableData, "public.png" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, self, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return mutableData as Data
    }
}
