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

        // Shared audio session must support simultaneous playback (TTS) and
        // recording (STT), otherwise the engine can fail to start or capture.
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("[SpeechBridge] Failed to configure audio session: \(error)")
            return
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
            guard let data = try? JSONSerialization.data(withJSONObject: transcript, options: .fragmentsAllowed),
                  let jsonString = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async {
                self?.webView?.evaluateJavaScript(
                    "window._hermesCallback('\(callbackId)', \(jsonString))",
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
