import SwiftUI

import SwiftUI

/// 简化版校音器视图 - 只负责麦克风监听和音高显示
struct SimplifiedTunerView: View {
    @StateObject private var tuner = TunerEngine()
    
    // 读取用户设置
    @AppStorage(UserDefaultsKeys.autoStopListening) private var autoStopListening = true
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景色：保持与其他页面一致的高级灰
                Color(UIColor.systemGray6)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    // 仪表盘 - 更大更突出
                    TunerGaugeDisplay(
                        tuner: tuner,
                        isListening: true,
                        selectedNoteIndex: 0,
                        selectedOctave: 4
                    )
                    .padding(.horizontal, 20)
                    
                    // 节拍指示器（在仪表盘和卡片之间）
                    VStack {
                        MetronomeBeatIndicator()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    
                    Spacer()
                    
                    // 底部信息卡片
                    VStack(spacing: 20) {
                        // 当前频率显示
                        if tuner.data.pitch > 0 {
                            VStack(spacing: 8) {
                                HStack {
                                    Label("检测频率", systemImage: "waveform")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                                
                                HStack {
                                    Spacer()
                                    Text(String(format: "%.1f", tuner.data.pitch))
                                        .font(.system(size: 44, weight: .bold, design: .monospaced))
                                        .foregroundColor(.blue)
                                        .contentTransition(.numericText(value: tuner.data.pitch))
                                    Text("Hz")
                                        .font(.title2)
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 4)
                                    Spacer()
                                }
                            }
                            .padding(.vertical, 12)
                            
                            // 简化的音准状态指示 - 只保留圆点
                            HStack {
                                Spacer()
                                Circle()
                                    .fill(tuningStatusColor)
                                    .frame(width: 16, height: 16)
                                    .shadow(color: tuningStatusColor.opacity(0.3), radius: 4, x: 0, y: 2)
                                Spacer()
                            }
                        } else {
                            // 等待输入提示（简化版）
                            VStack(spacing: 12) {
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.blue)
                                
                                Text("请对着麦克风演奏或唱歌")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                        }
                    }
                    .padding(24)
                    .background(
                        colorScheme == .dark ? Color(UIColor.systemGray5) : Color.white
                    )
                    .cornerRadius(28)
                    .shadow(
                        color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05),
                        radius: 12, x: 0, y: 4
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(Color.white.opacity(colorScheme == .dark ? 0.1 : 0), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
                
                // 错误提示（如果有）
                if let error = tuner.errorMessage {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.white)
                            Text(error)
                                .foregroundColor(.white)
                                .font(.footnote)
                        }
                        .padding()
                        .background(Color.red.opacity(0.9))
                        .cornerRadius(12)
                        .shadow(radius: 8)
                        .padding(.horizontal)
                        .padding(.bottom, 50)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .navigationTitle("校音器")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                tuner.startListening()
            }
            .onDisappear {
                if autoStopListening {
                    tuner.stopListening()
                }
            }
        }
    }
    
    // MARK: - 计算属性
    
    var tuningStatusColor: Color {
        let absDev = abs(tuner.data.deviation)
        if absDev < UIConstants.accurateThreshold { return .green }
        if absDev < UIConstants.closeThreshold { return .yellow }
        return .red
    }
}

#Preview {
    SimplifiedTunerView()
}
