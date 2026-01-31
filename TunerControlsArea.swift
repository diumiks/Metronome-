import SwiftUI

struct TunerControlsArea: View {
    @ObservedObject var tuner: TunerEngine
    @Binding var selectedNoteIndex: Int
    @Binding var selectedOctave: Int
    
    // [新增 1] 引入环境遍历，用于检测当前是深色还是浅色模式
    @Environment(\.colorScheme) var colorScheme
    
    // 防抖动：避免频繁切换导致崩溃
    @State private var debounceTask: DispatchWorkItem?
    
    var body: some View {
        VStack(spacing: 25) {
            // 生成音控制卡片
            VStack(spacing: 25) {
                HStack {
                    Label("标准音生成", systemImage: "tuningfork")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                }
                
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(0..<tuner.noteNames.count, id: \.self) { index in
                                NoteBubble(
                                    note: tuner.noteNames[index],
                                    isSelected: selectedNoteIndex == index,
                                    action: {
                                        selectedNoteIndex = index
                                        if tuner.isPlaying { restartTone() }
                                    }
                                )
                                .id(index)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 15)
                    }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation { proxy.scrollTo(9, anchor: .center) }
                        }
                    }
                }
                .padding(.horizontal, -20)
                
                HStack(alignment: .center) {
                    // 八度调节
                    HStack(spacing: 0) {
                        Button {
                            if selectedOctave > 1 { selectedOctave -= 1 }
                            if tuner.isPlaying { restartTone() }
                        } label: {
                            Image(systemName: "minus")
                                .frame(width: 44, height: 48)
                                .contentShape(Rectangle())
                        }
                        
                        Text("八度 \(selectedOctave)")
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.semibold)
                            .frame(width: 80, height: 48)
                            // [微调] 内部小按钮背景：深色模式下用更深一点的颜色，增加对比
                            .background(Color(UIColor.tertiarySystemFill))
                        
                        Button {
                            if selectedOctave < 7 { selectedOctave += 1 }
                            if tuner.isPlaying { restartTone() }
                        } label: {
                            Image(systemName: "plus")
                                .frame(width: 44, height: 48)
                                .contentShape(Rectangle())
                        }
                    }
                    // [微调] 胶囊背景
                    .background(Color(UIColor.tertiarySystemFill))
                    .cornerRadius(14)
                    .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // 播放按钮
                    Button(action: togglePlaying) {
                        Image(systemName: tuner.isPlaying ? "stop.fill" : "play.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 52, height: 52)
                            .background(tuner.isPlaying ? Color.red : Color.blue)
                            .clipShape(Circle())
                            .shadow(color: (tuner.isPlaying ? Color.red : Color.blue).opacity(0.3), radius: 6, x: 0, y: 3)
                    }
                }
            }
            .padding(20)
            
            // [修改 2] 核心背景逻辑
            .background(
                // 如果是深色模式 ? 使用稍亮的灰色(Gray5) : 否则使用纯白
                colorScheme == .dark ? Color(UIColor.systemGray5) : Color.white
            )
            .cornerRadius(24)
            // [修改 3] 阴影优化：在深色模式下稍微加重一点点阴影（或者加一个极细的边框）
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05),
                radius: 10, x: 0, y: 4
            )
            // [可选] 如果你觉得只有颜色对比还不够，可以加一个极细的边框，仅在深色模式显示
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.1 : 0), lineWidth: 1)
            )
        }
        .padding(.horizontal, 20)
    }
    
    func togglePlaying() {
        if tuner.isPlaying {
            tuner.stopPlaying()
            tuner.startListening()
        } else {
            tuner.playTone(frequency: currentPlayingFrequency)
        }
    }
    
    func restartTone() {
        // 取消之前的任务
        debounceTask?.cancel()
        
        // 【优化】调整防抖时间到 50ms，提升响应速度
        // 100ms 对用户来说感觉有点迟钝
        let task = DispatchWorkItem { [weak tuner] in
            guard let tuner = tuner else { return }
            if tuner.isPlaying {
                tuner.playTone(frequency: currentPlayingFrequency)
            }
        }
        
        debounceTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: task)
    }
    
    var currentPlayingFrequency: Double {
        let midiValue = (selectedOctave + 1) * 12 + selectedNoteIndex
        let noteDiff = Double(midiValue - 69)
        return tuner.standardFrequency * pow(2.0, noteDiff / 12.0)
    }
}
