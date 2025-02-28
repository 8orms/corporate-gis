import { createRouter, createWebHistory } from 'vue-router';

// Import views
const MapView = () => import('../views/MapView.vue');
const LayersView = () => import('../views/LayersView.vue');
const AboutView = () => import('../views/AboutView.vue');
const NotFoundView = () => import('../views/NotFoundView.vue');

// Define routes
const routes = [
  {
    path: '/',
    name: 'map',
    component: MapView,
    meta: { title: 'Карта' }
  },
  {
    path: '/layers',
    name: 'layers',
    component: LayersView,
    meta: { title: 'Слои' }
  },
  {
    path: '/about',
    name: 'about',
    component: AboutView,
    meta: { title: 'О системе' }
  },
  {
    path: '/:pathMatch(.*)*',
    name: 'not-found',
    component: NotFoundView,
    meta: { title: 'Страница не найдена' }
  }
];

// Create router instance
const router = createRouter({
  history: createWebHistory('/webgis/'),
  routes
});

// Navigation guard to update page title
router.beforeEach((to, from, next) => {
  document.title = to.meta.title ? `${to.meta.title} | Корпоративная ГИС` : 'Корпоративная ГИС';
  next();
});

export default router; 