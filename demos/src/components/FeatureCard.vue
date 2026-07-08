<template>
  <component
    :is="tag"
    class="feature-card"
    v-bind="linkProps"
    :class="cardClasses"
    :tabindex="clickable ? '0' : undefined"
    :role="clickable ? 'button' : undefined"
    :aria-disabled="disabled ? 'true' : undefined"
    @click="onClick"
    @keydown.enter="onClick"
    @keydown.space.prevent="onClick"
  >
    <div v-if="hasBadge" class="feature-badge" :class="`feature-badge--${badgeVariant}`">
      {{ badge }}
    </div>

    <div v-if="icon || $slots.icon" class="feature-icon" :class="iconClasses">
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

    <div v-if="$slots.footer" class="feature-footer">
      <slot name="footer" />
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
  iconVariant: {
    type: String,
    default: 'default',
    validator: (value) => ['default', 'filled', 'outlined', 'subtle'].includes(value)
  },
  title: {
    type: String,
    required: true
  },
  description: {
    type: String,
    default: ''
  },
  badge: {
    type: String,
    default: ''
  },
  badgeVariant: {
    type: String,
    default: 'default',
    validator: (value) => ['default', 'success', 'warning', 'danger', 'info'].includes(value)
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
  },
  elevation: {
    type: String,
    default: 'default',
    validator: (value) => ['none', 'default', 'raised', 'overlay'].includes(value)
  }
})

const emit = defineEmits(['click'])

const hasBadge = computed(() => Boolean(props.badge) || Boolean(props.$slots.badge))

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

const cardClasses = computed(() => ({
  'feature-card--clickable': clickable.value,
  'feature-card--disabled': props.disabled,
  [`feature-card--elevation-${props.elevation}`]: true,
  'feature-card--has-badge': hasBadge.value
}))

const iconClasses = computed(() => ({
  [`feature-icon--${props.iconVariant}`]: props.iconVariant !== 'default'
}))

const badgeVariant = computed(() => {
  const variants = ['default', 'success', 'warning', 'danger', 'info']
  return variants.includes(props.badgeVariant) ? props.badgeVariant : 'default'
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
  --feature-card-accent-weak: rgba(88, 166, 255, 0.12);
  --feature-card-badge-default-bg: #30363d;
  --feature-card-badge-default-text: #e6edf3;
  --feature-card-badge-success-bg: #238636;
  --feature-card-badge-success-text: #ffffff;
  --feature-card-badge-warning-bg: #9e6a03;
  --feature-card-badge-warning-text: #ffffff;
  --feature-card-badge-danger-bg: #da3633;
  --feature-card-badge-danger-text: #ffffff;
  --feature-card-badge-info-bg: #1f6feb;
  --feature-card-badge-info-text: #ffffff;

  background: var(--feature-card-bg);
  border: 1px solid var(--feature-card-border);
  border-radius: 14px;
  padding: 1.5rem;
  color: var(--feature-card-text);
  transition: border-color 0.25s ease, transform 0.25s cubic-bezier(0.22, 1, 0.36, 1), box-shadow 0.25s cubic-bezier(0.22, 1, 0.36, 1), background 0.25s ease;
  text-decoration: none;
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
  position: relative;
  overflow: hidden;
}

.feature-card--has-badge {
  padding-top: 1.25rem;
}

.feature-card--clickable {
  cursor: pointer;
}

.feature-card--clickable:hover {
  border-color: var(--feature-card-accent);
  transform: translateY(-4px);
  box-shadow:
    0 2px 4px rgba(0, 0, 0, 0.18),
    0 8px 24px rgba(0, 0, 0, 0.28),
    0 0 0 1px rgba(88, 166, 255, 0.08) inset;
}

.feature-card--clickable:active {
  transform: translateY(-2px) scale(1.005);
  box-shadow:
    0 1px 2px rgba(0, 0, 0, 0.22),
    0 4px 12px rgba(0, 0, 0, 0.32);
}

.feature-card--clickable:focus-visible {
  outline: 2px solid var(--feature-card-accent);
  outline-offset: 3px;
}

.feature-card--disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.feature-card--elevation-none {
  box-shadow: none;
}

.feature-card--elevation-default {
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.12), 0 1px 2px rgba(0, 0, 0, 0.16);
}

.feature-card--elevation-raised {
  box-shadow:
    0 4px 6px rgba(0, 0, 0, 0.15),
    0 10px 20px rgba(0, 0, 0, 0.22);
}

.feature-card--elevation-overlay {
  box-shadow:
    0 20px 40px rgba(0, 0, 0, 0.35),
    0 0 0 1px rgba(255, 255, 255, 0.06) inset;
}

.feature-card--elevation-overlay:hover {
  box-shadow:
    0 24px 48px rgba(0, 0, 0, 0.42),
    0 0 0 1px rgba(88, 166, 255, 0.14) inset;
}

.feature-badge {
  position: absolute;
  top: 0.75rem;
  right: 0.75rem;
  font-size: 0.65rem;
  font-weight: 600;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  padding: 0.2rem 0.5rem;
  border-radius: 999px;
  line-height: 1.4;
}

.feature-badge--default {
  background: var(--feature-card-badge-default-bg);
  color: var(--feature-card-badge-default-text);
}

.feature-badge--success {
  background: var(--feature-card-badge-success-bg);
  color: var(--feature-card-badge-success-text);
}

.feature-badge--warning {
  background: var(--feature-card-badge-warning-bg);
  color: var(--feature-card-badge-warning-text);
}

.feature-badge--danger {
  background: var(--feature-card-badge-danger-bg);
  color: var(--feature-card-badge-danger-text);
}

.feature-badge--info {
  background: var(--feature-card-badge-info-bg);
  color: var(--feature-card-badge-info-text);
}

.feature-icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 3rem;
  height: 3rem;
  border-radius: 12px;
  font-size: 1.75rem;
  line-height: 1;
  margin-bottom: 0.25rem;
  background: transparent;
  color: var(--feature-card-accent);
  transition: background 0.25s ease, color 0.25s ease, transform 0.25s cubic-bezier(0.22, 1, 0.36, 1);
}

.feature-icon--filled {
  background: var(--feature-card-accent-weak);
  color: var(--feature-card-accent);
}

.feature-icon--outlined {
  background: transparent;
  border: 1.5px solid var(--feature-card-accent);
  color: var(--feature-card-accent);
}

.feature-icon--subtle {
  background: rgba(230, 237, 243, 0.06);
  color: var(--feature-card-text-muted);
}

.feature-card--clickable:hover .feature-icon {
  transform: translateY(-2px) scale(1.05);
}

.feature-card--clickable:hover .feature-icon--filled {
  background: var(--feature-card-accent);
  color: #ffffff;
}

.feature-card--clickable:hover .feature-icon--outlined {
  background: var(--feature-card-accent-weak);
}

.feature-header {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.feature-title {
  font-size: 1.125rem;
  font-weight: 650;
  color: var(--feature-card-text);
  margin: 0;
  letter-spacing: -0.01em;
}

.feature-body {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.feature-description {
  font-size: 0.9rem;
  color: var(--feature-card-text-muted);
  line-height: 1.65;
  margin: 0;
}

.feature-footer {
  margin-top: auto;
  padding-top: 0.5rem;
}
</style>
