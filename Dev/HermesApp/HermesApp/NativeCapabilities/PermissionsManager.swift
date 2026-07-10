import Foundation
import AVFoundation
import Speech
import UserNotifications
#if canImport(Photos)
import Photos
#endif

/// Centralizes every system permission HermesApp can request, so the
/// setup flow can request them with clear context (rather than each
/// feature triggering a surprise system prompt the first time it's used).
@MainActor
final class PermissionsManager: ObservableObject {
    static let shared = PermissionsManager()

    enum Status { case notDetermined, granted, denied }

    @Published var microphone: Status = .notDetermined
    @Published var speechRecognition: Status = .notDetermined
    @Published var notifications: Status = .notDetermined
    @Published var photoLibrary: Status = .notDetermined

    private init() { refreshAll() }

    func refreshAll() {
        microphone = mapAVAudioStatus(AVAudioApplication.shared.recordPermission)
        speechRecognition = mapSpeechStatus(SFSpeechRecognizer.authorizationStatus())
        #if canImport(Photos)
        photoLibrary = mapPhotosStatus(PHPhotoLibrary.authorizationStatus(for: .readWrite))
        #endif
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                self.notifications = settings.authorizationStatus == .authorized ? .granted
                    : settings.authorizationStatus == .denied ? .denied : .notDetermined
            }
        }
    }

    /// Request every permission Hermes uses, in the order most likely to
    /// make sense to a user reading each system dialog in sequence.
    func requestAll() async {
        await requestMicrophone()
        await requestSpeechRecognition()
        await requestNotifications()
        await requestPhotoLibrary()
    }

    func requestMicrophone() async {
        let granted = await AVAudioApplication.requestRecordPermission()
        microphone = granted ? .granted : .denied
    }

    func requestSpeechRecognition() async {
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        speechRecognition = mapSpeechStatus(status)
    }

    func requestNotifications() async {
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        notifications = granted ? .granted : .denied
    }

    func requestPhotoLibrary() async {
        #if canImport(Photos)
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        photoLibrary = mapPhotosStatus(status)
        #endif
    }

    // MARK: - Mapping

    private func mapAVAudioStatus(_ status: AVAudioApplication.recordPermission) -> Status {
        switch status {
        case .granted: return .granted
        case .denied: return .denied
        default: return .notDetermined
        }
    }

    private func mapSpeechStatus(_ status: SFSpeechRecognizerAuthorizationStatus) -> Status {
        switch status {
        case .authorized: return .granted
        case .denied, .restricted: return .denied
        default: return .notDetermined
        }
    }

    #if canImport(Photos)
    private func mapPhotosStatus(_ status: PHAuthorizationStatus) -> Status {
        switch status {
        case .authorized, .limited: return .granted
        case .denied, .restricted: return .denied
        default: return .notDetermined
        }
    }
    #endif
}
