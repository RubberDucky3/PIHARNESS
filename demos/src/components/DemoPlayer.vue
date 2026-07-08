<template>
  <div class="demo-player" :class="{ 'demo-player--active': isPlaying }">
    <video
      ref="videoRef"
      class="demo-video"
      :src="src"
      :poster="poster"
      muted
      playsinline
      preload="metadata"
      @play="isPlaying = true"
      @pause="isPlaying = false"
      @ended="isPlaying = false"
      @error="onError"
    ></video>
    <button
      class="play-button"
      :class="{ 'play-button--visible': !isPlaying }"
      @click="togglePlay"
      :aria-label="isPlaying ? 'Pause' : 'Play'"
    >
      <svg v-if="!isPlaying" viewBox="0 0 24 24" width="48" height="48" fill="white">
        <path d="M8 5v14l11-7z"/>
      </svg>
      <svg v-else viewBox="0 0 24 24" width="48" height="48" fill="white">
        <path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z"/>
      </svg>
    </button>
    <div v-if="errorMsg" class="error-overlay">
      <span>{{ errorMsg }}</span>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'

const props = defineProps({
  src: { type: String, required: true },
  poster: { type: String, default: '' },
})

const videoRef = ref(null)
const isPlaying = ref(false)
const errorMsg = ref('')

function togglePlay() {
  if (!videoRef.value) return
  if (isPlaying.value) {
    videoRef.value.pause()
  } else {
    videoRef.value.play().catch(() => {})
  }
}

function onError() {
  const video = videoRef.value
  if (!video) return
  const code = video.error ? video.error.code : -1
  const messages = {
    1: 'Video load aborted',
    2: 'Network error loading video',
    3: 'Video format not supported',
    4: 'Video file not found',
  }
  errorMsg.value = messages[code] || `Playback error (code ${code})`
}
</script>

<style scoped>
.demo-player {
  position: relative;
  border-radius: 10px;
  overflow: hidden;
  background: #0d1117;
  border: 1px solid var(--border-color);
  line-height: 0;
}

.demo-video {
  width: 100%;
  display: block;
}

.play-button {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(0,0,0,0.35);
  border: none;
  cursor: pointer;
  opacity: 0;
  transition: opacity 0.2s ease, background 0.2s ease;
}

.demo-player:hover .play-button {
  opacity: 1;
}

.play-button--visible {
  opacity: 1;
  background: rgba(0,0,0,0.5);
}

.play-button:hover {
  background: rgba(0,0,0,0.6);
}

.play-button svg {
  filter: drop-shadow(0 2px 4px rgba(0,0,0,0.3));
}

.error-overlay {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(0,0,0,0.7);
  color: #f85149;
  font-size: 0.9rem;
  padding: 1rem;
  text-align: center;
}
</style>
