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

// mach 관련 헤더를 직접 참조
#if targetEnvironment(simulator)
// 시뮬레이터 타겟
import Darwin.C
#else
// 실제 디바이스 타겟
import Darwin.C
#endif

class SystemMonitor: ObservableObject {
    @Published var cpuUsage: Double = 0.0
    @Published var fps: Double = 0.0
    @Published var memoryUsage: Double = 0.0
    @Published var networkActivity: Double = 0.0
    
    private var timer: Timer?
    private var displayLink: CADisplayLink?
    private var lastTime: CFTimeInterval = 0
    private var frameCount: Int = 0
    
    // FPS 계산을 위한 설정
    func setupFPSMonitoring() {
        displayLink = CADisplayLink(target: self, selector: #selector(updateFPS))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    @objc private func updateFPS(link: CADisplayLink) {
        if lastTime == 0 {
            lastTime = link.timestamp
            return
        }
        
        frameCount += 1
        let deltaTime = link.timestamp - lastTime
        
        if deltaTime >= 1.0 {
            fps = Double(frameCount) / deltaTime
            frameCount = 0
            lastTime = link.timestamp
        }
    }
    
    // CPU 사용량 모니터링
    // SystemMonitor.swift 중 updateCPUUsage 메서드 수정
    private func updateCPUUsage() {
        var totalUsageOfCPU: Double = 0.0
        
        var cpuLoadInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &cpuLoadInfo) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { pointer in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, pointer, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let userTicks = Double(cpuLoadInfo.cpu_ticks.0)
            let systemTicks = Double(cpuLoadInfo.cpu_ticks.1)
            let idleTicks = Double(cpuLoadInfo.cpu_ticks.2)
            let niceTicks = Double(cpuLoadInfo.cpu_ticks.3)
            
            let totalTicks = userTicks + systemTicks + idleTicks + niceTicks
            totalUsageOfCPU = ((userTicks + systemTicks + niceTicks) / totalTicks) * 100.0
        } else {
            totalUsageOfCPU = -1
        }
        
        self.cpuUsage = totalUsageOfCPU
    }
    
    // 메모리 사용량 모니터링
    private func updateMemoryUsage() {
        var taskInfo = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size) / 4
        let result: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let usedMemory = Double(taskInfo.phys_footprint) / (1024.0 * 1024.0) // MB 단위
            self.memoryUsage = usedMemory
        } else {
            self.memoryUsage = -1
        }
    }
    
    // 네트워크 활동 모니터링 (예시, 실제 구현은 더 복잡할 수 있음)
    private func updateNetworkActivity() {
        // 실제 네트워크 활동 모니터링은 더 복잡하므로 임의의 값을 설정
        self.networkActivity = Double.random(in: 0...100)
    }
    
    // 모든 모니터링 시작
    func startMonitoring(interval: TimeInterval) {
        stopMonitoring()
        
        setupFPSMonitoring()
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.updateCPUUsage()
            self.updateMemoryUsage()
            self.updateNetworkActivity()
        }
    }
    
    // 모니터링 중지
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        
        displayLink?.invalidate()
        displayLink = nil
    }
    
    // 업데이트 주기 변경
    func updateInterval(to interval: TimeInterval) {
        if timer != nil {
            stopMonitoring()
            startMonitoring(interval: interval)
        }
    }
}
