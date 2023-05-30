//
//  MetadataModalType.swift
//  Turncast Client
//
//  Created by Harry Shamansky on 5/29/23.
//  Copyright © 2023 Harry Shamansky. All rights reserved.
//

import Foundation

enum MetadataModalType: String, Identifiable {
    
    @available(iOS 16, *)
    case appleMusic
    
    case custom
    
    var id: String {
        return rawValue
    }
}
