import SwiftUI

struct ContentView: View {
    @AppStorage(UserDefaultsKeys.keepScreenAwake) private var keepScreenAwake = false
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 第一页：节拍器
            MetronomeView()
                .tabItem {
                    Label("节拍器", systemImage: "metronome.fill")
                }
                .tag(0)
            
            // 第二页：校音器（纯监听）
            SimplifiedTunerView()
                .tabItem {
                    Label("校音器", systemImage: "waveform")
                }
                .tag(1)
            
            // 第三页：标准音生成器
            ToneGeneratorView()
                .tabItem {
                    Label("标准音", systemImage: "tuningfork")
                }
                .tag(2)
            
            // 第四页：设置
            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gear")
                }
                .tag(3)
        }
        // 设置选中时的颜色为蓝色
        .accentColor(.blue)
        .onAppear {
            updateScreenAwake()
        }
        .onChange(of: selectedTab) { _, newValue in
            if newValue != 2 {
                NotificationCenter.default.post(name: .stopToneGenerator, object: nil)
            }
        }
        .onChange(of: keepScreenAwake) { oldValue, newValue in
            updateScreenAwake()
        }
    }
    
    func updateScreenAwake() {
        UIApplication.shared.isIdleTimerDisabled = keepScreenAwake
    }
}

#Preview {
    ContentView()
}
