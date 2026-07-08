<template>
  <div class="code-block">
    <div class="code-header" v-if="language">
      <span class="code-language">{{ language }}</span>
      <button class="copy-button" @click="copyCode" title="Copy code">
        {{ copied ? 'Copied!' : 'Copy' }}
      </button>
    </div>
    <pre class="code-pre"><code>{{ code }}</code></pre>
  </div>
</template>

<script setup>
import { ref } from 'vue'

const props = defineProps({
  code: {
    type: String,
    required: true
  },
  language: {
    type: String,
    default: ''
  }
})

const copied = ref(false)

const copyCode = async () => {
  try {
    await navigator.clipboard.writeText(props.code)
    copied.value = true
    setTimeout(() => {
      copied.value = false
    }, 2000)
  } catch (err) {
    console.error('Failed to copy code:', err)
  }
}
</script>

<style scoped>
.code-block {
  background: var(--bg-card);
  border: 1px solid var(--border-color);
  border-radius: 12px;
  overflow: hidden;
}

.code-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.5rem 1rem;
  background: var(--bg-hover, #1c2128);
  border-bottom: 1px solid var(--border-color);
}

.code-language {
  font-size: 0.75rem;
  font-weight: 500;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--text-secondary);
}

.copy-button {
  font-size: 0.75rem;
  color: var(--accent);
  background: transparent;
  border: 1px solid var(--border-color);
  border-radius: 6px;
  padding: 0.25rem 0.5rem;
  cursor: pointer;
  transition: background 0.15s ease, border-color 0.15s ease;
}

.copy-button:hover {
  background: var(--bg-active, #21262d);
  border-color: var(--accent);
}

.code-pre {
  margin: 0;
  padding: 1rem;
  overflow-x: auto;
}

.code-pre code {
  font-family: 'SF Mono', 'Fira Code', 'Cascadia Code', monospace;
  font-size: 0.85rem;
  line-height: 1.6;
  color: var(--text-primary);
  background: transparent;
  padding: 0;
}
</style>
