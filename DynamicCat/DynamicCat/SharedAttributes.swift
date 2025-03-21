//
//  SharedAttributes.swift
//  DynamicCat
//
//  Created by Sion on 3/22/25.
//

import Foundation
import ActivityKit

// Live Activity와 Dynamic Island에서 사용할 속성들
struct DynamicCatLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // 시스템 성능 메트릭
        var cpuUsage: Double
        var fps: Double
        var memoryUsage: Double
        var networkActivity: Double
        
        // 업데이트 타임스탬프
        var timestamp: Date
        
        // 업데이트 횟수 (LiveActivity 업데이트 추적용)
        var updateCount: Int
        
        // 상태 심각도 (색상 변경을 위해 사용)
        var statusLevel: StatusLevel
        
        // 추가 상태 정보
        var batteryLevel: Double?
        var thermalState: ThermalState?
        
        // 상태 단계 열거형
        enum StatusLevel: Int, Codable {
            case normal = 0
            case warning = 1
            case critical = 2
            
            var color: String {
                switch self {
                case .normal: return "green"
                case .warning: return "yellow"
                case .critical: return "red"
                }
            }
        }
        
        // 디바이스 발열 상태
        enum ThermalState: Int, Codable {
            case nominal = 0
            case fair = 1
            case serious = 2
            case critical = 3
            
            init(from processInfo: ProcessInfo) {
                switch processInfo.thermalState {
                case .nominal: self = .nominal
                case .fair: self = .fair
                case .serious: self = .serious
                case .critical: self = .critical
                @unknown default: self = .nominal
                }
            }
        }
        
        // 상태 레벨 계산
        mutating func updateStatusLevel(thresholds: (low: Double, high: Double)) {
            // CPU 사용량을 기준으로 상태 레벨 결정
            if cpuUsage >= thresholds.high ||
               (thermalState == .serious || thermalState == .critical) {
                statusLevel = .critical
            } else if cpuUsage >= thresholds.low {
                statusLevel = .warning
            } else {
                statusLevel = .normal
            }
        }
    }
    
    // 앱 식별자
    var name: String
    
    // 앱 정보
    var appVersion: String
    
    // 추가 구성 옵션
    var configuration: ConfigOptions
    
    struct ConfigOptions: Codable, Hashable {
        var showAllMetrics: Bool
        var updateFrequency: UpdateFrequency
        
        enum UpdateFrequency: String, Codable {
            case low = "low"       // 5초마다
            case medium = "medium" // 2초마다
            case high = "high"     // 1초마다
            
            var seconds: TimeInterval {
                switch self {
                case .low: return 5.0
                case .medium: return 2.0
                case .high: return 1.0
                }
            }
        }
    }
}
