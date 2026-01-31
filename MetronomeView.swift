import SwiftUI
import AudioToolbox
import Combine
import AVFoundation

// MARK: - 1. 音效主题模型
enum SoundTheme: Int, CaseIterable, Identifiable {
    case crisp = 0
    case bright = 1
    case warm = 2
    case classic = 3
    case clear = 4
    
    var id: Int { self.rawValue }
    
    var name: String {
        switch self {
        case .crisp: return "清脆电子音"
        case .bright: return "明亮高音"
        case .warm: return "温暖低音"
        case .classic: return "经典木鱼音"
        case .clear: return "清晰中高音"
        }
    }
    
    // 保留这个用于兼容性，但现在不使用了
    var soundIDs: (strong: SystemSoundID, weak: SystemSoundID) {
        return (1104, 1103)
    }
}

// MARK: - 2. 主视图
struct MetronomeView: View {
    // --- 核心状态 ---
    @State private var isPlaying = false
    @State private var bpm: Double = AudioConstants.defaultBPM
    
    @State private var timeSignature: Int = 4
    @State private var selectedSoundTheme: SoundTheme = .crisp
    
    @State private var currentBeat = -1
    @State private var isVisualPulse = false
    
    @State private var lastTapTime: Date?
    @State private var showSettings = false
    
    // 使用高精度计时器（内置音频引擎）
    @State private var precisionTimer = PrecisionMetronomeTimer()
    
    // 读取用户设置
    @AppStorage(UserDefaultsKeys.soundEnabled) private var soundEnabled = true
    @AppStorage(UserDefaultsKeys.hapticEnabled) private var hapticEnabled = true
    
    let impactMed = UIImpactFeedbackGenerator(style: .medium)
    let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    
    var body: some View {
        // [修改 1] 使用 NavigationStack 替代 NavigationView
        // 它的加载机制不同，能立即显示标题栏结构
        NavigationStack {
            ZStack {
                // 背景色：浅灰色 (与校音器、设置页面统一)
                Color(UIColor.systemGray6)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    
                    Spacer()
                    
                    // 2. 核心显示区
                    VStack(spacing: 8) {
                        Text("\(Int(bpm))")
                            .font(.system(size: 100, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                            .contentTransition(.numericText(value: bpm))
                            .frame(height: 100)
                        
                        Text("BPM")
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        // 视觉节拍指示器
                        HStack(spacing: 10) {
                            ForEach(0..<timeSignature, id: \.self) { index in
                                Circle()
                                    .fill(getBeatColor(index: index))
                                    .frame(width: 14, height: 14)
                                    .scaleEffect(shouldHighlight(index) ? 1.5 : 1.0)
                                    .animation(.easeOut(duration: 0.1), value: isVisualPulse)
                            }
                        }
                        .frame(height: 40)
                        .padding(.top, 10)
                    }
                    
                    Spacer()
                    
                    // 3. 滑动控制条
                    HStack(spacing: 16) {
                        Button(action: { adjustBpm(-1) }) {
                            Image(systemName: "minus")
                                .font(.title3)
                                .frame(width: 40, height: 40)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(Circle())
                                .foregroundColor(.primary)
                        }
                        .accessibilityLabel("减少速度")
                        .accessibilityHint("将 BPM 减少 1")
                        
                        Slider(value: $bpm, in: AudioConstants.minBPM...AudioConstants.maxBPM, step: 1)
                            .accentColor(.blue)
                            .accessibilityLabel("速度调节")
                            .accessibilityValue("\(Int(bpm)) BPM")
                        
                        Button(action: { adjustBpm(1) }) {
                            Image(systemName: "plus")
                                .font(.title3)
                                .frame(width: 40, height: 40)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(Circle())
                                .foregroundColor(.primary)
                        }
                        .accessibilityLabel("增加速度")
                        .accessibilityHint("将 BPM 增加 1")
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                    
                    // 4. 底部极简操作栏
                    HStack(spacing: 50) {
                        Button(action: handleTapTempo) {
                            Image(systemName: "hand.tap.fill")
                                .font(.system(size: 28))
                                .frame(width: 70, height: 70)
                                .background(Color.orange.opacity(0.15))
                                .foregroundColor(.orange)
                                .clipShape(Circle())
                        }
                        .accessibilityLabel("Tap Tempo")
                        .accessibilityHint("连续点击以设置节拍速度")
                        
                        Button(action: toggleMetronome) {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 44))
                                .frame(width: 90, height: 90)
                                .background(isPlaying ? Color.red : Color.blue)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                                .shadow(color: (isPlaying ? Color.red : Color.blue).opacity(0.3), radius: 10, y: 5)
                        }
                        .accessibilityLabel(isPlaying ? "停止节拍器" : "开始节拍器")
                        .accessibilityHint("双击以\(isPlaying ? "停止" : "开始")节拍")
                        
                        Button(action: { showSettings = true }) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 28))
                                .frame(width: 70, height: 70)
                                .background(Color.gray.opacity(0.15))
                                .foregroundColor(.gray)
                                .clipShape(Circle())
                        }
                        .accessibilityLabel("设置")
                        .accessibilityHint("打开节拍器设置")
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("节拍器")
            // [修改 2] 强制使用大标题模式
            // 告诉系统“不用计算了，直接显示大标题”，消除延迟
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadSettings()
                
                // 恢复全局状态到本地状态
                let manager = MetronomeStateManager.shared
                if manager.isPlaying {
                    isPlaying = true
                    currentBeat = manager.currentBeat
                    timeSignature = manager.timeSignature
                }
            }
            .onDisappear {
                // 不再自动停止节拍器，允许后台播放
                // 只保存设置
                saveSettings()
            }
            .onChange(of: bpm) { oldValue, newValue in
                if isPlaying {
                    precisionTimer.updateBPM(newValue, timeSignature: timeSignature, soundTheme: selectedSoundTheme.rawValue)
                }
            }
            .onChange(of: timeSignature) { oldValue, newValue in
                if isPlaying {
                    precisionTimer.updateBPM(bpm, timeSignature: newValue, soundTheme: selectedSoundTheme.rawValue)
                }
            }
            .onChange(of: selectedSoundTheme) { oldValue, newValue in
                if isPlaying {
                    precisionTimer.updateBPM(bpm, timeSignature: timeSignature, soundTheme: newValue.rawValue)
                }
            }
            .sheet(isPresented: $showSettings) {
                MetronomeSettingsSheet(
                    timeSignature: $timeSignature,
                    selectedSoundTheme: $selectedSoundTheme
                )
            }
        }
    }
    
    // MARK: - 数据持久化
    
    func loadSettings() {
        let savedBPM = UserDefaults.standard.double(forKey: UserDefaultsKeys.lastBPM)
        if savedBPM > 0 {
            bpm = savedBPM
        }
        
        let savedSignature = UserDefaults.standard.integer(forKey: UserDefaultsKeys.lastTimeSignature)
        if savedSignature > 0 {
            timeSignature = savedSignature
        }
        
        let savedTheme = UserDefaults.standard.integer(forKey: UserDefaultsKeys.lastSoundTheme)
        if let theme = SoundTheme(rawValue: savedTheme) {
            selectedSoundTheme = theme
        }
    }
    
    func saveSettings() {
        UserDefaults.standard.set(bpm, forKey: UserDefaultsKeys.lastBPM)
        UserDefaults.standard.set(timeSignature, forKey: UserDefaultsKeys.lastTimeSignature)
        UserDefaults.standard.set(selectedSoundTheme.rawValue, forKey: UserDefaultsKeys.lastSoundTheme)
    }
    
    // MARK: - 逻辑辅助
    
    func shouldHighlight(_ index: Int) -> Bool {
        return isPlaying && currentBeat == index && isVisualPulse
    }
    
    func getBeatColor(index: Int) -> Color {
        if shouldHighlight(index) {
            if timeSignature == 1 {
                return .blue
            }
            return index == 0 ? .red : .blue
        }
        return Color.secondary.opacity(0.2)
    }
    
    func adjustBpm(_ amount: Double) {
        bpm = max(AudioConstants.minBPM, min(AudioConstants.maxBPM, bpm + amount))
        if hapticEnabled {
            impactMed.impactOccurred()
        }
    }
    
    func toggleMetronome() {
        isPlaying.toggle()
        if isPlaying {
            currentBeat = -1
            startMetronome()
        } else {
            stopMetronome()
        }
    }
    
    func startMetronome() {
        AudioSessionManager.shared.configureForPlayAndRecord()
        
        // 更新全局状态
        MetronomeStateManager.shared.start(timeSignature: timeSignature)
        
        precisionTimer.start(bpm: bpm, timeSignature: timeSignature, soundTheme: selectedSoundTheme.rawValue) { beatIndex, isStrongBeat in
            // 【修复】直接从音频线程接收准确的节拍信息
            // 这样 UI 和音频完全同步
            DispatchQueue.main.async {
                self.handleBeat(beatIndex: beatIndex, isStrongBeat: isStrongBeat)
            }
        }
        // 立即播放第一拍（手动触发 UI，因为音频回调还没开始）
        handleBeat(beatIndex: 0, isStrongBeat: timeSignature > 1)
    }
    
    func stopMetronome() {
        precisionTimer.stop()
        currentBeat = -1
        isVisualPulse = false
        
        // 更新全局状态
        MetronomeStateManager.shared.stop()
    }
    
    func handleTapTempo() {
        let now = Date()
        if let last = lastTapTime {
            let interval = now.timeIntervalSince(last)
            if interval < AudioConstants.tapTempoMaxInterval {
                let newBpm = 60.0 / interval
                if newBpm >= AudioConstants.minBPM && newBpm <= AudioConstants.maxBPM {
                    bpm = (bpm + newBpm) / 2
                }
            }
        }
        lastTapTime = now
        if hapticEnabled {
            impactHeavy.impactOccurred()
        }
    }
    
    
    /// 处理节拍（由音频线程精确触发）
    func handleBeat(beatIndex: Int, isStrongBeat: Bool) {
        // 直接使用音频线程传来的 beatIndex，确保同步
        currentBeat = beatIndex
        
        // 更新全局状态（让其他页面也能看到）
        MetronomeStateManager.shared.updateBeat(index: beatIndex, timeSignature: timeSignature)
        
        // 震动反馈
        if hapticEnabled {
            let generator = UIImpactFeedbackGenerator(style: isStrongBeat ? .heavy : .light)
            generator.impactOccurred()
        }
        
        // UI 动画
        isVisualPulse = true
        DispatchQueue.main.asyncAfter(deadline: .now() + AudioConstants.visualPulseDuration) {
            if self.isPlaying {
                self.isVisualPulse = false
            }
        }
    }
}

// MARK: - 3. 设置页面
struct MetronomeSettingsSheet: View {
    @Binding var timeSignature: Int
    @Binding var selectedSoundTheme: SoundTheme
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("拍号 (Time Signature)")) {
                    Picker("每小节拍数", selection: $timeSignature) {
                        Text("1/1 (无重音)").tag(1)
                        Text("2/4").tag(2)
                        Text("3/4").tag(3)
                        Text("4/4").tag(4)
                        Text("6/8").tag(6)
                    }
                    .pickerStyle(NavigationLinkPickerStyle())
                }
                Section(header: Text("声音风格 (Sound)")) {
                    Picker("音效", selection: $selectedSoundTheme) {
                        ForEach(SoundTheme.allCases) { theme in
                            Text(theme.name).tag(theme)
                        }
                    }
                    .pickerStyle(NavigationLinkPickerStyle())
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("完成") { dismiss() }
            }
        }
    }
}

#Preview {
    MetronomeView()
}
