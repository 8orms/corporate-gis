<template>
  <div class="layers-view">
    <div class="page-header">
      <h1>Управление слоями</h1>
      <div class="actions">
        <button class="btn refresh-btn" @click="refreshLayers">
          <span class="icon">🔄</span> Обновить
        </button>
      </div>
    </div>
    
    <div class="page-content">
      <div class="categories-panel">
        <h2>Категории</h2>
        <div class="categories-list">
          <div 
            class="category-item" 
            :class="{ 'active': selectedCategory === null }"
            @click="selectedCategory = null"
          >
            Все слои
          </div>
          <div 
            v-for="category in categories" 
            :key="category.id" 
            class="category-item"
            :class="{ 'active': selectedCategory === category.id }"
            @click="selectedCategory = category.id"
          >
            {{ category.name }}
            <span class="layer-count">({{ getLayerCountForCategory(category.id) }})</span>
          </div>
        </div>
      </div>
      
      <div class="layers-panel">
        <div class="panel-header">
          <h2>Слои {{ selectedCategoryName ? '- ' + selectedCategoryName : '' }}</h2>
          <div class="filter-actions">
            <input 
              type="text" 
              v-model="searchQuery" 
              placeholder="Поиск слоев..." 
              class="search-input"
            />
            <select v-model="typeFilter" class="type-filter">
              <option value="">Все типы</option>
              <option value="vector">Векторные</option>
              <option value="raster">Растровые</option>
              <option value="ecw">ECW</option>
            </select>
          </div>
        </div>
        
        <div v-if="isLoading" class="loading">
          Загрузка слоев...
        </div>
        
        <div v-else-if="error" class="error">
          {{ error }}
          <button @click="refreshLayers">Повторить</button>
        </div>
        
        <div v-else-if="filteredLayers.length === 0" class="no-layers">
          Нет слоев, соответствующих фильтрам
        </div>
        
        <div v-else class="layers-list">
          <div 
            v-for="layer in filteredLayers" 
            :key="layer.id" 
            class="layer-card"
            :class="{ 
              'active': selectedLayer && selectedLayer.id === layer.id,
              'published': layer.is_published 
            }"
            @click="selectLayer(layer)"
          >
            <div class="layer-card-header">
              <div class="layer-title">{{ layer.title }}</div>
              <div class="layer-type" :title="getLayerTypeTitle(layer.layer_type)">
                {{ getLayerTypeIcon(layer.layer_type) }}
              </div>
            </div>
            <div class="layer-card-content">
              <div class="layer-name">{{ layer.workspace }}:{{ layer.name }}</div>
              <div class="layer-description" v-if="layer.abstract">
                {{ layer.abstract.substring(0, 100) }}{{ layer.abstract.length > 100 ? '...' : '' }}
              </div>
            </div>
            <div class="layer-card-footer">
              <div class="layer-status">
                <span class="status-indicator" :class="{ 'active': layer.is_published }"></span>
                {{ layer.is_published ? 'Опубликован' : 'Скрыт' }}
              </div>
              <div class="layer-date">
                {{ formatDate(layer.last_updated) }}
              </div>
            </div>
          </div>
        </div>
      </div>
      
      <div class="layer-details-panel" v-if="selectedLayer">
        <div class="panel-header">
          <h2>Детали слоя</h2>
          <button class="close-btn" @click="selectedLayer = null">×</button>
        </div>
        
        <div class="layer-details">
          <h3>{{ selectedLayer.title }}</h3>
          
          <div class="detail-group">
            <div class="detail-label">Системное имя:</div>
            <div class="detail-value">{{ selectedLayer.workspace }}:{{ selectedLayer.name }}</div>
          </div>
          
          <div class="detail-group">
            <div class="detail-label">Тип слоя:</div>
            <div class="detail-value">{{ getLayerTypeTitle(selectedLayer.layer_type) }}</div>
          </div>
          
          <div class="detail-group">
            <div class="detail-label">Описание:</div>
            <div class="detail-value">{{ selectedLayer.abstract || 'Нет описания' }}</div>
          </div>
          
          <div class="detail-group">
            <div class="detail-label">Ключевые слова:</div>
            <div class="detail-value">{{ selectedLayer.keywords || 'Нет ключевых слов' }}</div>
          </div>
          
          <div class="detail-group">
            <div class="detail-label">Система координат:</div>
            <div class="detail-value">{{ selectedLayer.srs }}</div>
          </div>
          
          <div class="detail-group">
            <div class="detail-label">Дата создания:</div>
            <div class="detail-value">{{ formatDate(selectedLayer.date_created) }}</div>
          </div>
          
          <div class="detail-group">
            <div class="detail-label">Последнее обновление:</div>
            <div class="detail-value">{{ formatDate(selectedLayer.last_updated) }}</div>
          </div>
          
          <div class="detail-actions">
            <button class="btn" @click="viewOnMap(selectedLayer)">
              Просмотр на карте
            </button>
            <button class="btn" @click="editLayer(selectedLayer)">
              Редактировать
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { ref, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useLayerStore } from '../store/layers';

export default {
  name: 'LayersView',
  setup() {
    const router = useRouter();
    const layerStore = useLayerStore();
    
    const selectedLayer = ref(null);
    const selectedCategory = ref(null);
    const searchQuery = ref('');
    const typeFilter = ref('');
    
    // Load layers and categories on component mount
    onMounted(async () => {
      await layerStore.fetchLayers();
      await layerStore.fetchCategories();
    });
    
    // Get selected category name
    const selectedCategoryName = computed(() => {
      if (!selectedCategory.value) return '';
      const category = layerStore.categories.find(c => c.id === selectedCategory.value);
      return category ? category.name : '';
    });
    
    // Filter layers based on category, search query, and type filter
    const filteredLayers = computed(() => {
      let layers = layerStore.layers;
      
      // Filter by category
      if (selectedCategory.value) {
        layers = layers.filter(layer => 
          layer.categories && layer.categories.includes(selectedCategory.value)
        );
      }
      
      // Filter by search query
      if (searchQuery.value) {
        const query = searchQuery.value.toLowerCase();
        layers = layers.filter(layer => 
          layer.title.toLowerCase().includes(query) || 
          layer.name.toLowerCase().includes(query) ||
          (layer.abstract && layer.abstract.toLowerCase().includes(query))
        );
      }
      
      // Filter by layer type
      if (typeFilter.value) {
        layers = layers.filter(layer => layer.layer_type === typeFilter.value);
      }
      
      return layers;
    });
    
    // Helper function to get layer count for a category
    const getLayerCountForCategory = (categoryId) => {
      return layerStore.layers.filter(layer => 
        layer.categories && layer.categories.includes(categoryId)
      ).length;
    };
    
    // Helper function to get layer type icon
    const getLayerTypeIcon = (type) => {
      switch (type) {
        case 'vector':
          return '🔷';
        case 'raster':
          return '🔶';
        case 'ecw':
          return '🖼️';
        default:
          return '📄';
      }
    };
    
    // Helper function to get layer type title
    const getLayerTypeTitle = (type) => {
      switch (type) {
        case 'vector':
          return 'Векторный слой';
        case 'raster':
          return 'Растровый слой';
        case 'ecw':
          return 'ECW растр';
        default:
          return 'Слой';
      }
    };
    
    // Helper function to format date
    const formatDate = (dateString) => {
      if (!dateString) return '';
      const date = new Date(dateString);
      return date.toLocaleDateString('ru-RU', {
        year: 'numeric',
        month: 'short',
        day: 'numeric'
      });
    };
    
    // Function to select a layer
    const selectLayer = (layer) => {
      selectedLayer.value = layer;
    };
    
    // Function to refresh layers
    const refreshLayers = async () => {
      await layerStore.fetchLayers();
      await layerStore.fetchCategories();
    };
    
    // Function to view layer on map
    const viewOnMap = (layer) => {
      // Add layer to active layers if not already active
      if (!layerStore.isLayerActive(layer.id)) {
        layerStore.toggleLayerVisibility(layer.id);
      }
      
      // Navigate to map view
      router.push({ name: 'map' });
    };
    
    // Function to edit layer (placeholder)
    const editLayer = (layer) => {
      console.log('Edit layer:', layer);
      // This would open an edit form or navigate to an edit page
    };
    
    return {
      layers: computed(() => layerStore.layers),
      categories: computed(() => layerStore.categories),
      isLoading: computed(() => layerStore.isLoading),
      error: computed(() => layerStore.error),
      selectedLayer,
      selectedCategory,
      selectedCategoryName,
      searchQuery,
      typeFilter,
      filteredLayers,
      selectLayer,
      refreshLayers,
      getLayerCountForCategory,
      getLayerTypeIcon,
      getLayerTypeTitle,
      formatDate,
      viewOnMap,
      editLayer
    };
  }
}
</script>

<style scoped>
.layers-view {
  padding: 20px;
  height: calc(100vh - 120px);
  display: flex;
  flex-direction: column;
}

.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
}

.page-header h1 {
  margin: 0;
  font-size: 24px;
  font-weight: 600;
}

.actions {
  display: flex;
  gap: 10px;
}

.btn {
  padding: 8px 16px;
  border-radius: 4px;
  border: 1px solid #ddd;
  background-color: white;
  cursor: pointer;
  display: flex;
  align-items: center;
  gap: 4px;
  transition: all 0.2s;
}

.btn:hover {
  background-color: #f5f5f5;
}

.refresh-btn:hover {
  background-color: #e6f7ff;
  border-color: #91d5ff;
}

.page-content {
  display: flex;
  flex: 1;
  gap: 20px;
  overflow: hidden;
}

.categories-panel {
  width: 250px;
  background-color: white;
  border-radius: 8px;
  box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
  padding: 16px;
}

.categories-panel h2 {
  margin: 0 0 16px 0;
  font-size: 18px;
  font-weight: 600;
}

.categories-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.category-item {
  padding: 8px 12px;
  border-radius: 4px;
  cursor: pointer;
  display: flex;
  justify-content: space-between;
  transition: all 0.2s;
}

.category-item:hover {
  background-color: #f5f5f5;
}

.category-item.active {
  background-color: #e6f7ff;
  font-weight: 500;
}

.layer-count {
  color: #999;
  font-size: 14px;
}

.layers-panel {
  flex: 1;
  background-color: white;
  border-radius: 8px;
  box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
  padding: 16px;
  display: flex;
  flex-direction: column;
}

.layer-details-panel {
  width: 300px;
  background-color: white;
  border-radius: 8px;
  box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
  padding: 16px;
  position: relative;
}

.panel-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
}

.panel-header h2 {
  margin: 0;
  font-size: 18px;
  font-weight: 600;
}

.close-btn {
  background: none;
  border: none;
  font-size: 20px;
  cursor: pointer;
  line-height: 1;
}

.filter-actions {
  display: flex;
  gap: 8px;
}

.search-input, .type-filter {
  padding: 8px;
  border: 1px solid #ddd;
  border-radius: 4px;
}

.search-input {
  width: 200px;
}

.layers-list {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 16px;
  overflow-y: auto;
  padding: 8px 0;
}

.layer-card {
  border: 1px solid #eee;
  border-radius: 8px;
  padding: 16px;
  cursor: pointer;
  transition: all 0.2s;
}

.layer-card:hover {
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}

.layer-card.active {
  border-color: #1890ff;
  background-color: #e6f7ff;
}

.layer-card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 8px;
}

.layer-title {
  font-weight: 600;
  font-size: 16px;
}

.layer-card-content {
  margin-bottom: 12px;
}

.layer-name {
  font-size: 14px;
  color: #666;
  margin-bottom: 4px;
}

.layer-description {
  font-size: 14px;
  color: #333;
}

.layer-card-footer {
  display: flex;
  justify-content: space-between;
  font-size: 12px;
  color: #999;
}

.layer-status {
  display: flex;
  align-items: center;
  gap: 4px;
}

.status-indicator {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background-color: #ccc;
}

.status-indicator.active {
  background-color: #52c41a;
}

.layer-details h3 {
  margin: 0 0 16px 0;
  font-size: 18px;
  font-weight: 600;
}

.detail-group {
  margin-bottom: 12px;
}

.detail-label {
  font-weight: 500;
  font-size: 14px;
  margin-bottom: 4px;
  color: #666;
}

.detail-value {
  font-size: 14px;
}

.detail-actions {
  margin-top: 20px;
  display: flex;
  gap: 8px;
}

.loading, .error, .no-layers {
  padding: 40px;
  text-align: center;
  color: #666;
}

.error {
  color: #f5222d;
}

.error button {
  margin-top: 8px;
}

.no-layers {
  color: #999;
}
</style> 