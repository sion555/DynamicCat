//
//  SharedAttributes.swift
//  DynamicCat
//
//  Created by Sion on 3/22/25.
//

import Foundation
import ActivityKit

struct DynamicCatLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var cpuUsage: Double
        var fps: Double
        var memoryUsage: Double
        var networkActivity: Double
        var timestamp: Date
    }
    
    var name: String
}
