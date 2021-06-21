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

public enum MultipeerMessage: Codable {
    /// A request to broadcast an update to all connected clients
    case broadcastUpdate
    case albumTitle(String)
    case artist(String)
    case imageURL(URL)
    case clearImageURL
}
