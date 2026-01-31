import SwiftUI

struct TunerView: View {
    @StateObject private var tuner = TunerEngine()
    
    // 听音相关
    @State private var selectedNoteIndex = 9 // 默认 A
    @State private var selectedOctave = 4    // 默认 4
    
    // 频率管理
    @State private var savedFrequencies: [Double] = []
    @State private var showManageSheet = false
    
    // 读取用户设置
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false
    @State private var startListeningTask: Task<Void, Never>?
    
    let defaultFrequencies = [440.0, 442.0]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景色：保持与其他页面一致的高级灰
                Color(UIColor.systemGray6)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    // 仪表盘
                    TunerGaugeDisplay(
                        tuner: tuner,
                        isListening: !tuner.isPlaying,
                        selectedNoteIndex: selectedNoteIndex,
                        selectedOctave: selectedOctave
                    )
                    
                    Spacer()
                    
                    // 底部控制区
                    TunerControlsArea(
                        tuner: tuner,
                        selectedNoteIndex: $selectedNoteIndex,
                        selectedOctave: $selectedOctave
                    )
                    
                    Spacer()
                }
                .padding(.bottom, 20)
                
                // 错误提示（如果有）
                if let error = tuner.errorMessage {
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
            .navigationTitle("校音器")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    FrequencyMenuButton(
                        currentFreq: $tuner.standardFrequency,
                        defaultFrequencies: defaultFrequencies,
                        savedFrequencies: savedFrequencies,
                        showManageSheet: $showManageSheet
                    )
                }
            }
            .onAppear {
                isVisible = true
                scheduleStartListening()
                loadSavedFrequencies()
                NotificationCenter.default.post(name: .stopMetronome, object: nil)
            }
            .onDisappear {
                isVisible = false
                cancelStartListening()
                tuner.stopPlaying()
                tuner.stopListening()
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .background, .inactive:
                    cancelStartListening()
                    tuner.stopListening()
                case .active:
                    if isVisible {
                        scheduleStartListening()
                    }
                default:
                    break
                }
            }
            .sheet(isPresented: $showManageSheet) {
                FrequencyManageSheet(
                    savedFrequencies: $savedFrequencies,
                    currentFreq: $tuner.standardFrequency,
                    defaultFrequencies: defaultFrequencies
                )
            }
        }
    }

    private func scheduleStartListening() {
        cancelStartListening()
        startListeningTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard isVisible else { return }
            tuner.startListening()
        }
    }

    private func cancelStartListening() {
        startListeningTask?.cancel()
        startListeningTask = nil
    }
    
    func loadSavedFrequencies() {
        if let saved = UserDefaults.standard.array(forKey: UserDefaultsKeys.userFrequencies) as? [Double] {
            savedFrequencies = saved
        }
    }
}

// MARK: - 辅助组件：频率菜单按钮
struct FrequencyMenuButton: View {
    @Binding var currentFreq: Double
    let defaultFrequencies: [Double]
    let savedFrequencies: [Double]
    @Binding var showManageSheet: Bool
    
    var body: some View {
        Menu {
            Section("系统预设") {
                ForEach(defaultFrequencies, id: \.self) { freq in
                    Button {
                        currentFreq = freq
                    } label: {
                        if currentFreq == freq {
                            Label("\(Int(freq)) Hz", systemImage: "checkmark")
                        } else {
                            Text("\(Int(freq)) Hz")
                        }
                    }
                }
            }
            
            if !savedFrequencies.isEmpty {
                Section("我的预设") {
                    ForEach(savedFrequencies, id: \.self) { freq in
                        Button {
                            currentFreq = freq
                        } label: {
                            if currentFreq == freq {
                                Label("\(Int(freq)) Hz", systemImage: "checkmark")
                            } else {
                                Text("\(Int(freq)) Hz")
                            }
                        }
                    }
                }
            }
            
            Divider()
            
            Button {
                showManageSheet = true
            } label: {
                Label("管理频率...", systemImage: "gear")
            }
            
        } label: {
            // 简洁的导航栏样式：只显示频率值，更符合 iOS 原生风格
            Text("\(Int(currentFreq)) Hz")
                .font(.body)
                .foregroundColor(.blue)
        }
    }
}

// MARK: - 辅助组件：频率管理页面
struct FrequencyManageSheet: View {
    @Binding var savedFrequencies: [Double]
    @Binding var currentFreq: Double
    let defaultFrequencies: [Double]
    var onSave: (() -> Void)? = nil  // 可选的保存回调
    
    @Environment(\.dismiss) var dismiss
    
    @State private var newFreqInput = ""
    
    var body: some View {
        NavigationStack {
            List {
                Section("添加新频率") {
                    HStack {
                        TextField("输入频率 (例如 432)", text: $newFreqInput)
                            .keyboardType(.numberPad)
                        Button("添加") {
                            addFrequency()
                        }
                        .disabled(newFreqInput.isEmpty)
                    }
                }
                
                if !savedFrequencies.isEmpty {
                    Section("我的预设") {
                        ForEach(savedFrequencies, id: \.self) { freq in
                            HStack {
                                Text("\(Int(freq)) Hz")
                                Spacer()
                                if currentFreq == freq {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                currentFreq = freq
                            }
                        }
                        .onDelete(perform: deleteFrequency)
                    }
                }
                
                Section("系统预设") {
                    ForEach(defaultFrequencies, id: \.self) { freq in
                        HStack {
                            Text("\(Int(freq)) Hz")
                            Spacer()
                            if currentFreq == freq {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            currentFreq = freq
                        }
                    }
                }
            }
            .navigationTitle("频率管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        onSave?()  // 触发保存回调
                        dismiss()
                    }
                }
            }
        }
    }
    
    func addFrequency() {
        guard let val = Double(newFreqInput), val > 0 else { return }
        
        if !savedFrequencies.contains(val) && !defaultFrequencies.contains(val) {
            withAnimation {
                savedFrequencies.append(val)
                savedFrequencies.sort()
            }
            currentFreq = val
            save()
            newFreqInput = ""
        }
    }
    
    func deleteFrequency(at offsets: IndexSet) {
        let itemsToDelete = offsets.map { savedFrequencies[$0] }
        if itemsToDelete.contains(currentFreq) {
            currentFreq = 440.0
        }
        savedFrequencies.remove(atOffsets: offsets)
        save()
    }
    
    func save() {
        UserDefaults.standard.set(savedFrequencies, forKey: UserDefaultsKeys.userFrequencies)
        UserDefaults.standard.set(currentFreq, forKey: UserDefaultsKeys.lastStandardFrequency)
        onSave?()  // 也在这里触发回调
    }
}
