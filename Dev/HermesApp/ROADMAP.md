# HermesApp — OS Integration Roadmap

Tracks what's already wired up for system-level AI/Siri/Spotlight integration
vs. what's planned once Apple ships the next tier of platform APIs.

## Implemented (this PR)

| Capability | How | Files |
|---|---|---|
| Siri / Shortcuts actions | `AppIntent` conformance (`AskHermesIntent`, `OpenChatSessionIntent`) | `NativeCapabilities/AppIntents.swift` |
| Content Siri can reference ("that chat about X") | `AppEntity` + `IndexedEntity` for chat sessions & skills | `Search/HermesEntities.swift` |
| Spotlight system search | `CoreSpotlight` (`CSSearchableIndex`) indexing of sessions/skills | `Search/SpotlightIndexer.swift` |
| Handoff between devices | `NSUserActivity` continuation | `Continuity/HandoffManager.swift` |
| Actionable notifications | `UNNotificationCategory` with Reply/Open/Dismiss actions | `NativeCapabilities/NotificationCategories.swift` |
| Centralized permission requests | Mic, Speech, Notifications, Photos in one place, requested with context | `NativeCapabilities/PermissionsManager.swift` |
| On-device LLM (Apple Intelligence) | `FoundationModelsAdapter` via runtime-checked reflection (compiles without the SDK present) | `AI/FoundationModelsAdapter.swift` |
| On-device intent classification | NL heuristics + optional bundled Core ML model | `AI/OnDeviceClassifier.swift` |
| Voice I/O | `AVSpeechSynthesizer` + `SFSpeechRecognizer`, correct `AVAudioSession` config | `AI/SpeechBridge.swift` |
| Background sync | `BGAppRefreshTask` polling Hermes for new activity | `NativeCapabilities/BackgroundRefresh.swift` |

## Planned — next milestones

### 1. Assistant Schemas (Apple Intelligence, unreleased at time of writing)
Apple's App Intents framework is moving toward predefined **Assistant Schema
domains** (`@AssistantIntent(schema: .system.search)`-style annotations) that
give Siri structured vocabulary for common categories (messaging, browsing,
files) instead of only free-form natural-language phrase matching.

No schema symbols are referenced anywhere in this codebase yet — they're
unreleased and referencing them would break the build. When Apple ships
them:
- Re-annotate `AskHermesIntent` under the messaging-like schema so "text
  Hermes" style phrasing resolves without a custom phrase list
- Re-annotate `OpenChatSessionIntent` under a search/browsing schema
- `ChatSessionEntity` / `HermesSkillEntity` (`Search/HermesEntities.swift`)
  are already `AppEntity` + `IndexedEntity` — schema adoption is additive on
  top of these, not a rewrite

### 2. Visual Intelligence
Lets a user point the Camera app (or select on-screen content on Mac/iPad)
and jump into an app for matching results. Integration point is an
`AppIntent` that accepts an image and returns matching Hermes
sessions/skills — same `AppEntity` types already defined can be the return
value. Blocked on Apple publishing the integration API; the entity layer is
already in place to receive it.

### 3. macOS native target
`WebView`/`HermesWebViewCoordinator` currently use `UIViewRepresentable` and
UIKit-specific presentation (`UIActivityViewController`,
`UIDocumentPickerViewController`, `UIWindowScene`). A macOS target needs:
- `NSViewRepresentable` wrapping the same `WKWebView` + `NativeBridge`
  (the bridge itself, `Search/*`, `Continuity/*`, `AI/*` are already
  cross-platform Foundation/AppIntents code with no UIKit dependency)
- `NSSharingServicePicker` in place of `UIActivityViewController`
- `NSOpenPanel` in place of `UIDocumentPickerViewController`
- `NSApplicationDelegateAdaptor` + a small `MacAppDelegate` in place of
  the iOS `AppDelegate` (background refresh isn't applicable on Mac —
  use a `Timer`/`NSBackgroundActivityScheduler` instead of `BGAppRefreshTask`)
- Menu bar commands (`CommandGroup`) for reload / new chat / settings

Estimate: ~8 new files mirroring the iOS `WebKit`/`App` folders, sharing
everything under `Config/`, `Search/`, `Continuity/`, `AI/`,
`NativeCapabilities/PermissionsManager.swift`,
`NativeCapabilities/NotificationCategories.swift`, and `NativeCapabilities/AppIntents.swift`
unchanged. Add as a second XcodeGen target in `project.yml` once started.

### 4. Live Activities / widget (stretch)
A Lock Screen Live Activity showing the active Hermes task status, updated
via the same `/api/hermes/status` endpoint `BackgroundRefresh` already
polls. Not started — flagged here so it isn't silently dropped from scope.
