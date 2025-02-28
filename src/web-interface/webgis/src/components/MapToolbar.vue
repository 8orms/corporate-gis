<template>
  <div class="map-toolbar">
    <div class="toolbar-group">
      <button 
        class="toolbar-button" 
        @click="zoomIn" 
        title="Приблизить"
      >
        <span class="icon">➕</span>
      </button>
      <button 
        class="toolbar-button" 
        @click="zoomOut" 
        title="Отдалить"
      >
        <span class="icon">➖</span>
      </button>
      <button 
        class="toolbar-button" 
        @click="zoomToExtent" 
        title="Показать всю карту"
      >
        <span class="icon">🔍</span>
      </button>
    </div>
    
    <div class="toolbar-group">
      <button 
        class="toolbar-button" 
        :class="{ active: activeTool === 'measure-line' }"
        @click="setTool('measure-line')" 
        title="Измерить расстояние"
      >
        <span class="icon">📏</span>
      </button>
      <button 
        class="toolbar-button" 
        :class="{ active: activeTool === 'measure-area' }"
        @click="setTool('measure-area')" 
        title="Измерить площадь"
      >
        <span class="icon">📐</span>
      </button>
    </div>
    
    <div class="toolbar-group">
      <button 
        class="toolbar-button" 
        @click="printMap" 
        title="Печать карты"
      >
        <span class="icon">🖨️</span>
      </button>
      <button 
        class="toolbar-button" 
        @click="exportMap" 
        title="Экспорт карты"
      >
        <span class="icon">💾</span>
      </button>
    </div>
  </div>
</template>

<script>
import { ref } from 'vue';

export default {
  name: 'MapToolbar',
  props: {
    map: {
      type: Object,
      required: false
    }
  },
  setup(props) {
    const activeTool = ref(null);
    
    // Function to zoom in
    const zoomIn = () => {
      if (props.map) {
        const view = props.map.getView();
        const zoom = view.getZoom();
        view.animate({
          zoom: zoom + 1,
          duration: 250
        });
      }
    };
    
    // Function to zoom out
    const zoomOut = () => {
      if (props.map) {
        const view = props.map.getView();
        const zoom = view.getZoom();
        view.animate({
          zoom: zoom - 1,
          duration: 250
        });
      }
    };
    
    // Function to zoom to full extent
    const zoomToExtent = () => {
      if (props.map) {
        // For now, we'll just reset to the default view
        const view = props.map.getView();
        view.animate({
          center: [0, 0],
          zoom: 2,
          duration: 500
        });
      }
    };
    
    // Function to set the active tool
    const setTool = (tool) => {
      // If the tool is already active, deactivate it
      if (activeTool.value === tool) {
        activeTool.value = null;
      } else {
        activeTool.value = tool;
      }
      
      // Here we would implement the actual tool functionality
      // For now, this is just a placeholder
      console.log(`Tool activated: ${activeTool.value}`);
    };
    
    // Function to print the map
    const printMap = () => {
      console.log('Print map functionality not implemented yet');
      // Here we would implement the print functionality
    };
    
    // Function to export the map
    const exportMap = () => {
      console.log('Export map functionality not implemented yet');
      // Here we would implement the export functionality
    };
    
    return {
      activeTool,
      zoomIn,
      zoomOut,
      zoomToExtent,
      setTool,
      printMap,
      exportMap
    };
  }
}
</script>

<style scoped>
.map-toolbar {
  position: absolute;
  top: 20px;
  left: 20px;
  z-index: 1000;
  background-color: white;
  border-radius: 8px;
  box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding: 8px;
}

.toolbar-group {
  display: flex;
  flex-direction: column;
  gap: 4px;
  border-bottom: 1px solid #eee;
  padding-bottom: 8px;
}

.toolbar-group:last-child {
  border-bottom: none;
  padding-bottom: 0;
}

.toolbar-button {
  width: 36px;
  height: 36px;
  border-radius: 4px;
  border: 1px solid #eee;
  background-color: white;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: all 0.2s;
}

.toolbar-button:hover {
  background-color: #f5f5f5;
}

.toolbar-button.active {
  background-color: #e6f0ff;
  border-color: #b3d7ff;
}

.icon {
  font-size: 16px;
}
</style> 