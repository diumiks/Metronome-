import AVFoundation
import Combine

/// 标准音生成引擎
/// 专门负责播放标准音，不涉及麦克风监听
class ToneGeneratorEngine: ObservableObject {
    private var engine: AVAudioEngine
    private var player: AVAudioPlayerNode
    
    @Published var isPlaying = false
    @Published var errorMessage: String?
    
    // 音频处理队列 - 使用串行队列确保操作顺序
    private let audioQueue = DispatchQueue(label: "com.tonegenerator.audio", qos: .userInitiated)
    private let audioQueueKey = DispatchSpecificKey<Void>()
    
    // 线程安全锁
    private let lock = NSLock()
    
    // 当前播放频率，用于热切换
    private var currentPlayingFrequency: Double = 0
    
    // 缓冲区调度控制
    private var shouldContinueScheduling = false
    
    init() {
        engine = AVAudioEngine()
        player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: nil)
        audioQueue.setSpecific(key: audioQueueKey, value: ())
        
        // 不在初始化时设置音频会话
        // 延迟到真正需要播放时设置
    }
    
    deinit {
        stopPlaying()
        
        // 停止引擎
        if engine.isRunning {
            engine.stop()
        }
        
        print("🧹 ToneGeneratorEngine 已清理")
    }
    
    func setupAudioSession() {
        AudioSessionManager.shared.configureForPlayAndRecord()
        DispatchQueue.main.async {
            self.errorMessage = nil
        }
    }
    
    /// 播放指定频率的标准音
    func playTone(frequency: Double) {
        // 防止重复调用相同频率
        if isPlaying && abs(frequency - currentPlayingFrequency) < 0.1 {
            return
        }
        
        currentPlayingFrequency = frequency
        
        // 【新增】在播放前设置音频会话
        setupAudioSession()
        
        // 在音频队列中执行，确保线程安全
        audioQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.lock.lock()
            defer { self.lock.unlock() }
            
            // 停止调度循环
            self.shouldContinueScheduling = false
            
            // 停止播放器
            self.player.stop()
            
            // 停止引擎
            if self.engine.isRunning {
                self.engine.stop()
            }
            
            // 断开连接
            self.engine.disconnectNodeOutput(self.player)
            
            // 创建新的音频格式和缓冲区
            let format = AVAudioFormat(standardFormatWithSampleRate: AudioConstants.sampleRate, channels: 1)!
            guard let buffer = self.createSineWave(frequency: frequency, sampleRate: AudioConstants.sampleRate, format: format) else {
                DispatchQueue.main.async {
                    self.errorMessage = "创建音频缓冲区失败"
                    self.isPlaying = false
                }
                return
            }
            
            // 重新连接
            self.engine.connect(self.player, to: self.engine.mainMixerNode, format: format)
            
            do {
                try self.engine.start()
                
                // 启动调度循环
                self.shouldContinueScheduling = true
                self.scheduleBufferLoop(buffer: buffer)
                
                // 开始播放
                self.player.play()
                
                DispatchQueue.main.async {
                    self.isPlaying = true
                    self.errorMessage = nil
                }
            } catch {
                print("Engine start error: \(error)")
                DispatchQueue.main.async {
                    self.errorMessage = "音频引擎启动失败"
                    self.isPlaying = false
                }
            }
        }
    }
    
    /// 停止播放
    func stopPlaying() {
        performOnAudioQueue { [weak self] in
            guard let self = self else { return }
            
            self.lock.lock()
            defer { self.lock.unlock() }
            
            // 停止调度循环
            self.shouldContinueScheduling = false
            
            // 停止播放器
            self.player.stop()
            
            // 立即停止引擎，避免缓冲区继续播放
            if self.engine.isRunning {
                self.engine.stop()
            }
            
            DispatchQueue.main.async {
                self.isPlaying = false
            }
        }
    }
    
    // MARK: - 私有方法
    
    private func scheduleBufferLoop(buffer: AVAudioPCMBuffer) {
        guard shouldContinueScheduling else { return }
        
        // 预先调度5个缓冲区，每个完成后会触发回调补充
        for _ in 0..<5 {
            scheduleNextBuffer(buffer)
        }
    }
    
    private func scheduleNextBuffer(_ buffer: AVAudioPCMBuffer) {
        // 只检查 shouldContinueScheduling，不检查 isPlaying
        // 因为 isPlaying 可能在主线程更新有延迟
        guard shouldContinueScheduling else { return }
        
        player.scheduleBuffer(buffer) { [weak self] in
            guard let self = self else { return }
            // 每个缓冲区播放完成后，递归调度下一个
            // 这样就能无限循环播放
            self.scheduleNextBuffer(buffer)
        }
    }
    
    private func performOnAudioQueue(_ work: @escaping () -> Void) {
        if DispatchQueue.getSpecific(key: audioQueueKey) != nil {
            work()
        } else {
            audioQueue.sync(execute: work)
        }
    }
    
    /// 创建正弦波音频缓冲区
    private func createSineWave(frequency: Double, sampleRate: Double, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        // 精确生成正弦波，消除相位不连续导致的杂音
        
        let samplesPerCycle = sampleRate / frequency
        
        // 计算需要多少个完整周期才能让缓冲区足够长（约0.5秒）
        let desiredDuration: Double = 0.5
        let cycles = round(desiredDuration * frequency)
        
        // 帧数 = 周期数 × 每周期采样点数
        let frameCount = AVAudioFrameCount(cycles * samplesPerCycle)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount
        
        guard let channels = buffer.floatChannelData else { return nil }
        let samples = channels[0]
        
        // 使用周期归一化的方式生成波形
        // 确保最后一个采样点和第一个采样点相位连续
        let totalSamples = Int(frameCount)
        
        for i in 0..<totalSamples {
            // 将整个缓冲区分成 cycles 个完整周期
            let normalizedPosition = Double(i) / Double(totalSamples)  // 0.0 到 1.0
            let phase = 2.0 * .pi * cycles * normalizedPosition
            let sample = Float(sin(phase)) * 0.5  // 0.5 振幅，避免过载
            samples[i] = sample
        }
        
        #if DEBUG
        // 验证相位连续性（仅在调试模式）
        let firstSample = samples[0]
        let lastSample = samples[totalSamples - 1]
        let continuityError = abs(lastSample - firstSample)
        
        if continuityError > 0.001 {
            print("⚠️ 频率 \(String(format: "%.2f", frequency))Hz - 相位差: \(String(format: "%.6f", continuityError))")
        }
        #endif
        
        return buffer
    }
}
