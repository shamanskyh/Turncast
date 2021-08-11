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

struct MeshGradient: View {
    
    let image: UIImage?
    let opacity: Binding<Double>
    
    @State var colors: [Color] = [Color(white: 0.5), Color(white: 0.6), Color(white: 0.4), Color(white: 0.4)]
    
    var body: some View {
        AngularGradient(colors: colors, center: UnitPoint(x: 0.5, y: 0.5))
            .blur(radius: blurRadius)
            .scaleEffect(1.1)
            .opacity(opacity.wrappedValue)
            .onAppear {
                if let image = image {
                    DispatchQueue.global(qos: .background).async {
                        let colorPalette = ColorThief.getPalette(from: image, colorCount: 8, quality: 10)
                        var mappedColors = colorPalette?.map({ Color(uiColor: $0.makeUIColor()) }).shuffled() ?? []
                        if let firstColor = mappedColors.first {
                            mappedColors.append(firstColor)
                        }
                        DispatchQueue.main.async {
                            colors = mappedColors
                            withAnimation(.linear(duration: 4.0)) {
                                opacity.wrappedValue = 1.0
                            }
                        }
                    }
                } else {
                    colors = colors.shuffled()
                }
            }
    }
    
    var blurRadius: Double {
        #if os(tvOS)
        return 80.0
        #else
        return 20.0
        #endif
    }
}
