//
//  AirPlayRoutePicker.swift
//  Turncast (iOS)
//
//  Created by Harry Shamansky on 12/27/20.
//  Copyright © 2020 Harry Shamansky. All rights reserved.
//

import AVKit
import Foundation
import SwiftUI

struct AirPlayRoutePickerView: UIViewRepresentable {
    
    func makeUIView(context: Context) -> UIView {

        let routePickerView = AVRoutePickerView()
        routePickerView.backgroundColor = UIColor.clear
        routePickerView.activeTintColor = UIColor(named: "AccentColor")
        routePickerView.tintColor = UIColor.label
        routePickerView.prioritizesVideoDevices = false
        return routePickerView
    }

    func updateUIView(_ uiView: UIView, context: Context) {
    }
}
