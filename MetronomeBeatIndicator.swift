import SwiftUI

/// 节拍指示器组件
/// 显示节拍器的当前节拍状态
struct MetronomeBeatIndicator: View {
    @ObservedObject var stateManager = MetronomeStateManager.shared
    
    var body: some View {
        if stateManager.isPlaying {
            HStack(spacing: 10) {
                ForEach(0..<stateManager.timeSignature, id: \.self) { index in
                    Circle()
                        .fill(getBeatColor(index: index))
                        .frame(width: 12, height: 12)
                        .scaleEffect(shouldHighlight(index) ? 1.5 : 1.0)
                        .animation(.easeOut(duration: 0.1), value: stateManager.isVisualPulse)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.primary.opacity(0.05))
            .cornerRadius(20)
            .transition(.scale.combined(with: .opacity))
        }
    }
    
    func shouldHighlight(_ index: Int) -> Bool {
        return stateManager.currentBeat == index && stateManager.isVisualPulse
    }
    
    func getBeatColor(index: Int) -> Color {
        if shouldHighlight(index) {
            if stateManager.timeSignature == 1 {
                return .blue
            }
            return index == 0 ? .red : .blue
        }
        return Color.secondary.opacity(0.3)
    }
}

#Preview {
    VStack {
        // 模拟播放状态
        MetronomeBeatIndicator()
            .onAppear {
                let manager = MetronomeStateManager.shared
                manager.start(timeSignature: 4)
                
                // 模拟节拍
                var beat = 0
                Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                    manager.updateBeat(index: beat % 4, timeSignature: 4)
                    beat += 1
                }
            }
    }
    .padding()
}
