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
    
    @State var colors: [Color] = [Color(white: 0.5), Color(white: 0.8), Color(white: 0.2), Color(white: 0.4)]
    
    var body: some View {
        AngularGradient(colors: colors, center: UnitPoint(x: 0.5, y: 0.5))
            .blur(radius: 20)
            .scaleEffect(1.1)
            .opacity(opacity.wrappedValue)
            .onAppear {
                if let image = image {
                    DispatchQueue.global(qos: .background).async {
                        let colorPalette = ColorThief.getPalette(from: image, colorCount: 8, quality: 10)
                        let mappedColors = colorPalette?.map({ Color(uiColor: $0.makeUIColor()) }).shuffled() ?? []
                        DispatchQueue.main.async {
                            colors = mappedColors
                            withAnimation(.linear(duration: 4.0)) {
                                opacity.wrappedValue = 1.0
                            }
                        }
                    }
                }
            }
    }
}
