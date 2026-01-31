import SwiftUI

struct SettingsView: View {
    // 使用 @AppStorage 替代 @State，让设置持久化且全局共享
    @AppStorage(UserDefaultsKeys.soundEnabled) private var soundEnabled = true
    @AppStorage(UserDefaultsKeys.hapticEnabled) private var hapticEnabled = true
    @AppStorage(UserDefaultsKeys.keepScreenAwake) private var keepScreenAwake = false
    @AppStorage(UserDefaultsKeys.autoStopListening) private var autoStopListening = true
    
    // 标准频率管理
    @State private var standardFrequency: Double = 440.0
    @State private var savedFrequencies: [Double] = []
    @State private var showManageSheet = false
    
    let defaultFrequencies = [440.0, 442.0]
    
    // [1] 引入环境变量，用于判断深色模式
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景：最深的灰色
                Color(UIColor.systemGray6)
                    .edgesIgnoringSafeArea(.all)
                
                List {
                    // --- 通用设置 ---
                    Section(header: Text("通用")) {
                        Toggle("声音输出", isOn: $soundEnabled)
                        Toggle("震动反馈", isOn: $hapticEnabled)
                        Toggle("保持屏幕常亮", isOn: $keepScreenAwake)
                    }
                    .listRowBackground(rowBackgroundColor)
                    
                    // --- 校音器设置 ---
                    Section(header: Text("校音器")) {
                        Toggle("切换页面时自动停止监听", isOn: $autoStopListening)
                        
                        // 标准频率设置
                        Button {
                            showManageSheet = true
                        } label: {
                            HStack {
                                Text("标准频率")
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("\(Int(standardFrequency)) Hz")
                                    .foregroundColor(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .listRowBackground(rowBackgroundColor)
                    
                    // --- 关于 ---
                    Section(header: Text("关于")) {
                        HStack {
                            Text("版本")
                            Spacer()
                            Text("v1.0")
                                .foregroundColor(.gray)
                        }
                        Text("开发者：diumiks")
                    }
                    .listRowBackground(rowBackgroundColor)
                }
                // 隐藏列表默认的背景，让底部的 systemGray6 透出来
                .scrollContentBackground(.hidden)
                // 列表样式保持为卡片式
                .listStyle(.insetGrouped)
            }
            .navigationTitle("设置")
            .onAppear {
                loadSettings()
            }
            .sheet(isPresented: $showManageSheet) {
                FrequencyManageSheet(
                    savedFrequencies: $savedFrequencies,
                    currentFreq: $standardFrequency,
                    defaultFrequencies: defaultFrequencies,
                    onSave: {
                        // 保存到 UserDefaults
                        UserDefaults.standard.set(standardFrequency, forKey: UserDefaultsKeys.lastStandardFrequency)
                    }
                )
            }
        }
    }
    
    // MARK: - 数据加载
    
    func loadSettings() {
        // 加载标准频率
        let savedFreq = UserDefaults.standard.double(forKey: UserDefaultsKeys.lastStandardFrequency)
        if savedFreq > 0 {
            standardFrequency = savedFreq
        }
        
        // 加载自定义频率列表
        if let saved = UserDefaults.standard.array(forKey: UserDefaultsKeys.userFrequencies) as? [Double] {
            savedFrequencies = saved
        }
    }
    
    // [2] 提取颜色逻辑：与校音器卡片保持一致
    var rowBackgroundColor: Color {
        if colorScheme == .dark {
            // 深色模式：使用 Gray5 (比背景 Gray6 亮一点，形成层次)
            return Color(UIColor.systemGray5)
        } else {
            // 浅色模式：纯白
            return Color.white
        }
    }
}

#Preview {
    SettingsView()
}
