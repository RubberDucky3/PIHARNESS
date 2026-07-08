<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'

const router = useRouter()
const route = useRoute()
const mobileMenuOpen = ref(false)

const navLinks = [
  { path: '/', label: 'Home', icon: '⌂' },
  { path: '/demos', label: 'Demos', icon: '▶' },
  { path: '/commands', label: 'Commands', icon: '〉' },
  { path: '/about', label: 'About', icon: 'ⓘ' },
]

const isActive = (path) => route.path === path

function navigate(path) {
  router.push(path)
  mobileMenuOpen.value = false
}

function toggleMobileMenu() {
  mobileMenuOpen.value = !mobileMenuOpen.value
}

onMounted(() => {
  // Close mobile menu on route change
  router.afterEach(() => { mobileMenuOpen.value = false })
})
</script>

<template>
  <div class="app-shell">
    <!-- Nav -->
    <header class="nav-bar">
      <div class="nav-inner">
        <router-link to="/" class="nav-brand" @click="mobileMenuOpen = false">
          <span class="brand-icon">⛁</span>
          <span class="brand-text">PIHARNESS</span>
          <span class="brand-badge">v1.0</span>
        </router-link>

        <button class="mobile-toggle" @click="toggleMobileMenu" aria-label="Menu">
          <span class="hamburger" :class="{ open: mobileMenuOpen }">
            <span></span><span></span><span></span>
          </span>
        </button>

        <nav class="nav-links" :class="{ open: mobileMenuOpen }">
          <router-link
            v-for="link in navLinks"
            :key="link.path"
            :to="link.path"
            class="nav-link"
            :class="{ active: isActive(link.path) }"
          >
            <span class="nav-link-icon">{{ link.icon }}</span>
            {{ link.label }}
          </router-link>
        </nav>
      </div>
    </header>

    <!-- Main content -->
    <main class="main-content">
      <router-view v-slot="{ Component, route }">
        <transition name="page-fade" mode="out-in">
          <component :is="Component" :key="route.path" />
        </transition>
      </router-view>
    </main>

    <!-- Footer -->
    <footer class="site-footer">
      <div class="footer-inner">
        <div class="footer-links">
          <a href="https://github.com/RubberDucky3/PIHARNESS" target="_blank" rel="noopener">GitHub</a>
          <span class="footer-sep">·</span>
          <router-link to="/commands">Commands</router-link>
          <span class="footer-sep">·</span>
          <router-link to="/about">About</router-link>
        </div>
        <div class="footer-meta">
          <span class="footer-version">v1.0</span>
          <span class="footer-sep">·</span>
          <span>MIT License</span>
          <span class="footer-sep">·</span>
          <span class="footer-year">{{ new Date().getFullYear() }}</span>
        </div>
      </div>
    </footer>
  </div>
</template>

<style>
/* ── Global nav & footer styles (not scoped so they apply across views) ── */

/* Nav */
.nav-bar {
  position: sticky;
  top: 0;
  z-index: 100;
  background: rgba(13, 17, 23, 0.92);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
  border-bottom: 1px solid var(--border-color);
}

.nav-inner {
  max-width: 1200px;
  margin: 0 auto;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 1.5rem;
  height: 56px;
}

.nav-brand {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  text-decoration: none;
  color: var(--text-primary);
  font-weight: 700;
  font-size: 1.1rem;
}

.brand-icon { font-size: 1.3rem; }
.brand-badge {
  font-size: 0.65rem;
  font-weight: 600;
  padding: 0.15rem 0.45rem;
  border-radius: 999px;
  background: var(--accent);
  color: #fff;
  opacity: 0.8;
}

.nav-links {
  display: flex;
  gap: 0.25rem;
  align-items: center;
}

.nav-link {
  display: flex;
  align-items: center;
  gap: 0.35rem;
  padding: 0.45rem 0.85rem;
  border-radius: 8px;
  text-decoration: none;
  color: var(--text-secondary);
  font-size: 0.9rem;
  font-weight: 500;
  transition: all 0.15s;
}

.nav-link:hover {
  color: var(--text-primary);
  background: var(--bg-hover);
}

.nav-link.active {
  color: var(--accent);
  background: rgba(88, 166, 255, 0.1);
}

.nav-link-icon { font-size: 0.85rem; }

/* Mobile toggle */
.mobile-toggle {
  display: none;
  background: none;
  border: none;
  cursor: pointer;
  padding: 0.4rem;
}

.hamburger {
  display: flex;
  flex-direction: column;
  gap: 4px;
  width: 20px;
}

.hamburger span {
  display: block;
  height: 2px;
  background: var(--text-primary);
  border-radius: 2px;
  transition: all 0.2s;
}

.hamburger.open span:nth-child(1) { transform: translateY(6px) rotate(45deg); }
.hamburger.open span:nth-child(2) { opacity: 0; }
.hamburger.open span:nth-child(3) { transform: translateY(-6px) rotate(-45deg); }

/* Footer */
.site-footer {
  border-top: 1px solid var(--border-color);
  margin-top: auto;
}

.footer-inner {
  max-width: 1200px;
  margin: 0 auto;
  padding: 1.5rem;
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 0.8rem;
  color: var(--text-secondary);
}

.footer-links {
  display: flex;
  gap: 0.5rem;
  align-items: center;
}

.footer-links a {
  color: var(--text-secondary);
  text-decoration: none;
}

.footer-links a:hover { color: var(--accent); }

.footer-meta { display: flex; gap: 0.5rem; align-items: center; }
.footer-sep { opacity: 0.3; }

/* Page transitions */
.page-fade-enter-active,
.page-fade-leave-active {
  transition: opacity 0.12s ease;
}

.page-fade-enter-from,
.page-fade-leave-to {
  opacity: 0;
}

/* Responsive nav */
@media (max-width: 640px) {
  .mobile-toggle { display: block; }

  .nav-links {
    position: fixed;
    top: 56px;
    left: 0;
    right: 0;
    flex-direction: column;
    background: rgba(13, 17, 23, 0.98);
    backdrop-filter: blur(12px);
    border-bottom: 1px solid var(--border-color);
    padding: 0.5rem;
    gap: 0;
    transform: translateY(-100%);
    opacity: 0;
    pointer-events: none;
    transition: all 0.2s;
  }

  .nav-links.open {
    transform: translateY(0);
    opacity: 1;
    pointer-events: auto;
  }

  .nav-link {
    padding: 0.75rem 1rem;
    width: 100%;
    border-radius: 6px;
  }

  .footer-inner {
    flex-direction: column;
    gap: 0.5rem;
    text-align: center;
  }
}
</style>
