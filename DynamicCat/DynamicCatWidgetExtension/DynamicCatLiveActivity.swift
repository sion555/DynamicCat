////
////  DynamicCatLiveActivity.swift
////  DynamicCat
////
////  Created by Sion on 3/22/25.
////
//
//import ActivityKit
//import WidgetKit
//import SwiftUI
//
//struct DynamicCatLiveActivityAttributes: ActivityAttributes {
//    public struct ContentState: Codable, Hashable {
//        var cpuUsage: Double
//        var fps: Double
//        var memoryUsage: Double
//        var networkActivity: Double
//        var timestamp: Date
//    }
//    
//    
//    var name: String
//}
//
//struct DynamicCatLiveActivity: Widget {
//    var body: some WidgetConfiguration {
//        ActivityConfiguration(for: DynamicCatLiveActivityAttributes.self) { context in
//            // 라이브 액티비티 뷰
//            ZStack {
//                RoundedRectangle(cornerRadius: 15)
//                    .fill(Color.black)
//                
//                HStack {
//                    catAnimationView(speed: calculateAnimationSpeed(cpu: context.state.cpuUsage))
//                    
//                    VStack(alignment: .leading) {
//                        Text("CPU: \(Int(context.state.cpuUsage))%")
//                            .foregroundColor(colorForValue(context.state.cpuUsage))
//                        
//                        Text("FPS: \(Int(context.state.fps))")
//                            .foregroundColor(colorForValue(context.state.fps / 60 * 100))
//                    }
//                    .font(.system(size: 12, weight: .semibold))
//                }
//                .padding(.horizontal)
//            }
//        } dynamicIsland: { context in
//            DynamicIsland {
//                // Dynamic Island 확장 상태
//                DynamicIslandExpandedRegion(.leading) {
//                    catAnimationView(speed: calculateAnimationSpeed(cpu: context.state.cpuUsage))
//                        .frame(width: 40, height: 40)
//                }
//                
//                DynamicIslandExpandedRegion(.trailing) {
//                    VStack(alignment: .trailing) {
//                        Text("CPU: \(Int(context.state.cpuUsage))%")
//                            .foregroundColor(colorForValue(context.state.cpuUsage))
//                            .font(.system(size: 14, weight: .bold))
//                        
//                        Text("FPS: \(Int(context.state.fps))")
//                            .foregroundColor(colorForValue(context.state.fps / 60 * 100))
//                            .font(.system(size: 14, weight: .bold))
//                    }
//                }
//                
//                DynamicIslandExpandedRegion(.center) {
//                    Text("DynamicCat")
//                        .font(.system(size: 12, weight: .semibold))
//                        .foregroundColor(.white)
//                }
//                
//                DynamicIslandExpandedRegion(.bottom) {
//                    HStack {
//                        Label("Memory: \(Int(context.state.memoryUsage)) MB", systemImage: "memorychip")
//                        Spacer()
//                        Label("Net: \(Int(context.state.networkActivity)) KB/s", systemImage: "network")
//                    }
//                    .font(.system(size: 12))
//                    .foregroundColor(.white)
//                    .padding(.top, 8)
//                }
//            } compactLeading: {
//                // 컴팩트 리딩 뷰
//                catAnimationView(speed: calculateAnimationSpeed(cpu: context.state.cpuUsage))
//                    .frame(width: 20, height: 20)
//            } compactTrailing: {
//                // 컴팩트 트레일링 뷰
//                Text("\(Int(context.state.cpuUsage))%")
//                    .font(.system(size: 12, weight: .bold))
//                    .foregroundColor(colorForValue(context.state.cpuUsage))
//            } minimal: {
//                // 미니멀 뷰
//                catAnimationView(speed: calculateAnimationSpeed(cpu: context.state.cpuUsage))
//                    .frame(width: 20, height: 20)
//            }
//        }
//    }
//    
//    // 애니메이션 속도 계산 (CPU 사용량에 따라)
//    private func calculateAnimationSpeed(cpu: Double) -> Double {
//        // 최소 0.5, 최대 2.0 사이의 속도
//        return max(0.5, min(2.0, cpu / 100 * 1.5 + 0.5))
//    }
//    
//    // 값에 따른 색상 변경
//    private func colorForValue(_ value: Double) -> Color {
//        switch value {
//        case 0..<30:
//            return .green
//        case 30..<70:
//            return .yellow
//        default:
//            return .red
//        }
//    }
//    
//    // 고양이 애니메이션 뷰
//    private func catAnimationView(speed: Double) -> some View {
//        // 여기서는 간단한 예시로 표현합니다. 실제로는 애니메이션된 고양이 이미지나 아이콘을 사용할 수 있습니다.
//        Image(systemName: "cat.fill")
//            .font(.system(size: 24))
//            .foregroundColor(.white)
//            .modifier(ShakeEffect(animatableData: speed))
//    }
//}
//
//// 고양이 애니메이션을 위한 효과
//struct ShakeEffect: GeometryEffect {
//    var animatableData: Double
//    
//    func effectValue(size: CGSize) -> ProjectionTransform {
//        let angle = sin(animatableData * Date().timeIntervalSince1970 * 10) * 0.05
//        let translation = CGSize(width: sin(animatableData * Date().timeIntervalSince1970 * 10) * 5, height: 0)
//        let rotation = CGAffineTransform(rotationAngle: angle)
//        let translationTransform = CGAffineTransform(translationX: translation.width, y: translation.height)
//        return ProjectionTransform(rotation.concatenating(translationTransform))
//    }
//}
