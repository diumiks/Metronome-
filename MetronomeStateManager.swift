import SwiftUI
import Combine
import QuartzCore

/// 全局节拍器状态管理器
class MetronomeStateManager: ObservableObject {
    static let shared = MetronomeStateManager()

    @Published var isPlaying = false
    @Published var currentBeat = -1
    @Published var timeSignature = 4

    // 仅用于 UI 动画
    @Published var isVisualPulse = false

    /// 最近一次节拍发生的高精度时间戳（秒）
    /// 用于 Tuner 仅屏蔽极短点击窗口（不要用 isVisualPulse 的长时间）
    @Published var lastBeatTime: CFTimeInterval = 0

    private init() {}

    func updateBeat(index: Int, timeSignature: Int) {
        self.currentBeat = index
        self.timeSignature = timeSignature

        self.isVisualPulse = true
        self.lastBeatTime = CACurrentMediaTime()

        // UI 脉冲要短：别影响 tuner
        DispatchQueue.main.asyncAfter(deadline: .now() + AudioConstants.visualPulseDuration) { [weak self] in
            self?.isVisualPulse = false
        }
    }

    func start(timeSignature: Int) {
        self.isPlaying = true
        self.timeSignature = timeSignature
        self.currentBeat = -1
    }

    func stop() {
        self.isPlaying = false
        self.currentBeat = -1
        self.isVisualPulse = false
    }
}
