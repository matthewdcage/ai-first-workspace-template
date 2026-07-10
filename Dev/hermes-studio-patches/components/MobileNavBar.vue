<template>
  <nav class="hermes-mobile-nav" aria-label="Main navigation">
    <button
      v-for="tab in tabs"
      :key="tab.route"
      class="hermes-mobile-nav__item"
      :class="{ active: isActive(tab.route) }"
      @click="navigate(tab.route)"
      :aria-label="tab.label"
      :aria-current="isActive(tab.route) ? 'page' : undefined"
    >
      <component :is="tab.icon" class="icon" />
      <span>{{ tab.label }}</span>
    </button>
  </nav>
</template>

<script setup lang="ts">
import { useRouter, useRoute } from 'vue-router'
import { h } from 'vue'

// Render functions (not template strings) so these work in runtime-only
// Vue builds, where the template compiler is stripped out (the Vite default).
const ChatIcon = {
  render() {
    return h('svg', { viewBox: '0 0 24 24', fill: 'none', stroke: 'currentColor', 'stroke-width': '2' }, [
      h('path', { d: 'M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z' })
    ])
  }
}
const TaskIcon = {
  render() {
    return h('svg', { viewBox: '0 0 24 24', fill: 'none', stroke: 'currentColor', 'stroke-width': '2' }, [
      h('rect', { x: '3', y: '3', width: '7', height: '7', rx: '1' }),
      h('rect', { x: '14', y: '3', width: '7', height: '7', rx: '1' }),
      h('rect', { x: '3', y: '14', width: '7', height: '7', rx: '1' }),
      h('rect', { x: '14', y: '14', width: '7', height: '7', rx: '1' })
    ])
  }
}
const FileIcon = {
  render() {
    return h('svg', { viewBox: '0 0 24 24', fill: 'none', stroke: 'currentColor', 'stroke-width': '2' }, [
      h('path', { d: 'M13 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V9z' }),
      h('polyline', { points: '13 2 13 9 20 9' })
    ])
  }
}
const SkillIcon = {
  render() {
    return h('svg', { viewBox: '0 0 24 24', fill: 'none', stroke: 'currentColor', 'stroke-width': '2' }, [
      h('polygon', { points: '13 2 3 14 12 14 11 22 21 10 12 10 13 2' })
    ])
  }
}
const SettingsIcon = {
  render() {
    return h('svg', { viewBox: '0 0 24 24', fill: 'none', stroke: 'currentColor', 'stroke-width': '2' }, [
      h('circle', { cx: '12', cy: '12', r: '3' }),
      h('path', { d: 'M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 1 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 1 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 1 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 1 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z' })
    ])
  }
}

const tabs = [
  { route: '/chat',     label: 'Chat',     icon: ChatIcon },
  { route: '/tasks',    label: 'Tasks',    icon: TaskIcon },
  { route: '/files',    label: 'Files',    icon: FileIcon },
  { route: '/skills',   label: 'Skills',   icon: SkillIcon },
  { route: '/settings', label: 'Settings', icon: SettingsIcon },
]

const router = useRouter()
const route = useRoute()

function isActive(routePath: string): boolean {
  return route.path.startsWith(routePath)
}

function navigate(routePath: string): void {
  if (!isActive(routePath)) {
    router.push(routePath)
  }
}
</script>
