//
//  DynamicCatLiveActivity.swift
//  DynamicCatWidgetExtension
//
//  Created by Sion on 3/22/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct DynamicCatLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DynamicCatLiveActivityAttributes.self) { context in
            // 라이브 액티비티 뷰 (알림 및 잠금 화면)
            ZStack {
                // 배경
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.black.opacity(0.8))
                
                VStack(spacing: 10) {
                    // 헤더
                    HStack {
                        Image(systemName: "gauge.medium")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("DynamicCat 모니터")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        // 시간 표시
                        Text(formatDate(context.state.timestamp))
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    
                    Divider()
                        .background(Color.gray.opacity(0.3))
                    
                    // 성능 메트릭 표시
                    HStack(spacing: 15) {
                        // CPU 메트릭
                        MetricView(
                            icon: "cpu",
                            value: String(format: "%.1f%%", context.state.cpuUsage),
                            title: "CPU",
                            color: colorForValue(context.state.cpuUsage)
                        )
                        
                        // FPS 메트릭
                        MetricView(
                            icon: "gauge.high",
                            value: String(format: "%.0f", context.state.fps),
                            title: "FPS",
                            color: colorForFPS(context.state.fps)
                        )
                        
                        if context.attributes.configuration.showAllMetrics {
                            // 메모리 메트릭
                            MetricView(
                                icon: "memorychip",
                                value: String(format: "%.0f MB", context.state.memoryUsage),
                                title: "메모리",
                                color: .blue
                            )
                            
                            // 네트워크 메트릭
                            MetricView(
                                icon: "network",
                                value: String(format: "%.1f KB/s", context.state.networkActivity),
                                title: "네트워크",
                                color: .green
                            )
                        }
                    }
                    
                    // 애니메이션 효과
                    catAnimationView(speed: calculateAnimationSpeed(cpu: context.state.cpuUsage))
                        .frame(height: 30)
                }
                .padding()
            }
        } dynamicIsland: { context in
            DynamicIsland {
                // 확장 상태 (펼쳐진 Dynamic Island)
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        catAnimationView(speed: calculateAnimationSpeed(cpu: context.state.cpuUsage))
                            .frame(width: 36, height: 36)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("CPU")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.gray)
                            Text("\(Int(context.state.cpuUsage))%")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(colorForValue(context.state.cpuUsage))
                        }
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("FPS")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                        Text("\(Int(context.state.fps))")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(colorForFPS(context.state.fps))
                    }
                }
                
                DynamicIslandExpandedRegion(.center) {
                    Text("DynamicCat")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .frame(width: 80)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 20) {
                        // 메모리 정보
                        VStack(alignment: .leading, spacing: 2) {
                            Label {
                                Text("Memory")
                                    .font(.system(size: 12, weight: .medium))
                            } icon: {
                                Image(systemName: "memorychip")
                                    .font(.system(size: 14))
                            }
                            .foregroundColor(.gray)
                            
                            Text("\(Int(context.state.memoryUsage)) MB")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        // 네트워크 정보
                        VStack(alignment: .trailing, spacing: 2) {
                            Label {
                                Text("Network")
                                    .font(.system(size: 12, weight: .medium))
                            } icon: {
                                Image(systemName: "network")
                                    .font(.system(size: 14))
                            }
                            .foregroundColor(.gray)
                            
                            Text("\(Int(context.state.networkActivity)) KB/s")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.top, 8)
                }
            } compactLeading: {
                // 축소된 상태 - 왼쪽 부분
                catAnimationView(speed: calculateAnimationSpeed(cpu: context.state.cpuUsage))
                    .frame(width: 20, height: 20)
            } compactTrailing: {
                // 축소된 상태 - 오른쪽 부분
                Text("\(Int(context.state.cpuUsage))%")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(colorForValue(context.state.cpuUsage))
            } minimal: {
                // 최소 상태
                Image(systemName: "gauge.medium")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(colorForValue(context.state.cpuUsage))
            }
            // 수정: contentMargins 호출 방식 변경
            .widgetURL(URL(string: "dynamiccat://refresh"))
        }
    }
    
    // 애니메이션 속도 계산 (CPU 사용량에 따라)
    private func calculateAnimationSpeed(cpu: Double) -> Double {
        // CPU 사용량에 비례하여 속도 조절 (최소 0.5, 최대 2.0)
        return max(0.5, min(2.0, cpu / 100.0 * 1.5 + 0.5))
    }
    
    // CPU 값에 따른 색상 변경
    private func colorForValue(_ value: Double) -> Color {
        switch value {
        case 0..<30:
            return .green
        case 30..<70:
            return .yellow
        default:
            return .red
        }
    }
    
    // FPS 값에 따른 색상 변경 (높을수록 좋음)
    private func colorForFPS(_ value: Double) -> Color {
        switch value {
        case 0..<30:
            return .red
        case 30..<50:
            return .yellow
        default:
            return .green
        }
    }
    
    // 날짜 포맷팅
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
    
    // 고양이 애니메이션 뷰
    private func catAnimationView(speed: Double) -> some View {
        Image(systemName: "cat.fill")
            .font(.system(size: 24))
            .foregroundColor(.white)
            .modifier(ShakeEffect(animatableData: speed))
    }
}

// 메트릭 표시를 위한 뷰
struct MetricView: View {
    let icon: String
    let value: String
    let title: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
                
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(color)
            }
            
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
    }
}

// 고양이 애니메이션을 위한 효과
struct ShakeEffect: GeometryEffect {
    var animatableData: Double
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        // 현재 시간을 기반으로 애니메이션 적용
        let time = Date().timeIntervalSince1970
        
        // 각도 계산 (사인파로 흔들림 생성)
        let angle = sin(animatableData * time * 5) * 0.05
        
        // 위치 이동
        let xOffset = sin(animatableData * time * 10) * 3
        
        // 회전 및 이동 변환
        let rotation = CGAffineTransform(rotationAngle: angle)
        let translation = CGAffineTransform(translationX: xOffset, y: 0)
        
        return ProjectionTransform(rotation.concatenating(translation))
    }
}

// Live Activity 미리보기용 데이터
extension DynamicCatLiveActivityAttributes {
    static var preview: DynamicCatLiveActivityAttributes {
        DynamicCatLiveActivityAttributes(
            name: "DynamicCat",
            appVersion: "1.0.0",
            configuration: ConfigOptions(
                showAllMetrics: true,
                updateFrequency: .medium
            )
        )
    }
}

extension DynamicCatLiveActivityAttributes.ContentState {
    static var preview: DynamicCatLiveActivityAttributes.ContentState {
        DynamicCatLiveActivityAttributes.ContentState(
            cpuUsage: 45.6,
            fps: 58.7,
            memoryUsage: 256.3,
            networkActivity: 32.4,
            timestamp: Date(),
            updateCount: 1,
            statusLevel: .normal,
            batteryLevel: 85.0,
            thermalState: .nominal
        )
    }
    
    static var critical: DynamicCatLiveActivityAttributes.ContentState {
        DynamicCatLiveActivityAttributes.ContentState(
            cpuUsage: 88.5,
            fps: 28.3,
            memoryUsage: 845.7,
            networkActivity: 128.9,
            timestamp: Date(),
            updateCount: 10,
            statusLevel: .critical,
            batteryLevel: 25.0,
            thermalState: .serious
        )
    }
}
