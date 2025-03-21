//
//  AppDelegate.swift
//  DynamicCat
//
//  Created by Sion on 3/22/25.
//

import UIKit
import BackgroundTasks

class AppDelegate: NSObject, UIApplicationDelegate {
    // 앱이 시작될 때 호출
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // 배터리 모니터링 활성화
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        // 백그라운드 태스크 등록
        registerBackgroundTasks()
        
        return true
    }
    
    // 백그라운드 태스크 등록
    private func registerBackgroundTasks() {
        // 앱 리프레시 태스크 등록
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.sion555.DynamicCat.refresh",
            using: nil
        ) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
        
        // 처리 태스크 등록
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.sion555.DynamicCat.processing",
            using: nil
        ) { task in
            self.handleBackgroundProcessing(task: task as! BGProcessingTask)
        }
    }
    
    // 앱이 백그라운드로 전환될 때 호출
    func applicationDidEnterBackground(_ application: UIApplication) {
        scheduleAppRefresh()
    }
    
    // 앱 리프레시 태스크 스케줄링
    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.sion555.DynamicCat.refresh")
        // 최소 15분 후 실행 (시스템이 최적 시간 결정)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Background app refresh scheduled")
        } catch {
            print("Could not schedule app refresh: \(error)")
        }
    }
    
    // 백그라운드 처리 태스크 스케줄링
    func scheduleBackgroundProcessing() {
        let request = BGProcessingTaskRequest(identifier: "com.sion555.DynamicCat.processing")
        request.requiresNetworkConnectivity = true  // 네트워크 필요
        request.requiresExternalPower = false       // 외부 전원 불필요
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Background processing scheduled")
        } catch {
            print("Could not schedule background processing: \(error)")
        }
    }
    
    // 앱 리프레시 태스크 처리
    func handleAppRefresh(task: BGAppRefreshTask) {
        // 실행 중인 Live Activity가 있는지 확인하고 업데이트
        let notificationCenter = NotificationCenter.default
        
        // 태스크 종료 핸들러 설정
        task.expirationHandler = {
            // 태스크가 만료될 때 리소스 정리
            notificationCenter.removeObserver(self)
        }
        
        // 시스템 메트릭 업데이트 알림 발송
        notificationCenter.post(name: NSNotification.Name("BackgroundRefreshTriggered"), object: nil)
        
        // 다음 백그라운드 태스크 예약
        scheduleAppRefresh()
        
        // 태스크 완료 표시
        task.setTaskCompleted(success: true)
    }
    
    // 백그라운드 처리 태스크 처리
    func handleBackgroundProcessing(task: BGProcessingTask) {
        // 태스크 만료 핸들러
        task.expirationHandler = {
            // 태스크 만료 시 정리
        }
        
        // 백그라운드에서 더 긴 작업 수행
        // 예: 데이터 분석, 네트워크 동기화 등
        
        // 다음 처리 태스크 예약
        scheduleBackgroundProcessing()
        
        // 태스크 완료 표시
        task.setTaskCompleted(success: true)
    }
}
