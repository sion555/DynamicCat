//
//  ContentView.swift
//  DynamicCat
//
//  Created by Sion on 3/22/25.
//

import SwiftUI
import ActivityKit
import Combine

// ContentView를 class로 변환하여 @objc 메서드와 weak 참조를 사용할 수 있게 함
class ContentViewModel: ObservableObject {
    @Published var systemMonitor = SystemMonitor()
    @Published var settings = AppSettings()
    @Published var currentActivity: Activity<DynamicCatLiveActivityAttributes>? = nil
    @Published var activityState: DynamicCatLiveActivityAttributes.ContentState?
    @Published var isSettingsPresented = false
    
    // 백그라운드에서 업데이트 알림을 받기 위한 구독
    var metricsSubscription: AnyCancellable?
    
    // 자동 업데이트 타이머
    var liveActivityUpdateTimer: Timer?
    
    // 실시간 배터리 정보
    @Published var batteryLevel: Double = 100.0
    @Published var thermalState: DynamicCatLiveActivityAttributes.ContentState.ThermalState = .nominal
    
    var updateFrequency: TimeInterval {
        return settings.updateInterval
    }
    
    init() {
        setupMonitoring()
    }
    
    func setupMonitoring() {
        systemMonitor.startMonitoring(interval: settings.updateInterval)
        setupBackgroundUpdates()
        setupBatteryMonitoring()
    }
    
    // 백그라운드 업데이트 설정
    private func setupBackgroundUpdates() {
        // 기존 구독 정리
        cleanupSubscriptions()
        
        // 시스템 메트릭 업데이트 구독 - weak 참조 수정
        metricsSubscription = NotificationCenter.default
            .publisher(for: NSNotification.Name("SystemMetricsUpdated"))
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let self = self, let userInfo = notification.userInfo else { return }
                
                // Live Activity 업데이트
                self.updateLiveActivityWithLatestData(userInfo: userInfo)
            }
    }
    
    // 배터리 모니터링 설정
    private func setupBatteryMonitoring() {
        // UIDevice 배터리 모니터링 활성화
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        // 초기 배터리 레벨 읽기
        updateBatteryInfo()
        
        // 배터리 알림 등록
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batteryLevelDidChange),
            name: UIDevice.batteryLevelDidChangeNotification,
            object: nil
        )
        
        // 열 상태 알림 등록
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(thermalStateDidChange),
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil
        )
    }
    
    // 리소스 정리
    func cleanupSubscriptions() {
        metricsSubscription?.cancel()
        metricsSubscription = nil
        
        liveActivityUpdateTimer?.invalidate()
        liveActivityUpdateTimer = nil
        
        // 알림 제거
        NotificationCenter.default.removeObserver(self)
    }
    
    // 배터리 레벨 변경 처리
    @objc private func batteryLevelDidChange() {
        updateBatteryInfo()
    }
    
    // 열 상태 변경 처리
    @objc private func thermalStateDidChange() {
        thermalState = DynamicCatLiveActivityAttributes.ContentState.ThermalState(from: ProcessInfo.processInfo)
        updateLiveActivityWithCurrentData()
    }
    
    // 배터리 정보 업데이트
    private func updateBatteryInfo() {
        batteryLevel = Double(UIDevice.current.batteryLevel) * 100
        if batteryLevel < 0 { batteryLevel = 100 } // 시뮬레이터에서는 -1 반환
    }
    
    // Live Activity 토글
    func toggleLiveActivity() {
        if currentActivity == nil {
            startLiveActivity()
        } else {
            endLiveActivity()
        }
    }
    
    // Live Activity 시작
    private func startLiveActivity() {
        guard currentActivity == nil else { return }
        
        let attributes = DynamicCatLiveActivityAttributes(
            name: "DynamicCat",
            appVersion: "1.0",
            configuration: DynamicCatLiveActivityAttributes.ConfigOptions(
                showAllMetrics: settings.selectedMonitors.count > 2,
                updateFrequency: .medium
            )
        )
        
        let contentState = createLiveActivityContentState()
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: nil),
                pushType: nil
            )
            
            self.currentActivity = activity
            self.activityState = contentState
            
            // 주기적 업데이트 타이머 설정
            scheduleLiveActivityUpdates()
        } catch {
            print("Error starting live activity: \(error)")
        }
    }
    
    // Live Activity 종료
    func endLiveActivity() {
        Task {
            if let activity = currentActivity {
                let contentState = createLiveActivityContentState()
                
                // 최신 API 사용
                await activity.end(
                    ActivityContent(state: contentState, staleDate: nil),
                    dismissalPolicy: .immediate
                )
                
                // 상태 초기화
                DispatchQueue.main.async {
                    self.currentActivity = nil
                    self.activityState = nil
                    
                    // 타이머 정리
                    self.liveActivityUpdateTimer?.invalidate()
                    self.liveActivityUpdateTimer = nil
                }
            }
        }
    }
    
    // Live Activity 업데이트 스케줄링
    private func scheduleLiveActivityUpdates() {
        // 이전 타이머 정리
        liveActivityUpdateTimer?.invalidate()
        
        // 새 타이머 생성 - weak 참조 수정
        liveActivityUpdateTimer = Timer.scheduledTimer(
            withTimeInterval: updateFrequency,
            repeats: true
        ) { [weak self] _ in
            guard let self = self, self.currentActivity != nil else { return }
            self.updateLiveActivityWithCurrentData()
        }
        
        // 백그라운드에서도 작동하도록 설정
        RunLoop.current.add(liveActivityUpdateTimer!, forMode: .common)
    }
    
    // 현재 데이터로 Live Activity 업데이트
    func updateLiveActivityWithCurrentData() {
        // 최신 상태 생성
        let contentState = createLiveActivityContentState()
        
        // Live Activity 업데이트
        if let activity = currentActivity {
            Task {
                await activity.update(
                    ActivityContent(state: contentState, staleDate: nil)
                )
                
                // UI 업데이트
                DispatchQueue.main.async {
                    self.activityState = contentState
                }
            }
        }
    }
    
    // 사용자 정보로 Live Activity 업데이트
    private func updateLiveActivityWithLatestData(userInfo: [AnyHashable: Any]) {
        // 알림에서 데이터 추출
        guard let activity = currentActivity,
              let cpuUsage = userInfo["cpuUsage"] as? Double,
              let fps = userInfo["fps"] as? Double,
              let memoryUsage = userInfo["memoryUsage"] as? Double,
              let networkActivity = userInfo["networkActivity"] as? Double else {
            return
        }
        
        // 이전 상태 가져오기
        let updateCount = (activityState?.updateCount ?? 0) + 1
        
        // 새 상태 생성
        var contentState = DynamicCatLiveActivityAttributes.ContentState(
            cpuUsage: cpuUsage,
            fps: fps,
            memoryUsage: memoryUsage,
            networkActivity: networkActivity,
            timestamp: Date(),
            updateCount: updateCount,
            statusLevel: .normal,
            batteryLevel: batteryLevel,
            thermalState: thermalState
        )
        
        // 상태 레벨 업데이트
        contentState.updateStatusLevel(
            thresholds: (
                low: Double(settings.lowThreshold),
                high: Double(settings.highThreshold)
            )
        )
        
        // Live Activity 업데이트
        Task {
            await activity.update(
                ActivityContent(state: contentState, staleDate: nil)
            )
            
            // UI 업데이트
            DispatchQueue.main.async {
                self.activityState = contentState
            }
        }
    }
    
    // Live Activity 상태 생성
    private func createLiveActivityContentState() -> DynamicCatLiveActivityAttributes.ContentState {
        // 이전 상태에서 업데이트 카운트 가져오기
        let updateCount = (activityState?.updateCount ?? 0) + 1
        
        // 새 상태 생성
        var contentState = DynamicCatLiveActivityAttributes.ContentState(
            cpuUsage: systemMonitor.cpuUsage,
            fps: systemMonitor.fps,
            memoryUsage: systemMonitor.memoryUsage,
            networkActivity: systemMonitor.networkActivity,
            timestamp: Date(),
            updateCount: updateCount,
            statusLevel: .normal,
            batteryLevel: batteryLevel,
            thermalState: thermalState
        )
        
        // 상태 레벨 업데이트
        contentState.updateStatusLevel(
            thresholds: (
                low: Double(settings.lowThreshold),
                high: Double(settings.highThreshold)
            )
        )
        
        return contentState
    }
    
    // Live Activity 구성 업데이트
    func updateLiveActivityConfiguration() {
        guard let activity = currentActivity else { return }
        
        // 새 상태 생성
        let contentState = createLiveActivityContentState()
        
        // 업데이트 빈도 결정
        let updateFrequency: DynamicCatLiveActivityAttributes.ConfigOptions.UpdateFrequency
        switch settings.updateInterval {
        case 0.5:
            updateFrequency = .high
        case 1.0:
            updateFrequency = .medium
        default:
            updateFrequency = .low
        }
        
        // 활동 종료 후 새 구성으로 다시 시작
        Task {
            await activity.end(
                ActivityContent(state: contentState, staleDate: nil),
                dismissalPolicy: .immediate
            )
            
            DispatchQueue.main.async {
                self.currentActivity = nil
                self.activityState = nil
                
                // 새 구성으로 재시작
                let attributes = DynamicCatLiveActivityAttributes(
                    name: "DynamicCat",
                    appVersion: "1.0",
                    configuration: DynamicCatLiveActivityAttributes.ConfigOptions(
                        showAllMetrics: self.settings.selectedMonitors.count > 2,
                        updateFrequency: updateFrequency
                    )
                )
                
                do {
                    let newActivity = try Activity.request(
                        attributes: attributes,
                        content: .init(state: contentState, staleDate: nil),
                        pushType: nil
                    )
                    
                    self.currentActivity = newActivity
                    self.activityState = contentState
                    
                    // 타이머 업데이트
                    self.scheduleLiveActivityUpdates()
                } catch {
                    print("Error restarting live activity: \(error)")
                }
            }
        }
    }
    
    // 모니터 타입에 따른 아이콘
    func iconForMonitorType(_ type: MonitorType) -> String {
        switch type {
        case .cpu:
            return "cpu"
        case .fps:
            return "gauge.high"
        case .memory:
            return "memorychip"
        case .network:
            return "network"
        }
    }
    
    // 모니터 타입에 따른 값 반환 (포맷팅)
    func formattedValueForMonitorType(_ type: MonitorType) -> String {
        let value = valueForMonitorType(type)
        switch type {
        case .cpu:
            return String(format: "%.1f", value)
        case .fps:
            return String(format: "%.0f", value)
        case .memory:
            return String(format: "%.0f", value)
        case .network:
            return String(format: "%.1f", value)
        }
    }
    
    // 모니터 타입에 따른 값 반환
    func valueForMonitorType(_ type: MonitorType) -> Double {
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
    func colorForMonitorValue(_ type: MonitorType) -> Color {
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
        
        return getStatusColor(1 - (normalizedValue / 100))
    }
    
    // 상태 색상 가져오기
    func getStatusColor(_ normalizedValue: Double) -> Color {
        let lowThreshold = Double(settings.lowThreshold) / 100
        let highThreshold = Double(settings.highThreshold) / 100
        
        if normalizedValue >= highThreshold {
            return settings.highValueColor
        } else if normalizedValue >= lowThreshold {
            return settings.mediumValueColor
        } else {
            return settings.lowValueColor
        }
    }
    
    // 애니메이션 속도 계산
    func calculateAnimationSpeed() -> Double {
        let cpuSpeed = systemMonitor.cpuUsage / 100 * 1.5 + 0.5 // 0.5 ~ 2.0
        return max(0.5, min(2.0, cpuSpeed))
    }
    
    // 시간 형식화
    func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
    
    // 해제 시 리소스 정리
    deinit {
        cleanupSubscriptions()
    }
}

// SwiftUI View 구조체
struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    
    // 배터리 아이콘 계산
    private var batteryIcon: String {
        if viewModel.batteryLevel <= 20 {
            return "battery.0"
        } else if viewModel.batteryLevel <= 40 {
            return "battery.25"
        } else if viewModel.batteryLevel <= 60 {
            return "battery.50"
        } else if viewModel.batteryLevel <= 80 {
            return "battery.75"
        } else {
            return "battery.100"
        }
    }
    
    var body: some View {
        ZStack {
            // 배경 그라데이션
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: "1A1A2E"), Color(hex: "16213E")]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 25) {
                // 헤더
                Text("DynamicCat")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 20)
                
                // 시스템 상태 요약
                systemStatusView
                    .padding(.horizontal)
                
                // 고양이 애니메이션
                if viewModel.settings.showCatAnimation {
                    catAnimationView
                        .frame(height: 100)
                        .padding()
                }
                
                // 실시간 모니터링 정보
                monitoringInfoView
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(hex: "222B45").opacity(0.8))
                            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                    )
                    .padding(.horizontal)
                
                // 동적 섬 활성화 버튼
                Button(action: { viewModel.toggleLiveActivity() }) {
                    HStack {
                        Image(systemName: viewModel.currentActivity == nil ? "plus.circle.fill" : "minus.circle.fill")
                            .font(.system(size: 18))
                        Text(viewModel.currentActivity == nil ? "Dynamic Island 활성화" : "Dynamic Island 비활성화")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(viewModel.currentActivity == nil ? Color.blue : Color.red)
                            .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 3)
                    )
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // 설정 버튼
                Button(action: { viewModel.isSettingsPresented = true }) {
                    HStack {
                        Image(systemName: "gear")
                            .font(.system(size: 16))
                        Text("설정")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color(hex: "0F3460"))
                            .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 3)
                    )
                    .padding(.horizontal)
                }
            }
            .padding()
        }
        .sheet(isPresented: $viewModel.isSettingsPresented) {
            SettingsView(settings: $viewModel.settings, onUpdateInterval: { interval in
                viewModel.systemMonitor.updateInterval(to: interval)
                viewModel.updateLiveActivityConfiguration()
            })
        }
    }
    
    // 시스템 상태 요약 뷰
    private var systemStatusView: some View {
        HStack(spacing: 20) {
            // CPU 상태
            statusIndicator(
                value: viewModel.systemMonitor.cpuUsage,
                maxValue: 100,
                icon: "cpu",
                title: "CPU",
                format: "%.1f%%"
            )
            
            // FPS 상태
            statusIndicator(
                value: viewModel.systemMonitor.fps,
                maxValue: 60,
                isInverted: true,
                icon: "gauge.high",
                title: "FPS",
                format: "%.0f"
            )
            
            // 배터리 상태
            statusIndicator(
                value: viewModel.batteryLevel,
                maxValue: 100,
                isInverted: true,
                icon: batteryIcon,
                title: "배터리",
                format: "%.0f%%"
            )
        }
    }
    
    // 상태 표시기 뷰
    private func statusIndicator(value: Double, maxValue: Double, isInverted: Bool = false, icon: String, title: String, format: String) -> some View {
        // isInverted가 true이면 값이 높을수록 좋음 (예: FPS)
        let normalizedValue = isInverted ? (value / maxValue) : (1 - (value / maxValue))
        let statusColor = viewModel.getStatusColor(normalizedValue)
        
        return VStack {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(statusColor)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.white)
            
            Text(String(format: format, value))
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(statusColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.black.opacity(0.2))
        )
    }
    
    // 고양이 애니메이션 뷰
    private var catAnimationView: some View {
        Image(systemName: "cat.fill")
            .font(.system(size: 64))
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.5), radius: 2, x: 1, y: 1)
            .modifier(ShakeEffect(animatableData: viewModel.calculateAnimationSpeed()))
    }
    
    // 모니터링 정보 뷰
    private var monitoringInfoView: some View {
        VStack(spacing: 18) {
            ForEach(viewModel.settings.selectedMonitors, id: \.self) { monitor in
                HStack {
                    Image(systemName: viewModel.iconForMonitorType(monitor))
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .frame(width: 30)
                    
                    Text(monitor.description)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("\(viewModel.formattedValueForMonitorType(monitor)) \(monitor.unit)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(viewModel.colorForMonitorValue(monitor))
                }
                
                if monitor != viewModel.settings.selectedMonitors.last {
                    Divider()
                        .background(Color.gray.opacity(0.3))
                }
            }
            
            // 추가 정보: 업데이트 시간 및 활성화 상태
            HStack {
                if let activity = viewModel.currentActivity {
                    Label {
                        Text("Live Activity 활성화됨")
                            .font(.caption)
                            .foregroundColor(.blue)
                    } icon: {
                        Image(systemName: "checkerboard.shield")
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    if let state = viewModel.activityState {
                        Text("마지막 업데이트: \(viewModel.formattedTime(state.timestamp))")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.top, 5)
        }
        .padding()
    }
}

// 고양이 애니메이션을 위한 효과
struct ShakeEffect: GeometryEffect {
    var animatableData: Double
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        let angle = sin(animatableData * Date().timeIntervalSince1970 * 10) * 0.05
        let translation = CGSize(width: sin(animatableData * Date().timeIntervalSince1970 * 10) * 5, height: 0)
        let rotation = CGAffineTransform(rotationAngle: angle)
        let translationTransform = CGAffineTransform(translationX: translation.width, y: translation.height)
        return ProjectionTransform(rotation.concatenating(translationTransform))
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
