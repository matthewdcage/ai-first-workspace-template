# HermesApp — iOS Web Wrapper for Hermes Studio

A native iOS app that wraps your self-hosted **Hermes Studio** web UI in WKWebView with:
- Cloudflare Tunnel authenticated access (CF Access headers + Hermes JWT)
- Keychain-backed credential storage
- Native iOS integration hooks (Siri, Share Sheet, Notifications, Background Refresh)
- On-device AI via Apple Intelligence / Foundation Models (iPhone 15 Pro+ / iPhone 16)
- Voice input/output via STT + TTS
- App Intents for Siri Shortcuts

## Requirements

| Requirement | Version |
|---|---|
| Xcode | 16.0+ |
| Swift | 5.10+ |
| iOS Deployment Target | 18.0 |
| Apple Intelligence (optional) | iOS 18.1+, iPhone 15 Pro / iPhone 16 family |

## Hermes Studio — Latest Commit

Tested against: **`ca2b62e`** — `sort preview version tags (#2015)` — 2026-07-10

## Quick Start

```bash
# 1. Open the project
open Dev/HermesApp/HermesApp.xcodeproj

# 2. In Xcode: set your signing team & bundle ID
#    HermesApp target → Signing & Capabilities

# 3. Add capabilities:
#    + Background Modes (Background Fetch)
#    + Push Notifications
#    + Siri

# 4. Add Info.plist keys:
#    NSMicrophoneUsageDescription
#    NSSpeechRecognitionUsageDescription
#    BGTaskSchedulerPermittedIdentifiers: [com.hermesapp.refresh]

# 5. Run on device or simulator (⌘R)
```

## First Launch Flow

1. App opens → `SetupView` (no config in Keychain yet)
2. Enter your Hermes tunnel URL: `https://hermes.yourdomain.com`
3. Enter your Hermes API token (Settings → Account → API Token in Hermes Studio)
4. Optionally enter Cloudflare Access Client ID + Secret
5. Tap **Connect to Hermes**
6. Full Hermes Studio UI loads in WKWebView

## Architecture

```
┌─────────────────────────────────────────────┐
│                 iOS App                      │
│  ┌──────────┐  ┌────────────────────────┐   │
│  │SetupView │  │      WebView           │   │
│  │(Keychain)│  │   (WKWebView)          │   │
│  └──────────┘  │                        │   │
│                │  ┌─────────────────┐   │   │
│                │  │  NativeBridge   │   │   │
│                │  │ window.hermesNative   │   │
│                │  └────────┬────────┘   │   │
│                └───────────┼────────────┘   │
│                            │                │
│  ┌─────────────────────────▼────────────┐   │
│  │         Native Capabilities          │   │
│  │  AVSpeech │ AppIntents │ BGFetch     │   │
│  │  CoreML   │ UNNotify   │ ShareExt    │   │
│  │  FoundationModels (Apple Intelligence)│  │
│  └──────────────────────────────────────┘   │
└─────────────────────────────────────────────┘
              │ HTTPS + CF-Access headers
              ▼
┌──────────────────────────────┐
│   Cloudflare Tunnel          │
└──────────────┬───────────────┘
               │
┌──────────────▼───────────────┐
│   Self-hosted Hermes Studio  │
│   (Vue 3 + Koa + Socket.IO)  │
└──────────────────────────────┘
```

## JS → Swift Bridge

The web UI can call native features via `window.hermesNative`:

```js
// Voice output
window.hermesNative.speak("Task complete.")

// Share a response
window.hermesNative.shareText("Here's what Hermes said: ...")

// Upload a file
const file = await window.hermesNative.requestFile()
// → { name: "document.pdf", data: "<base64>" }

// Schedule a local notification
window.hermesNative.scheduleNotification("Hermes", "Your task is done", 0)

// Run on-device Apple Intelligence
const summary = await window.hermesNative.onDeviceAI("Summarize: " + longText)
```

## Cloudflare Tunnel Setup

### Option A: Open tunnel, Hermes auth only
Leave CF Access fields blank in the setup screen. The app uses your Hermes API token for auth.

### Option B: Cloudflare Access protected tunnel
1. In Cloudflare Zero Trust → Access → Service Auth → Create Service Token
2. Copy the Client ID and Client Secret
3. Enter both in the HermesApp setup screen

The app injects `CF-Access-Client-Id` and `CF-Access-Client-Secret` headers on every navigation request.

## Mobile UI Patches

See `../hermes-studio-patches/APPLY_PATCHES.md` for instructions on making the Hermes Studio Vue UI mobile-responsive (bottom nav bar, safe area handling, touch targets).
