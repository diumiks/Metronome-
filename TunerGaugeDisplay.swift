import SwiftUI

struct TunerGaugeDisplay: View {
    @ObservedObject var tuner: TunerEngine
    var isListening: Bool
    var selectedNoteIndex: Int
    var selectedOctave: Int
    
    var body: some View {
        ZStack {
            MinimalGaugeView()
            
            // 指针
            Rectangle()
                .fill(indicatorColor)
                .frame(width: 4, height: 95)
                .cornerRadius(2)
                .offset(y: -55)
                .rotationEffect(.degrees(needleRotation))
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: tuner.data.deviation)
                // 播放时不显示指针
                .opacity(tuner.isPlaying ? 0 : 1)
            
            // 信息显示区域
            ZStack {
                // 状态 A: 播放声音模式 (只显示一个大喇叭)
                VStack {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 60)) // 放大图标
                        .foregroundColor(.blue)
                        .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .opacity(tuner.isPlaying ? 1 : 0)
                .animation(.easeInOut(duration: 0.2), value: tuner.isPlaying)
                
                // 状态 B: 听音校准模式
                VStack(spacing: 8) {
                    // 占位符，保持高度一致
                    Color.clear.frame(height: 0)
                    
                    Text(tuner.data.noteName)
                        .font(.system(size: 85, weight: .bold, design: .rounded))
                        .foregroundColor(noteNameColor) // 使用带颜色的音名
                        .frame(height: 100)
                    
                    if tuner.data.noteName != "--" {
                        Text(String(format: "%+.0f", tuner.data.deviation))
                            .font(.title3.bold())
                            .foregroundColor(indicatorColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(indicatorColor.opacity(0.1))
                            .cornerRadius(8)
                    } else {
                        Text("监听中...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 4)
                    }
                }
                .opacity(tuner.isPlaying ? 0 : 1)
                .animation(.easeInOut(duration: 0.2), value: tuner.isPlaying)
            }
            .offset(y: 60)
        }
        .frame(height: 280)
        .padding(.top, 20)
    }
    
    var needleRotation: Double {
        if tuner.isPlaying { return 0 }
        let angle = tuner.data.deviation
        let maxRotation = UIConstants.needleMaxRotation
        if angle > maxRotation { return maxRotation }
        if angle < -maxRotation { return -maxRotation }
        return angle
    }
    
    var indicatorColor: Color {
        if tuner.isPlaying { return .clear }
        if tuner.data.noteName == "--" { return .gray }
        let absDev = abs(tuner.data.deviation)
        if absDev < UIConstants.accurateThreshold { return .green }
        if absDev < UIConstants.closeThreshold { return .yellow }
        return .red
    }
    
    // 音名颜色（与指针颜色一致）
    var noteNameColor: Color {
        if tuner.data.noteName == "--" { return .primary }
        return indicatorColor
    }
}
