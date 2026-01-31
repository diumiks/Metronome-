import Foundation
import AVFoundation

/// 专业级高精度节拍器
/// 使用音频渲染回调驱动，精度达到采样级别（~0.02ms）
class PrecisionMetronomeTimer {
    // 音频引擎
    private let audioEngine = AVAudioEngine()
    private var playerNode: AVAudioSourceNode?
    
    // 音频参数
    private let sampleRate: Double = 44100
    private var phase: Float = 0
    private var currentFrame: AVAudioFramePosition = 0
    private var nextBeatFrame: AVAudioFramePosition = 0
    private var framesPerBeat: AVAudioFramePosition = 0
    
    // 节拍参数
    private var bpm: Double = 120
    private var isPlaying = false
    private var beatCount: Int = 0
    private var timeSignature: Int = 4  // 拍号（每小节的拍数）
    
    // 音频特征 - 不同音色的频率配置
    private var soundTheme: Int = 0  // 当前音色主题
    
    // 音色配置：(强音频率, 弱音频率)
    private let soundThemes: [(strong: Float, weak: Float)] = [
        (1200.0, 800.0),   // 0: 清脆电子音（原有）
        (2000.0, 1500.0),  // 1: 明亮高音
        (600.0, 400.0),    // 2: 温暖低音
        (1000.0, 750.0),   // 3: 经典木鱼音
        (1600.0, 1200.0),  // 4: 清晰中高音
    ]
    
    private let clickDuration: AVAudioFrameCount = 2205 // 0.05秒
    private var clickFramesRemaining: AVAudioFrameCount = 0
    private var currentFrequency: Float = 0
    
    // 高精度相位增量（预计算，避免实时计算）
    private var phaseIncrement: Float = 0
    
    // UI 回调 - 传递节拍索引信息
    private var onBeatCallback: ((Int, Bool) -> Void)?  // (beatIndex, isStrongBeat)
    
    init() {
        setupAudio()
        createAudioNode()
    }
    
    var isRunning: Bool { isPlaying }
    
    /// 设置音频会话
    private func setupAudio() {
        AudioSessionManager.shared.configureForPlayAndRecord()
    }
    
    /// 创建音频节点（只创建一次）
    private func createAudioNode() {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }
        
        let sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self, self.isPlaying else {
                // 不播放时输出静音
                let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
                for buffer in ablPointer {
                    memset(buffer.mData, 0, Int(buffer.mDataByteSize))
                }
                return noErr
            }
            
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let buffer = ablPointer.first,
                  let data = buffer.mData?.assumingMemoryBound(to: Float.self) else {
                return noErr
            }
            
            // 生成音频样本
            for frame in 0..<Int(frameCount) {
                // 检查是否到达下一个节拍
                if self.currentFrame >= self.nextBeatFrame {
                    // 触发新节拍
                    self.clickFramesRemaining = self.clickDuration
                    
                    // 根据拍号计算是否为重音
                    let beatIndex = self.beatCount % self.timeSignature
                    let isStrongBeat = (self.timeSignature == 1) ? false : (beatIndex == 0)
                    
                    // 根据音色主题选择频率
                    let theme = self.soundThemes[self.soundTheme]
                    self.currentFrequency = isStrongBeat ? theme.strong : theme.weak
                    
                    // 【修复 1】每次节拍时完全重置相位，确保波形从零点开始
                    // 这样可以避免相位不连续导致的杂音
                    self.phase = 0
                    
                    // 【高频优化】预计算相位增量，提高高频音色的精度
                    // 使用 Double 精度计算，然后转为 Float，减少累积误差
                    let preciseIncrement = 2.0 * Double.pi * Double(self.currentFrequency) / self.sampleRate
                    self.phaseIncrement = Float(preciseIncrement)
                    
                    // 【修复 2】在音频线程计算节拍信息，通过回调传递给 UI
                    // 这样可以确保视觉指示器和音频完全同步
                    let capturedBeatIndex = beatIndex
                    let capturedIsStrong = isStrongBeat
                    DispatchQueue.main.async {
                        self.onBeatCallback?(capturedBeatIndex, capturedIsStrong)
                    }
                    
                    self.beatCount += 1
                    
                    // 【优化】定期重置计数器，避免长时间运行导致溢出
                    // 每隔 10000 个节拍重置一次（约在 120BPM 时为 83 分钟）
                    if self.beatCount % 10000 == 0 {
                        self.currentFrame = 0
                        self.nextBeatFrame = self.framesPerBeat
                    } else {
                        // 安全地计算下一个节拍位置
                        let nextFrame = self.nextBeatFrame.addingReportingOverflow(self.framesPerBeat)
                        if nextFrame.overflow {
                            // 发生溢出，重置
                            self.currentFrame = 0
                            self.nextBeatFrame = self.framesPerBeat
                        } else {
                            self.nextBeatFrame = nextFrame.partialValue
                        }
                    }
                }
                
                // 生成点击声音
                var sample: Float = 0
                if self.clickFramesRemaining > 0 {
                    // 【优化】使用指数衰减替代线性衰减，音色更自然
                    let progress = Float(self.clickDuration - self.clickFramesRemaining) / Float(self.clickDuration)
                    
                    // 【高频优化】针对高频音色（>1800Hz）使用更快的衰减
                    // 这样可以减少高频音色的刺耳感，同时保持干脆
                    let decayRate: Float = self.currentFrequency > 1800.0 ? 5.5 : 4.0
                    let fadeOut = exp(-decayRate * progress)
                    
                    // 【高频优化】针对高频音色降低振幅，避免刺耳和失真
                    let theme = self.soundThemes[self.soundTheme]
                    let isStrongBeat = (self.currentFrequency == theme.strong)
                    
                    let baseAmplitude: Float
                    if self.currentFrequency > 1800.0 {
                        // 高频音色：强音 0.6，弱音 0.4
                        baseAmplitude = isStrongBeat ? 0.6 : 0.4
                    } else {
                        // 常规音色：强音 0.8，弱音 0.5
                        baseAmplitude = isStrongBeat ? 0.8 : 0.5
                    }
                    let amplitudeBoost: Float = 2.25
                    let amplitude = min(baseAmplitude * amplitudeBoost, 1.0)
                    
                    // 【高频优化】使用预计算的相位增量，避免实时计算误差
                    sample = sin(self.phase) * amplitude * fadeOut
                    
                    // 使用预计算的增量更新相位
                    self.phase += self.phaseIncrement
                    
                    // 【修复 3】更精确的相位归一化，避免累积误差
                    // 对于高频，每 8 个样本检查一次相位（减少计算开销）
                    if self.clickFramesRemaining % 8 == 0 {
                        while self.phase >= 2.0 * Float.pi {
                            self.phase -= 2.0 * Float.pi
                        }
                    }
                    
                    self.clickFramesRemaining -= 1
                }
                
                data[frame] = sample
                
                // 安全地增加帧计数
                let nextCurrentFrame = self.currentFrame.addingReportingOverflow(1)
                if nextCurrentFrame.overflow {
                    // 重置计数器，避免溢出
                    self.currentFrame = 0
                    self.nextBeatFrame = self.framesPerBeat
                } else {
                    self.currentFrame = nextCurrentFrame.partialValue
                }
            }
            
            return noErr
        }
        
        // 连接节点
        audioEngine.attach(sourceNode)
        audioEngine.connect(sourceNode, to: audioEngine.mainMixerNode, format: format)
        playerNode = sourceNode
        
        // 启动引擎
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("引擎启动失败: \(error)")
        }
    }
    
    /// 播放声音（接口兼容）
    func playSound(isStrong: Bool) {
        // 音频由渲染回调生成
    }
    
    /// 开始
    func start(bpm: Double, timeSignature: Int, soundTheme: Int, onBeat: @escaping (Int, Bool) -> Void) {
        // 先停止，确保状态清零
        isPlaying = false
        
        // 重置所有状态
        self.bpm = bpm
        self.timeSignature = timeSignature
        self.soundTheme = min(soundTheme, soundThemes.count - 1)  // 确保索引有效
        self.onBeatCallback = onBeat
        self.beatCount = 0
        self.currentFrame = 0
        self.nextBeatFrame = 0
        self.framesPerBeat = AVAudioFramePosition(sampleRate * 60.0 / bpm)
        self.phase = 0
        self.clickFramesRemaining = 0
        
        // 重新开始
        self.isPlaying = true
        
        // 确保引擎在运行
        if !audioEngine.isRunning {
            audioEngine.prepare()
            try? audioEngine.start()
        }
    }
    
    /// 停止
    func stop() {
        isPlaying = false
        onBeatCallback = nil
        currentFrame = 0
        nextBeatFrame = 0
        beatCount = 0
        clickFramesRemaining = 0
    }
    
    /// 更新 BPM
    func updateBPM(_ bpm: Double, timeSignature: Int, soundTheme: Int) {
        guard isPlaying, let callback = onBeatCallback else { return }
        start(bpm: bpm, timeSignature: timeSignature, soundTheme: soundTheme, onBeat: callback)
    }
    
    deinit {
        stop()
        audioEngine.stop()
    }
}
