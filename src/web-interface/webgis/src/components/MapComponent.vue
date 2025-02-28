<template>
  <div ref="mapContainer" class="map-container"></div>
</template>

<script>
import { ref, onMounted, onUnmounted } from 'vue';
import { useLayerStore } from '../store/layers';

// OpenLayers imports
import 'ol/ol.css';
import Map from 'ol/Map';
import View from 'ol/View';
import TileLayer from 'ol/layer/Tile';
import OSM from 'ol/source/OSM';
import { fromLonLat } from 'ol/proj';
import { defaults as defaultControls } from 'ol/control';

export default {
  name: 'MapComponent',
  setup() {
    const mapContainer = ref(null);
    const map = ref(null);
    const layerStore = useLayerStore();
    
    // Initialize the map when the component is mounted
    onMounted(() => {
      if (mapContainer.value) {
        // Create the OpenLayers map
        map.value = new Map({
          target: mapContainer.value,
          layers: [
            // Base OSM layer
            new TileLayer({
              source: new OSM(),
              title: 'OpenStreetMap',
              type: 'base',
              visible: true
            })
          ],
          view: new View({
            center: fromLonLat([37.618423, 55.751244]), // Default center: Moscow
            zoom: 10
          }),
          controls: defaultControls({
            attribution: true,
            zoom: true,
            rotate: false
          })
        });
        
        // Load initial layers from store
        loadLayers();
        
        // Subscribe to layer changes
        layerStore.$subscribe((mutation, state) => {
          loadLayers();
        });
      }
    });
    
    // Clean up on component unmount
    onUnmounted(() => {
      if (map.value) {
        map.value.setTarget(null);
        map.value = null;
      }
    });
    
    // Function to load layers from the store
    const loadLayers = () => {
      // This function will be implemented to add layers from the API
      // For now, it's a placeholder
      console.log('Loading layers from store...');
    };
    
    // Expose map and container for other components
    return {
      mapContainer,
      map
    };
  }
}
</script>

<style scoped>
.map-container {
  width: 100%;
  height: 100%;
  position: relative;
  background-color: #f5f5f5;
}
</style> 