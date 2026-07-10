# Hermes Studio Mobile UI Patches

These patches make Hermes Studio's Vue 3 UI mobile-responsive inside the iOS WKWebView wrapper.

## Apply to your hermes-studio clone

```bash
# From your hermes-studio repo root
git clone https://github.com/EKKOLearnAI/hermes-studio.git
cd hermes-studio
```

### 1. Mobile CSS breakpoints

Append `styles/mobile.scss` to the end of:
```
packages/app/src/styles/global.scss
```

Or import it explicitly:
```scss
// In global.scss:
@import './mobile';
```

### 2. MobileNavBar component

Copy `components/MobileNavBar.vue` to:
```
packages/app/src/components/MobileNavBar.vue
```

Then register it in your root layout (e.g. `packages/app/src/App.vue` or `packages/app/src/layouts/DefaultLayout.vue`):

```vue
<template>
  <n-config-provider>
    <router-view />
    <!-- Add this line: -->
    <MobileNavBar />
  </n-config-provider>
</template>

<script setup>
import MobileNavBar from '@/components/MobileNavBar.vue'
</script>
```

The component only renders on screens ≤768px (controlled by CSS).

### 3. Native Bridge composable

Copy `composables/useNativeBridge.ts` to:
```
packages/app/src/composables/useNativeBridge.ts
```

Use in any component that needs native iOS capabilities:

```vue
<script setup>
import { useNativeBridge } from '@/composables/useNativeBridge'

const { isNative, shareText, speak, requestFile, onDeviceAI } = useNativeBridge()

// Share current chat message
async function share(text: string) {
  await shareText(text)
}

// Use on-device AI to summarize before sending
async function smartSend(message: string) {
  const refined = await onDeviceAI(`Make this clearer: ${message}`)
  // ... send refined to Hermes
}
</script>
```

### 4. Viewport meta tag

Ensure `packages/app/index.html` has this in `<head>`:
```html
<meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
```

The iOS app also injects this via WKUserScript as a fallback.

## Route name mapping

The bottom nav uses these routes. Verify they match your hermes-studio router config:

| Tab      | Route path |
|----------|------------|
| Chat     | `/chat`    |
| Tasks    | `/tasks`   |
| Files    | `/files`   |
| Skills   | `/skills`  |
| Settings | `/settings`|

Adjust `MobileNavBar.vue` `tabs` array if your routes differ.
