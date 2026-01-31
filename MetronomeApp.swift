//
//  MetronomeApp.swift
//  Metronome
//
//  Created by Ding Zhou on 1/28/26.
//

import SwiftUI
import Combine

@main
struct MetronomeApp: App {
    // 【新增】监控场景生命周期
    @Environment(\.scenePhase) var scenePhase
    @StateObject private var appState = AppState()
    
    init() {
        // ✅ App 启动时立即初始化音频会话
        _ = AudioSessionManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    handleScenePhaseChange(newPhase)
                }
        }
    }
    
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .background:
            // 进入后台时的处理
            print("📱 App 进入后台")
        case .inactive:
            // 非活动状态（例如控制中心、通知中心）
            print("📱 App 非活动")
        case .active:
            // 前台活动
            print("📱 App 前台活动")
        @unknown default:
            break
        }
    }
}
// 【新增】全局状态管理
class AppState: ObservableObject {
    @Published var isInBackground = false
}

