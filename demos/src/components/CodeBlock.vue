<template>
  <div class="code-block" :class="{ 'code-block--line-numbers': lineNumbers }">
    <div class="code-header" v-if="language || showCopy">
      <div class="code-header-left">
        <span v-if="language" class="code-language">{{ language }}</span>
      </div>
      <button
        v-if="showCopy"
        class="copy-button"
        :class="{ 'copy-button--copied': copied }"
        @click="copyCode"
        :aria-label="copied ? 'Copied' : 'Copy code'"
      >
        <svg class="copy-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <rect x="9" y="9" width="13" height="13" rx="2" ry="2" />
          <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" />
        </svg>
        <svg class="copy-icon copy-icon--check" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
          <polyline points="20 6 9 17 4 12" />
        </svg>
        <span class="copy-label">{{ copied ? 'Copied!' : 'Copy' }}</span>
      </button>
    </div>
    <div class="code-wrapper">
      <div v-if="lineNumbers" class="line-numbers" aria-hidden="true">
        <span v-for="n in lineCount" :key="n" class="line-number">{{ n }}</span>
      </div>
      <pre class="code-pre"><code v-html="highlightedCode" /></pre>
    </div>
  </div>
</template>

<script setup>
import { computed, ref, watch } from 'vue'

const props = defineProps({
  code: {
    type: String,
    required: true
  },
  language: {
    type: String,
    default: ''
  },
  lineNumbers: {
    type: Boolean,
    default: false
  },
  showCopy: {
    type: Boolean,
    default: true
  }
})

const copied = ref(false)

const lines = computed(() => {
  if (!props.code) return []
  return props.code.split('\n')
})

const lineCount = computed(() => lines.value.length)

const highlightedCode = computed(() => {
  if (!props.code) return ''
  const lang = props.language.toLowerCase()
  if (!lang) return escapeHtml(props.code)
  return highlightSyntax(props.code, lang)
})

function escapeHtml(text) {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
}

function highlightSyntax(code, language) {
  const tokenizer = tokenizers[language] || tokenizers.plain
  const tokens = tokenizer(code)
  return tokens.map(token => {
    const escaped = escapeHtml(token.content)
    if (!token.type) return escaped
    return `<span class="token token--${token.type}">${escaped}</span>`
  }).join('')
}

const tokenizers = {
  plain(code) {
    return [{ content: code, type: null }]
  },
  javascript(code) {
    return tokenize(code, [
      { pattern: /(\/\/[^\n]*)/g, type: 'comment' },
      { pattern: /(\/\*[\s\S]*?\*\/)/g, type: 'comment' },
      { pattern: /\b(const|let|var|function|return|if|else|for|while|class|import|export|from|default|async|await|try|catch|throw|new|this|extends|super|yield|of|in|switch|case|break|continue|typeof|instanceof)\b/g, type: 'keyword' },
      { pattern: /\b(true|false|null|undefined|NaN|Infinity)\b/g, type: 'boolean' },
      { pattern: /("(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'|`(?:[^`\\]|\\.)*`)/g, type: 'string' },
      { pattern: /\b(\d+\.?\d*(?:e[+-]?\d+)?)\b/g, type: 'number' },
      { pattern: /\b([A-Z][a-zA-Z0-9]*)\b/g, type: 'class' },
      { pattern: /([a-zA-Z_$][a-zA-Z0-9_$]*)\s*\(/g, type: 'function', group: 1 }
    ])
  },
  typescript(code) {
    return tokenize(code, [
      { pattern: /(\/\/[^\n]*)/g, type: 'comment' },
      { pattern: /(\/\*[\s\S]*?\*\/)/g, type: 'comment' },
      { pattern: /\b(const|let|var|function|return|if|else|for|while|class|import|export|from|default|async|await|try|catch|throw|new|this|extends|super|yield|of|in|switch|case|break|continue|typeof|instanceof|interface|type|enum|implements|public|private|protected|readonly|static|abstract|as|is|keyof|infer|never|unknown|any)\b/g, type: 'keyword' },
      { pattern: /\b(true|false|null|undefined|NaN|Infinity)\b/g, type: 'boolean' },
      { pattern: /("(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'|`(?:[^`\\]|\\.)*`)/g, type: 'string' },
      { pattern: /\b(\d+\.?\d*(?:e[+-]?\d+)?)\b/g, type: 'number' },
      { pattern: /\b([A-Z][a-zA-Z0-9]*)\b/g, type: 'class' },
      { pattern: /([a-zA-Z_$][a-zA-Z0-9_$]*)\s*\(/g, type: 'function', group: 1 }
    ])
  },
  vue(code) {
    return tokenize(code, [
      { pattern: /(&lt;\/?[a-zA-Z][a-zA-Z0-9-]*)/g, type: 'tag' },
      { pattern: /(\{\{.*?\}\})/g, type: 'template' },
      { pattern: /(@[a-zA-Z]+)(?==)/g, type: 'event' },
      { pattern: /(:[a-zA-Z-]+)(?=)/g, type: 'binding' },
      { pattern: /\b(v-if|v-else|v-for|v-show|v-model|v-bind|v-on|v-slot|v-html|v-text|v-pre|v-cloak|v-once|v-memo)\b/g, type: 'directive' },
      { pattern: /("(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*')/g, type: 'string' }
    ])
  },
  html(code) {
    return tokenize(code, [
      { pattern: /(&lt;\/?[a-zA-Z][a-zA-Z0-9-]*)/g, type: 'tag' },
      { pattern: /\s([a-zA-Z-]+)=/g, type: 'attribute' },
      { pattern: /("(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*')/g, type: 'string' },
      { pattern: /(&lt;!--[\s\S]*?--&gt;)/g, type: 'comment' }
    ])
  },
  css(code) {
    return tokenize(code, [
      { pattern: /(\/\*[\s\S]*?\*\/)/g, type: 'comment' },
      { pattern: /([.#]?[a-zA-Z_-][a-zA-Z0-9_-]*)\s*\{/g, type: 'selector' },
      { pattern: /([a-zA-Z-]+)\s*:/g, type: 'property' },
      { pattern: /:\s*([^;{}]+)/g, type: 'value', prefix: ': ' },
      { pattern: /(@[a-zA-Z-]+)/g, type: 'at-rule' }
    ])
  },
  json(code) {
    return tokenize(code, [
      { pattern: /("(?:[^"\\]|\\.)*")\s*:/g, type: 'key' },
      { pattern: /:\s*("(?:[^"\\]|\\.)*")/g, type: 'string' },
      { pattern: /\b(true|false|null)\b/g, type: 'boolean' },
      { pattern: /\b(\d+\.?\d*)\b/g, type: 'number' }
    ])
  },
  bash(code) {
    return tokenize(code, [
      { pattern: /(#.*)/g, type: 'comment' },
      { pattern: /(\$\w+)/g, type: 'variable' },
      { pattern: /("(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*')/g, type: 'string' },
      { pattern: /\b(echo|cd|ls|rm|cp|mv|mkdir|rmdir|cat|grep|sed|awk|find|sort|uniq|wc|head|tail|chmod|chown|sudo|apt|npm|yarn|pip|docker|kubectl|git|curl|wget|ssh|scp|tar|gzip|gunzip|zip|unzip|ps|kill|top|htop|df|du|free|whoami|pwd|export|source|alias|function|if|then|else|fi|for|do|done|while|case|esac|return|exit)\b/g, type: 'keyword' }
    ])
  }
}

function tokenize(code, rules) {
  const tokens = [{ content: code, type: null }]

  for (const rule of rules) {
    const result = []
    for (const token of tokens) {
      if (token.type && token.type !== rule.type) {
        result.push(token)
        continue
      }
      const parts = token.content.split(rule.pattern)
      let i = 0
      while (i < parts.length) {
        if (i % 2 === 1) {
          const match = parts[i]
          result.push({ content: match, type: rule.type })
        } else if (parts[i]) {
          result.push({ content: parts[i], type: null })
        }
        i++
      }
    }
    tokens.length = 0
    tokens.push(...result)
  }

  return tokens
}

watch(() => props.code, () => {
  copied.value = false
})

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
  background: var(--bg-card, #0d1117);
  border: 1px solid var(--border-color, #30363d);
  border-radius: 12px;
  overflow: hidden;
}

.code-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.6rem 1rem;
  background: var(--bg-hover, #161b22);
  border-bottom: 1px solid var(--border-color, #30363d);
}

.code-header-left {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.code-language {
  font-size: 0.75rem;
  font-weight: 500;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: var(--text-secondary, #8b949e);
}

.copy-button {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  font-size: 0.75rem;
  font-weight: 500;
  color: var(--text-secondary, #8b949e);
  background: transparent;
  border: 1px solid var(--border-color, #30363d);
  border-radius: 6px;
  padding: 0.3rem 0.6rem;
  cursor: pointer;
  transition: background 0.15s ease, border-color 0.15s ease, color 0.15s ease;
}

.copy-button:hover {
  background: var(--bg-active, #21262d);
  border-color: var(--accent, #58a6ff);
  color: var(--accent, #58a6ff);
}

.copy-button--copied {
  color: #3fb950;
  border-color: #3fb950;
}

.copy-icon {
  width: 14px;
  height: 14px;
  flex-shrink: 0;
}

.copy-icon--check {
  display: none;
}

.copy-button--copied .copy-icon--regular {
  display: none;
}

.copy-button--copied .copy-icon--check {
  display: block;
}

.copy-label {
  line-height: 1;
}

.code-wrapper {
  display: flex;
  position: relative;
}

.line-numbers {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  padding: 1rem 0.75rem 1rem 1rem;
  user-select: none;
  border-right: 1px solid var(--border-color, #21262d);
  background: rgba(255, 255, 255, 0.02);
}

.line-number {
  font-family: 'SF Mono', 'Fira Code', 'Cascadia Code', monospace;
  font-size: 0.8rem;
  line-height: 1.6;
  color: var(--text-secondary, #484f58);
  min-width: 1.5rem;
  text-align: right;
}

.code-pre {
  margin: 0;
  padding: 1rem;
  overflow-x: auto;
  flex: 1;
  counter-reset: line;
}

.code-pre code {
  font-family: 'SF Mono', 'Fira Code', 'Cascadia Code', monospace;
  font-size: 0.85rem;
  line-height: 1.6;
  background: transparent;
  padding: 0;
}

/* Syntax highlighting tokens */
.token--keyword { color: #ff7b72; }
.token--string { color: #a5d6ff; }
.token--comment { color: #8b949e; font-style: italic; }
.token--number { color: #79c0ff; }
.token--boolean { color: #ff7b72; }
.token--function { color: #d2a8ff; }
.token--class { color: #ffa657; }
.token--tag { color: #7ee787; }
.token--template { color: #ff7b72; }
.token--event { color: #79c0ff; }
.token--binding { color: #79c0ff; }
.token--directive { color: #ff7b72; }
.token--attribute { color: #79c0ff; }
.token--selector { color: #7ee787; }
.token--property { color: #79c0ff; }
.token--value { color: #a5d6ff; }
.token--at-rule { color: #ff7b72; }
.token--key { color: #79c0ff; }
.token--variable { color: #ffa657; }
</style>
