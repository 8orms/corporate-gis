import { defineStore } from 'pinia';
// We'll implement the API later, but we reference it here
// import { layersApi } from '../api/layers';

// Define the layer store
export const useLayerStore = defineStore('layers', {
  // State
  state: () => ({
    layers: [],
    activeLayerIds: [],
    isLoading: false,
    error: null,
    categories: [],
    selectedCategory: null
  }),
  
  // Getters
  getters: {
    // Get all visible layers
    visibleLayers: (state) => {
      return state.layers.filter(layer => state.activeLayerIds.includes(layer.id));
    },
    
    // Get all layer categories
    layerCategories: (state) => {
      return state.categories;
    },
    
    // Get layers by category
    layersByCategory: (state) => (categoryId) => {
      if (!categoryId) return state.layers;
      return state.layers.filter(layer => 
        layer.categories && layer.categories.includes(categoryId)
      );
    },
    
    // Check if a layer is active
    isLayerActive: (state) => (layerId) => {
      return state.activeLayerIds.includes(layerId);
    }
  },
  
  // Actions
  actions: {
    // Fetch all layers from the API
    async fetchLayers() {
      this.isLoading = true;
      this.error = null;
      
      try {
        // For now, we'll use mock data until we implement the API
        // const response = await layersApi.getLayers();
        // this.layers = response.data;
        
        // Mock data for testing
        this.layers = [
          {
            id: 1,
            name: 'buildings',
            title: 'Здания',
            workspace: 'vector',
            layer_type: 'vector',
            categories: [1],
            is_published: true
          },
          {
            id: 2,
            name: 'roads',
            title: 'Дороги',
            workspace: 'vector',
            layer_type: 'vector',
            categories: [1],
            is_published: true
          },
          {
            id: 3,
            name: 'city_orthophoto',
            title: 'Ортофотоплан города',
            workspace: 'ecw',
            layer_type: 'ecw',
            categories: [2],
            is_published: true
          }
        ];
      } catch (error) {
        console.error('Error fetching layers:', error);
        this.error = 'Не удалось загрузить слои. Пожалуйста, попробуйте позже.';
      } finally {
        this.isLoading = false;
      }
    },
    
    // Fetch layer categories
    async fetchCategories() {
      this.isLoading = true;
      this.error = null;
      
      try {
        // For now, we'll use mock data until we implement the API
        // const response = await layersApi.getCategories();
        // this.categories = response.data;
        
        // Mock data for testing
        this.categories = [
          { id: 1, name: 'Базовые слои', description: 'Основные векторные слои' },
          { id: 2, name: 'Растровые слои', description: 'Растровые подложки и ортофотопланы' }
        ];
      } catch (error) {
        console.error('Error fetching categories:', error);
        this.error = 'Не удалось загрузить категории. Пожалуйста, попробуйте позже.';
      } finally {
        this.isLoading = false;
      }
    },
    
    // Toggle layer visibility
    toggleLayerVisibility(layerId) {
      const index = this.activeLayerIds.indexOf(layerId);
      if (index === -1) {
        // Add layer to active layers
        this.activeLayerIds.push(layerId);
      } else {
        // Remove layer from active layers
        this.activeLayerIds.splice(index, 1);
      }
    },
    
    // Set selected category
    setSelectedCategory(categoryId) {
      this.selectedCategory = categoryId;
    }
  }
}); 