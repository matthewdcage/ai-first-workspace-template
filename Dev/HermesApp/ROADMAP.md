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

## Update — WWDC26 shipped (iOS/macOS 27 beta, June 2026)

Assistant Schemas and Visual Intelligence's app-integration API are no
longer unreleased — they shipped in the iOS/macOS 27 beta SDK. Revised
status below supersedes the "planned, blocked on Apple" framing that was
accurate when this doc was first written (pre-WWDC26).

### 1. Assistant Schemas — evaluated, deliberately not adopted for Hermes's entities

`@AppEntity(schema:)` / `@AssistantIntent(schema:)` bind an entity/intent to
a system-defined domain (`.messages`, `.mail`, `.photos`, `.documents`, and
others) so Siri gets structured vocabulary for free, confirmed via the
WWDC26 "Build intelligent Siri experiences with App Schemas" session.

None of the announced domains is a semantic match for "AI agent chat
session" or "agent skill" — `.messages` in particular implies sender/
recipient semantics a Hermes session doesn't have. Force-fitting it would
make Siri infer relationships about the entity that aren't true, which is
worse than not adopting a schema at all. `ChatSessionEntity` /
`HermesSkillEntity` (`Search/HermesEntities.swift`) stay plain
`AppEntity`/`IndexedEntity` — a fully supported, permanent path Apple's own
guidance describes for content outside the predefined categories, not a
fallback. See the doc comment in that file for the full reasoning.

If Apple later ships an assistant-adjacent domain that actually fits (e.g.
a general "AI conversation" or "task" domain), revisit — the entity layer
underneath doesn't need to change, only the attribute macros on top of it.

### 2. Visual Intelligence — implemented and verified against Apple's own sample

An app-facing `IntentValueQuery` receives a `SemanticContentDescriptor`
(camera frame / on-screen selection) and returns matching `AppEntity`
results; an intent annotated with the `semanticContentSearch` schema gets
that descriptor auto-supplied when Visual Intelligence invokes it.

Implemented in `VisualIntelligence/HermesVisualIntelligenceQuery.swift`,
entirely inside `#if canImport(VisualIntelligence)` so it's inert on any
SDK where the framework doesn't exist. Every symbol used —
`SemanticContentDescriptor.pixelBuffer: CVReadOnlyPixelBuffer?`, the
`IntentValueQuery` protocol shape, and the exact
`@AppIntent(schema: .visualIntelligence.semanticContentSearch)` macro
syntax — was confirmed verbatim against Apple's own worked example in the
WWDC26 session 297 transcript ("Best practices for integrating visual
intelligence in your app"), not inferred from secondary coverage.

The matching logic differs from Apple's own album-art sample on purpose:
their example matches images to images via `Vision`'s
`GenerateImageFeaturePrintRequest` (feature-print similarity), which is the
right tool for "does this photo look like that photo." Hermes sessions are
text content, so `HermesSemanticContentQuery` instead runs
`VNRecognizeTextRequest` (on-device OCR, a stable pre-27 Vision API) over
the captured frame and matches recognized text against cached session
titles — the correct technique for this domain rather than a copy-paste of
the image-similarity approach.

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
