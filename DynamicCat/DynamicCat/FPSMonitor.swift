//
//  FPSMonitor.swift
//  DynamicCat
//
//  Created by Sion on 3/22/25.
//

import Foundation
import QuartzCore
import UIKit
import os.log

/// FPS 모니터링을 위한 클래스
class FPSMonitor {
    // 싱글톤 인스턴스
    static let shared = FPSMonitor()
    
    // FPS 관련 속성
    private(set) var fps: Double = 0
    private(set) var fpsHistory: [Double] = []
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var frameCount: Int = 0
    
    // FPS 히스토리 제한 (최근 10초)
    private let maxHistoryCount = 20
    
    // 업데이트 콜백
    var onUpdate: ((Double) -> Void)?
    
    private init() {}
    
    /// FPS 모니터링 시작
    func startMonitoring() {
        stopMonitoring()
        
        // 새 displayLink 생성
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkTick))
        
        // iOS 15 이상에서는 preferredFrameRateRange를 사용
        if #available(iOS 15.0, *) {
            // 최대 120fps까지 측정 가능하도록 설정
            displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 1, maximum: 120, preferred: 60)
        }
        
        // RunLoop에 추가
        displayLink?.add(to: .main, forMode: .common)
        
        lastTimestamp = 0
        frameCount = 0
        fpsHistory.removeAll()
        
        os_log("FPS monitoring started",
               log: OSLog(subsystem: "com.sion555.DynamicCat", category: "FPS"),
               type: .info)
    }
    
    /// FPS 모니터링 중지
    func stopMonitoring() {
        displayLink?.invalidate()
        displayLink = nil
        
        os_log("FPS monitoring stopped",
               log: OSLog(subsystem: "com.sion555.DynamicCat", category: "FPS"),
               type: .info)
    }
    
    /// DisplayLink 틱 처리
    @objc private func displayLinkTick(link: CADisplayLink) {
        // 첫 프레임이면 초기화
        if lastTimestamp == 0 {
            lastTimestamp = link.timestamp
            frameCount = 0
            return
        }
        
        // 프레임 카운트 증가
        frameCount += 1
        
        // 경과 시간 계산
        let deltaTime = link.timestamp - lastTimestamp
        
        // 0.5초마다 FPS 계산 (보다 정확한 측정을 위해)
        if deltaTime >= 0.5 {
            // 초당 프레임 수 계산
            let currentFPS = Double(frameCount) / deltaTime
            
            // FPS 값 업데이트
            updateFPS(currentFPS)
            
            // 카운터 리셋
            frameCount = 0
            lastTimestamp = link.timestamp
        }
    }
    
    /// FPS 값 업데이트 및 히스토리 관리
    private func updateFPS(_ newFPS: Double) {
        // FPS 값 설정
        fps = min(newFPS, 120.0) // 120fps로 제한
        
        // 히스토리에 추가
        fpsHistory.append(fps)
        
        // 히스토리 크기 제한
        if fpsHistory.count > maxHistoryCount {
            fpsHistory.removeFirst()
        }
        
        // 콜백 호출
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.onUpdate?(self.fps)
        }
        
        // FPS 로그
        os_log("Current FPS: %.1f",
               log: OSLog(subsystem: "com.sion555.DynamicCat", category: "FPS"),
               type: .debug,
               fps)
    }
    
    /// 평균 FPS 계산
    var averageFPS: Double {
        guard !fpsHistory.isEmpty else { return 0 }
        return fpsHistory.reduce(0, +) / Double(fpsHistory.count)
    }
    
    /// 최소 FPS 계산
    var minFPS: Double {
        return fpsHistory.min() ?? 0
    }
    
    /// 최대 FPS 계산
    var maxFPS: Double {
        return fpsHistory.max() ?? 0
    }
    
    /// FPS 표준 편차 계산
    var fpsStandardDeviation: Double {
        guard fpsHistory.count > 1 else { return 0 }
        
        let mean = averageFPS
        let variance = fpsHistory.reduce(0.0) { $0 + pow($1 - mean, 2) } / Double(fpsHistory.count - 1)
        return sqrt(variance)
    }
    
    /// FPS 안정성 점수 (0-100)
    var fpsStabilityScore: Int {
        guard !fpsHistory.isEmpty else { return 0 }
        
        // 표준 편차가 낮을수록 안정적
        let deviation = fpsStandardDeviation
        let maxAcceptableDeviation: Double = 10.0
        
        // 안정성 점수 계산 (표준편차가 낮을수록 높은 점수)
        let stabilityPercentage = max(0, min(100, 100 - (deviation / maxAcceptableDeviation * 100)))
        
        return Int(stabilityPercentage)
    }
    
    deinit {
        stopMonitoring()
    }
}

// MARK: - FPS 관련 UIView 확장
extension UIView {
    /// 현재 화면의 렌더링 성능 추정
    class func estimateRenderingPerformance() -> (complexity: Int, overdraw: Double) {
        // 현재 화면의 루트 뷰 가져오기
        guard let keyWindow = UIApplication.shared.connectedScenes
            .filter({ $0.activationState == .foregroundActive })
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows
            .first(where: { $0.isKeyWindow }) else {
            return (0, 0)
        }
        
        // 복잡도 측정 (뷰 계층 깊이)
        let complexity = measureViewHierarchyComplexity(view: keyWindow)
        
        // 오버드로우 추정 (겹쳐진 뷰)
        let overdraw = estimateOverdraw(view: keyWindow)
        
        return (complexity, overdraw)
    }
    
    /// 뷰 계층 복잡도 측정
    private class func measureViewHierarchyComplexity(view: UIView) -> Int {
        var complexity = 1 // 현재 뷰
        
        // 하위 뷰에 대해 재귀적으로 계산
        for subview in view.subviews {
            complexity += measureViewHierarchyComplexity(view: subview)
        }
        
        return complexity
    }
    
    /// 오버드로우 추정 (겹쳐진 뷰의 비율)
    private class func estimateOverdraw(view: UIView) -> Double {
        let screenBounds = UIScreen.main.bounds
        let screenArea = screenBounds.width * screenBounds.height
        
        var totalViewArea: CGFloat = 0
        
        // 모든 뷰의 총 면적 계산
        calculateTotalArea(view: view, screenBounds: screenBounds, totalArea: &totalViewArea)
        
        // 오버드로우 비율 계산
        return Double(totalViewArea / screenArea)
    }
    
    /// 총 뷰 면적 계산
    private class func calculateTotalArea(view: UIView, screenBounds: CGRect, totalArea: inout CGFloat) {
        // 뷰가 화면에 있고 보이는 경우만 계산
        guard view.isHidden == false, view.alpha > 0 else { return }
        
        // 뷰의 프레임을 화면 좌표계로 변환
        let frameInWindow = view.convert(view.bounds, to: nil)
        
        // 화면과 겹치는 영역 계산
        let visibleFrame = frameInWindow.intersection(screenBounds)
        
        if !visibleFrame.isEmpty {
            // 넓이 추가 - 수정: visibleHeight -> visibleFrame.height
            let area = visibleFrame.width * visibleFrame.height
            totalArea += area
        }
        
        // 하위 뷰 재귀적 처리
        for subview in view.subviews {
            calculateTotalArea(view: subview, screenBounds: screenBounds, totalArea: &totalArea)
        }
    }
}
