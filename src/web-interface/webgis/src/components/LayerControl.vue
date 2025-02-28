<template>
  <div class="layer-control">
    <div class="layer-control-header">
      <h3>Слои карты</h3>
      <div class="layer-control-actions">
        <button @click="refreshLayers" title="Обновить слои">
          <span class="icon">🔄</span>
        </button>
      </div>
    </div>

    <div v-if="isLoading" class="layer-loading">
      Загрузка слоев...
    </div>
    
    <div v-else-if="error" class="layer-error">
      {{ error }}
      <button @click="refreshLayers">Повторить</button>
    </div>
    
    <div v-else class="layer-categories">
      <div class="category-selector">
        <select v-model="selectedCategory">
          <option :value="null">Все категории</option>
          <option v-for="category in categories" :key="category.id" :value="category.id">
            {{ category.name }}
          </option>
        </select>
      </div>
      
      <div class="layer-list">
        <div 
          v-for="layer in filteredLayers" 
          :key="layer.id" 
          class="layer-item"
          :class="{ 'layer-active': isLayerActive(layer.id) }"
        >
          <div class="layer-item-header">
            <label class="layer-checkbox">
              <input 
                type="checkbox" 
                :checked="isLayerActive(layer.id)"
                @change="toggleLayer(layer.id)"
              />
              <span class="layer-title">{{ layer.title }}</span>
            </label>
            <span class="layer-type" :title="getLayerTypeTitle(layer.layer_type)">
              {{ getLayerTypeIcon(layer.layer_type) }}
            </span>
          </div>
          <div class="layer-item-details" v-if="isLayerActive(layer.id)">
            <div class="layer-opacity">
              <label>Прозрачность:</label>
              <input type="range" min="0" max="100" value="100" />
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { computed, onMounted, ref } from 'vue';
import { useLayerStore } from '../store/layers';

export default {
  name: 'LayerControl',
  setup() {
    const layerStore = useLayerStore();
    const selectedCategory = ref(null);
    
    // Load layers and categories on component mount
    onMounted(async () => {
      if (layerStore.layers.length === 0) {
        await layerStore.fetchLayers();
      }
      if (layerStore.categories.length === 0) {
        await layerStore.fetchCategories();
      }
    });
    
    // Get filtered layers based on selected category
    const filteredLayers = computed(() => {
      if (!selectedCategory.value) {
        return layerStore.layers;
      }
      return layerStore.layersByCategory(selectedCategory.value);
    });
    
    // Helper function to get layer type icon
    const getLayerTypeIcon = (type) => {
      switch (type) {
        case 'vector':
          return '🔷'; // Vector layer icon
        case 'raster':
          return '🔶'; // Raster layer icon
        case 'ecw':
          return '🖼️'; // ECW layer icon
        default:
          return '📄'; // Default layer icon
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
    
    // Function to toggle layer visibility
    const toggleLayer = (layerId) => {
      layerStore.toggleLayerVisibility(layerId);
    };
    
    // Function to refresh layers
    const refreshLayers = async () => {
      await layerStore.fetchLayers();
      await layerStore.fetchCategories();
    };
    
    return {
      layers: computed(() => layerStore.layers),
      categories: computed(() => layerStore.categories),
      isLoading: computed(() => layerStore.isLoading),
      error: computed(() => layerStore.error),
      isLayerActive: (id) => layerStore.isLayerActive(id),
      selectedCategory,
      filteredLayers,
      toggleLayer,
      refreshLayers,
      getLayerTypeIcon,
      getLayerTypeTitle
    };
  }
}
</script>

<style scoped>
.layer-control {
  background-color: white;
  border-radius: 8px;
  box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
  width: 300px;
  max-height: calc(100vh - 200px);
  display: flex;
  flex-direction: column;
  position: absolute;
  top: 20px;
  right: 20px;
  z-index: 1000;
}

.layer-control-header {
  padding: 12px 16px;
  border-bottom: 1px solid #eee;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.layer-control-header h3 {
  margin: 0;
  font-size: 16px;
  font-weight: 600;
}

.layer-control-actions button {
  background: none;
  border: none;
  cursor: pointer;
  font-size: 16px;
}

.category-selector {
  padding: 12px 16px;
  border-bottom: 1px solid #eee;
}

.category-selector select {
  width: 100%;
  padding: 8px;
  border: 1px solid #ddd;
  border-radius: 4px;
}

.layer-list {
  padding: 8px;
  overflow-y: auto;
  flex: 1;
}

.layer-item {
  padding: 8px;
  border-radius: 4px;
  margin-bottom: 8px;
  border: 1px solid #eee;
}

.layer-item-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.layer-checkbox {
  display: flex;
  align-items: center;
  cursor: pointer;
}

.layer-title {
  margin-left: 8px;
  font-size: 14px;
}

.layer-active {
  background-color: #f0f7ff;
  border-color: #d0e3ff;
}

.layer-item-details {
  margin-top: 8px;
  padding-top: 8px;
  border-top: 1px solid #eee;
}

.layer-opacity {
  display: flex;
  align-items: center;
  font-size: 12px;
}

.layer-opacity label {
  margin-right: 8px;
  min-width: 80px;
}

.layer-opacity input {
  flex: 1;
}

.layer-loading, .layer-error {
  padding: 20px;
  text-align: center;
  color: #666;
}

.layer-error {
  color: #d9534f;
}

.layer-error button {
  margin-top: 8px;
  padding: 4px 8px;
  background-color: #f0f0f0;
  border: 1px solid #ddd;
  border-radius: 4px;
  cursor: pointer;
}
</style> 