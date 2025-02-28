<template>
  <div class="map-page">
    <MapComponent />
    <LayerControl />
    <MapToolbar />
  </div>
</template>

<script>
import MapComponent from '../components/MapComponent.vue';
import LayerControl from '../components/LayerControl.vue';
import MapToolbar from '../components/MapToolbar.vue';

export default {
  name: 'MapView',
  components: {
    MapComponent,
    LayerControl,
    MapToolbar
  }
}
</script>

<style scoped>
.map-page {
  position: relative;
  height: calc(100vh - 120px);
}
</style> 