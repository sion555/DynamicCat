//
//  DynamicCatApp.swift
//  DynamicCat
//
//  Created by Sion on 3/22/25.
//

import SwiftUI
import BackgroundTasks
import ActivityKit

@main
struct DynamicCatApp: App {
    @Environment(\.scenePhase) private var scenePhase
    
    // 모든 화면에서 공유하는 시스템 모니터링 객체
    @StateObject private var systemMonitor = SystemMonitor()
    
    // 현재 활성화된 Live Activity
    @State private var liveActivity: Activity<DynamicCatLiveActivityAttributes>? = nil
    
    // 백그라운드 태스크 식별자
    private let backgroundTaskIdentifier = "com.sion555.DynamicCat.refresh"
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(systemMonitor)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
        .backgroundTask(.appRefresh(backgroundTaskIdentifier)) {
            await performBackgroundRefresh()
        }
    }
    
    // 앱 생명주기 변화 처리
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            print("App became active")
            // 앱이 활성화될 때 모니터링 시작
            systemMonitor.startMonitoring(interval: 1.0)
            
            // 활성화된 Live Activity가 있는지 확인
            checkForExistingLiveActivities()
            
        case .inactive:
            print("App became inactive")
            // 앱이 비활성화될 때 처리
            if liveActivity != nil {
                // Live Activity가 활성화된 경우 모니터링 계속 유지
                scheduleBackgroundRefresh()
            }
            
        case .background:
            print("App moved to background")
            // 백그라운드로 가면서 처리
            if liveActivity == nil {
                // Live Activity가 없으면 모니터링 중지
                systemMonitor.stopMonitoring()
            } else {
                // Live Activity가 있으면 모니터링 계속 유지하고 백그라운드 태스크 예약
                scheduleBackgroundRefresh()
            }
            
        @unknown default:
            break
        }
    }
    
    // 기존 Live Activity 확인
    private func checkForExistingLiveActivities() {
        Task {
            for activity in Activity<DynamicCatLiveActivityAttributes>.activities {
                liveActivity = activity
                // 기존 활동이 있으면 업데이트
                updateLiveActivity(activity)
                break  // 가장 최근 활동만 사용
            }
        }
    }
    
    // Live Activity 업데이트
    private func updateLiveActivity(_ activity: Activity<DynamicCatLiveActivityAttributes>) {
        Task {
            // 현재 시스템 정보로 상태 업데이트
            let contentState = DynamicCatLiveActivityAttributes.ContentState(
                cpuUsage: systemMonitor.cpuUsage,
                fps: systemMonitor.fps,
                memoryUsage: systemMonitor.memoryUsage,
                networkActivity: systemMonitor.networkActivity,
                timestamp: Date(),
                updateCount: (try? activity.content.state.updateCount + 1) ?? 1,
                statusLevel: .normal,
                batteryLevel: Double(UIDevice.current.batteryLevel) * 100,
                thermalState: DynamicCatLiveActivityAttributes.ContentState.ThermalState(from: ProcessInfo.processInfo)
            )
            
            // ActivityContent 업데이트
            await activity.update(ActivityContent(state: contentState, staleDate: nil))
        }
    }
    
    // 백그라운드 태스크 예약
    private func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        // 지금으로부터 15분 후 실행 (iOS 시스템에 의해 조정될 수 있음)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Background task scheduled")
        } catch {
            print("Could not schedule background task: \(error)")
        }
    }
    
    // 백그라운드 새로고침 수행
    private func performBackgroundRefresh() async {
        print("Performing background refresh")
        
        // 현재 활성화된 Live Activity 있는지 확인
        var hasActiveActivity = false
        
        for activity in Activity<DynamicCatLiveActivityAttributes>.activities {
            hasActiveActivity = true
            
            // 시스템 정보 가져오기 (백그라운드에서 제한적으로 가능)
            systemMonitor.startMonitoring(interval: 1.0)
            
            // 잠시 대기하여 모니터링 데이터 수집
            try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1초
            
            // Live Activity 업데이트
            updateLiveActivity(activity)
        }
        
        // 다음 백그라운드 태스크 예약 (활성 Activity가 있는 경우만)
        if hasActiveActivity {
            scheduleBackgroundRefresh()
        }
        
        // 작업 완료
        systemMonitor.stopMonitoring()
    }
}

// Info.plist에 추가되어야 하는 항목:
/*
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.sion555.DynamicCat.refresh</string>
</array>
*/
