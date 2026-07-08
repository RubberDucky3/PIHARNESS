<template>
  <div
    class="demo-player"
    :class="{ 'demo-player--playing': isPlaying, 'demo-player--loading': isLoading }"
    tabindex="0"
    @keydown="onKeydown"
    role="application"
    :aria-label="`Video player: ${title || 'demo'}`"
  >
    <video
      ref="videoRef"
      class="demo-video"
      :src="src"
      :poster="poster"
      muted
      playsinline
      preload="metadata"
      @play="onPlay"
      @pause="onPause"
      @ended="onEnded"
      @error="onError"
      @waiting="isLoading = true"
      @canplay="isLoading = false"
      @loadedmetadata="onMeta"
      @timeupdate="onTime"
    ></video>

    <!-- Loading spinner -->
    <div v-if="isLoading && !errorMsg" class="loading-overlay" aria-label="Buffering">
      <div class="spinner"></div>
    </div>

    <!-- Play/pause button -->
    <button
      class="play-button"
      :class="{ 'play-button--visible': !isPlaying || isLoading }"
      @click="togglePlay"
      :aria-label="isPlaying ? 'Pause (space)' : 'Play (space)'"
    >
      <svg v-if="isLoading" viewBox="0 0 24 24" width="40" height="40" fill="white">
        <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/>
      </svg>
      <svg v-else-if="!isPlaying" viewBox="0 0 24 24" width="48" height="48" fill="white">
        <path d="M8 5v14l11-7z"/>
      </svg>
      <svg v-else viewBox="0 0 24 24" width="48" height="48" fill="white">
        <path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z"/>
      </svg>
    </button>

    <!-- Time overlay (bottom-left) -->
    <div v-if="duration" class="time-overlay" aria-live="off">
      <span class="time-current">{{ formatTime(currentTime) }}</span>
      <span class="time-sep">/</span>
      <span class="time-total">{{ formatTime(duration) }}</span>
    </div>

    <!-- Error state -->
    <div v-if="errorMsg" class="error-overlay" role="alert">
      <span class="error-text">{{ errorMsg }}</span>
      <button class="retry-btn" @click="retry" aria-label="Retry loading video">Retry</button>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue'

const props = defineProps({
  src: { type: String, required: true },
  poster: { type: String, default: '' },
  title: { type: String, default: '' },
})

defineEmits(['play', 'pause', 'ended'])

const videoRef = ref(null)
const isPlaying = ref(false)
const isLoading = ref(false)
const errorMsg = ref('')
const currentTime = ref(0)
const duration = ref(0)

function togglePlay() {
  const v = videoRef.value
  if (!v) return
  if (isPlaying.value) { v.pause() } else { v.play().catch(() => {}) }
}

function onPlay() { isPlaying.value = true }
function onPause() { isPlaying.value = false }
function onEnded() { isPlaying.value = false }
function onMeta() { duration.value = videoRef.value?.duration || 0 }
function onTime() { currentTime.value = videoRef.value?.currentTime || 0 }

function onError() {
  isLoading.value = false
  const v = videoRef.value
  if (!v) return
  const code = v.error ? v.error.code : -1
  const msgs = { 1: 'Video load aborted', 2: 'Network error', 3: 'Format not supported', 4: 'File not found' }
  errorMsg.value = msgs[code] || `Playback error (${code})`
}

function retry() {
  errorMsg.value = ''
  isLoading.value = true
  const v = videoRef.value
  if (v) { v.load(); v.play().catch(() => {}) }
}

function formatTime(s) {
  if (!s || !isFinite(s)) return '0:00'
  const m = Math.floor(s / 60)
  const sec = Math.floor(s % 60)
  return `${m}:${sec.toString().padStart(2, '0')}`
}

function onKeydown(e) {
  if (e.key === ' ' || e.key === 'Space') { e.preventDefault(); togglePlay(); return }
  if (e.key === 'm' || e.key === 'M') {
    const v = videoRef.value
    if (v) v.muted = !v.muted
    return
  }
}

// Bind/unbind keyboard when component mounts
let globalHandler = null
onMounted(() => {
  globalHandler = (e) => {
    // Only handle if focus is on this component or no input is focused
    const tag = document.activeElement?.tagName || ''
    if (tag === 'INPUT' || tag === 'TEXTAREA') return
    if (e.key === ' ' || e.key === 'Space') {
      // Don't steal space if we're not the focused player
      const el = videoRef.value?.closest('.demo-player')
      if (!el || !el.contains(document.activeElement)) return
      e.preventDefault()
      togglePlay()
    }
  }
  document.addEventListener('keydown', globalHandler)
})
onUnmounted(() => {
  if (globalHandler) document.removeEventListener('keydown', globalHandler)
})
</script>

<style scoped>
.demo-player {
  position: relative;
  border-radius: 10px;
  overflow: hidden;
  background: #0d1117;
  border: 1px solid var(--border-color);
  line-height: 0;
  outline: none;
}
.demo-player:focus-visible { box-shadow: 0 0 0 2px var(--accent); }

.demo-video { width: 100%; display: block; }

/* Loading spinner */
.loading-overlay {
  position: absolute; inset: 0;
  display: flex; align-items: center; justify-content: center;
  background: rgba(13,17,23,0.6);
}
.spinner {
  width: 36px; height: 36px;
  border: 3px solid rgba(255,255,255,0.15);
  border-top-color: var(--accent);
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}
@keyframes spin { to { transform: rotate(360deg); } }

/* Play button */
.play-button {
  position: absolute; inset: 0;
  display: flex; align-items: center; justify-content: center;
  background: rgba(0,0,0,0.35);
  border: none; cursor: pointer;
  opacity: 0;
  transition: opacity 0.2s ease, background 0.2s ease;
}
.demo-player:hover .play-button,
.play-button--visible { opacity: 1; }
.play-button--visible { background: rgba(0,0,0,0.5); }
.play-button:hover { background: rgba(0,0,0,0.65); }
.play-button svg { filter: drop-shadow(0 2px 6px rgba(0,0,0,0.4)); }

/* Time overlay */
.time-overlay {
  position: absolute;
  bottom: 0.5rem;
  left: 0.75rem;
  font-family: 'SF Mono', 'Fira Code', monospace;
  font-size: 0.75rem;
  color: rgba(255,255,255,0.85);
  background: rgba(0,0,0,0.55);
  padding: 0.2rem 0.5rem;
  border-radius: 4px;
  line-height: 1.4;
  pointer-events: none;
}
.time-sep { margin: 0 0.2rem; opacity: 0.5; }

/* Error */
.error-overlay {
  position: absolute; inset: 0;
  display: flex; flex-direction: column;
  align-items: center; justify-content: center;
  gap: 0.75rem;
  background: rgba(0,0,0,0.75);
}
.error-text { color: #f85149; font-size: 0.85rem; text-align: center; padding: 0 1rem; line-height: 1.4; }
.retry-btn {
  padding: 0.4rem 1rem;
  font-size: 0.8rem;
  font-weight: 600;
  color: #fff;
  background: var(--accent);
  border: none;
  border-radius: 6px;
  cursor: pointer;
}
.retry-btn:hover { background: var(--accent-hover); }
</style>
