import SwiftUI
import AVFoundation
import Combine

class TunerEngine: ObservableObject {
    private var engine: AVAudioEngine
    private var mic: AVAudioInputNode
    private var player: AVAudioPlayerNode
    
    let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    
    @Published var data = TunerData()
    @Published var isPlaying = false
    @Published var standardFrequency: Double = 440.0
    @Published var errorMessage: String?
    
    // 性能优化：复用缓冲区
    private var sampleBuffer: [Float] = []
    
    // 音频处理队列 - 使用串行队列确保操作顺序
    private let audioQueue = DispatchQueue(label: "com.tuner.audio", qos: .userInitiated)
    
    // 线程安全锁
    private let lock = NSLock()
    
    // 当前播放频率，用于热切换
    private var currentPlayingFrequency: Double = 0
    
    // 缓冲区调度控制
    private var shouldContinueScheduling = false
    
    struct TunerData {
        var pitch: Double = 0.0
        var amplitude: Double = 0.0
        var noteName: String = "--"
        var deviation: Double = 0.0
    }
    
    init() {
        engine = AVAudioEngine()
        mic = engine.inputNode
        player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: nil)
        
        // 加载上次的标准频率
        let savedFreq = UserDefaults.standard.double(forKey: UserDefaultsKeys.lastStandardFrequency)
        if savedFreq > 0 {
            standardFrequency = savedFreq
        }
        
        setupAudioSession()
    }
    
    deinit {
        // 保存标准频率
        UserDefaults.standard.set(standardFrequency, forKey: UserDefaultsKeys.lastStandardFrequency)
        
        // 【新增】清理音频资源
        stopPlaying()
        stopListening()
        
        // 停止引擎
        if engine.isRunning {
            engine.stop()
        }
        
        print("🧹 TunerEngine 已清理")
    }
    
    func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            
            // 【优化】检查当前类别，避免不必要的重新设置
            let currentCategory = session.category
            let currentOptions = session.categoryOptions
            
            let needsSetup = !(
                currentCategory == .playAndRecord &&
                currentOptions.contains(.defaultToSpeaker) &&
                currentOptions.contains(.mixWithOthers)
            )
            
            if needsSetup {
                // 【修改】不要停用当前音频会话，避免打断节拍器
                // try? session.setActive(false, options: .notifyOthersOnDeactivation)
                
                // 【优化】添加短暂延迟，让之前的操作完成
                Thread.sleep(forTimeInterval: 0.1)
                
                // 设置新的类别，使用 .mixWithOthers 确保不打断其他音频
                try session.setCategory(
                    .playAndRecord,
                    mode: .default,
                    options: [.defaultToSpeaker, .mixWithOthers]
                )
                
                // 【新增】添加延迟后再激活
                Thread.sleep(forTimeInterval: 0.05)
            }
            
            // 【修改】激活时不打断其他音频
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            
            DispatchQueue.main.async {
                self.errorMessage = nil
            }
        } catch let error as NSError {
            print("⚠️ TunerEngine Audio Session Error: \(error.code) - \(error.localizedDescription)")
            
            // 忽略"正在使用"的错误
            if error.code != AVAudioSession.ErrorCode.isBusy.rawValue &&
               error.code != AVAudioSession.ErrorCode.cannotInterruptOthers.rawValue {
                DispatchQueue.main.async {
                    self.errorMessage = AudioError.sessionSetupFailed.localizedDescription
                }
            }
        }
    }
    
    func startListening() {
        stopPlaying()
        
        // 【优化】增加延迟到 100ms，确保音频引擎完全停止
        Thread.sleep(forTimeInterval: 0.1)
        
        if engine.isRunning { 
            engine.stop() 
        }
        engine.reset()
        
        // 【新增】在获取输入格式前先设置音频会话
        setupAudioSession()
        
        // 【新增】再次添加延迟，确保音频会话完全生效
        Thread.sleep(forTimeInterval: 0.05)
        
        let format = mic.inputFormat(forBus: 0)
        guard format.sampleRate > 0 else {
            print("❌ Invalid microphone format: sampleRate = \(format.sampleRate)")
            DispatchQueue.main.async {
                self.errorMessage = AudioError.deviceNotAvailable.localizedDescription
            }
            return
        }
        
        print("✅ Microphone format: \(format.sampleRate) Hz, \(format.channelCount) channels")
        
        mic.removeTap(onBus: 0)
        
        // 使用常量配置缓冲区大小
        mic.installTap(onBus: 0, bufferSize: AudioConstants.bufferSize, format: format) { [weak self] (buffer, time) in
            self?.processAudio(buffer: buffer)
        }
        
        do {
            try engine.start()
            DispatchQueue.main.async {
                self.errorMessage = nil
            }
        } catch {
            print("⚠️ TunerEngine start error: \(error)")
            DispatchQueue.main.async {
                self.errorMessage = AudioError.engineStartFailed.localizedDescription
            }
        }
    }
    
    func stopListening() {
        mic.removeTap(onBus: 0)
        engine.stop()
        DispatchQueue.main.async { self.data = TunerData() }
    }
    
    func playTone(frequency: Double) {
        // 防止重复调用相同频率
        if isPlaying && abs(frequency - currentPlayingFrequency) < 0.1 {
            return
        }
        
        currentPlayingFrequency = frequency
        
        // 在音频队列中执行，确保线程安全
        audioQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.lock.lock()
            defer { self.lock.unlock() }
            
            // 停止调度循环
            self.shouldContinueScheduling = false
            
            // 停止监听
            if self.mic.numberOfInputs > 0 {
                self.mic.removeTap(onBus: 0)
            }
            
            // 停止播放器
            self.player.stop()
            
            // 停止引擎（移除 sleep，AVAudioEngine.stop() 是同步的）
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
                    self.errorMessage = AudioError.engineStartFailed.localizedDescription
                    self.isPlaying = false
                }
            }
        }
    }
    
    private func scheduleBufferLoop(buffer: AVAudioPCMBuffer) {
        guard shouldContinueScheduling else { return }
        
        // 预先调度5个缓冲区，每个完成后会触发回调补充
        for _ in 0..<5 {
            scheduleNextBuffer(buffer)
        }
    }
    
    private func scheduleNextBuffer(_ buffer: AVAudioPCMBuffer) {
        // 关键修复：只检查 shouldContinueScheduling，不检查 isPlaying
        // 因为 isPlaying 可能在主线程更新有延迟
        guard shouldContinueScheduling else { return }
        
        player.scheduleBuffer(buffer) { [weak self] in
            guard let self = self else { return }
            // 关键：每个缓冲区播放完成后，递归调度下一个
            // 这样就能无限循环播放
            self.scheduleNextBuffer(buffer)
        }
    }
    
    func stopPlaying() {
        audioQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.lock.lock()
            defer { self.lock.unlock() }
            
            // 停止调度循环
            self.shouldContinueScheduling = false
            
            // 停止播放器
            self.player.stop()
            
            DispatchQueue.main.async {
                self.isPlaying = false
            }
        }
    }
    
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
        
        // 关键修复：使用周期归一化的方式生成波形
        // 确保最后一个采样点和第一个采样点相位连续
        let totalSamples = Int(frameCount)
        
        for i in 0..<totalSamples {
            // 方法1：基于总周期数归一化（更精确）
            // 将整个缓冲区分成 cycles 个完整周期
            let normalizedPosition = Double(i) / Double(totalSamples)  // 0.0 到 1.0
            let phase = 2.0 * .pi * cycles * normalizedPosition
            let sample = Float(sin(phase)) * 0.5
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
    
    private func processAudio(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        
        // 性能优化：在栈上创建临时缓冲区，避免竞争条件
        // 由于音频回调在专用线程，使用局部变量更安全
        var localBuffer = sampleBuffer
        if localBuffer.count != frameLength {
            localBuffer = [Float](repeating: 0, count: frameLength)
            sampleBuffer = localBuffer  // 更新共享缓冲区
        }
        
        // 复制数据到缓冲区
        for i in 0..<frameLength {
            localBuffer[i] = channelData[i]
        }
        
        // 1. 计算 RMS (音量/振幅)
        var sum: Float = 0
        for sample in localBuffer {
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(frameLength))
        
        // 2. 计算过零率 (Zero-Crossing)
        // 这种算法比 FFT 简单，它是通过数波形穿过 0 轴的次数来估算频率
        var zeroCrossings = 0
        var previousSign = localBuffer[0] > 0
        for sample in localBuffer {
            let currentSign = sample > 0
            if currentSign != previousSign {
                zeroCrossings += 1
                previousSign = currentSign
            }
        }
        
        let frequency = Double(zeroCrossings) * buffer.format.sampleRate / (2.0 * Double(frameLength))
        
        // 3. 噪音门限：只有音量大于阈值才更新音高
        // 【新增】提高阈值，过滤掉节拍器的短促音
        let dynamicThreshold = AudioConstants.rmsThreshold * 1.5  // 提高 50% 阈值
        
        if Double(rms) > dynamicThreshold {
            analyzePitch(frequency: frequency, amplitude: Double(rms))
        } else {
            DispatchQueue.main.async { self.data.amplitude = Double(rms) }
        }
    }
    
    private func analyzePitch(frequency: Double, amplitude: Double) {
        // 【优化 1】过滤掉节拍器的高频音（800-2000 Hz）
        // 节拍器通常使用高频短促音，与乐器音色不同
        let isLikelyMetronome = frequency > 700.0 && frequency < 2100.0 && amplitude < 0.3
        
        if isLikelyMetronome {
            // 忽略疑似节拍器的声音
            return
        }
        
        // 【优化 2】过滤掉人耳听不到的极端频率
        guard frequency > AudioConstants.minFrequency && frequency < AudioConstants.maxFrequency else { return }
        
        let baseFreq = self.standardFrequency
        
        let semitones = 12.0 * log2(frequency / baseFreq)
        let noteNumDouble = semitones + 69.0
        let roundedNoteNum = Int(round(noteNumDouble))
        let diff = noteNumDouble - Double(roundedNoteNum)
        let deviationCents = 100.0 * diff
        
        var index = roundedNoteNum % 12
        if index < 0 { index += 12 }
        
        DispatchQueue.main.async {
            self.data.pitch = frequency
            self.data.noteName = self.noteNames[index]
            self.data.deviation = deviationCents
            self.data.amplitude = amplitude
        }
    }
}
