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
    // AppDelegate 연결
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // 앱 생명주기 감지
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
                .onOpenURL { url in
                    // URL 스킴 처리
                    handleURL(url)
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(to: newPhase)
        }
    }
    
    // 앱 생명주기 변화 처리
    private func handleScenePhaseChange(to newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            print("App became active")
            // 앱이 활성화될 때 모니터링 시작
            systemMonitor.startMonitoring(interval: 1.0)
            
            // 활성화된 Live Activity가 있는지 확인
            checkForExistingLiveActivities()
            
        case .inactive:
            print("App became inactive")
            // Live Activity가 활성화된 경우 모니터링 계속 유지
            
        case .background:
            print("App moved to background")
            // Live Activity가 없으면 모니터링 중지
            if !hasActiveLiveActivities() {
                systemMonitor.stopMonitoring()
            }
            
        @unknown default:
            break
        }
    }
    
    // URL 처리
    private func handleURL(_ url: URL) {
        guard let scheme = url.scheme, scheme == "dynamiccat" else { return }
        
        // 동작 경로에 따라 처리
        if url.host == "refresh" {
            // Live Activity 강제 업데이트
            updateLiveActivities()
        }
    }
    
    // 활성 Live Activity가 있는지 확인
    private func hasActiveLiveActivities() -> Bool {
        if #available(iOS 16.2, *) {
            return !Activity<DynamicCatLiveActivityAttributes>.activities.isEmpty
        } else {
            return false
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
    
    // 모든 활성 Live Activity 업데이트
    private func updateLiveActivities() {
        Task {
            for activity in Activity<DynamicCatLiveActivityAttributes>.activities {
                updateLiveActivity(activity)
            }
        }
    }
    
    // Live Activity 업데이트
    private func updateLiveActivity(_ activity: Activity<DynamicCatLiveActivityAttributes>) {
        Task {
            // 현재 시스템 정보로 상태 업데이트
            var contentState = DynamicCatLiveActivityAttributes.ContentState(
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
            
            // 상태 레벨 업데이트
            contentState.updateStatusLevel(thresholds: (low: 30.0, high: 70.0))
            
            // ActivityContent 업데이트
            await activity.update(ActivityContent(state: contentState, staleDate: nil))
        }
    }
}
