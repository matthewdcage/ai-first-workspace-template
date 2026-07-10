import AVFoundation
import Speech
import WebKit

/// Bridges iOS speech capabilities to/from the Hermes web UI.
final class SpeechBridge: NSObject {
    static let shared = SpeechBridge()

    private let synthesizer = AVSpeechSynthesizer()
    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    weak var webView: WKWebView?

    private override init() {
        super.init()
        recognizer = SFSpeechRecognizer(locale: Locale.current)
    }

    // MARK: - TTS

    func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.identifier)
        utterance.rate = 0.52
        synthesizer.speak(utterance)
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    // MARK: - STT

    func requestSTTPermission() {
        SFSpeechRecognizer.requestAuthorization { _ in }
        AVAudioApplication.requestRecordPermission { _ in }
    }

    /// Starts listening; sends transcript to web UI via JS on each update.
    func startListening(callbackId: String) {
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            requestSTTPermission(); return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let req = recognitionRequest else { return }
        req.shouldReportPartialResults = true

        let node = audioEngine.inputNode
        let fmt = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: fmt) { buf, _ in
            req.append(buf)
        }
        audioEngine.prepare()
        try? audioEngine.start()

        recognitionTask = recognizer?.recognitionTask(with: req) { [weak self] result, error in
            guard let result else { return }
            let transcript = result.bestTranscription.formattedString
            let escaped = transcript.replacingOccurrences(of: "'", with: "\\'")
            DispatchQueue.main.async {
                self?.webView?.evaluateJavaScript(
                    "window._hermesCallback('\(callbackId)', '\(escaped)')",
                    completionHandler: nil
                )
            }
            if result.isFinal { self?.stopListening() }
        }
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
    }
}
