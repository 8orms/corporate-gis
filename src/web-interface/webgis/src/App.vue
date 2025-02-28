<template>
  <div class="app-container">
    <header class="app-header">
      <div class="logo">
        <h1>Корпоративная ГИС</h1>
      </div>
      <nav class="main-nav">
        <router-link to="/">Карта</router-link>
        <router-link to="/layers">Слои</router-link>
        <router-link to="/about">О системе</router-link>
      </nav>
      <div class="user-panel">
        <button class="user-btn">Войти</button>
      </div>
    </header>
    
    <main class="app-content">
      <router-view />
    </main>
    
    <footer class="app-footer">
      <p>&copy; 2025 Корпоративная ГИС-платформа</p>
    </footer>
  </div>
</template>

<script>
export default {
  name: 'App'
}
</script>

<style>
.app-container {
  display: flex;
  flex-direction: column;
  min-height: 100vh;
  font-family: 'Roboto', sans-serif;
}

.app-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.5rem 1rem;
  background-color: #2c3e50;
  color: white;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.logo h1 {
  margin: 0;
  font-size: 1.2rem;
  font-weight: 500;
}

.main-nav {
  display: flex;
  gap: 1rem;
}

.main-nav a {
  color: white;
  text-decoration: none;
  padding: 0.5rem;
  border-radius: 4px;
  transition: background-color 0.3s;
}

.main-nav a:hover,
.main-nav a.router-link-active {
  background-color: rgba(255, 255, 255, 0.1);
}

.user-btn {
  background-color: transparent;
  border: 1px solid white;
  color: white;
  padding: 0.25rem 0.75rem;
  border-radius: 4px;
  cursor: pointer;
  transition: all 0.3s;
}

.user-btn:hover {
  background-color: white;
  color: #2c3e50;
}

.app-content {
  flex: 1;
  padding: 1rem;
}

.app-footer {
  background-color: #f8f9fa;
  padding: 0.5rem 1rem;
  text-align: center;
  font-size: 0.8rem;
  color: #6c757d;
}
</style> 