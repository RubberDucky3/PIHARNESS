<template>
  <div class="terminal-window">
    <div class="terminal-header">
      <div class="terminal-dots">
        <span class="dot dot-red"></span>
        <span class="dot dot-yellow"></span>
        <span class="dot dot-green"></span>
      </div>
      <span class="terminal-title">PIHARNESS — ~/workspace</span>
    </div>
    <div class="terminal-body">
      <div class="terminal-line" v-for="(line, i) in displayedLines" :key="i">
        <span class="terminal-prompt" :class="promptClass(line.prompt)">{{ line.prompt }}</span>
        <span v-if="line.typing" class="terminal-typing">{{ line.text }}<span class="cursor-blink">▊</span></span>
        <span v-else>{{ line.text }}</span>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onBeforeUnmount } from 'vue'

const props = defineProps({
  commands: {
    type: Array,
    default: () => [
      { prompt: '$', text: './piharness.sh spawn --label worker-a' },
      { prompt: '▶', text: 'Spawning worker-a from kilo-auto/free...' },
      { prompt: '✓', text: 'worker-a ready (surface:42)' },
      { prompt: '$', text: './piharness.sh auto surface:42 "Build a REST API"' },
      { prompt: '▶', text: 'Routing through runtime chain...' },
      { prompt: '✓', text: 'Task running on pi:kilo-auto/free' },
    ]
  },
  typingSpeed: {
    type: Number,
    default: 40
  },
  pauseAfterLine: {
    type: Number,
    default: 800
  }
})

const displayedLines = ref([])
let currentLine = 0
let currentChar = 0
let typingTimer = null
let commandCycleTimer = null

function typeNextChar() {
  if (currentLine >= props.commands.length) {
    // Pause, then reset and cycle
    commandCycleTimer = setTimeout(resetAndCycle, 3000)
    return
  }

  const cmd = props.commands[currentLine]

  if (currentChar === 0) {
    // Show line with empty text, start typing
    displayedLines.value = [
      ...displayedLines.value,
      { prompt: cmd.prompt, text: '', typing: true }
    ]
  }

  const text = cmd.text
  if (currentChar < text.length) {
    currentChar++
    const lines = [...displayedLines.value]
    lines[lines.length - 1] = {
      prompt: cmd.prompt,
      text: text.substring(0, currentChar),
      typing: true
    }
    displayedLines.value = lines
    typingTimer = setTimeout(typeNextChar, props.typingSpeed)
  } else {
    // Line complete - mark as done, wait, move to next
    const lines = [...displayedLines.value]
    lines[lines.length - 1] = {
      ...lines[lines.length - 1],
      typing: false
    }
    displayedLines.value = lines
    currentLine++
    currentChar = 0
    typingTimer = setTimeout(typeNextChar, props.pauseAfterLine)
  }
}

function promptClass(p) {
  if (p === '$') return 'prompt-dollar'
  if (p === '✓') return 'prompt-check'
  if (p === '▶') return 'prompt-play'
  if (p === 'ℹ') return 'prompt-info'
  return ''
}

function resetAndCycle() {
  displayedLines.value = []
  currentLine = 0
  currentChar = 0
  typingTimer = setTimeout(typeNextChar, 500)
}

onMounted(() => {
  typingTimer = setTimeout(typeNextChar, 500)
})

onBeforeUnmount(() => {
  if (typingTimer) clearTimeout(typingTimer)
  if (commandCycleTimer) clearTimeout(commandCycleTimer)
})
</script>

<style scoped>
.terminal-window {
  background: #0d1117;
  border: 1px solid #30363d;
  border-radius: 12px;
  overflow: hidden;
  font-family: 'SF Mono', 'Fira Code', 'Cascadia Code', 'Menlo', monospace;
  font-size: 0.8rem;
  line-height: 1.7;
  box-shadow: 0 8px 30px rgba(0, 0, 0, 0.4);
}

.terminal-header {
  background: #161b22;
  padding: 0.6rem 1rem;
  display: flex;
  align-items: center;
  gap: 0.75rem;
  border-bottom: 1px solid #30363d;
}

.terminal-dots {
  display: flex;
  gap: 6px;
  flex-shrink: 0;
}

.dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
}

.dot-red { background: #ff5f56; }
.dot-yellow { background: #ffbd2e; }
.dot-green { background: #27c93f; }

.terminal-title {
  color: #8b949e;
  font-size: 0.75rem;
  font-weight: 500;
}

.terminal-body {
  padding: 1rem;
  min-height: 200px;
}

.terminal-line {
  white-space: pre;
  word-break: normal;
  color: #e6edf3;
}

.terminal-prompt {
  margin-right: 0.5rem;
  font-weight: 600;
}

.terminal-prompt:first-child {
  color: #58a6ff;
}

.prompt-dollar { color: #58a6ff; }
.prompt-check { color: #3fb950; }
.prompt-play  { color: #d29922; }
.prompt-info  { color: #79c0ff; }

.terminal-typing {
  border-right: none;
}

.cursor-blink {
  color: #58a6ff;
  animation: blink 0.6s step-end infinite;
}

@keyframes blink {
  50% { opacity: 0; }
}
</style>
