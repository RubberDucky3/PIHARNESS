<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { invoke } from '@tauri-apps/api/core'
import { listen } from '@tauri-apps/api/event'
import { Terminal } from 'xterm'
import { FitAddon } from 'xterm-addon-fit'
import 'xterm/css/xterm.css'

const props = defineProps({
  terminalId: { type: String, required: true },
  cmd: { type: String, default: 'zsh' },
  cwd: { type: String, default: undefined },
})

const emit = defineEmits(['closed'])

const terminalRef = ref(null)
let term = null
let fitAddon = null
let unlisten = null
let resizeObserver = null
let resizeTimer = null

async function safeInvoke(cmd, args = {}) {
  try {
    return await invoke(cmd, args)
  } catch (e) {
    const msg = typeof e === 'object' && e !== null ? (e.message || String(e)) : String(e)
    if (term) term.writeln(`\x1b[31mError: ${msg}\x1b[0m`)
  }
}

function scheduleFit() {
  if (resizeTimer) clearTimeout(resizeTimer)
  resizeTimer = setTimeout(() => {
    if (!term || !fitAddon || !terminalRef.value) return
    try {
      fitAddon.fit()
      safeInvoke('resize_terminal', {
        id: props.terminalId,
        cols: term.cols,
        rows: term.rows,
      })
    } catch {
      /* container may be zero-sized mid-layout */
    }
  }, 50)
}

onMounted(async () => {
  if (!terminalRef.value) return

  term = new Terminal({
    cursorBlink: true,
    cursorStyle: 'bar',
    fontSize: 13,
    fontFamily: 'Menlo, Monaco, "Courier New", monospace',
    theme: {
      background: '#0d1117',
      foreground: '#c9d1d9',
      cursor: '#58a6ff',
      selectionBackground: '#264f78',
      black: '#484f58',
      red: '#ff7b72',
      green: '#3fb950',
      yellow: '#d29922',
      blue: '#58a6ff',
      magenta: '#bc8cff',
      cyan: '#39c5cf',
      white: '#b1bac4',
      brightBlack: '#6e7681',
      brightRed: '#ffa198',
      brightGreen: '#56d364',
      brightYellow: '#e3b341',
      brightBlue: '#79c0ff',
      brightMagenta: '#d2a8ff',
      brightCyan: '#56d4dd',
      brightWhite: '#f0f6fc',
    },
    allowTransparency: true,
  })

  fitAddon = new FitAddon()
  term.loadAddon(fitAddon)
  term.open(terminalRef.value)
  fitAddon.fit()

  // Subscribe BEFORE spawning the PTY so no early output is lost.
  try {
    unlisten = await doListen()
  } catch (e) {
    term.writeln('\x1b[31mTerminal backend unavailable (not running inside Tauri?)\x1b[0m')
    try { await invoke('close_terminal', { id: props.terminalId }) } catch {}
    return
  }

  await safeInvoke('create_terminal', {
    id: props.terminalId,
    cmd: props.cmd,
    cwd: props.cwd || null,
    cols: term.cols,
    rows: term.rows,
  })

  // Keyboard input → PTY stdin (raw, xterm handles encoding).
  term.onData((data) => {
    safeInvoke('write_stdin', { id: props.terminalId, data })
  })

  resizeObserver = new ResizeObserver(scheduleFit)
  resizeObserver.observe(terminalRef.value)
})

function doListen() {
  return listen('terminal-output', (event) => {
    const payload = event.payload
    if (!payload || payload.id !== props.terminalId) return
    if (payload.data === null) {
      if (term) term.write('\r\n\x1b[33m[Session ended]\x1b[0m')
      emit('closed')
      return
    }
    if (term) term.write(payload.data)
  })
}

onUnmounted(async () => {
  if (resizeTimer) clearTimeout(resizeTimer)
  if (resizeObserver) {
    resizeObserver.disconnect()
    resizeObserver = null
  }
  if (unlisten) {
    unlisten()
    unlisten = null
  }
  try {
    await invoke('close_terminal', { id: props.terminalId })
  } catch {
    /* backend may already have dropped the session */
  }
  if (term) {
    term.dispose()
    term = null
  }
})
</script>

<template>
  <div ref="terminalRef" class="terminal-pane"></div>
</template>

<style scoped>
.terminal-pane {
  width: 100%;
  height: 100%;
  min-height: 200px;
  background: #0d1117;
}
</style>
