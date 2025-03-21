//
//  Models.swift
//  DynamicCat
//
//  Created by Sion on 3/22/25.
//

import SwiftUI
import ActivityKit

struct DynamicCatAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var cpuUsage: Double
        var fps: Double
        var animationSpeed: Double
    }
    
    var name: String
}

enum MonitorType: String, CaseIterable, Identifiable {
    case cpu = "CPU"
    case fps = "FPS"
    case memory = "Memory"
    case network = "Network"
    
    var id: String { self.rawValue }
    
    var description: String {
        switch self {
        case .cpu: return "CPU 사용량"
        case .fps: return "프레임 속도"
        case .memory: return "메모리 사용량"
        case .network: return "네트워크 활동"
        }
    }
    
    var unit: String {
        switch self {
        case .cpu: return "%"
        case .fps: return "FPS"
        case .memory: return "MB"
        case .network: return "KB/s"
        }
    }
}

struct AppSettings {
    var selectedMonitors: [MonitorType] = [.cpu, .fps]
    var updateInterval: TimeInterval = 1.0
    var lowValueColor: Color = .green
    var mediumValueColor: Color = .yellow
    var highValueColor: Color = .red
    var lowThreshold: Double = 30.0
    var highThreshold: Double = 70.0
    var showCatAnimation: Bool = true
}
