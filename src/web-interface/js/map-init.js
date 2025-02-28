/**
 * Инициализация карты на основе динамической конфигурации слоев
 * 
 * Этот файл содержит функции для инициализации карты OpenLayers
 * с использованием слоев, определенных в автоматически сгенерированном файле
 * generated-layers.js
 */

// Глобальные переменные
let map;
let layerControls = {}; // Хранит ссылки на элементы управления слоями

/**
 * Инициализация карты с динамически загруженными слоями
 */
function initMap() {
    console.log('Инициализация карты...');
    
    // Базовые слои (подложки)
    const osmLayer = new ol.layer.Tile({
        title: 'OpenStreetMap',
        type: 'base',
        visible: true,
        source: new ol.source.OSM()
    });
    
    const satelliteLayer = new ol.layer.Tile({
        title: 'Спутник',
        type: 'base',
        visible: false,
        source: new ol.source.XYZ({
            url: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
            attributions: 'Tiles © <a href="https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer">ArcGIS</a>'
        })
    });
    
    // Создаем массив слоев
    const layers = [osmLayer, satelliteLayer];
    
    // Создаем растровые слои из конфигурации
    if (layerConfig && layerConfig.rasterLayers) {
        layerConfig.rasterLayers.forEach(rasterLayerConfig => {
            console.log(`Создание растрового слоя: ${rasterLayerConfig.id}`);
            
            // Создаем источник данных WMS
            const source = new ol.source.TileWMS({
                url: `${geoserverUrl}/${rasterLayerConfig.instance}/wms`,
                params: {
                    'LAYERS': `${rasterLayerConfig.workspace}:${rasterLayerConfig.layerName}`,
                    'TILED': true,
                    'FORMAT': 'image/png'
                },
                serverType: 'geoserver',
                crossOrigin: 'anonymous'
            });
            
            // Обработчик ошибок загрузки тайлов
            source.on('tileloaderror', function(event) {
                console.warn(`Ошибка загрузки тайла для слоя ${rasterLayerConfig.title}:`, event);
            });
            
            // Создаем слой
            const rasterLayer = new ol.layer.Tile({
                title: rasterLayerConfig.title,
                id: rasterLayerConfig.id,
                type: 'overlay',
                visible: rasterLayerConfig.visible,
                source: source,
                // Дополнительные метаданные
                metadata: {
                    objectId: rasterLayerConfig.objectId,
                    category: rasterLayerConfig.category,
                    year: rasterLayerConfig.year,
                    tags: rasterLayerConfig.tags,
                    layerType: 'raster',
                    workspace: rasterLayerConfig.workspace,
                    layerName: rasterLayerConfig.layerName,
                    instance: rasterLayerConfig.instance
                }
            });
            
            // Добавляем слой в массив
            layers.push(rasterLayer);
        });
    }
    
    // Создаем векторные слои из конфигурации
    if (layerConfig && layerConfig.vectorLayers) {
        layerConfig.vectorLayers.forEach(vectorLayerConfig => {
            console.log(`Создание векторного слоя: ${vectorLayerConfig.id}`);
            
            // Создаем источник данных WFS
            const source = new ol.source.Vector({
                format: new ol.format.GeoJSON(),
                url: function(extent) {
                    return `${geoserverUrl}/${vectorLayerConfig.instance}/wfs?` +
                        'service=WFS&' +
                        'version=1.1.0&' +
                        'request=GetFeature&' +
                        `typeName=${vectorLayerConfig.workspace}:${vectorLayerConfig.layerName}&` +
                        'outputFormat=application/json&' +
                        `bbox=${extent.join(',')},EPSG:3857`;
                },
                strategy: ol.loadingstrategy.bbox
            });
            
            // Обработчик ошибок загрузки данных
            source.on('featuresloaderror', function(event) {
                console.warn(`Ошибка загрузки объектов для слоя ${vectorLayerConfig.title}:`, event);
            });
            
            // Создаем слой
            const vectorLayer = new ol.layer.Vector({
                title: vectorLayerConfig.title,
                id: vectorLayerConfig.id,
                type: 'overlay',
                visible: vectorLayerConfig.visible,
                source: source,
                // Дополнительные метаданные
                metadata: {
                    objectId: vectorLayerConfig.objectId,
                    category: vectorLayerConfig.category,
                    year: vectorLayerConfig.year,
                    tags: vectorLayerConfig.tags,
                    layerType: 'vector',
                    workspace: vectorLayerConfig.workspace,
                    layerName: vectorLayerConfig.layerName,
                    instance: vectorLayerConfig.instance,
                    dataStore: vectorLayerConfig.dataStore,
                    tableName: vectorLayerConfig.tableName
                }
            });
            
            // Добавляем слой в массив
            layers.push(vectorLayer);
        });
    }
    
    // Создаем карту
    map = new ol.Map({
        target: 'map',
        layers: layers,
        view: new ol.View({
            center: ol.proj.fromLonLat([37.618423, 55.751244]), // Центр Москвы
            zoom: 10
        }),
        controls: ol.control.defaults().extend([
            new ol.control.ScaleLine(),
            new ol.control.FullScreen(),
            new ol.control.ZoomSlider()
        ])
    });
    
    // Обновляем панель слоев
    updateLayerPanel();
    
    // Добавляем обработчики событий
    setupEventListeners();
    
    // Проверяем доступность слоев
    checkLayersAvailability();
    
    console.log('Карта успешно инициализирована');
}

/**
 * Проверяет доступность всех слоев
 */
function checkLayersAvailability() {
    console.log('Проверка доступности слоев...');
    
    // Проверяем растровые слои
    if (layerConfig && layerConfig.rasterLayers) {
        layerConfig.rasterLayers.forEach(rasterLayerConfig => {
            checkLayerAvailability(rasterLayerConfig);
        });
    }
    
    // Проверяем векторные слои (можно реализовать аналогичную логику)
}

/**
 * Проверяет доступность отдельного слоя
 * @param {Object} layerConfig - Конфигурация слоя
 */
function checkLayerAvailability(layerConfig) {
    const capabilitiesUrl = `${geoserverUrl}/${layerConfig.instance}/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetCapabilities`;
    
    console.log(`Проверка доступности слоя ${layerConfig.workspace}:${layerConfig.layerName}...`);
    
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
            
            // Получаем информацию о слоях
            let layers = [];
            
            if (capabilities.Capability && capabilities.Capability.Layer) {
                if (Array.isArray(capabilities.Capability.Layer.Layer)) {
                    layers = capabilities.Capability.Layer.Layer;
                } else if (capabilities.Capability.Layer.Layer) {
                    layers = [capabilities.Capability.Layer.Layer];
                }
            }
            
            // Ищем наш слой
            const targetLayerName = `${layerConfig.workspace}:${layerConfig.layerName}`;
            const targetLayer = layers.find(layer => layer.Name === targetLayerName || layer.name === targetLayerName);
            
            // Обновляем UI на основе доступности слоя
            updateLayerStatusUI(layerConfig.id, !!targetLayer);
        })
        .catch(error => {
            console.error(`Ошибка при проверке доступности слоя ${layerConfig.title}:`, error);
            updateLayerStatusUI(layerConfig.id, false);
        });
}

/**
 * Обновляет UI слоя в зависимости от его доступности
 * @param {string} layerId - ID слоя
 * @param {boolean} isAvailable - Доступен ли слой
 */
function updateLayerStatusUI(layerId, isAvailable) {
    const layerControl = layerControls[layerId];
    
    if (layerControl) {
        if (isAvailable) {
            // Слой доступен - убираем предупреждающую иконку если она есть
            const warningIcon = layerControl.querySelector('.layer-warning-icon');
            if (warningIcon) {
                warningIcon.remove();
            }
        } else {
            // Слой недоступен - добавляем предупреждающую иконку если её нет
            if (!layerControl.querySelector('.layer-warning-icon')) {
                const warningIcon = document.createElement('span');
                warningIcon.className = 'layer-warning-icon';
                warningIcon.textContent = '⚠️';
                warningIcon.title = 'Слой недоступен в GeoServer';
                
                const label = layerControl.querySelector('.layer-title');
                if (label) {
                    label.appendChild(warningIcon);
                } else {
                    layerControl.appendChild(warningIcon);
                }
            }
        }
    }
}

/**
 * Настраивает обработчики событий
 */
function setupEventListeners() {
    // Обработчик клика по карте для получения информации о точке
    map.on('singleclick', function(evt) {
        handleMapClick(evt);
    });
    
    // Добавляем обработчик изменения размеров окна
    window.addEventListener('resize', function() {
        map.updateSize();
    });
}

/**
 * Обработчик клика по карте
 * @param {ol.MapBrowserEvent} evt - Событие клика
 */
function handleMapClick(evt) {
    // Получаем все видимые векторные и растровые слои
    const layers = map.getLayers().getArray().filter(layer => 
        layer.getVisible() && layer.get('type') === 'overlay'
    );
    
    // Если есть видимые слои, запрашиваем информацию о точке
    if (layers.length > 0) {
        getPointInfo(map, layers, evt.pixel);
    }
}

/**
 * Обновляет панель слоев
 */
function updateLayerPanel() {
    const layerList = document.getElementById('layer-list');
    if (!layerList) return;
    
    // Очищаем текущее содержимое
    layerList.innerHTML = '';
    layerControls = {};
    
    // Создаем группу для базовых слоев
    const baseLayersGroup = document.createElement('div');
    baseLayersGroup.className = 'layer-group';
    baseLayersGroup.innerHTML = '<h3>Базовые карты</h3>';
    
    // Создаем группу для объектов
    const objectsGroup = {};
    
    // Получаем все слои карты
    const layers = map.getLayers().getArray();
    
    // Добавляем базовые слои
    const baseLayers = layers.filter(layer => layer.get('type') === 'base');
    
    baseLayers.forEach(layer => {
        const layerItem = document.createElement('div');
        layerItem.className = 'layer-item';
        
        const radio = document.createElement('input');
        radio.type = 'radio';
        radio.name = 'base-layer';
        radio.checked = layer.getVisible();
        
        radio.addEventListener('change', function() {
            // Скрываем все базовые слои
            baseLayers.forEach(l => l.setVisible(false));
            // Показываем выбранный слой
            layer.setVisible(true);
        });
        
        const label = document.createElement('label');
        label.className = 'layer-title';
        label.appendChild(radio);
        label.appendChild(document.createTextNode(' ' + layer.get('title')));
        
        layerItem.appendChild(label);
        baseLayersGroup.appendChild(layerItem);
    });
    
    layerList.appendChild(baseLayersGroup);
    
    // Создаем разделитель
    const divider = document.createElement('hr');
    layerList.appendChild(divider);
    
    // Сначала создаем группы объектов
    if (layerConfig && layerConfig.objects) {
        layerConfig.objects.forEach(object => {
            const objGroup = document.createElement('div');
            objGroup.className = 'layer-group object-group';
            objGroup.innerHTML = `<h3>${object.name}</h3>`;
            
            // Добавляем кнопку для приближения к объекту
            const zoomButton = document.createElement('button');
            zoomButton.className = 'zoom-to-object-btn';
            zoomButton.textContent = '⎋';
            zoomButton.title = 'Приблизить к объекту';
            zoomButton.addEventListener('click', function() {
                zoomToObject(object.id);
            });
            
            objGroup.querySelector('h3').appendChild(zoomButton);
            
            // Сохраняем группу для дальнейшего использования
            objectsGroup[object.id] = objGroup;
        });
    }
    
    // Получаем все оверлейные слои
    const overlayLayers = layers.filter(layer => layer.get('type') === 'overlay');
    
    // Добавляем оверлейные слои в соответствующие группы объектов
    overlayLayers.forEach(layer => {
        const metadata = layer.get('metadata') || {};
        const objectId = metadata.objectId;
        
        // Создаем элемент управления слоем
        const layerItem = document.createElement('div');
        layerItem.className = 'layer-item';
        
        // Создаем чекбокс для видимости слоя
        const checkbox = document.createElement('input');
        checkbox.type = 'checkbox';
        checkbox.checked = layer.getVisible();
        
        checkbox.addEventListener('change', function() {
            layer.setVisible(this.checked);
        });
        
        // Создаем метку слоя
        const label = document.createElement('label');
        label.className = 'layer-title';
        label.appendChild(checkbox);
        label.appendChild(document.createTextNode(' ' + layer.get('title')));
        
        // Добавляем кнопки управления слоем
        const controlsDiv = document.createElement('div');
        controlsDiv.className = 'layer-controls';
        
        // Кнопка приближения к слою
        const zoomButton = document.createElement('button');
        zoomButton.className = 'zoom-button';
        zoomButton.textContent = '⎋';
        zoomButton.title = 'Приблизить к слою';
        zoomButton.addEventListener('click', function() {
            zoomToLayer(layer);
        });
        
        // Кнопка информации о слое
        const infoButton = document.createElement('button');
        infoButton.className = 'info-button';
        infoButton.textContent = 'ℹ️';
        infoButton.title = 'Информация о слое';
        infoButton.addEventListener('click', function() {
            showLayerInfo(layer);
        });
        
        controlsDiv.appendChild(zoomButton);
        controlsDiv.appendChild(infoButton);
        
        layerItem.appendChild(label);
        layerItem.appendChild(controlsDiv);
        
        // Сохраняем ссылку на элемент управления
        if (layer.get('id')) {
            layerControls[layer.get('id')] = layerItem;
        }
        
        // Добавляем слой в группу объекта, если он принадлежит объекту
        if (objectId && objectsGroup[objectId]) {
            objectsGroup[objectId].appendChild(layerItem);
        } else {
            // Если слой не принадлежит ни одному объекту, добавляем его напрямую в список
            layerList.appendChild(layerItem);
        }
    });
    
    // Добавляем группы объектов в панель
    Object.values(objectsGroup).forEach(group => {
        layerList.appendChild(group);
    });
}

/**
 * Приближает карту к границам объекта
 * @param {string} objectId - ID объекта
 */
function zoomToObject(objectId) {
    const object = LayerUtils.getObjectById(objectId);
    
    if (object && object.bbox) {
        // Преобразуем bbox из EPSG:4326 в EPSG:3857
        const extent = ol.proj.transformExtent(
            object.bbox,
            'EPSG:4326',
            'EPSG:3857'
        );
        
        // Приближаем к границам объекта
        map.getView().fit(extent, {
            padding: [50, 50, 50, 50],
            duration: 1000
        });
        
        // Показываем уведомление
        showMessage(`Приближение к объекту "${object.name}"`, 'success');
    }
}

/**
 * Приближает карту к границам слоя
 * @param {ol.layer.Layer} layer - Слой
 */
function zoomToLayer(layer) {
    const metadata = layer.get('metadata') || {};
    
    // Проверяем видимость слоя
    if (!layer.getVisible()) {
        // Если слой не виден, включаем его
        layer.setVisible(true);
        
        // Обновляем чекбокс в UI
        const layerId = layer.get('id');
        if (layerId && layerControls[layerId]) {
            const checkbox = layerControls[layerId].querySelector('input[type="checkbox"]');
            if (checkbox) {
                checkbox.checked = true;
            }
        }
    }
    
    // Показываем индикатор загрузки
    showLoader('Получение границ слоя...');
    
    // Получаем границы слоя
    getLayerExtent(metadata.workspace, metadata.layerName, function(extent) {
        // Скрываем индикатор загрузки
        hideLoader();
        
        if (extent) {
            // Приближаем к границам слоя
            map.getView().fit(extent, {
                padding: [50, 50, 50, 50],
                duration: 1000
            });
            
            // Показываем уведомление
            showMessage(`Приближение к слою "${layer.get('title')}"`, 'success');
        } else {
            // Показываем предупреждение
            showWarning(`Не удалось получить границы слоя "${layer.get('title')}"`);
            
            // Проверяем доступность слоя
            checkLayerAvailability(metadata);
        }
    });
}

/**
 * Отображает информацию о слое
 * @param {ol.layer.Layer} layer - Слой
 */
function showLayerInfo(layer) {
    const metadata = layer.get('metadata') || {};
    
    if (metadata.workspace && metadata.layerName) {
        displayLayerMetadata(metadata.workspace, metadata.layerName);
    } else {
        showWarning(`Нет метаданных для слоя "${layer.get('title')}"`);
    }
}

/**
 * Показывает индикатор загрузки
 * @param {string} text - Текст индикатора
 */
function showLoader(text) {
    // Проверяем, существует ли уже индикатор
    let loader = document.getElementById('layer-loader');
    
    if (!loader) {
        loader = document.createElement('div');
        loader.id = 'layer-loader';
        loader.className = 'layer-loader';
        document.body.appendChild(loader);
    }
    
    loader.textContent = text || 'Загрузка...';
    loader.style.display = 'block';
}

/**
 * Скрывает индикатор загрузки
 */
function hideLoader() {
    const loader = document.getElementById('layer-loader');
    if (loader) {
        loader.style.display = 'none';
    }
}

/**
 * Показывает сообщение
 * @param {string} text - Текст сообщения
 * @param {string} type - Тип сообщения (success, info)
 */
function showMessage(text, type) {
    createNotification(text, 'message', type);
}

/**
 * Показывает предупреждение
 * @param {string} text - Текст предупреждения
 */
function showWarning(text) {
    createNotification(text, 'warning');
}

/**
 * Показывает ошибку
 * @param {string} text - Текст ошибки
 */
function showError(text) {
    createNotification(text, 'error');
}

/**
 * Создает уведомление
 * @param {string} text - Текст уведомления
 * @param {string} notificationType - Тип уведомления (message, warning, error)
 * @param {string} messageType - Подтип сообщения (success, info)
 */
function createNotification(text, notificationType, messageType) {
    // Создаем элемент уведомления
    const notification = document.createElement('div');
    notification.className = `layer-${notificationType}`;
    
    if (notificationType === 'message' && messageType) {
        notification.classList.add(messageType);
    }
    
    // Иконка
    const icon = document.createElement('span');
    icon.className = `${notificationType}-icon`;
    
    // Выбираем иконку в зависимости от типа
    if (notificationType === 'message') {
        icon.textContent = messageType === 'success' ? '✅' : 'ℹ️';
    } else if (notificationType === 'warning') {
        icon.textContent = '⚠️';
    } else if (notificationType === 'error') {
        icon.textContent = '❌';
    }
    
    // Текст
    const textElement = document.createElement('div');
    textElement.className = `${notificationType}-text`;
    textElement.textContent = text;
    
    // Кнопка закрытия
    const closeButton = document.createElement('button');
    closeButton.className = `${notificationType}-close`;
    closeButton.textContent = '×';
    closeButton.addEventListener('click', function() {
        document.body.removeChild(notification);
    });
    
    // Собираем уведомление
    notification.appendChild(icon);
    notification.appendChild(textElement);
    notification.appendChild(closeButton);
    
    // Добавляем на страницу
    document.body.appendChild(notification);
    
    // Автоматически скрываем через 5 секунд
    setTimeout(function() {
        if (document.body.contains(notification)) {
            document.body.removeChild(notification);
        }
    }, 5000);
}

/**
 * Инициализация после загрузки DOM
 */
document.addEventListener('DOMContentLoaded', function() {
    // Инициализируем карту при условии, что загружена конфигурация слоев
    if (typeof layerConfig !== 'undefined') {
        initMap();
    } else {
        console.error('Конфигурация слоев не найдена. Убедитесь, что файл generated-layers.js загружен перед map-init.js');
    }
}); 