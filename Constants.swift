import Foundation
import CoreGraphics
import AVFoundation

// MARK: - 音频常量
struct AudioConstants {
    static let defaultBPM: Double = 120
    static let minBPM: Double = 40
    static let maxBPM: Double = 300
    
    static let tapTempoMaxInterval: TimeInterval = 2.0
    static let visualPulseDuration: TimeInterval = 0.1
    
    // 校音器相关
    static let standardA4Frequency: Double = 440.0
    static let minFrequency: Double = 80.0
    static let maxFrequency: Double = 1200.0
    
    // 音频处理参数
    static let sampleRate: Double = 44100.0
    static let bufferSize: AVAudioFrameCount = 2048  // 改为 AVAudioFrameCount 类型
    static let rmsThreshold: Double = 0.01  // 改为 Double 以避免类型转换问题
}

// MARK: - UI 常量
struct UIConstants {
    static let cornerRadius: CGFloat = 12
    static let padding: CGFloat = 16
    static let buttonSize: CGFloat = 60
    static let animationDuration: Double = 0.3
    
    // 校音器相关
    static let closeThreshold: Double = 3.0      // 音准偏差 ±3 cents 内视为准确
    static let accurateThreshold: Double = 10.0  // 音准偏差 ±10 cents 内视为接近
    static let needleMaxRotation: Double = 50.0  // 指针最大旋转角度
    static let gaugeTickCount: Int = 41          // 校音器刻度数量
    static let gaugeMajorTickInterval: Int = 5   // 主刻度间隔
    static let gaugeRadius: CGFloat = 120        // 刻度盘半径
    static let bubbleSize: CGFloat = 50          // 音符气泡大小
    static let bubbleScaleSelected: CGFloat = 1.1 // 选中时的缩放比例
}

// MARK: - UserDefaults 键
struct UserDefaultsKeys {
    // 节拍器相关
    static let lastBPM = "lastBPM"
    static let lastTimeSignature = "lastTimeSignature"
    static let lastSoundTheme = "lastSoundTheme"
    static let soundEnabled = "soundEnabled"
    static let hapticEnabled = "hapticEnabled"
    
    // 校音器相关
    static let lastStandardFrequency = "lastStandardFrequency"
    static let autoStopListening = "autoStopListening"
    static let userFrequencies = "userFrequencies"  // 用户自定义频率列表
    
    // 通用设置
    static let keepScreenAwake = "keepScreenAwake"
}
// MARK: - 音频错误
enum AudioError: Error {
    case inputUnavailable
    case configurationFailed
    case recordPermissionDenied
    case startFailed
    case processingFailed
    case sessionSetupFailed
    case deviceNotAvailable
    case engineStartFailed
    
    var localizedDescription: String {
        switch self {
        case .inputUnavailable:
            return "音频输入不可用"
        case .configurationFailed:
            return "音频配置失败"
        case .recordPermissionDenied:
            return "未获得录音权限"
        case .startFailed:
            return "启动音频引擎失败"
        case .processingFailed:
            return "音频处理失败"
        case .sessionSetupFailed:
            return "音频会话设置失败"
        case .deviceNotAvailable:
            return "音频设备不可用"
        case .engineStartFailed:
            return "音频引擎启动失败"
        }
    }
}

extension Notification.Name {
    static let stopToneGenerator = Notification.Name("stopToneGenerator")
}
