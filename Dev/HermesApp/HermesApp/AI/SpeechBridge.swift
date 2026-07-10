import AVFoundation
import Speech
import WebKit

/// Bridges iOS speech capabilities to/from the Hermes web UI.
final class SpeechBridge: NSObject, @unchecked Sendable {
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
        stopListening()

        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            requestSTTPermission()
            complete(callbackId: callbackId, result: [
                "error": "speech_permission_required"
            ])
            return
        }

        guard AVAudioApplication.shared.recordPermission == .granted else {
            AVAudioApplication.requestRecordPermission { _ in }
            complete(callbackId: callbackId, result: [
                "error": "microphone_permission_required"
            ])
            return
        }

        guard recognizer?.isAvailable == true else {
            complete(callbackId: callbackId, result: [
                "error": "speech_recognizer_unavailable"
            ])
            return
        }

        // Shared audio session must support simultaneous playback (TTS) and
        // recording (STT), otherwise the engine can fail to start or capture.
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("[SpeechBridge] Failed to configure audio session: \(error)")
            complete(callbackId: callbackId, result: [
                "error": "audio_session_failed",
                "message": error.localizedDescription
            ])
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
        do {
            try audioEngine.start()
        } catch {
            print("[SpeechBridge] Failed to start audio engine: \(error)")
            complete(callbackId: callbackId, result: [
                "error": "audio_engine_failed",
                "message": error.localizedDescription
            ])
            return
        }

        recognitionTask = recognizer?.recognitionTask(with: req) { [weak self] result, error in
            if let result {
                let transcript = result.bestTranscription.formattedString
                self?.dispatchTranscript(transcript, isFinal: result.isFinal)
                if result.isFinal {
                    self?.complete(callbackId: callbackId, result: transcript)
                    self?.stopListening()
                }
            } else if let error {
                self?.complete(callbackId: callbackId, result: [
                    "error": "recognition_failed",
                    "message": error.localizedDescription
                ])
                self?.stopListening()
            }
        }
    }

    func stopListening() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
    }

    private func complete(callbackId: String, result: Any) {
        guard !callbackId.isEmpty,
              let callbackLiteral = Self.jsonLiteral(callbackId),
              let resultLiteral = Self.jsonLiteral(result) else { return }

        DispatchQueue.main.async { [weak self] in
            self?.webView?.evaluateJavaScript(
                "window._hermesCallback(\(callbackLiteral), \(resultLiteral))",
                completionHandler: nil
            )
        }
    }

    private func dispatchTranscript(_ transcript: String, isFinal: Bool) {
        let payload: [String: Any] = [
            "transcript": transcript,
            "isFinal": isFinal
        ]
        guard let payloadLiteral = Self.jsonLiteral(payload) else { return }

        DispatchQueue.main.async { [weak self] in
            self?.webView?.evaluateJavaScript(
                "window.dispatchEvent(new CustomEvent('hermes:speechTranscript', { detail: \(payloadLiteral) }))",
                completionHandler: nil
            )
        }
    }

    private static func jsonLiteral(_ value: Any) -> String? {
        guard JSONSerialization.isValidJSONObject(value)
                || value is String
                || value is NSNumber
                || value is NSNull else {
            return nil
        }

        guard let data = try? JSONSerialization.data(withJSONObject: value, options: .fragmentsAllowed) else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }
}
