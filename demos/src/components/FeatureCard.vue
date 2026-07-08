<template>
  <component
    :is="tag"
    class="feature-card"
    v-bind="linkProps"
    :class="{ 'feature-card--clickable': clickable }"
    :tabindex="clickable ? '0' : undefined"
    :role="clickable ? 'button' : undefined"
    :aria-disabled="disabled ? 'true' : undefined"
    @click="onClick"
    @keydown.enter="onClick"
    @keydown.space.prevent="onClick"
  >
    <div v-if="icon || $slots.icon" class="feature-icon">
      <slot name="icon">
        <span v-if="icon" v-html="icon" />
      </slot>
    </div>

    <div v-if="title || $slots.title" class="feature-header">
      <slot name="title">
        <h3 class="feature-title">{{ title }}</h3>
      </slot>
    </div>

    <div v-if="description || $slots.description || $slots.default" class="feature-body">
      <slot name="description">
        <p v-if="description" class="feature-description">{{ description }}</p>
      </slot>
      <slot />
    </div>
  </component>
</template>

<script setup>
import { computed } from 'vue'

defineOptions({
  name: 'FeatureCard'
})

const props = defineProps({
  icon: {
    type: String,
    default: ''
  },
  title: {
    type: String,
    required: true
  },
  description: {
    type: String,
    default: ''
  },
  to: {
    type: [String, Object],
    default: undefined
  },
  href: {
    type: String,
    default: undefined
  },
  target: {
    type: String,
    default: undefined
  },
  rel: {
    type: String,
    default: undefined
  },
  disabled: {
    type: Boolean,
    default: false
  }
})

const emit = defineEmits(['click'])

const clickable = computed(() => !props.disabled && (props.to || props.href))

const tag = computed(() => {
  if (props.disabled) return 'div'
  if (props.to) return 'router-link'
  if (props.href) return 'a'
  return 'div'
})

const linkProps = computed(() => {
  if (props.to) {
    return { to: props.to }
  }
  if (props.href) {
    return {
      href: props.href,
      target: props.target,
      rel: props.target === '_blank' ? (props.rel || 'noopener noreferrer') : props.rel
    }
  }
  return {}
})

function onClick(event) {
  if (props.disabled) return
  emit('click', event)
}
</script>

<style scoped>
.feature-card {
  --feature-card-bg: #161b22;
  --feature-card-border: #30363d;
  --feature-card-text: #e6edf3;
  --feature-card-text-muted: #8b949e;
  --feature-card-accent: #58a6ff;
  --feature-card-accent-hover: #79c0ff;

  background: var(--feature-card-bg);
  border: 1px solid var(--feature-card-border);
  border-radius: 12px;
  padding: 1.5rem;
  color: var(--feature-card-text);
  transition: border-color 0.2s ease, transform 0.2s ease, box-shadow 0.2s ease;
  text-decoration: none;
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.feature-card--clickable {
  cursor: pointer;
}

.feature-card--clickable:hover {
  border-color: var(--feature-card-accent);
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.25);
}

.feature-card--clickable:focus-visible {
  outline: 2px solid var(--feature-card-accent);
  outline-offset: 2px;
}

.feature-icon {
  font-size: 1.75rem;
  margin-bottom: 0.25rem;
  line-height: 1;
}

.feature-header {
  display: flex;
  align-items: center;
}

.feature-title {
  font-size: 1.125rem;
  font-weight: 600;
  color: var(--feature-card-text);
  margin: 0;
}

.feature-body {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.feature-description {
  font-size: 0.875rem;
  color: var(--feature-card-text-muted);
  line-height: 1.6;
  margin: 0;
}
</style>
