<script setup>
import { ref, onMounted } from 'vue'
import { invoke } from '@tauri-apps/api/core'

const darkTheme = ref(true)
const deps = ref(null)
const loading = ref(false)
const error = ref('')
const pingResult = ref('')

async function checkDeps() {
  try {
    const result = await invoke('check_deps')
    deps.value = typeof result === 'string' ? JSON.parse(result) : result
  } catch {
    deps.value = { cmux: false, ade_mcp: false, version: 'unknown' }
  }
}

async function testMcpConnection() {
  loading.value = true
  error.value = ''
  pingResult.value = ''
  try {
    const result = await invoke('ade_mcp_list_tools')
    const parsed = JSON.parse(result)
    const tools = parsed?.result?.tools || []
    pingResult.value = `Connected (${tools.length} tools available)`
  } catch (e) {
    error.value = e?.message || 'Failed to connect'
    pingResult.value = 'Disconnected'
  } finally {
    loading.value = false
  }
}

function applyTheme() {
  document.documentElement.setAttribute('data-theme', darkTheme.value ? 'dark' : 'light')
}

function toggleTheme() {
  darkTheme.value = !darkTheme.value
  applyTheme()
}

onMounted(() => {
  applyTheme()
  checkDeps()
})
</script>

<template>
  <div class="settings-view">
    <header class="view-header">
      <h1>Settings</h1>
    </header>
    <main class="view-main">
      <section class="setting-group">
        <h2>Appearance</h2>
        <div class="setting-row">
          <div class="setting-info">
            <div class="setting-title">Dark theme</div>
            <div class="setting-desc">Use dark colors for the interface.</div>
          </div>
          <button class="btn btn-toggle" :class="{ active: darkTheme }" @click="toggleTheme">
            {{ darkTheme ? 'On' : 'Off' }}
          </button>
        </div>
      </section>

      <section class="setting-group">
        <h2>ADE</h2>
        <div class="setting-row">
          <div class="setting-info">
            <div class="setting-title">Version</div>
            <div class="setting-desc">{{ deps?.version || 'Loading...' }}</div>
          </div>
        </div>
        <div class="setting-row">
          <div class="setting-info">
            <div class="setting-title">cmux</div>
            <div class="setting-desc" :class="{ ok: deps?.cmux, fail: !deps?.cmux }">
              {{ deps?.cmux ? 'Installed' : 'Not installed' }}
            </div>
          </div>
        </div>
        <div class="setting-row">
          <div class="setting-info">
            <div class="setting-title">ade-mcp</div>
            <div class="setting-desc" :class="{ ok: deps?.ade_mcp, fail: !deps?.ade_mcp }">
              {{ deps?.ade_mcp ? 'Running (127.0.0.1:9000)' : 'Not running' }}
            </div>
          </div>
          <button class="btn btn-ghost" @click="checkDeps">Refresh</button>
        </div>
      </section>

      <section class="setting-group">
        <h2>Connection Test</h2>
        <div class="setting-row">
          <div class="setting-info">
            <div class="setting-title">ade-mcp tools</div>
            <div class="setting-desc">{{ pingResult || (loading ? 'Testing...' : 'Not tested') }}</div>
          </div>
          <button class="btn btn-ghost" @click="testMcpConnection" :disabled="loading">
            {{ loading ? 'Testing...' : 'Test' }}
          </button>
        </div>
      </section>

      <div v-if="error" class="state error">{{ error }}</div>
    </main>
  </div>
</template>

<style scoped>
.settings-view { display:flex; flex-direction:column; height:100%; color:var(--color-text); }
.view-header { padding:16px 20px; border-bottom:1px solid var(--color-border); }
.view-main { flex:1; padding:20px; overflow:auto; display:flex; flex-direction:column; gap:24px; }
.setting-group { display:flex; flex-direction:column; gap:12px; }
.setting-group h2 { font-size:14px; text-transform:uppercase; letter-spacing:0.08em; color:var(--color-text-secondary); margin:0; }
.setting-row { display:flex; justify-content:space-between; align-items:center; gap:16px; padding:10px 0; border-bottom:1px solid var(--color-border); }
.setting-row:last-child { border-bottom:none; }
.setting-info { display:flex; flex-direction:column; gap:2px; }
.setting-title { font-weight:600; }
.setting-desc { font-size:13px; color:var(--color-text-secondary); }
.setting-desc.ok { color:var(--color-success); }
.setting-desc.fail { color:var(--color-danger); }
.state { color:var(--color-text-secondary); }
.state.error { color:var(--color-danger); }
</style>
