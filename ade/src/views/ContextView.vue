<script setup>
import { ref, onMounted } from 'vue'
import { invoke } from '@tauri-apps/api/core'

const tab = ref('memory')
const loading = ref(false)
const error = ref('')

// Memory
const memoryQuery = ref('')
const memoryResult = ref('')

// Decisions
const decisionsResult = ref('')
const newDecision = ref({ title: '', context: '', decision: '', consequences: '' })
const showDecisionForm = ref(false)

// Diagnostics
const diagnosticsResult = ref('')

async function callTool(name, args = {}) {
  return await invoke('ade_mcp_call_tool', {
    name,
    args: JSON.stringify(args)
  })
}

async function readResource(uri) {
  return await invoke('ade_mcp_read_resource', { uri })
}

function extractText(result) {
  try {
    const parsed = typeof result === 'string' ? JSON.parse(result) : result
    return parsed?.result?.content?.[0]?.text || parsed?.content?.[0]?.text || JSON.stringify(parsed, null, 2)
  } catch {
    return String(result)
  }
}

async function loadMemory() {
  loading.value = true
  error.value = ''
  try {
    if (memoryQuery.value.trim()) {
      const result = await callTool('memory_search', { query: memoryQuery.value, limit: 20 })
      memoryResult.value = extractText(result)
    } else {
      const result = await callTool('workspace_snapshot', {})
      memoryResult.value = extractText(result)
    }
  } catch (e) {
    error.value = e?.message || 'Failed to load memory'
  } finally {
    loading.value = false
  }
}

async function loadDecisions() {
  loading.value = true
  error.value = ''
  try {
    const result = await readResource('context://decisions')
    memoryResult.value = extractText(result)
  } catch (e) {
    error.value = e?.message || 'Failed to load decisions'
  } finally {
    loading.value = false
  }
}

async function logDecision() {
  const d = newDecision.value
  if (!d.title || !d.context || !d.decision) return
  loading.value = true
  error.value = ''
  try {
    await callTool('decision_log', {
      title: d.title,
      context: d.context,
      decision: d.decision,
      consequences: d.consequences
    })
    newDecision.value = { title: '', context: '', decision: '', consequences: '' }
    showDecisionForm.value = false
    await loadDecisions()
  } catch (e) {
    error.value = e?.message || 'Failed to log decision'
  } finally {
    loading.value = false
  }
}

async function loadDiagnostics() {
  loading.value = true
  error.value = ''
  try {
    const result = await readResource('context://diagnostics/active')
    diagnosticsResult.value = extractText(result)
  } catch (e) {
    error.value = e?.message || 'Failed to load diagnostics'
  } finally {
    loading.value = false
  }
}

async function resolveAll() {
  loading.value = true
  error.value = ''
  try {
    await callTool('diagnostics_resolve', {})
    await loadDiagnostics()
  } catch (e) {
    error.value = e?.message || 'Failed to resolve diagnostics'
  } finally {
    loading.value = false
  }
}

function switchTab(next) {
  tab.value = next
  error.value = ''
  if (next === 'memory') loadMemory()
  else if (next === 'decisions') loadDecisions()
  else if (next === 'diagnostics') loadDiagnostics()
}

onMounted(() => {
  loadMemory()
})
</script>

<template>
  <div class="context-view">
    <header class="view-header">
      <h1>Shared Context</h1>
    </header>
    <main class="view-main">
      <div class="tabs">
        <button class="tab" :class="{ active: tab === 'memory' }" @click="switchTab('memory')">Memory</button>
        <button class="tab" :class="{ active: tab === 'decisions' }" @click="switchTab('decisions')">Decisions</button>
        <button class="tab" :class="{ active: tab === 'diagnostics' }" @click="switchTab('diagnostics')">Diagnostics</button>
      </div>

      <section class="tab-panel">
        <div v-if="loading && !memoryResult && !diagnosticsResult" class="state">Loading...</div>
        <div v-else-if="error" class="state error">{{ error }}</div>

        <!-- Memory -->
        <template v-if="tab === 'memory'">
          <div class="search-row">
            <input v-model="memoryQuery" type="text" placeholder="Search memory or leave empty for snapshot" @keydown.enter="loadMemory" />
            <button class="btn btn-primary" @click="loadMemory">Search</button>
          </div>
          <pre v-if="memoryResult" class="output">{{ memoryResult }}</pre>
          <div v-else class="state">No memory items found.</div>
        </template>

        <!-- Decisions -->
        <template v-if="tab === 'decisions'">
          <div class="toolbar">
            <button class="btn btn-primary" @click="showDecisionForm = !showDecisionForm">
              {{ showDecisionForm ? 'Cancel' : '+ Log Decision' }}
            </button>
          </div>
          <div v-if="showDecisionForm" class="decision-form">
            <input v-model="newDecision.title" type="text" placeholder="Title" />
            <textarea v-model="newDecision.context" placeholder="Context (why this decision was needed)" rows="2"></textarea>
            <textarea v-model="newDecision.decision" placeholder="Decision (what was decided)" rows="2"></textarea>
            <textarea v-model="newDecision.consequences" placeholder="Consequences (optional)" rows="2"></textarea>
            <button class="btn btn-primary" @click="logDecision" :disabled="loading || !newDecision.title || !newDecision.context || !newDecision.decision">
              {{ loading ? 'Saving...' : 'Save' }}
            </button>
          </div>
          <pre v-if="memoryResult && tab === 'decisions' && !showDecisionForm" class="output">{{ memoryResult }}</pre>
          <div v-else-if="tab === 'decisions' && !showDecisionForm" class="state">Loading decisions...</div>
        </template>

        <!-- Diagnostics -->
        <template v-if="tab === 'diagnostics'">
          <div class="toolbar">
            <button class="btn btn-ghost" @click="resolveAll" :disabled="loading">Resolve All</button>
          </div>
          <pre v-if="diagnosticsResult" class="output">{{ diagnosticsResult }}</pre>
          <div v-else class="state">No unresolved diagnostics.</div>
        </template>
      </section>
    </main>
  </div>
</template>

<style scoped>
.context-view { display:flex; flex-direction:column; height:100%; color:var(--color-text); }
.view-header { padding:16px 20px; border-bottom:1px solid var(--color-border); }
.view-main { flex:1; padding:20px; overflow:auto; display:flex; flex-direction:column; gap:16px; }
.tabs { display:flex; gap:8px; }
.tab { padding:8px 12px; border-radius:6px; border:1px solid var(--color-border); background:transparent; color:var(--color-text-secondary); cursor:pointer; }
.tab.active { background:var(--color-surface); color:var(--color-text); border-color:var(--color-primary); }
.tab-panel { display:flex; flex-direction:column; gap:12px; }
.search-row { display:flex; gap:8px; }
.search-row input { flex:1; padding:8px 10px; border-radius:6px; border:1px solid var(--color-border); background:var(--color-surface); color:var(--color-text); }
.toolbar { display:flex; gap:8px; }
.decision-form { display:flex; flex-direction:column; gap:8px; background:var(--color-surface); border:1px solid var(--color-border); border-radius:8px; padding:12px; }
.decision-form input, .decision-form textarea { padding:8px 10px; border-radius:6px; border:1px solid var(--color-border); background:var(--color-bg); color:var(--color-text); font-family:inherit; font-size:13px; resize:vertical; }
.output { margin:0; white-space:pre-wrap; word-break:break-word; font-family:ui-monospace,SFMono-Regular,Menlo,Monaco,Consolas,monospace; font-size:13px; line-height:1.6; background:var(--color-surface); border:1px solid var(--color-border); border-radius:8px; padding:12px; }
.state { color:var(--color-text-secondary); }
.state.error { color:var(--color-danger); }
</style>
