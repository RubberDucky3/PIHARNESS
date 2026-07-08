import { createRouter, createWebHashHistory } from 'vue-router'
import HomeView from '../views/HomeView.vue'

const routes = [
  {
    path: '/',
    name: 'Home',
    component: HomeView,
    meta: { title: 'PIHARNESS — AI Orchestrator' },
  },
  {
    path: '/demos',
    name: 'Demos',
    component: () => import('../views/DemosView.vue'),
    meta: { title: 'Demos — PIHARNESS' },
  },
  {
    path: '/commands',
    name: 'Commands',
    component: () => import('../views/CommandsView.vue'),
    meta: { title: 'Commands — PIHARNESS' },
  },
  {
    path: '/about',
    name: 'About',
    component: () => import('../views/AboutView.vue'),
    meta: { title: 'About — PIHARNESS' },
  },
]

const router = createRouter({
  history: createWebHashHistory(),
  routes,
})

// Update document title on route change
router.beforeEach((to, _from, next) => {
  if (to.meta?.title) {
    document.title = to.meta.title
  }
  next()
})

export default router
