# Changelog

All notable changes to HermesApp are tracked here.

## 2026-07-10

### Added
- Native setup flow with prominent connection status, named favorite connections, recent connections, and connection history.
- In-app fast switching between favorite connections when two or more favorites are available.
- Last successful connection and recent session logging.
- Native connected shell with status header, loading progress, back/forward/reload/share/settings controls, and a main menu.
- Native capabilities surface for permissions, voice input, notifications, files, and photos.
- App icon asset generated from `ttm-the-thiking-monkey.webp`.

### Improved
- Connect now validates Hermes before opening, displays clear progress, and opens the newly saved URL instead of reloading a stale WebView page.
- Test Connection results are shown near the top of setup instead of lower off-screen.
- WebView reload and settings flows now recreate the WebView when the configured server changes.
- Authentication headers and URL normalization are centralized through `ServerConfig`.
- Foundation Models usage is runtime/SDK gated for iOS beta compatibility.

### Fixed
- Stale connection URL usage after changing settings.
- Hidden/ambiguous setup status after testing or connecting.
- Missing startup main-menu access.
- Asset catalog app icon wiring.

