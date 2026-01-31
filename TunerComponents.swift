import SwiftUI

// 极简刻度盘组件
struct MinimalGaugeView: View {
    var body: some View {
        ZStack {
            ForEach(0..<UIConstants.gaugeTickCount, id: \.self) { i in
                let angle = -90.0 + Double(i) * (180.0 / Double(UIConstants.gaugeTickCount - 1))
                let centerIndex = UIConstants.gaugeTickCount / 2
                let isCenter = i == centerIndex
                let isMajor = i % UIConstants.gaugeMajorTickInterval == 0
                
                let tickColor: Color = isCenter ? .primary : (isMajor ? .gray.opacity(0.8) : .gray.opacity(0.3))
                
                Rectangle()
                    .fill(tickColor)
                    .frame(width: isCenter ? 3 : (isMajor ? 2 : 1),
                           height: isCenter ? 25 : (isMajor ? 15 : 10))
                    .offset(y: -UIConstants.gaugeRadius)
                    .rotationEffect(.degrees(angle))
            }
        }
    }
}

// 音符气泡组件
struct NoteBubble: View {
    let note: String
    let isSelected: Bool
    let action: () -> Void
    
    // [新增] 引入环境变量，感知深色/浅色模式
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button {
            action()
        } label: {
            ZStack {
                Circle()
                    // [修改] 填充色逻辑优化
                    .fill(bubbleColor)
                    // 阴影修复：只给圆圈加阴影，不影响外部 Frame
                    .shadow(color: isSelected ? .blue.opacity(0.4) : .clear, radius: 4, x: 0, y: 2)
                
                Text(note)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(width: UIConstants.bubbleSize, height: UIConstants.bubbleSize)
            .scaleEffect(isSelected ? UIConstants.bubbleScaleSelected : 1.0) // 稍微放大选中效果
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        }
        .buttonStyle(.plain)
    }
    
    // [新增] 专门的颜色计算逻辑
    var bubbleColor: Color {
        if isSelected {
            return Color.blue
        } else {
            if colorScheme == .dark {
                // 深色模式下：
                // 卡片背景是 Gray5 (较深)，所以按钮用 Gray3 (较亮)，形成层次感
                return Color(UIColor.systemGray3)
            } else {
                // 浅色模式下：
                // 卡片背景是白色，按钮用浅灰色
                return Color(UIColor.secondarySystemBackground)
            }
        }
    }
}
