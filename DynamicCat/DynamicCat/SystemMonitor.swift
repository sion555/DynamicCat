//
//  SystemMonitor.swift
//  DynamicCat
//
//  Created by Sion on 3/22/25.
//

import Foundation
import Combine
import UIKit
import Darwin
import MetricKit
import Network

// mach 관련 헤더를 직접 참조
#if targetEnvironment(simulator)
// 시뮬레이터 타겟
import Darwin.C
#else
// 실제 디바이스 타겟
import Darwin.C
#endif

class SystemMonitor: ObservableObject {
    // 발행 속성 - UI 업데이트를 위한 값
    @Published var cpuUsage: Double = 0.0
    @Published var fps: Double = 0.0
    @Published var memoryUsage: Double = 0.0
    @Published var networkActivity: Double = 0.0
    
    // 시스템 모니터링을 위한 내부 변수
    private var timer: Timer?
    private var displayLink: CADisplayLink?
    private var lastTime: CFTimeInterval = 0
    private var frameCount: Int = 0
    
    // CPU 사용량 계산을 위한 이전 값을 추적
    private var previousCPUInfo: host_cpu_load_info?
    private var previousCPUInfoTime: Date?
    
    // 네트워크 모니터링을 위한 변수
    private let pathMonitor = NWPathMonitor()
    private var bytesIn: UInt64 = 0
    private var bytesOut: UInt64 = 0
    private var lastBytesIn: UInt64 = 0
    private var lastBytesOut: UInt64 = 0
    private var lastNetworkCheckTime: Date = Date()
    
    // 백그라운드 업데이트를 위한 작업 식별자
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    // FPS 계산을 위한 설정
    func setupFPSMonitoring() {
        // 기존 displayLink가 있다면 정리
        displayLink?.invalidate()
        
        // 새 displayLink 생성 및 설정
        displayLink = CADisplayLink(target: self, selector: #selector(updateFPS))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 1, maximum: 120, preferred: 120)
        displayLink?.add(to: .main, forMode: .common)
    }
    
    @objc private func updateFPS(link: CADisplayLink) {
        if lastTime == 0 {
            lastTime = link.timestamp
            frameCount = 0
            return
        }
        
        frameCount += 1
        let deltaTime = link.timestamp - lastTime
        
        // 0.5초마다 FPS 업데이트
        if deltaTime >= 0.5 {
            fps = Double(frameCount) / deltaTime
            frameCount = 0
            lastTime = link.timestamp
        }
    }
    
    // CPU 사용량 모니터링 - 보다 정확한 델타 값 계산 적용
    private func updateCPUUsage() {
        var cpuInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &cpuInfo) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { pointer in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, pointer, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let currentTime = Date()
            
            if let previousInfo = previousCPUInfo, let previousTime = previousCPUInfoTime {
                // 델타 시간 계산
                let timeDelta = currentTime.timeIntervalSince(previousTime)
                
                // 각 CPU 상태에 대한 틱 계산
                let userDelta = Double(cpuInfo.cpu_ticks.0 - previousInfo.cpu_ticks.0)
                let systemDelta = Double(cpuInfo.cpu_ticks.1 - previousInfo.cpu_ticks.1)
                let idleDelta = Double(cpuInfo.cpu_ticks.2 - previousInfo.cpu_ticks.2)
                let niceDelta = Double(cpuInfo.cpu_ticks.3 - previousInfo.cpu_ticks.3)
                
                let totalTicks = userDelta + systemDelta + idleDelta + niceDelta
                
                if totalTicks > 0 {
                    // 비율 계산
                    let cpuUsageValue = ((userDelta + systemDelta + niceDelta) / totalTicks) * 100.0
                    
                    // UI 업데이트는 메인 스레드에서
                    DispatchQueue.main.async {
                        self.cpuUsage = max(0, min(100, cpuUsageValue))
                    }
                }
            }
            
            // 현재 값을 이전 값으로 저장
            previousCPUInfo = cpuInfo
            previousCPUInfoTime = currentTime
        }
    }
    
    // 메모리 사용량 모니터링 - 정확한 물리 메모리 사용량 계산
    private func updateMemoryUsage() {
        var taskInfo = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size) / 4
        
        let result: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            // 앱의 물리적 메모리 사용량(MB)
            let appMemoryUsage = Double(taskInfo.phys_footprint) / (1024.0 * 1024.0)
            
            // 시스템 전체 메모리 정보
            var pageSize: vm_size_t = 0
            
            let hostPortResult = host_page_size(mach_host_self(), &pageSize)
            if hostPortResult == KERN_SUCCESS {
                var statistics = vm_statistics64()
                var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
                
                let statisticsResult = withUnsafeMutablePointer(to: &statistics) {
                    $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                        host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &size)
                    }
                }
                
                if statisticsResult == KERN_SUCCESS {
                    // 시스템 메모리 활용량 계산
                    let freeMemory = Double(statistics.free_count) * Double(pageSize) / (1024.0 * 1024.0)
                    let activeMemory = Double(statistics.active_count) * Double(pageSize) / (1024.0 * 1024.0)
                    let inactiveMemory = Double(statistics.inactive_count) * Double(pageSize) / (1024.0 * 1024.0)
                    let wiredMemory = Double(statistics.wire_count) * Double(pageSize) / (1024.0 * 1024.0)
                    
                    // 총 메모리 계산
                    let totalMemory = freeMemory + activeMemory + inactiveMemory + wiredMemory
                    
                    // 현재 사용 중인 메모리 비율 계산
                    let usedMemoryPercentage = ((totalMemory - freeMemory) / totalMemory) * 100.0
                    
                    DispatchQueue.main.async {
                        self.memoryUsage = appMemoryUsage // 앱이 사용하는 메모리양(MB)으로 표시
                    }
                }
            }
        }
    }
    
    // 네트워크 활동 모니터링 - 실제 네트워크 트래픽 측정
    private func setupNetworkMonitoring() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            // 네트워크 연결 타입 확인
            if path.status == .satisfied {
                // 네트워크가 연결됨, 필요한 처리를 수행할 수 있음
            }
        }
        
        // 모니터링 시작
        let queue = DispatchQueue(label: "NetworkMonitor")
        pathMonitor.start(queue: queue)
    }
    
    private func updateNetworkActivity() {
        // 현재 네트워크 활동 가져오기
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return }
        defer { freeifaddrs(ifaddr) }
        
        var currentBytesIn: UInt64 = 0
        var currentBytesOut: UInt64 = 0
        
        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }
            
            guard let interface = ptr?.pointee else { continue }
            
            // 인터페이스 이름 확인
            let name = String(cString: interface.ifa_name)
            
            // loopback 인터페이스 제외
            if name == "lo0" || name == "lo1" { continue }
            
            // IPv4 또는 IPv6 인터페이스만 처리
            guard interface.ifa_addr.pointee.sa_family == UInt8(AF_INET) ||
                  interface.ifa_addr.pointee.sa_family == UInt8(AF_INET6) else { continue }
            
            // 인터페이스 데이터 가져오기
            var data = if_data()
            
            // 데이터 구조에 접근
            if name.hasPrefix("en") || name.hasPrefix("pdp_ip") || name.hasPrefix("wlan") || name.hasPrefix("wifi") {
                memcpy(&data, interface.ifa_data, MemoryLayout<if_data>.size)
                currentBytesIn += UInt64(data.ifi_ibytes)
                currentBytesOut += UInt64(data.ifi_obytes)
            }
        }
        
        // 시간 간격 계산
        let now = Date()
        let interval = now.timeIntervalSince(lastNetworkCheckTime)
        
        // 초당 데이터 전송량 계산 (KB/s)
        if lastBytesIn > 0 && lastBytesOut > 0 && interval > 0 {
            let bytesInDelta = currentBytesIn > lastBytesIn ? currentBytesIn - lastBytesIn : 0
            let bytesOutDelta = currentBytesOut > lastBytesOut ? currentBytesOut - lastBytesOut : 0
            
            let totalBytesPerSecond = Double(bytesInDelta + bytesOutDelta) / interval / 1024.0
            
            DispatchQueue.main.async {
                self.networkActivity = totalBytesPerSecond // KB/s
            }
        }
        
        // 값 업데이트
        lastBytesIn = currentBytesIn
        lastBytesOut = currentBytesOut
        lastNetworkCheckTime = now
    }
    
    // 백그라운드 업데이트를 위한 메서드
    private func beginBackgroundTask() {
        // 이미 실행 중인 백그라운드 작업이 있다면 종료
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
        
        // 새 백그라운드 작업 시작
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            guard let self = self else { return }
            UIApplication.shared.endBackgroundTask(self.backgroundTask)
            self.backgroundTask = .invalid
        }
    }
    
    // 백그라운드 작업 종료
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    // 모든 모니터링 시작
    func startMonitoring(interval: TimeInterval) {
        stopMonitoring()
        
        // 앱 상태 알림 등록
        NotificationCenter.default.addObserver(self,
                                             selector: #selector(handleAppStateChange),
                                             name: UIApplication.willResignActiveNotification,
                                             object: nil)
        
        NotificationCenter.default.addObserver(self,
                                             selector: #selector(handleAppStateChange),
                                             name: UIApplication.didBecomeActiveNotification,
                                             object: nil)
        
        // FPS 모니터링 설정
        setupFPSMonitoring()
        
        // 네트워크 모니터링 설정
        setupNetworkMonitoring()
        
        // 초기 CPU 정보 읽기
        updateCPUUsage()
        
        // 타이머 시작 - CPU, 메모리, 네트워크 업데이트
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // 각 측정 함수를 별도 스레드에서 실행
            DispatchQueue.global(qos: .userInitiated).async {
                self.updateCPUUsage()
                self.updateMemoryUsage()
                self.updateNetworkActivity()
                
                // 백그라운드에서 업데이트를 위한 NotificationCenter 사용
                NotificationCenter.default.post(name: NSNotification.Name("SystemMetricsUpdated"), object: nil, userInfo: [
                    "cpuUsage": self.cpuUsage,
                    "fps": self.fps,
                    "memoryUsage": self.memoryUsage,
                    "networkActivity": self.networkActivity
                ])
            }
        }
        
        // 런루프에 타이머 추가 (백그라운드에서도 작동하도록)
        RunLoop.current.add(timer!, forMode: .common)
    }
    
    // 앱 상태 변경 처리
    @objc private func handleAppStateChange(notification: Notification) {
        if notification.name == UIApplication.willResignActiveNotification {
            // 앱이 백그라운드로 전환될 때
            beginBackgroundTask()
        } else if notification.name == UIApplication.didBecomeActiveNotification {
            // 앱이 다시 활성화될 때
            endBackgroundTask()
        }
    }
    
    // 모니터링 중지
    func stopMonitoring() {
        // 알림 제거
        NotificationCenter.default.removeObserver(self)
        
        timer?.invalidate()
        timer = nil
        
        displayLink?.invalidate()
        displayLink = nil
        
        pathMonitor.cancel()
        
        endBackgroundTask()
    }
    
    // 업데이트 주기 변경
    func updateInterval(to interval: TimeInterval) {
        if timer != nil {
            stopMonitoring()
            startMonitoring(interval: interval)
        }
    }
    
    deinit {
        stopMonitoring()
    }
}
