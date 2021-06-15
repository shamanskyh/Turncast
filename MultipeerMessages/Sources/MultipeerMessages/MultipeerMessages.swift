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
    case canEdit(Bool)
    case albumTitle(String)
    case artist(String)
    case imageData(Data)
    case devicePushNotificationRegistration(String)
}

extension MultipeerMessage {
    enum CodingKeys: CodingKey {
        case broadcastUpdate
        case canEdit
        case albumTitle
        case artist
        case imageData
        case devicePushNotificationRegistration
    }
}

extension MultipeerMessage: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .broadcastUpdate:
            try container.encode(true, forKey: .broadcastUpdate)
        case .canEdit(let canEdit):
            try container.encode(canEdit, forKey: .canEdit)
        case .albumTitle(let title):
            try container.encode(title, forKey: .albumTitle)
        case .artist(let artist):
            try container.encode(artist, forKey: .artist)
        case .imageData(let data):
            try container.encode(data, forKey: .imageData)
        case .devicePushNotificationRegistration(let device):
            try container.encode(device, forKey: .devicePushNotificationRegistration)
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
        case .canEdit:
            let canEdit = try container.decode(Bool.self, forKey: .canEdit)
            self = .canEdit(canEdit)
        case .albumTitle:
            let title = try container.decode(String.self, forKey: .albumTitle)
            self = .albumTitle(title)
        case .artist:
            let artist = try container.decode(String.self, forKey: .artist)
            self = .artist(artist)
        case .imageData:
            let data = try container.decode(Data.self, forKey: .imageData)
            self = .imageData(data)
        case .devicePushNotificationRegistration:
            let data = try container.decode(String.self, forKey: .devicePushNotificationRegistration)
            self = .devicePushNotificationRegistration(data)
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
