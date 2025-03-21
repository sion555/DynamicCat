//
//  NetworkMonitor.swift
//  DynamicCat
//
//  Created by Sion on 3/22/25.
//

import Foundation
import Network
import os.log

// 네트워크 인터페이스 종류
enum NetworkInterfaceType: String {
    case wifi = "en0"
    case cellular = "pdp_ip0"
    case loopback = "lo0"
    case unknown = "unknown"
}

// 네트워크 트래픽 데이터 구조체
struct NetworkTrafficData {
    var interfaceType: NetworkInterfaceType
    var bytesIn: UInt64 = 0
    var bytesOut: UInt64 = 0
    var packetsIn: UInt64 = 0
    var packetsOut: UInt64 = 0
    var timestamp: Date = Date()
    
    // 시간 간격 동안의 초당 바이트 수 계산
    func calculateBytesPerSecond(previous: NetworkTrafficData?) -> (bytesIn: Double, bytesOut: Double) {
        guard let prev = previous else {
            return (0, 0)
        }
        
        let timeInterval = timestamp.timeIntervalSince(prev.timestamp)
        if timeInterval <= 0 {
            return (0, 0)
        }
        
        let bytesInDelta = bytesIn >= prev.bytesIn ? Double(bytesIn - prev.bytesIn) : 0
        let bytesOutDelta = bytesOut >= prev.bytesOut ? Double(bytesOut - prev.bytesOut) : 0
        
        return (
            bytesInDelta / timeInterval,
            bytesOutDelta / timeInterval
        )
    }
}

// 네트워크 모니터링 클래스
class NetworkMonitor {
    // 싱글톤 인스턴스
    static let shared = NetworkMonitor()
    
    // NWPathMonitor로 현재 네트워크 연결 모니터링
    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitorQueue")
    
    // 현재 네트워크 상태
    private(set) var isConnected = false
    private(set) var connectionType: NetworkInterfaceType = .unknown
    private(set) var availableInterfaces = [NetworkInterfaceType]()
    
    // 트래픽 데이터 추적
    private var previousTrafficData: [NetworkInterfaceType: NetworkTrafficData] = [:]
    private var currentTrafficData: [NetworkInterfaceType: NetworkTrafficData] = [:]
    
    // 네트워크 활동량 (KB/s)
    private(set) var totalBytesPerSecond: Double = 0
    private(set) var wifiBytesPerSecond: Double = 0
    private(set) var cellularBytesPerSecond: Double = 0
    
    private init() {
        setupPathMonitor()
    }
    
    // 네트워크 경로 모니터 설정
    private func setupPathMonitor() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            // 연결 상태 확인
            self.isConnected = path.status == .satisfied
            
            // 사용 가능한 인터페이스 확인
            self.availableInterfaces.removeAll()
            
            if path.usesInterfaceType(.wifi) {
                self.availableInterfaces.append(.wifi)
                self.connectionType = .wifi
            } else if path.usesInterfaceType(.cellular) {
                self.availableInterfaces.append(.cellular)
                self.connectionType = .cellular
            } else if path.usesInterfaceType(.loopback) {
                self.availableInterfaces.append(.loopback)
                self.connectionType = .loopback
            } else {
                self.connectionType = .unknown
            }
            
            // 연결 상태 로그
            os_log("Network connection status: %{public}@, type: %{public}@",
                   log: OSLog(subsystem: "com.sion555.DynamicCat", category: "Network"),
                   type: .info,
                   self.isConnected ? "Connected" : "Disconnected",
                   self.connectionType.rawValue)
        }
        
        // 모니터링 시작
        pathMonitor.start(queue: monitorQueue)
    }
    
    // 네트워크 트래픽 업데이트
    func updateNetworkTraffic() {
        // 이전 데이터 저장
        previousTrafficData = currentTrafficData
        
        // 현재 데이터 초기화
        currentTrafficData = [:]
        
        // 인터페이스 정보 가져오기
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else {
            os_log("Failed to get network interfaces",
                   log: OSLog(subsystem: "com.sion555.DynamicCat", category: "Network"),
                   type: .error)
            return
        }
        
        defer { freeifaddrs(ifaddr) }
        
        // 인터페이스별 데이터 수집
        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }
            
            guard let interface = ptr?.pointee else { continue }
            let name = String(cString: interface.ifa_name)
            
            // 사용 가능한 인터페이스만 처리
            let interfaceType: NetworkInterfaceType
            if name == NetworkInterfaceType.wifi.rawValue {
                interfaceType = .wifi
            } else if name == NetworkInterfaceType.cellular.rawValue {
                interfaceType = .cellular
            } else if name == NetworkInterfaceType.loopback.rawValue {
                interfaceType = .loopback
            } else {
                continue
            }
            
            // IPv4/IPv6만 처리
            guard interface.ifa_addr.pointee.sa_family == UInt8(AF_INET) ||
                  interface.ifa_addr.pointee.sa_family == UInt8(AF_INET6) else {
                continue
            }
            
            // 인터페이스 데이터 구조에 접근
            var data = if_data()
            memcpy(&data, interface.ifa_data, MemoryLayout<if_data>.size)
            
            // 데이터 저장
            var trafficData = NetworkTrafficData(interfaceType: interfaceType)
            trafficData.bytesIn = UInt64(data.ifi_ibytes)
            trafficData.bytesOut = UInt64(data.ifi_obytes)
            trafficData.packetsIn = UInt64(data.ifi_ipackets)
            trafficData.packetsOut = UInt64(data.ifi_opackets)
            trafficData.timestamp = Date()
            
            currentTrafficData[interfaceType] = trafficData
        }
        
        // 네트워크 속도 계산
        calculateNetworkSpeeds()
    }
    
    // 네트워크 속도 계산
    private func calculateNetworkSpeeds() {
        var totalSpeed: Double = 0
        
        // Wi-Fi 속도 계산
        if let current = currentTrafficData[.wifi], let previous = previousTrafficData[.wifi] {
            let speeds = current.calculateBytesPerSecond(previous: previous)
            wifiBytesPerSecond = (speeds.bytesIn + speeds.bytesOut) / 1024.0 // KB/s
            totalSpeed += wifiBytesPerSecond
        } else {
            wifiBytesPerSecond = 0
        }
        
        // 셀룰러 속도 계산
        if let current = currentTrafficData[.cellular], let previous = previousTrafficData[.cellular] {
            let speeds = current.calculateBytesPerSecond(previous: previous)
            cellularBytesPerSecond = (speeds.bytesIn + speeds.bytesOut) / 1024.0 // KB/s
            totalSpeed += cellularBytesPerSecond
        } else {
            cellularBytesPerSecond = 0
        }
        
        // 총 속도 저장
        totalBytesPerSecond = totalSpeed
        
        // 결과 로그
        os_log("Network speed: total=%.2f KB/s, wifi=%.2f KB/s, cellular=%.2f KB/s",
               log: OSLog(subsystem: "com.sion555.DynamicCat", category: "Network"),
               type: .debug,
               totalBytesPerSecond, wifiBytesPerSecond, cellularBytesPerSecond)
    }
    
    // 모니터링 중지
    func stopMonitoring() {
        pathMonitor.cancel()
    }
    
    deinit {
        stopMonitoring()
    }
}
