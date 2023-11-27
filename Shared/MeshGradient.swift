//
//  MeshGradient.swift
//  Turncast
//
//  Created by Harry Shamansky on 8/9/21.
//  Copyright © 2021 Harry Shamansky. All rights reserved.
//

import ColorThiefSwift
import Foundation
import SwiftUI

extension Color {
    init(platformNativeColor: PlatformNativeColor) {
        #if canImport(UIKit)
        self.init(uiColor: platformNativeColor)
        #elseif canImport(AppKit)
        self.init(nsColor: platformNativeColor)
        #endif
    }
}

struct MeshGradient: View {

    var image: PlatformNativeImage?
    
    @State var colors: [Color] = [Color(white: 0.5), Color(white: 0.6), Color(white: 0.4), Color(white: 0.4)]
    
    var body: some View {
        FloatingClouds(colors: colors)
            .onAppear {
                if let image = image {
                    DispatchQueue.global(qos: .background).async {
                        let colorPalette = ColorThief.getPalette(from: image, colorCount: 8, quality: 10)
                        var mappedColors = colorPalette?.map({ Color(platformNativeColor: $0.makePlatformNativeColor()) }).shuffled() ?? []
                        if let firstColor = mappedColors.first {
                            mappedColors.append(firstColor)
                        }
                        DispatchQueue.main.async {
                            colors = mappedColors
                        }
                    }
                }
            }.tag(image.hashValue)
    }
    
//    var blurRadius: Double {
//        #if os(tvOS)
//        return 80.0
//        #else
//        return 20.0
//        #endif
//    }
}
