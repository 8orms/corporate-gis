/**
 * Функции для работы с информацией о слоях ГИС-платформы
 */

// Конфигурация GeoServer
const geoserverUrl = '/geoserver';
const rasterInstance = 'ecw';    // Инстанция для растровых данных
const workspace = 'TEST';      // Рабочее пространство для растровых данных
const layerName = '2020-2021';     // Имя слоя растровых данных

// Получение экстента слоя из GeoServer через GetCapabilities
function getLayerExtent(workspace, layerName, callback) {
    const capabilitiesUrl = `${geoserverUrl}/${rasterInstance}/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetCapabilities`;
    console.log(`Запрашиваем информацию о слое ${workspace}:${layerName} из: ${capabilitiesUrl}`);
    
    fetch(capabilitiesUrl)
        .then(response => {
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }
            return response.text();
        })
        .then(text => {
            const parser = new ol.format.WMSCapabilities();
            const capabilities = parser.read(text);
            
            console.log('Получены данные о возможностях WMS:', capabilities);
            
            // Получаем информацию о слоях
            let layers = [];
            
            if (capabilities.Capability && capabilities.Capability.Layer) {
                // Проверяем, есть ли слои в виде массива или они вложены глубже
                if (Array.isArray(capabilities.Capability.Layer.Layer)) {
                    layers = capabilities.Capability.Layer.Layer;
                } else if (capabilities.Capability.Layer.Layer) {
                    // Если это один слой, создаем массив из него
                    layers = [capabilities.Capability.Layer.Layer];
                }
            }
            
            if (layers.length === 0) {
                console.warn('Не найдены слои в ответе GetCapabilities:', capabilities);
                callback(null);
                return;
            }
            
            console.log(`Найдено ${layers.length} слоев в ответе GetCapabilities`);
            
            // Ищем наш слой
            const targetLayerName = `${workspace}:${layerName}`;
            const targetLayer = layers.find(layer => layer.Name === targetLayerName || layer.name === targetLayerName || layer.n === targetLayerName);
            
            if (targetLayer) {
                console.log('Найден слой:', targetLayer);
                
                // Получаем границы слоя - проверяем различные свойства
                let bbox = null;
                
                if (targetLayer.EX_GeographicBoundingBox) {
                    bbox = targetLayer.EX_GeographicBoundingBox;
                } else if (targetLayer.BoundingBox && targetLayer.BoundingBox.length > 0) {
                    // Используем первый BoundingBox для EPSG:4326
                    const wgs84BBox = targetLayer.BoundingBox.find(bbox => bbox.crs === 'CRS:84' || bbox.crs === 'EPSG:4326');
                    if (wgs84BBox) {
                        bbox = {
                            westBoundLongitude: wgs84BBox.minx,
                            southBoundLatitude: wgs84BBox.miny,
                            eastBoundLongitude: wgs84BBox.maxx,
                            northBoundLatitude: wgs84BBox.maxy
                        };
                    }
                }
                
                if (bbox) {
                    // Преобразуем в формат [minX, minY, maxX, maxY]
                    const extent = [
                        bbox.westBoundLongitude,
                        bbox.southBoundLatitude,
                        bbox.eastBoundLongitude,
                        bbox.northBoundLatitude
                    ];
                    
                    console.log('Получен экстент слоя в WGS 84:', extent);
                    
                    // Преобразуем в проекцию Web Mercator
                    const webMercatorExtent = ol.proj.transformExtent(
                        extent,
                        'EPSG:4326',  // исходная система координат (WGS 84)
                        'EPSG:3857'   // целевая проекция (Web Mercator)
                    );
                    
                    console.log('Преобразованный экстент в Web Mercator:', webMercatorExtent);
                    
                    // Вызываем callback с полученным экстентом
                    callback(webMercatorExtent);
                } else {
                    console.warn(`Слой ${targetLayerName} найден, но не имеет информации о границах:`, targetLayer);
                    callback(null);
                }
            } else {
                console.warn(`Слой ${targetLayerName} не найден в списке слоев:`, layers.map(l => l.Name || l.name || l.n));
                callback(null);
            }
        })
        .catch(error => {
            console.error(`Ошибка при получении границ слоя ${workspace}:${layerName}:`, error);
            callback(null);
        });
}

// Получение и отображение информации о слое (метаданные)
function displayLayerMetadata(workspace, layerName) {
    const url = `${geoserverUrl}/${rasterInstance}/wms?service=WMS&version=1.3.0&request=GetCapabilities`;
    
    fetch(url)
        .then(response => {
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }
            return response.text();
        })
        .then(text => {
            const parser = new ol.format.WMSCapabilities();
            const capabilities = parser.read(text);
            
            // Получаем информацию о слоях
            const layers = capabilities.Capability.Layer.Layer;
            
            if (!layers) {
                console.warn('Не найдены слои в ответе GetCapabilities');
                return;
            }
            
            // Ищем наш слой
            const targetLayer = layers.find(layer => layer.Name === `${workspace}:${layerName}`);
            
            if (targetLayer) {
                // Создаем HTML с информацией о слое
                let html = `<h4>${targetLayer.Title || targetLayer.Name}</h4>`;
                
                if (targetLayer.Abstract) {
                    html += `<p>${targetLayer.Abstract}</p>`;
                }
                
                if (targetLayer.KeywordList && targetLayer.KeywordList.length > 0) {
                    html += `<p><strong>Ключевые слова:</strong> ${targetLayer.KeywordList.join(', ')}</p>`;
                }
                
                if (targetLayer.EX_GeographicBoundingBox) {
                    const bbox = targetLayer.EX_GeographicBoundingBox;
                    html += `<p><strong>Координаты:</strong><br>`;
                    html += `Запад: ${bbox.westBoundLongitude.toFixed(6)}<br>`;
                    html += `Юг: ${bbox.southBoundLatitude.toFixed(6)}<br>`;
                    html += `Восток: ${bbox.eastBoundLongitude.toFixed(6)}<br>`;
                    html += `Север: ${bbox.northBoundLatitude.toFixed(6)}</p>`;
                }
                
                // Показываем информацию в панели
                const infoPanel = document.getElementById('layer-info-panel');
                if (infoPanel) {
                    infoPanel.innerHTML = html;
                    infoPanel.style.display = 'block';
                    
                    // Добавляем кнопку закрытия
                    const closeButton = document.createElement('button');
                    closeButton.textContent = '✕';
                    closeButton.className = 'close-btn';
                    closeButton.addEventListener('click', function() {
                        infoPanel.style.display = 'none';
                    });
                    infoPanel.prepend(closeButton);
                } else {
                    console.log('Метаданные слоя:', html);
                }
            } else {
                console.warn(`Слой ${workspace}:${layerName} не найден`);
                alert(`Слой ${workspace}:${layerName} не найден в GeoServer. Проверьте, что слой опубликован.`);
            }
        })
        .catch(error => {
            console.error('Ошибка при получении метаданных слоя:', error);
            alert('Ошибка при получении метаданных слоя. Проверьте соединение с GeoServer.');
        });
}

// Получение информации о точке (GetFeatureInfo)
function getPointInfo(map, layers, pixel) {
    const viewResolution = map.getView().getResolution();
    const coordinate = map.getCoordinateFromPixel(pixel);
    
    // Формируем промисы для каждого слоя
    const promises = layers
        .filter(layer => layer.getVisible())
        .map(layer => {
            const source = layer.getSource();
            if (!source.getFeatureInfoUrl) return null;
            
            const url = source.getFeatureInfoUrl(
                coordinate,
                viewResolution,
                'EPSG:3857',
                {'INFO_FORMAT': 'application/json'}
            );
            
            if (!url) return null;
            
            return fetch(url)
                .then(response => response.json())
                .then(data => ({
                    layerTitle: layer.get('title'),
                    data: data
                }))
                .catch(error => {
                    console.error(`Ошибка при получении данных для слоя ${layer.get('title')}:`, error);
                    return null;
                });
        })
        .filter(Boolean); // Удаляем null значения
    
    // Ждем выполнения всех запросов
    Promise.all(promises)
        .then(results => {
            // Фильтруем результаты, чтобы убрать пустые
            const validResults = results.filter(result => 
                result && result.data && result.data.features && result.data.features.length > 0
            );
            
            if (validResults.length > 0) {
                // Здесь можно отобразить результаты в UI
                // Например, в виде всплывающего окна или боковой панели
                console.log('Найдена информация по точке:', validResults);
                
                // Создаем HTML с информацией
                let html = '<div class="feature-info">';
                
                validResults.forEach(result => {
                    html += `<h4>${result.layerTitle}</h4>`;
                    
                    result.data.features.forEach(feature => {
                        html += '<table class="feature-table">';
                        
                        if (feature.properties) {
                            Object.entries(feature.properties).forEach(([key, value]) => {
                                html += `<tr><th>${key}</th><td>${value}</td></tr>`;
                            });
                        }
                        
                        html += '</table>';
                    });
                });
                
                html += '</div>';
                
                // Отображаем информацию в попапе или панели
                const popup = document.getElementById('map-popup');
                if (popup) {
                    popup.innerHTML = html;
                    popup.style.display = 'block';
                    
                    // Позиционируем попап у точки клика
                    const mapEl = document.getElementById('map');
                    const mapRect = mapEl.getBoundingClientRect();
                    
                    popup.style.left = `${pixel[0] + 10}px`;
                    popup.style.top = `${pixel[1] + 10}px`;
                    
                    // Если попап выходит за границы карты, корректируем позицию
                    const popupRect = popup.getBoundingClientRect();
                    
                    if (popupRect.right > mapRect.right) {
                        popup.style.left = `${pixel[0] - popupRect.width - 10}px`;
                    }
                    
                    if (popupRect.bottom > mapRect.bottom) {
                        popup.style.top = `${pixel[1] - popupRect.height - 10}px`;
                    }
                } else {
                    console.log('HTML для отображения информации:', html);
                }
            } else {
                console.log('Нет данных для этой точки');
                
                // Если есть попап, скрываем его
                const popup = document.getElementById('map-popup');
                if (popup) {
                    popup.style.display = 'none';
                }
            }
        });
} 