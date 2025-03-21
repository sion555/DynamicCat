//
//  SettingsView.swift
//  DynamicCat
//
//  Created by Sion on 3/22/25.
//

import SwiftUI

struct SettingsView: View {
    @Binding var settings: AppSettings
    var onUpdateInterval: (TimeInterval) -> Void
    
    @Environment(\.presentationMode) var presentationMode
    
    let updateIntervals: [TimeInterval] = [0.5, 1.0, 2.0, 5.0]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("모니터링 항목")) {
                    ForEach(MonitorType.allCases) { type in
                        HStack {
                            Text(type.description)
                            Spacer()
                            if settings.selectedMonitors.contains(type) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            toggleMonitor(type)
                        }
                    }
                }
                
                Section(header: Text("업데이트 주기")) {
                    Picker("새로고침 주기", selection: $settings.updateInterval) {
                        ForEach(updateIntervals, id: \.self) { interval in
                            Text("\(interval, specifier: "%.1f")초")
                                .tag(interval)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: settings.updateInterval) { oldValue, newValue in
                        onUpdateInterval(newValue)
                    }
                }
                
                Section(header: Text("표시 설정")) {
                    Toggle("고양이 애니메이션 표시", isOn: $settings.showCatAnimation)
                    
                    ColorPicker("낮은 값 색상", selection: $settings.lowValueColor)
                    ColorPicker("중간 값 색상", selection: $settings.mediumValueColor)
                    ColorPicker("높은 값 색상", selection: $settings.highValueColor)
                    
                    HStack {
                        Text("임계값 범위")
                        Spacer()
                        Text("\(Int(settings.lowThreshold))% - \(Int(settings.highThreshold))%")
                    }
                    
                    VStack {
                        HStack {
                            Text("낮음")
                            Slider(value: $settings.lowThreshold, in: 0...settings.highThreshold)
                                .accentColor(settings.lowValueColor)
                            Text("\(Int(settings.lowThreshold))%")
                        }
                        
                        HStack {
                            Text("높음")
                            Slider(value: $settings.highThreshold, in: settings.lowThreshold...100)
                                .accentColor(settings.highValueColor)
                            Text("\(Int(settings.highThreshold))%")
                        }
                    }
                }
                
                Section(header: Text("정보")) {
                    HStack {
                        Text("버전")
                        Spacer()
                        Text("1.0.0")
                    }
                }
            }
            .navigationTitle("설정")
            .navigationBarItems(trailing: Button("완료") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private func toggleMonitor(_ type: MonitorType) {
        if settings.selectedMonitors.contains(type) {
            // 최소한 하나의 모니터 항목은 선택되어 있어야 함
            if settings.selectedMonitors.count > 1 {
                settings.selectedMonitors.removeAll { $0 == type }
            }
        } else {
            settings.selectedMonitors.append(type)
        }
    }
}
