import AVFoundation

final class AudioSessionManager {
    static let shared = AudioSessionManager()
    
    private let lock = NSLock()
    private var isConfigured = false
    private var lastCategory: AVAudioSession.Category?
    private var lastMode: AVAudioSession.Mode?
    private var lastOptions: AVAudioSession.CategoryOptions?
    
    private init() {}
    
    func configureForPlayAndRecord() {
        configure(
            category: .playAndRecord,
            mode: .default,
            options: [.defaultToSpeaker, .mixWithOthers, .allowBluetooth, .allowBluetoothA2DP]
        )
    }
    
    private func configure(
        category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions
    ) {
        lock.lock()
        defer { lock.unlock() }
        
        guard needsConfiguration(category: category, mode: mode, options: options) else { return }
        
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(category, mode: mode, options: options)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            
            lastCategory = category
            lastMode = mode
            lastOptions = options
            isConfigured = true
        } catch {
            print("⚠️ AudioSessionManager configure failed: \(error.localizedDescription)")
        }
    }
    
    private func needsConfiguration(
        category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions
    ) -> Bool {
        if !isConfigured {
            return true
        }
        
        return lastCategory != category || lastMode != mode || lastOptions != options
    }
}
