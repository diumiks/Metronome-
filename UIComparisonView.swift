import SwiftUI

/// UI 对比预览文件
/// 用于展示新旧设计的差异

struct UIComparisonView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 旧版本：混合式校音器
            OldDesignPreview()
                .tabItem {
                    Label("旧版设计", systemImage: "1.circle")
                }
                .tag(0)
            
            // 新版本：分离式校音器
            NewDesignPreview()
                .tabItem {
                    Label("新版设计", systemImage: "2.circle")
                }
                .tag(1)
        }
    }
}

// MARK: - 旧版设计预览

struct OldDesignPreview: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("📱 旧版设计")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    FeatureCard(
                        title: "混合式校音器",
                        description: "在同一个页面中包含：\n• 麦克风监听\n• 标准音播放\n• 音符选择器\n• 八度调节",
                        icon: "tuningfork",
                        color: .orange
                    )
                    
                    Divider()
                        .padding(.vertical)
                    
                    Text("⚠️ 存在的问题")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    IssueCard(
                        title: "音频会话冲突",
                        description: "麦克风输入和扬声器输出频繁切换，导致延迟和杂音"
                    )
                    
                    IssueCard(
                        title: "复杂的状态管理",
                        description: "需要大量的锁、队列、防抖处理来避免竞态条件"
                    )
                    
                    IssueCard(
                        title: "难以调试",
                        description: "音频问题很难追踪，因为两个功能互相干扰"
                    )
                }
                .padding()
            }
            .background(Color(UIColor.systemGray6))
            .navigationTitle("旧版设计")
        }
    }
}

// MARK: - 新版设计预览

struct NewDesignPreview: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("✨ 新版设计")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    FeatureCard(
                        title: "校音器（纯监听）",
                        description: "专注于音高检测：\n• 大号仪表盘\n• 实时频率显示\n• 音准状态提示\n• 无播放功能干扰",
                        icon: "waveform",
                        color: .blue
                    )
                    
                    FeatureCard(
                        title: "标准音生成器",
                        description: "专注于音频播放：\n• 音符选择器\n• 八度调节\n• 频率显示\n• 无麦克风监听干扰",
                        icon: "tuningfork",
                        color: .green
                    )
                    
                    Divider()
                        .padding(.vertical)
                    
                    Text("✅ 优势")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    BenefitCard(
                        title: "音频架构清晰",
                        description: "每个页面独立管理音频会话，互不干扰"
                    )
                    
                    BenefitCard(
                        title: "代码更简洁",
                        description: "移除了复杂的切换逻辑，易于维护"
                    )
                    
                    BenefitCard(
                        title: "用户体验更好",
                        description: "快速切换，响应迅速，没有延迟"
                    )
                    
                    BenefitCard(
                        title: "易于扩展",
                        description: "未来可以为每个功能添加独立的高级功能"
                    )
                }
                .padding()
            }
            .background(Color(UIColor.systemGray6))
            .navigationTitle("新版设计")
        }
    }
}

// MARK: - 辅助组件

struct FeatureCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundColor(color)
                .frame(width: 60, height: 60)
                .background(color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            colorScheme == .dark ? Color(UIColor.systemGray5) : Color.white
        )
        .cornerRadius(16)
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05),
            radius: 8, x: 0, y: 2
        )
    }
}

struct IssueCard: View {
    let title: String
    let description: String
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            colorScheme == .dark ? Color(UIColor.systemGray5) : Color.white
        )
        .cornerRadius(12)
    }
}

struct BenefitCard: View {
    let title: String
    let description: String
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            colorScheme == .dark ? Color(UIColor.systemGray5) : Color.white
        )
        .cornerRadius(12)
    }
}

#Preview {
    UIComparisonView()
}
