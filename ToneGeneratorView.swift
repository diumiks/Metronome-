import SwiftUI

struct ToneGeneratorView: View {
    @StateObject private var engine = ToneGeneratorEngine()
    
    @State private var selectedNoteIndex = 9 // 默认 A
    @State private var selectedOctave = 4    // 默认 4
    
    let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) var scenePhase  // 监听场景状态
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景色：保持与其他页面一致的高级灰
                Color(UIColor.systemGray6)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    // 中央显示区：当前音符 + 频率（简洁版）
                    VStack(spacing: 16) {
                        // 当前音符显示（包含八度）
                        Text(currentNoteName)
                            .font(.system(size: 100, weight: .bold, design: .rounded))
                            .foregroundColor(engine.isPlaying ? .blue : .primary)
                            .contentTransition(.identity)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentNoteName)
                        
                        // 频率显示
                        Text(String(format: "%.1f Hz", currentPlayingFrequency))
                            .font(.system(size: 28, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                            .contentTransition(.numericText(value: currentPlayingFrequency))
                    }
                    
                    // 节拍指示器（在音符和卡片之间）
                    VStack {
                        MetronomeBeatIndicator()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    
                    Spacer()
                    
                    // 底部控制卡片
                    VStack(spacing: 30) {
                        // 1. 音符选择器
                        VStack(spacing: 16) {
                            HStack {
                                Label("音符", systemImage: "music.note")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            
                            ScrollViewReader { proxy in
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(0..<noteNames.count, id: \.self) { index in
                                            NoteBubble(
                                                note: noteNames[index],
                                                isSelected: selectedNoteIndex == index,
                                                action: {
                                                    withAnimation {
                                                        selectedNoteIndex = index
                                                    }
                                                }
                                            )
                                            .id(index)
                                        }
                                    }
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 8)
                                }
                                .onAppear {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        withAnimation { proxy.scrollTo(9, anchor: .center) }
                                    }
                                }
                            }
                        }
                        
                        // 2. 八度调节
                        VStack(spacing: 12) {
                            HStack {
                                Label("八度", systemImage: "waveform")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            
                            HStack(spacing: 0) {
                                Button {
                                    if selectedOctave > 1 { 
                                        withAnimation { selectedOctave -= 1 }
                                    }
                                } label: {
                                    Image(systemName: "minus")
                                        .frame(width: 50, height: 50)
                                        .contentShape(Rectangle())
                                }
                                .disabled(selectedOctave <= 1)
                                
                                Spacer()
                                
                                Text("\(selectedOctave)")
                                    .font(.system(.title, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                                    .frame(minWidth: 60)
                                    .contentTransition(.numericText(value: Double(selectedOctave)))
                                
                                Spacer()
                                
                                Button {
                                    if selectedOctave < 7 { 
                                        withAnimation { selectedOctave += 1 }
                                    }
                                } label: {
                                    Image(systemName: "plus")
                                        .frame(width: 50, height: 50)
                                        .contentShape(Rectangle())
                                }
                                .disabled(selectedOctave >= 7)
                            }
                            .foregroundColor(.primary)
                            .background(Color(UIColor.tertiarySystemFill))
                            .cornerRadius(14)
                        }
                        
                        // 3. 播放/停止按钮（移到最底部）
                        Button(action: togglePlaying) {
                            HStack(spacing: 12) {
                                Image(systemName: engine.isPlaying ? "stop.fill" : "play.fill")
                                    .font(.title2)
                                Text(engine.isPlaying ? "停止播放" : "播放标准音")
                                    .font(.headline)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(engine.isPlaying ? Color.red : Color.blue)
                            .cornerRadius(16)
                            .shadow(color: (engine.isPlaying ? Color.red : Color.blue).opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                    }
                    .padding(24)
                    .background(
                        colorScheme == .dark ? Color(UIColor.systemGray5) : Color.white
                    )
                    .cornerRadius(28)
                    .shadow(
                        color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05),
                        radius: 12, x: 0, y: 4
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(Color.white.opacity(colorScheme == .dark ? 0.1 : 0), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
                
                // 错误提示（如果有）
                if let error = engine.errorMessage {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.white)
                            Text(error)
                                .foregroundColor(.white)
                                .font(.footnote)
                        }
                        .padding()
                        .background(Color.red.opacity(0.9))
                        .cornerRadius(12)
                        .shadow(radius: 8)
                        .padding(.horizontal)
                        .padding(.bottom, 50)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .navigationTitle("标准音")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadSettings()
            }
            .onDisappear {
                // 离开页面时停止播放
                engine.stopPlaying()
            }
            .onReceive(NotificationCenter.default.publisher(for: .stopToneGenerator)) { _ in
                engine.stopPlaying()
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                // 监听 App 进入后台/前台
                switch newPhase {
                case .active:
                    // App 回到前台，不做任何操作
                    break
                case .background:
                    // App 进入后台，继续播放（不停止）
                    break
                case .inactive:
                    // App 失去焦点（过渡状态），不做操作
                    break
                @unknown default:
                    break
                }
            }
            .onChange(of: selectedNoteIndex) { oldValue, newValue in
                // 如果正在播放，实时切换到新频率
                if engine.isPlaying {
                    engine.playTone(frequency: currentPlayingFrequency)
                }
            }
            .onChange(of: selectedOctave) { oldValue, newValue in
                // 如果正在播放，实时切换到新频率
                if engine.isPlaying {
                    engine.playTone(frequency: currentPlayingFrequency)
                }
            }
        }
    }
    
    // MARK: - 计算属性
    
    var currentNoteName: String {
        let note = noteNames[selectedNoteIndex]
        return "\(note)\(selectedOctave)"
    }
    
    var currentPlayingFrequency: Double {
        // 从 UserDefaults 读取标准频率
        let baseFreq = UserDefaults.standard.double(forKey: UserDefaultsKeys.lastStandardFrequency)
        let standardFreq = baseFreq > 0 ? baseFreq : 440.0
        
        let midiValue = (selectedOctave + 1) * 12 + selectedNoteIndex
        let noteDiff = Double(midiValue - 69)
        return standardFreq * pow(2.0, noteDiff / 12.0)
    }
    
    // MARK: - 交互逻辑
    
    func togglePlaying() {
        if engine.isPlaying {
            engine.stopPlaying()
        } else {
            engine.playTone(frequency: currentPlayingFrequency)
        }
    }
    
    // MARK: - 数据持久化
    
    func loadSettings() {
        // 可选：加载上次的音符和八度
        let savedNote = UserDefaults.standard.integer(forKey: "lastSelectedNote")
        let savedOctave = UserDefaults.standard.integer(forKey: "lastSelectedOctave")
        
        if savedNote >= 0 && savedNote < noteNames.count {
            selectedNoteIndex = savedNote
        }
        if savedOctave > 0 && savedOctave <= 7 {
            selectedOctave = savedOctave
        }
    }
}

#Preview {
    ToneGeneratorView()
}
