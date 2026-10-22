import AVFoundation
import Foundation
import Speech

/// One audio session for the whole app: plays the Spanish voice and records for speaking practice
/// without switching modes in between.
enum Audio {
    static func configure() {
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP, .duckOthers])
        try? s.setActive(true)
    }
}

/// Reads Spanish aloud with the best installed Latin American voice.
@MainActor
final class Speaker: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = Speaker()

    @Published private(set) var speaking = false
    private let synth = AVSpeechSynthesizer()
    private var voice: AVSpeechSynthesisVoice?

    /// Normal speed, 0.3…0.55 (Apple's default is 0.5). Set in the profile.
    var rate: Float {
        get { UserDefaults.standard.object(forKey: "speechRate") as? Float ?? 0.45 }
        set { UserDefaults.standard.set(newValue, forKey: "speechRate") }
    }

    override init() {
        super.init()
        synth.delegate = self
        voice = Self.bestVoice()
    }

    /// Prefers an enhanced/premium Mexican or US-Spanish voice, then any Latin American one.
    static func bestVoice() -> AVSpeechSynthesisVoice? {
        let all = AVSpeechSynthesisVoice.speechVoices()
        for lang in ["es-MX", "es-US", "es-419", "es-CO", "es-AR", "es-ES"] {
            let matches = all.filter { $0.language == lang }
            if let best = matches.max(by: { $0.quality.rawValue < $1.quality.rawValue }) { return best }
        }
        return AVSpeechSynthesisVoice(language: "es-MX")
    }

    var voiceName: String { voice.map { "\($0.name) (\($0.language))" } ?? "Default" }
    var hasEnhancedVoice: Bool { (voice?.quality.rawValue ?? 0) > AVSpeechSynthesisVoiceQuality.default.rawValue }

    func say(_ text: String, slow: Bool = false) {
        synth.stopSpeaking(at: .immediate)
        let u = AVSpeechUtterance(string: text)
        u.voice = voice
        u.rate = slow ? max(0.25, rate - 0.17) : rate
        u.preUtteranceDelay = 0.05
        synth.speak(u)
    }

    func stop() { synth.stopSpeaking(at: .immediate) }

    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didStart u: AVSpeechUtterance) {
        Task { @MainActor in self.speaking = true }
    }

    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) {
        Task { @MainActor in self.speaking = false }
    }

    nonisolated func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel u: AVSpeechUtterance) {
        Task { @MainActor in self.speaking = false }
    }
}

/// Spanish speech recognition, on the device when the iPhone supports it.
@MainActor
final class Listener: ObservableObject {
    @Published private(set) var transcript = ""
    @Published private(set) var listening = false
    @Published private(set) var denied = false

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "es-MX"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    var available: Bool { recognizer?.isAvailable == true && !denied }

    /// Asks for microphone + speech permission once.
    func authorize() async -> Bool {
        let speech: Bool = await withCheckedContinuation { c in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0 == .authorized) }
        }
        let mic: Bool = await withCheckedContinuation { c in
            AVAudioSession.sharedInstance().requestRecordPermission { c.resume(returning: $0) }
        }
        denied = !(speech && mic)
        return !denied
    }

    func start() async {
        guard !listening else { return }
        guard await authorize(), let recognizer, recognizer.isAvailable else { return }
        Speaker.shared.stop()
        Audio.configure()
        transcript = ""
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition { req.requiresOnDeviceRecognition = true }
        request = req

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            req.append(buffer)
        }
        engine.prepare()
        do { try engine.start() } catch { return }
        listening = true

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let done = error != nil || (result?.isFinal ?? false)
            Task { @MainActor in
                if let text { self?.transcript = text }
                if done { self?.finish() }
            }
        }
    }

    /// Stops listening; the final words arrive shortly after.
    func stop() {
        guard listening else { return }
        request?.endAudio()
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        listening = false
    }

    private func finish() {
        if listening { stop() }
        task = nil
        request = nil
    }
}
