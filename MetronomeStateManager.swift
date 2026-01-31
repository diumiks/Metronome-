import SwiftUI
import SwiftUI
import Combine

/// 全局节拍器状态管理器
/// 用于在不同页面间同步节拍器状态
class MetronomeStateManager: ObservableObject {
    static let shared = MetronomeStateManager()
    
    // 节拍器是否正在播放
    @Published var isPlaying = false
    
    // 当前节拍索引 (0, 1, 2, 3...)
    @Published var currentBeat = -1
    
    // 拍号（每小节拍数）
    @Published var timeSignature = 4
    
    // 视觉脉冲标记（用于触发动画）
    @Published var isVisualPulse = false
    
    private init() {}
    
    /// 更新节拍状态
    func updateBeat(index: Int, timeSignature: Int) {
        self.currentBeat = index
        self.timeSignature = timeSignature
        self.isVisualPulse = true
        
        // 短暂延迟后重置脉冲
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.isVisualPulse = false
        }
    }
    
    /// 启动节拍器
    func start(timeSignature: Int) {
        self.isPlaying = true
        self.timeSignature = timeSignature
        self.currentBeat = -1
    }
    
    /// 停止节拍器
    func stop() {
        self.isPlaying = false
        self.currentBeat = -1
        self.isVisualPulse = false
    }
}
