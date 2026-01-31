import AVFoundation

final class AudioSessionManager {
    static let shared = AudioSessionManager()

    private let lock = NSLock()
    private var isConfigured = false
    private var lastCategory: AVAudioSession.Category?
    private var lastMode: AVAudioSession.Mode?
    private var lastOptions: AVAudioSession.CategoryOptions?

    // Tuner 正在监听时，强制 session 维持 measurement，避免其它模块降级回 default
    private var tunerRequestCount: Int = 0

    private init() {}

    /// App 的通用会话配置
    /// 注意：每个 App 只有一个共享 AVAudioSession，所以必须统一管理
    func configureForPlayAndRecord(mode: AVAudioSession.Mode = .default) {
        let effectiveMode: AVAudioSession.Mode = (tunerRequestCount > 0) ? .measurement : mode
        configure(
            category: .playAndRecord,
            mode: effectiveMode,
            options: [.defaultToSpeaker, .mixWithOthers]
        )
    }

    /// Tuner 开始监听：强制 measurement
    func beginTunerSession() {
        lock.lock()
        tunerRequestCount += 1
        lock.unlock()
        configureForPlayAndRecord(mode: .measurement)
    }

    /// Tuner 停止监听：恢复 default
    func endTunerSession() {
        lock.lock()
        tunerRequestCount = max(0, tunerRequestCount - 1)
        let shouldRestoreDefault = (tunerRequestCount == 0)
        lock.unlock()

        if shouldRestoreDefault {
            configureForPlayAndRecord(mode: .default)
        }
    }

    private func configure(
        category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions
    ) {
        lock.lock()
        defer { lock.unlock() }

        guard needsConfiguration(category: category, mode: mode, options: options) else { return }

        let session = AVAudioSession.sharedInstance()
        do {
            // 降低延迟（系统可能会调整，这是“请求”）
            try session.setPreferredSampleRate(44100)
            try session.setPreferredIOBufferDuration(0.0058) // ~256 frames @ 44.1k

            try session.setCategory(category, mode: mode, options: options)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            lastCategory = category
            lastMode = mode
            lastOptions = options
            isConfigured = true
        } catch {
            print("⚠️ AudioSessionManager configure failed: \(error.localizedDescription)")
        }
    }

    private func needsConfiguration(
        category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions
    ) -> Bool {
        if !isConfigured { return true }
        return lastCategory != category || lastMode != mode || lastOptions != options
    }
}
