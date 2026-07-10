/**
 * useNativeBridge — composable for calling iOS native capabilities
 * from within Hermes Studio Vue components.
 *
 * The iOS WKWebView injects window.hermesNative at document start.
 * This composable wraps those calls with type safety and graceful
 * fallbacks for browser environments.
 */

interface HermesNative {
  isNative: true
  shareText: (text: string) => void
  speak: (text: string) => void
  requestFile: () => Promise<{ name: string; data: string } | null>
  scheduleNotification: (title: string, body: string, delay?: number) => void
  onDeviceAI: (prompt: string) => Promise<string>
}

declare global {
  interface Window {
    hermesNative?: HermesNative
  }
}

export function useNativeBridge() {
  const isNative = !!window.hermesNative

  /**
   * Share text via the iOS native share sheet.
   * Falls back to navigator.share or clipboard in browser.
   */
  async function shareText(text: string): Promise<void> {
    if (window.hermesNative) {
      window.hermesNative.shareText(text)
      return
    }
    if (navigator.share) {
      await navigator.share({ text })
      return
    }
    await navigator.clipboard.writeText(text)
  }

  /**
   * Speak text aloud via iOS AVSpeechSynthesizer.
   * Falls back to Web Speech API in browser.
   */
  function speak(text: string): void {
    if (window.hermesNative) {
      window.hermesNative.speak(text)
      return
    }
    if ('speechSynthesis' in window) {
      const utterance = new SpeechSynthesisUtterance(text)
      window.speechSynthesis.speak(utterance)
    }
  }

  /**
   * Open native file picker and return file as base64.
   * Falls back to a hidden <input type="file"> in browser.
   */
  async function requestFile(): Promise<{ name: string; data: string } | null> {
    if (window.hermesNative) {
      return window.hermesNative.requestFile()
    }
    return new Promise((resolve) => {
      const input = document.createElement('input')
      input.type = 'file'
      input.onchange = () => {
        const file = input.files?.[0]
        if (!file) { resolve(null); return }
        const reader = new FileReader()
        reader.onload = () => {
          const b64 = (reader.result as string).split(',')[1] ?? ''
          resolve({ name: file.name, data: b64 })
        }
        reader.readAsDataURL(file)
      }
      input.click()
    })
  }

  /**
   * Schedule a local notification (iOS only; no-op in browser).
   */
  function scheduleNotification(title: string, body: string, delay = 0): void {
    if (window.hermesNative) {
      window.hermesNative.scheduleNotification(title, body, delay)
    }
  }

  /**
   * Run a prompt through on-device Apple Intelligence (iOS 18.1+).
   * Falls back to returning the prompt unchanged in browser.
   */
  async function onDeviceAI(prompt: string): Promise<string> {
    if (window.hermesNative) {
      return window.hermesNative.onDeviceAI(prompt)
    }
    return prompt
  }

  return { isNative, shareText, speak, requestFile, scheduleNotification, onDeviceAI }
}
