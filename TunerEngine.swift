import SwiftUI
import AVFoundation
import Combine

final class TunerEngine: ObservableObject {
    private let audioQueue = DispatchQueue(label: "com.metronomeapp.tuner.audio", qos: .userInitiated)
    private let lock = NSLock()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var mic: AVAudioInputNode { engine.inputNode }

    let noteNames = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]

    @Published var data = TunerData()
    @Published var isPlaying: Bool = false
    @Published var standardFrequency: Double = 440.0
    @Published var errorMessage: String?

    private var isListening = false
    private var sampleBuffer: [Float] = []

    // 追踪状态
    private var smoothedPitch: Double = 0
    private var silenceFrameCount = 0
    private var recentPitchEstimates: [Double] = []
    private let maxPitchHistory = 2

    private var pendingJumpPitch: Double = 0
    private var pendingJumpCount: Int = 0

    private var noiseFloorRMS: Double = 0
    private let noiseFloorAlpha: Double = 0.96

    struct TunerData {
        var pitch: Double = 0
        var amplitude: Double = 0
        var noteName: String = "--"
        var deviation: Double = 0
    }

    init() {
        let saved = UserDefaults.standard.double(forKey: UserDefaultsKeys.lastStandardFrequency)
        if saved > 0 { standardFrequency = saved }

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: nil)
    }

    deinit {
        UserDefaults.standard.set(standardFrequency, forKey: UserDefaultsKeys.lastStandardFrequency)
        stopPlaying()
        stopListening()
    }

    // MARK: - Listening

    func startListening() {
        audioQueue.async { [weak self] in
            guard let self else { return }

            self.lock.lock()
            defer { self.lock.unlock() }

            if self.isListening || self.isPlaying { return }
            self.isListening = true

            AudioSessionManager.shared.beginTunerSession()

            self.mic.removeTap(onBus: 0)
            let format = self.mic.inputFormat(forBus: 0)
            guard format.sampleRate > 0 else {
                DispatchQueue.main.async { self.errorMessage = AudioError.deviceNotAvailable.localizedDescription }
                self.isListening = false
                AudioSessionManager.shared.endTunerSession()
                return
            }

            self.mic.installTap(onBus: 0, bufferSize: AudioConstants.bufferSize, format: format) { [weak self] buffer, _ in
                self?.processAudio(buffer: buffer)
            }

            if !self.engine.isRunning {
                do { try self.engine.start() }
                catch {
                    DispatchQueue.main.async { self.errorMessage = AudioError.engineStartFailed.localizedDescription }
                    self.mic.removeTap(onBus: 0)
                    self.isListening = false
                    AudioSessionManager.shared.endTunerSession()
                    return
                }
            }

            DispatchQueue.main.async { self.errorMessage = nil }
        }
    }

    func stopListening() {
        audioQueue.async { [weak self] in
            guard let self else { return }

            self.lock.lock()
            defer { self.lock.unlock() }

            guard self.isListening else { return }
            self.isListening = false

            self.mic.removeTap(onBus: 0)
            self.resetTrackingState()

            AudioSessionManager.shared.endTunerSession()
            if self.engine.isRunning {
                self.engine.stop()
            }

            DispatchQueue.main.async { self.data = TunerData() }
        }
    }

    private func resetTrackingState() {
        recentPitchEstimates.removeAll()
        smoothedPitch = 0
        silenceFrameCount = 0
        pendingJumpPitch = 0
        pendingJumpCount = 0
        noiseFloorRMS = 0
    }

    // MARK: - Tone

    func playTone(frequency: Double) {
        audioQueue.async { [weak self] in
            guard let self else { return }

            self.lock.lock()
            defer { self.lock.unlock() }

            // 播放音时，停止监听
            if self.isListening {
                self.isListening = false
                self.mic.removeTap(onBus: 0)
                self.resetTrackingState()
                AudioSessionManager.shared.endTunerSession()
            }

            if !self.engine.isRunning {
                do { try self.engine.start() }
                catch {
                    DispatchQueue.main.async { self.errorMessage = AudioError.engineStartFailed.localizedDescription }
                    return
                }
            }

            guard let format = AVAudioFormat(standardFormatWithSampleRate: AudioConstants.sampleRate, channels: 1),
                  let buffer = self.createSineWave(frequency: frequency, sampleRate: AudioConstants.sampleRate, format: format)
            else {
                DispatchQueue.main.async { self.errorMessage = "创建音频缓冲区失败" }
                return
            }

            self.player.stop()
            self.player.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
            self.player.play()

            DispatchQueue.main.async {
                self.isPlaying = true
                self.errorMessage = nil
            }
        }
    }

    func stopPlaying() {
        audioQueue.async { [weak self] in
            guard let self else { return }
            self.player.stop()
            if !self.isListening, self.engine.isRunning {
                self.engine.stop()
            }
            DispatchQueue.main.async { self.isPlaying = false }
        }
    }

    private func createSineWave(frequency: Double, sampleRate: Double, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let desiredDuration: Double = 0.5
        let frameCount = AVAudioFrameCount(sampleRate * desiredDuration)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount
        guard let channels = buffer.floatChannelData else { return nil }

        let samples = channels[0]
        let total = Int(frameCount)
        let twoPiF = 2.0 * Double.pi * frequency

        for i in 0..<total {
            let t = Double(i) / sampleRate
            samples[i] = Float(sin(twoPiF * t)) * 0.5
        }
        return buffer
    }

    // MARK: - Audio processing

    private func processAudio(buffer: AVAudioPCMBuffer) {
        guard isListening else { return }
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let n = Int(buffer.frameLength)
        guard n > 0 else { return }

        if sampleBuffer.count != n { sampleBuffer = [Float](repeating: 0, count: n) }
        for i in 0..<n { sampleBuffer[i] = channelData[i] }

        var sum: Float = 0
        for s in sampleBuffer { sum += s * s }
        let rms = sqrt(sum / Float(n))
        let amp = Double(rms)

        DispatchQueue.main.async { self.data.amplitude = amp }

        let baseThreshold = AudioConstants.rmsThreshold * 0.45
        if amp < max(baseThreshold, noiseFloorRMS * 1.25) {
            noiseFloorRMS = noiseFloorAlpha * noiseFloorRMS + (1.0 - noiseFloorAlpha) * amp
        }
        let gate = max(baseThreshold, noiseFloorRMS * 2.8)

        guard amp > gate else {
            silenceFrameCount += 1
            if silenceFrameCount >= 2 { smoothedPitch = 0 }
            return
        }
        silenceFrameCount = 0

        if let freq = estimatePitch(buffer: sampleBuffer, sampleRate: buffer.format.sampleRate) {
            analyzePitch(frequency: freq, amplitude: amp)
        }
    }

    private func estimatePitch(buffer: [Float], sampleRate: Double) -> Double? {
        let n = buffer.count
        guard n > 1 else { return nil }

        var mean: Float = 0
        for s in buffer { mean += s }
        mean /= Float(n)

        var x = [Float](repeating: 0, count: n)
        for i in 0..<n {
            let w = 0.5 - 0.5 * cos(2.0 * .pi * Double(i) / Double(n - 1))
            x[i] = (buffer[i] - mean) * Float(w)
        }

        let minLag = max(Int(sampleRate / AudioConstants.maxFrequency), 1)
        let maxLag = min(Int(sampleRate / AudioConstants.minFrequency), n - 1)
        guard maxLag > minLag else { return nil }

        func corr(_ lag: Int) -> Float {
            var sum: Float = 0, e1: Float = 0, e2: Float = 0
            let upper = n - lag
            if upper <= 0 { return 0 }
            for i in 0..<upper {
                let a = x[i], b = x[i + lag]
                sum += a * b
                e1 += a * a
                e2 += b * b
            }
            return sum / (sqrt(e1 * e2) + 1e-9)
        }

        var bestLag = minLag
        var bestCorr: Float = -1
        var correlations = [Float](repeating: 0, count: maxLag + 1)

        for lag in minLag...maxLag {
            let c = corr(lag)
            correlations[lag] = c
            if c > bestCorr { bestCorr = c; bestLag = lag }
        }

        if bestCorr < 0.15 { return nil }

        var firstPeak: Int?
        if maxLag - minLag >= 2 {
            for lag in (minLag + 1)..<maxLag {
                let p = correlations[lag - 1], c = correlations[lag], n = correlations[lag + 1]
                if c > 0.24 && c > p && c > n { firstPeak = lag; break }
            }
        }
        if let peak = firstPeak, correlations[peak] >= bestCorr * 0.85 {
            bestLag = peak
            bestCorr = correlations[peak]
        }

        var refined = Double(bestLag)
        if bestLag > minLag && bestLag < maxLag {
            let c1 = Double(correlations[bestLag - 1])
            let c2 = Double(bestCorr)
            let c3 = Double(correlations[bestLag + 1])
            let denom = (2 * c2 - c1 - c3)
            if abs(denom) > 1e-6 {
                refined += 0.5 * (c1 - c3) / denom
            }
        }

        return sampleRate / refined
    }

    private func analyzePitch(frequency: Double, amplitude: Double) {
        guard frequency > AudioConstants.minFrequency && frequency < AudioConstants.maxFrequency else { return }

        recentPitchEstimates.append(frequency)
        if recentPitchEstimates.count > maxPitchHistory {
            recentPitchEstimates.removeFirst(recentPitchEstimates.count - maxPitchHistory)
        }
        let sorted = recentPitchEstimates.sorted()
        let median = sorted[sorted.count / 2]

        if smoothedPitch > 0 {
            let jump = abs(1200.0 * log2(median / smoothedPitch))
            if jump > 110 {
                if pendingJumpPitch == 0 {
                    pendingJumpPitch = median
                    pendingJumpCount = 1
                    return
                } else {
                    let delta = abs(1200.0 * log2(median / pendingJumpPitch))
                    if delta < 30 { pendingJumpCount += 1 }
                    else { pendingJumpPitch = median; pendingJumpCount = 1 }

                    if pendingJumpCount >= 1 {
                        smoothedPitch = median
                        recentPitchEstimates = [median]
                        pendingJumpPitch = 0
                        pendingJumpCount = 0
                    } else {
                        return
                    }
                }
            } else {
                pendingJumpPitch = 0
                pendingJumpCount = 0
            }
        }

        let smoothing = amplitude > 0.08 ? 0.85 : 0.65
        if smoothedPitch == 0 { smoothedPitch = median }
        else { smoothedPitch += (median - smoothedPitch) * smoothing }

        let stable = smoothedPitch
        let base = standardFrequency

        let semitones = 12.0 * log2(stable / base)
        let noteNum = semitones + 69.0
        let rounded = Int(round(noteNum))
        let diff = noteNum - Double(rounded)
        let cents = diff * 100.0

        var idx = rounded % 12
        if idx < 0 { idx += 12 }

        DispatchQueue.main.async {
            self.data.pitch = stable
            self.data.noteName = self.noteNames[idx]
            self.data.deviation = cents
        }
    }
}
