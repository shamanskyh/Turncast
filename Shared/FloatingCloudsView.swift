//
//  FloatingCloudsView.swift
//  Turncast
//
//  Adapted from https://www.cephalopod.studio/blog/swiftui-aurora-background-animation
//

import Foundation
import SwiftUI

struct FloatingClouds: View {
    
    let colors: [Color]
    
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    @Environment(\.accessibilityDifferentiateWithoutColor) var differentiateWithoutColor
    @Environment(\.colorScheme) var scheme
    var testReduceTransparency = false
    var testDifferentiateWithoutColor = false

    var body: some View {
        if differentiateWithoutColor || testDifferentiateWithoutColor {
        #if canImport(UIKit)
            #if os(iOS)
            Color(.systemBackground)
                .ignoresSafeArea()
            #elseif os(tvOS)
            Color(.lightGray)
                .ignoresSafeArea()
            #endif
        #elseif canImport(AppKit)
            Color(.windowBackgroundColor)
                .ignoresSafeArea()
        #endif
        } else {
            if reduceTransparency || testReduceTransparency {
                LinearNonTransparency(colors: colors)
            } else {
                FloatingCloudsInner(colors: colors)
            }
        }
    }
}

struct FloatingCloudsInner: View {
    let colors: [Color]
    
    @Environment(\.colorScheme) var scheme
    let blur: CGFloat = 60

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                #if canImport(UIKit)
                #if os(iOS)
                Color(uiColor: .systemBackground)
                #elseif os(tvOS)
                Rectangle()
                    .foregroundStyle(.regularMaterial)
                #endif
                #elseif canImport(AppKit)
                Color(nsColor: .windowBackgroundColor)
                #endif
                ZStack {
                    let allAlignments: [Alignment] = [.topLeading, .top, .topTrailing, .leading, .trailing, .bottomLeading, .bottom, .bottomTrailing]
                    ForEach(Array(colors.enumerated()), id: \.offset) { (index, color) in
                        Cloud(proxy: proxy,
                              color: color,
                              rotationStart: Double.random(in: 0..<360),
                              duration: TimeInterval.random(in: 30..<80),
                              alignment: index < allAlignments.count ? allAlignments[index] : allAlignments.randomElement()!)
                    }
                }
                .blur(radius: blur)
            }
            .ignoresSafeArea()
        }
    }
}

struct Cloud: View {
    @StateObject var provider = CloudProvider()
    @State var move = false
    let proxy: GeometryProxy
    let color: Color
    let rotationStart: Double
    let duration: TimeInterval
    let alignment: Alignment

    var body: some View {
        Circle()
            .fill(color)
            .frame(height: proxy.size.height /  provider.frameHeightRatio)
            .offset(provider.offset)
            .rotationEffect(.init(degrees: move ? rotationStart : rotationStart + 360))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
            .opacity(0.8)
            .onAppear {
                withOptionalAnimation(Animation.linear(duration: duration).repeatForever(autoreverses: false)) {
                    move.toggle()
                }
            }
    }
}

class CloudProvider: ObservableObject {
    let offset: CGSize
    let frameHeightRatio: CGFloat
    init() {
        frameHeightRatio = CGFloat.random(in: 0.7 ..< 1.4)
        offset = CGSize(width: CGFloat.random(in: -150 ..< 150),
                        height: CGFloat.random(in: -150 ..< 150))
    }
}

func withOptionalAnimation<Result>(_ animation: Animation? = .default, _ body: () throws -> Result) rethrows -> Result {
    #if canImport(UIKit)
    if UIAccessibility.isReduceMotionEnabled {
        return try body()
    } else {
        return try withAnimation(animation, body)
    }
    #elseif canImport(AppKit)
    if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
        return try body()
    } else {
        return try withAnimation(animation, body)
    }
    #endif
}

struct LinearNonTransparency: View {
    var colors: [Color]
    @Environment(\.colorScheme) var scheme
    var gradient: Gradient {
        Gradient(colors: colors)
    }

    var body: some View {
        LinearGradient(gradient: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
    }
}
