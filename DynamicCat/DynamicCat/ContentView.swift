//
//  ContentView.swift
//  DynamicCat
//
//  Created by Sion on 3/22/25.
//

import SwiftUI
import ActivityKit

struct ContentView: View {
    @StateObject private var systemMonitor = SystemMonitor()
    @State private var settings = AppSettings()
    @State private var isSettingsPresented = false
    @State private var currentActivity: Activity<DynamicCatLiveActivityAttributes>? = nil
    
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // 배경
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: "1A1A2E"), Color(hex: "16213E")]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 30) {
                // 헤더
                Text("DynamicCat")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 30)
                
                // 고양이 애니메이션
                if settings.showCatAnimation {
                    catAnimationView
                        .frame(height: 120)
                        .padding()
                }
                
                // 실시간 모니터링 정보
                monitoringInfoView
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(hex: "222B45").opacity(0.7))
                    )
                    .padding(.horizontal)
                
                // 동적 섬 활성화 버튼
                Button(action: toggleLiveActivity) {
                    Text(currentActivity == nil ? "Dynamic Island 활성화" : "Dynamic Island 비활성화")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(currentActivity == nil ? Color.blue : Color.red)
                        )
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // 설정 버튼
                Button(action: { isSettingsPresented = true }) {
                    Text("설정")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color(hex: "0F3460"))
                        )
                        .padding(.horizontal)
                }
            }
            .padding()
        }
        .onAppear {
            systemMonitor.startMonitoring(interval: settings.updateInterval)
        }
        .onDisappear {
            systemMonitor.stopMonitoring()
            endLiveActivity()
        }
        .onReceive(timer) { _ in
            updateLiveActivity()
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView(settings: $settings, onUpdateInterval: { interval in
                systemMonitor.updateInterval(to: interval)
            })
        }
    }
    
    // 고양이 애니메이션 뷰
    private var catAnimationView: some View {
        Image("cat_sprite") // 고양이 스프라이트 이미지 필요 (앱 에셋에 추가)
            .resizable()
            .aspectRatio(contentMode: .fit)
//            .modifier(ShakeEffect(animatableData: calculateAnimationSpeed()))
    }
    
    // 모니터링 정보 뷰
    private var monitoringInfoView: some View {
        VStack(spacing: 15) {
            ForEach(settings.selectedMonitors, id: \.self) { monitor in
                HStack {
                    Text(monitor.description)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("\(valueForMonitorType(monitor), specifier: "%.1f") \(monitor.unit)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(colorForMonitorValue(monitor))
                }
                
                if monitor != settings.selectedMonitors.last {
                    Divider()
                        .background(Color.gray.opacity(0.3))
                }
            }
        }
        .padding()
    }
    
    // 모니터 타입에 따른 값 반환
    private func valueForMonitorType(_ type: MonitorType) -> Double {
        switch type {
        case .cpu:
            return systemMonitor.cpuUsage
        case .fps:
            return systemMonitor.fps
        case .memory:
            return systemMonitor.memoryUsage
        case .network:
            return systemMonitor.networkActivity
        }
    }
    
    // 값에 따른 색상 변경
    private func colorForMonitorValue(_ type: MonitorType) -> Color {
        let value = valueForMonitorType(type)
        let normalizedValue: Double
        
        switch type {
        case .cpu:
            normalizedValue = value // 0-100%
        case .fps:
            normalizedValue = 100 - (value / 60 * 100) // FPS는 높을수록 좋으므로 반전
        case .memory:
            normalizedValue = min(100, value / 4000 * 100) // 4GB를 최대로 가정
        case .network:
            normalizedValue = min(100, value / 1000 * 100) // 1MB/s를 최대로 가정
        }
        
        if normalizedValue < settings.lowThreshold {
            return settings.lowValueColor
        } else if normalizedValue < settings.highThreshold {
            return settings.mediumValueColor
        } else {
            return settings.highValueColor
        }
    }
    
    // 애니메이션 속도 계산
    private func calculateAnimationSpeed() -> Double {
        let cpuSpeed = systemMonitor.cpuUsage / 100 * 1.5 + 0.5 // 0.5 ~ 2.0
        return max(0.5, min(2.0, cpuSpeed))
    }
    
    // Live Activity 토글
    private func toggleLiveActivity() {
        if currentActivity == nil {
            startLiveActivity()
        } else {
            endLiveActivity()
        }
    }
    
    // LiveActivity 시작 함수 수정
    private func startLiveActivity() {
        // 로그 추가
        print("Attempting to start Live Activity")
        
        guard currentActivity == nil else {
            print("Activity already exists")
            return
        }
        
        // 명시적으로 권한 확인
        if ActivityAuthorizationInfo().areActivitiesEnabled {
            print("Live Activities are enabled")
        } else {
            print("Live Activities are NOT enabled")
            return
        }
        
        let attributes = DynamicCatLiveActivityAttributes(name: "DynamicCat")
        let contentState = DynamicCatLiveActivityAttributes.ContentState(
            cpuUsage: systemMonitor.cpuUsage,
            fps: systemMonitor.fps,
            memoryUsage: systemMonitor.memoryUsage,
            networkActivity: systemMonitor.networkActivity,
            timestamp: Date()
        )
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: contentState, staleDate: nil)
            )
            print("Successfully requested Live Activity: \(activity.id)")
            currentActivity = activity
        } catch {
            print("Error requesting Live Activity: \(error.localizedDescription)")
        }
    }
    
    // Live Activity 종료
    private func endLiveActivity() {
        Task {
            if let activity = currentActivity {
                let contentState = DynamicCatLiveActivityAttributes.ContentState(
                    cpuUsage: systemMonitor.cpuUsage,
                    fps: systemMonitor.fps,
                    memoryUsage: systemMonitor.memoryUsage,
                    networkActivity: systemMonitor.networkActivity,
                    timestamp: Date()
                )
                
                await activity.end(ActivityContent(state: contentState, staleDate: nil), dismissalPolicy: .immediate)
            }
            currentActivity = nil
        }
    }
    
    // Live Activity 업데이트
    private func updateLiveActivity() {
        guard let activity = currentActivity else { return }
        
        let contentState = DynamicCatLiveActivityAttributes.ContentState(
            cpuUsage: systemMonitor.cpuUsage,
            fps: systemMonitor.fps,
            memoryUsage: systemMonitor.memoryUsage,
            networkActivity: systemMonitor.networkActivity,
            timestamp: Date()
        )
        
        Task {
            await activity.update(ActivityContent(state: contentState, staleDate: nil))
        }
    }
}

// 16진수 색상 변환 확장
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
