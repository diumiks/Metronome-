import SwiftUI

struct ContentView: View {
    @AppStorage(UserDefaultsKeys.keepScreenAwake) private var keepScreenAwake = false
    
    var body: some View {
        TabView {
            // 第一页：节拍器
            MetronomeView()
                .tabItem {
                    Label("节拍器", systemImage: "metronome.fill")
                }
            
            // 第二页：校音器（纯监听）
            SimplifiedTunerView()
                .tabItem {
                    Label("校音器", systemImage: "waveform")
                }
            
            // 第三页：标准音生成器
            ToneGeneratorView()
                .tabItem {
                    Label("标准音", systemImage: "tuningfork")
                }
            
            // 第四页：设置
            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gear")
                }
        }
        // 设置选中时的颜色为蓝色
        .accentColor(.blue)
        .onAppear {
            updateScreenAwake()
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
