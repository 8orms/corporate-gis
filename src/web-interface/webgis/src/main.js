import { createApp } from 'vue';
import { createPinia } from 'pinia';
import App from './App.vue';
import router from './router';
import './assets/css/main.css';

// Initialize the Vue application
const app = createApp(App);

// Add Pinia for state management
const pinia = createPinia();
app.use(pinia);

// Add Vue Router
app.use(router);

// Mount the application
app.mount('#app'); 