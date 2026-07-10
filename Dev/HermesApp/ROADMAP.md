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

### 2. Visual Intelligence — implemented, gated behind `canImport`

Shipped: an app-facing `IntentValueQuery` that receives a
`SemanticContentDescriptor` (camera frame / on-screen selection) and
returns matching `AppEntity` results, plus a `semanticContentSearch`
Assistant Schema that auto-supplies that descriptor to an intent.

Implemented in `VisualIntelligence/HermesVisualIntelligenceQuery.swift`,
entirely inside `#if canImport(VisualIntelligence)` so it's inert on any
SDK where the framework doesn't exist. Two things there are corroborated
from WWDC26 coverage but **not yet confirmed against Apple's primary doc
page** (it returned empty on fetch — likely JS-rendered content) and need
a quick check in Xcode 27 before this ships to TestFlight:
- `SemanticContentDescriptor.pixelBuffer` — property name plausible, not
  independently confirmed
- The exact schema path for `semanticContentSearch` (`.system....` vs.
  `.visualIntelligence....` vs. something else) — the intent currently
  takes `semanticContent` as a manual `@Parameter` rather than guessing
  the schema macro path and getting it wrong

The matching logic itself (`HermesSemanticContentQuery.values(for:)`) is a
placeholder returning all cached sessions — replace with real OCR/vision
similarity ranking once the descriptor's actual pixel data access is
confirmed.

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
