<script setup>
import { ref, onMounted } from 'vue'

const loading = ref(false)
const error = ref('')
const channel = ref('tasks/api')
const messageText = ref('')
const sender = ref('ade-ui')
const busMessages = ref([])
const sessions = ref([])
const activeTab = ref('bus')

async function callTool(name, args = {}) {
  const result = await window.__TAURI_INTERNALS__.invoke('ade_mcp_call_tool', {
    name,
    args: JSON.stringify(args)
  })
  return JSON.parse(result)
}

async function pollBus() {
  loading.value = true
  error.value = ''
  try {
    const result = await callTool('agent_bus_poll', {
      channel: channel.value || 'tasks/api',
      limit: 50
    })
    const text = result?.result?.content?.[0]?.text || result?.content?.[0]?.text || ''
    busMessages.value = text ? text.split('\n').filter(Boolean) : []
  } catch (e) {
    error.value = e?.message || 'Failed to poll agent bus'
  } finally {
    loading.value = false
  }
}

async function publishMessage() {
  const text = messageText.value.trim()
  if (!text) return
  loading.value = true
  error.value = ''
  try {
    await callTool('agent_bus_publish', {
      channel: channel.value || 'tasks/api',
      message: text,
      sender: sender.value || 'ade-ui'
    })
    messageText.value = ''
    await pollBus()
  } catch (e) {
    error.value = e?.message || 'Failed to publish message'
  } finally {
    loading.value = false
  }
}

async function loadSessions() {
  loading.value = true
  error.value = ''
  try {
    const result = await callTool('session_list', {})
    const text = result?.result?.content?.[0]?.text || result?.content?.[0]?.text || ''
    sessions.value = text ? text.split('\n').filter(Boolean) : []
  } catch (e) {
    error.value = e?.message || 'Failed to load sessions'
  } finally {
    loading.value = false
  }
}

function switchTab(tab) {
  activeTab.value = tab
  error.value = ''
  if (tab === 'bus') pollBus()
  else if (tab === 'sessions') loadSessions()
}

onMounted(() => {
  pollBus()
})
</script>

<template>
  <div class="agents-view">
    <header class="view-header">
      <h1>Connected Agents</h1>
      <div class="header-actions">
        <button class="btn btn-ghost" @click="activeTab === 'bus' ? pollBus() : loadSessions()" :disabled="loading">
          {{ loading ? 'Loading...' : 'Refresh' }}
        </button>
      </div>
    </header>

    <main class="view-main">
      <div class="tabs">
        <button class="tab" :class="{ active: activeTab === 'bus' }" @click="switchTab('bus')">Agent Bus</button>
        <button class="tab" :class="{ active: activeTab === 'sessions' }" @click="switchTab('sessions')">Sessions</button>
      </div>

      <section v-if="activeTab === 'bus'" class="tab-panel">
        <div class="channel-row">
          <label>Channel:</label>
          <input v-model="channel" type="text" placeholder="tasks/api" class="input-sm" />
          <label>Sender:</label>
          <input v-model="sender" type="text" placeholder="ade-ui" class="input-sm" />
        </div>
        <div class="publish-row">
          <input
            v-model="messageText"
            type="text"
            placeholder="Enter message to publish..."
            @keydown.enter="publishMessage"
          />
          <button class="btn btn-primary" @click="publishMessage" :disabled="loading || !messageText.trim()">
            Publish
          </button>
        </div>
        <h2>Messages</h2>
        <div v-if="loading && !busMessages.length" class="state">Loading bus history...</div>
        <div v-else-if="error" class="state error">{{ error }}</div>
        <div v-else-if="!busMessages.length" class="state">No messages yet.</div>
        <div v-else class="msg-list">
          <div v-for="(msg, i) in busMessages" :key="i" class="msg-item">{{ msg }}</div>
        </div>
      </section>

      <section v-else-if="activeTab === 'sessions'" class="tab-panel">
        <h2>Active Sessions</h2>
        <div v-if="loading && !sessions.length" class="state">Loading sessions...</div>
        <div v-else-if="error" class="state error">{{ error }}</div>
        <div v-else-if="!sessions.length" class="state">No active sessions.</div>
        <div v-else class="msg-list">
          <div v-for="(s, i) in sessions" :key="i" class="msg-item session-item">{{ s }}</div>
        </div>
      </section>
    </main>
  </div>
</template>

<style scoped>
.agents-view { display:flex; flex-direction:column; height:100%; color:var(--color-text); }
.view-header { display:flex; justify-content:space-between; align-items:center; padding:16px 20px; border-bottom:1px solid var(--color-border); }
.view-main { flex:1; padding:20px; overflow:auto; display:flex; flex-direction:column; gap:16px; }
.tabs { display:flex; gap:8px; }
.tab { padding:8px 12px; border-radius:6px; border:1px solid var(--color-border); background:transparent; color:var(--color-text-secondary); cursor:pointer; }
.tab.active { background:var(--color-surface); color:var(--color-text); border-color:var(--color-primary); }
.tab-panel { display:flex; flex-direction:column; gap:12px; }
.tab-panel h2 { font-size:13px; text-transform:uppercase; letter-spacing:0.08em; color:var(--color-text-secondary); margin:0; }
.channel-row { display:flex; gap:8px; align-items:center; }
.channel-row label { font-size:12px; color:var(--color-text-secondary); }
.input-sm { width:140px; padding:6px 8px; border-radius:6px; border:1px solid var(--color-border); background:var(--color-surface); color:var(--color-text); font-size:13px; }
.publish-row { display:flex; gap:8px; }
.publish-row input { flex:1; padding:8px 10px; border-radius:6px; border:1px solid var(--color-border); background:var(--color-surface); color:var(--color-text); }
.state { color:var(--color-text-secondary); }
.state.error { color:var(--color-danger); }
.msg-list { display:flex; flex-direction:column; gap:6px; }
.msg-item { background:var(--color-surface); border:1px solid var(--color-border); border-radius:6px; padding:8px 10px; font-family:ui-monospace,SFMono-Regular,Menlo,Monaco,Consolas,monospace; font-size:12px; line-height:1.5; }
.session-item { color:var(--color-primary); }
</style>
