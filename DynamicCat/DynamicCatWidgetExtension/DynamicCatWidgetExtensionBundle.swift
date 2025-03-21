//
//  DynamicCatWidgetExtensionBundle.swift
//  DynamicCatWidgetExtension
//
//  Created by Sion on 3/22/25.
//

import WidgetKit
import SwiftUI

@main
struct DynamicCatWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
//        DynamicCatWidgetExtension()
        DynamicCatWidgetExtensionControl()
        DynamicCatLiveActivity()
//        DynamicCatWidgetExtensionLiveActivity()
    }
}
