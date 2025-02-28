/**
 * Инициализация и управление картой ГИС-платформы
 */

// Конфигурация GeoServer
const geoserverUrl = '/geoserver';
const vectorInstance = 'vector'; // Инстанция для векторных данных
const rasterInstance = 'ecw';    // Инстанция для растровых данных
const workspace = 'TEST';      // Рабочее пространство для растровых данных
const layerName = '2020-2021';     // Имя слоя растровых данных

// Глобальные переменные для доступа к карте и слоям
let map;
let baseLayers = {}; // Объект для хранения различных базовых слоев
let activeBaseLayer; // Текущий активный базовый слой
let rasterLayer;
let view;

// Инициализация карты при загрузке страницы
document.addEventListener('DOMContentLoaded', function() {
    initMap();
    setupEventListeners();
});

/**
 * Инициализация карты с базовыми слоями
 */
function initMap() {
    // Показываем индикатор загрузки
    const loader = document.getElementById('map-loader');
    if (loader) {
        loader.style.display = 'block';
    }
    
    try {
        // Создаем базовые слои
        baseLayers = {
            'osm': new ol.layer.Tile({
                title: 'OpenStreetMap',
                source: new ol.source.OSM({
                    url: 'https://{a-c}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    crossOrigin: 'anonymous'
                }),
                visible: true
            }),
            'satellite': new ol.layer.Tile({
                title: 'Спутник',
                source: new ol.source.XYZ({
                    attributions: ['Powered by Esri', 'Source: Esri, DigitalGlobe, GeoEye, Earthstar Geographics, CNES/Airbus DS, USDA, USGS, AeroGRID, IGN, and the GIS User Community'],
                    attributionsCollapsible: false,
                    url: 'https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                    maxZoom: 19,
                    crossOrigin: 'anonymous'
                }),
                visible: false
            }),
            'topo': new ol.layer.Tile({
                title: 'Топографическая',
                source: new ol.source.XYZ({
                    attributions: ['Powered by Esri', 'Source: Esri, DeLorme, USGS, NPS'],
                    attributionsCollapsible: false,
                    url: 'https://services.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}',
                    maxZoom: 19,
                    crossOrigin: 'anonymous'
                }),
                visible: false
            })
        };
        
        // Установим активный базовый слой
        activeBaseLayer = baseLayers.osm;

        // Создаем слой с растровыми данными из GeoServer
        rasterLayer = new ol.layer.Tile({
            title: 'Растровый слой',
            source: new ol.source.TileWMS({
                url: `${geoserverUrl}/${rasterInstance}/wms`,
                params: {
                    'LAYERS': `${workspace}:${layerName}`,
                    'TILED': true,
                    'FORMAT': 'image/png',
                    'VERSION': '1.1.1',
                    'TRANSPARENT': true
                },
                serverType: 'geoserver',
                crossOrigin: 'anonymous'
            }),
            visible: true,
            opacity: 1.0
        });

        // Создаем представление карты
        view = new ol.View({
            center: ol.proj.fromLonLat([37.618423, 55.751244]), // Москва
            zoom: 6,
            minZoom: 2,
            maxZoom: 19
        });

        // Создаем карту с базовыми слоями и растровым слоем
        map = new ol.Map({
            target: 'map',
            layers: [
                ...Object.values(baseLayers),
                rasterLayer
            ],
            view: view,
            controls: ol.control.defaults().extend([
                new ol.control.ScaleLine(),
                new ol.control.ZoomSlider(),
                new ol.control.FullScreen(),
                new ol.control.Attribution({
                    collapsible: true
                })
            ])
        });

        // Обновляем панель управления слоями
        updateLayerPanel();

        // Обработчики ошибки загрузки тайлов для базовых слоев
        Object.values(baseLayers).forEach(layer => {
            layer.getSource().on('tileloaderror', function(event) {
                console.error(`Ошибка загрузки тайла для ${layer.get('title')}:`, event);
                
                // Если это первая ошибка для базовых слоев и ни один другой базовый слой не загружен успешно
                if (!window.baseLayerErrorShown) {
                    // Проверяем, загрузился ли какой-либо базовый слой
                    const anyLayerLoaded = Object.values(baseLayers).some(baseLayer => 
                        baseLayer.getSource().getTileLoadFunction && 
                        baseLayer.getSource().getTileLoadFunction() !== undefined);
                    
                    if (!anyLayerLoaded) {
                        window.baseLayerErrorShown = true;
                        
                        // Создаем и показываем предупреждение
                        const warningDiv = document.createElement('div');
                        warningDiv.className = 'layer-warning';
                        warningDiv.innerHTML = `
                            <div class="warning-icon">⚠️</div>
                            <div class="warning-text">Ошибка загрузки базовой карты. Проверьте соединение с интернетом.</div>
                            <button class="warning-close" onclick="this.parentNode.style.display='none';">✕</button>
                        `;
                        document.body.appendChild(warningDiv);
                        
                        // Автоматически скрываем через 10 секунд
                        setTimeout(function() {
                            if (warningDiv.parentNode) {
                                warningDiv.style.display = 'none';
                            }
                        }, 10000);
                        
                        // Если одна из базовых карт не загрузилась, пробуем загрузить следующую
                        tryNextBaseLayer();
                    }
                }
            });
        });

        // Обработчик ошибки загрузки тайлов для растрового слоя
        rasterLayer.getSource().on('tileloaderror', function(event) {
            console.error('Ошибка загрузки растрового тайла:', event);
            // Создаем предупреждение о проблеме с загрузкой растрового слоя
            if (!window.rasterLayerErrorShown) {
                window.rasterLayerErrorShown = true;
                
                const warningDiv = document.createElement('div');
                warningDiv.className = 'layer-warning';
                warningDiv.innerHTML = `
                    <div class="warning-icon">⚠️</div>
                    <div class="warning-text">Ошибка загрузки растрового слоя "${workspace}:${layerName}". Проверьте настройки GeoServer.</div>
                    <button class="warning-close" onclick="this.parentNode.style.display='none';">✕</button>
                `;
                document.body.appendChild(warningDiv);
                
                setTimeout(function() {
                    if (warningDiv.parentNode) {
                        warningDiv.style.display = 'none';
                    }
                }, 10000);
            }
        });

        // Добавляем метод для проверки доступности растрового слоя
        function checkRasterLayerAvailability() {
            const capabilitiesUrl = `${geoserverUrl}/${rasterInstance}/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetCapabilities`;
            
            fetch(capabilitiesUrl)
                .then(response => {
                    if (!response.ok) {
                        throw new Error(`HTTP error! status: ${response.status}`);
                    }
                    return response.text();
                })
                .then(text => {
                    try {
                        const parser = new ol.format.WMSCapabilities();
                        const capabilities = parser.read(text);
                        
                        // Проверяем наличие слоя
                        let layerFound = false;
                        if (capabilities && capabilities.Capability && capabilities.Capability.Layer && capabilities.Capability.Layer.Layer) {
                            const layers = capabilities.Capability.Layer.Layer;
                            layerFound = layers.some(layer => layer.Name === `${workspace}:${layerName}`);
                        }
                        
                        if (!layerFound) {
                            console.warn(`Растровый слой "${workspace}:${layerName}" не найден в GeoServer`);
                            // Обновляем интерфейс
                            updateRasterLayerUI(false);
                        } else {
                            console.log(`Растровый слой "${workspace}:${layerName}" доступен`);
                            // Обновляем интерфейс
                            updateRasterLayerUI(true);
                        }
                    } catch (error) {
                        console.error('Ошибка при разборе XML ответа:', error);
                        updateRasterLayerUI(false);
                    }
                })
                .catch(error => {
                    console.error('Ошибка при проверке доступности растрового слоя:', error);
                    updateRasterLayerUI(false);
                });
        }

        // Функция для обновления UI в зависимости от доступности слоя
        function updateRasterLayerUI(isAvailable) {
            const rasterLayerItem = document.getElementById('raster-layer').closest('.layer-item');
            
            if (!isAvailable) {
                // Добавляем класс для обозначения недоступности
                rasterLayerItem.classList.add('layer-unavailable');
                
                // Добавляем иконку недоступности
                if (!rasterLayerItem.querySelector('.layer-unavailable-icon')) {
                    const icon = document.createElement('span');
                    icon.className = 'layer-unavailable-icon';
                    icon.title = `Слой "${workspace}:${layerName}" не опубликован в GeoServer`;
                    icon.textContent = '⚠️';
                    rasterLayerItem.appendChild(icon);
                }
            } else {
                // Удаляем класс недоступности если слой доступен
                rasterLayerItem.classList.remove('layer-unavailable');
                
                // Удаляем иконку недоступности если она есть
                const icon = rasterLayerItem.querySelector('.layer-unavailable-icon');
                if (icon) {
                    icon.remove();
                }
            }
        }

        // Проверяем доступность растрового слоя после загрузки карты
        map.once('rendercomplete', function() {
            // Проверяем доступность растрового слоя
            checkRasterLayerAvailability();
        });

        // Обработчик ошибки загрузки тайлов
        baseLayers.osm.getSource().on('tileloaderror', function(event) {
            console.error('Ошибка загрузки базового тайла:', event);
        });

        // Скрываем индикатор загрузки когда карта загружена
        map.once('rendercomplete', function() {
            if (loader) {
                loader.style.display = 'none';
            }
        });

        // Запасной вариант для скрытия индикатора загрузки после таймаута
        setTimeout(function() {
            if (loader && loader.style.display === 'block') {
                loader.style.display = 'none';
                console.warn('Индикатор загрузки скрыт по таймауту');
            }
        }, 5000);

        // Инициализация чекбоксов слоев
        const baseLayerCheckbox = document.getElementById('base-layer');
        const rasterLayerCheckbox = document.getElementById('raster-layer');
        
        if (baseLayerCheckbox) {
            baseLayerCheckbox.checked = rasterLayer.getVisible();
        }
        
        if (rasterLayerCheckbox) {
            rasterLayerCheckbox.checked = rasterLayer.getVisible();
        }
        
        console.log('Карта успешно инициализирована');
    } catch (error) {
        console.error('Ошибка при инициализации карты:', error);
        // Скрываем индикатор загрузки при ошибке
        if (loader) {
            loader.style.display = 'none';
        }
        
        // Отображаем сообщение об ошибке на карте
        const mapElement = document.getElementById('map');
        if (mapElement) {
            mapElement.innerHTML = '<div class="map-error">Ошибка загрузки карты. Пожалуйста, обновите страницу или обратитесь к администратору.</div>';
        }
    }
}

/**
 * Настройка обработчиков событий
 */
function setupEventListeners() {
    try {
        // Обработчик видимости базового слоя
        const baseLayerCheckbox = document.getElementById('base-layer');
        if (baseLayerCheckbox) {
            baseLayerCheckbox.addEventListener('change', function(e) {
                if (rasterLayer) {
                    rasterLayer.setVisible(e.target.checked);
                }
            });
        }

        // Обработчик видимости растрового слоя
        const rasterLayerCheckbox = document.getElementById('raster-layer');
        if (rasterLayerCheckbox) {
            rasterLayerCheckbox.addEventListener('change', function(e) {
                if (rasterLayer) {
                    rasterLayer.setVisible(e.target.checked);
                }
            });
        }

        // Кнопки масштабирования
        const zoomInBtn = document.getElementById('zoom-in');
        if (zoomInBtn) {
            zoomInBtn.addEventListener('click', function() {
                if (view) {
                    view.animate({
                        zoom: view.getZoom() + 1,
                        duration: 250
                    });
                }
            });
        }

        const zoomOutBtn = document.getElementById('zoom-out');
        if (zoomOutBtn) {
            zoomOutBtn.addEventListener('click', function() {
                if (view) {
                    view.animate({
                        zoom: view.getZoom() - 1,
                        duration: 250
                    });
                }
            });
        }

        // Кнопка "домой"
        const homeBtn = document.querySelector('.home-btn');
        if (homeBtn) {
            homeBtn.addEventListener('click', function() {
                if (view) {
                    view.animate({
                        center: ol.proj.fromLonLat([37.618423, 55.751244]), // Москва
                        zoom: 6,
                        duration: 500
                    });
                }
            });
        }

        // Переключатель темы
        const themeSwitch = document.getElementById('theme-switch');
        if (themeSwitch) {
            themeSwitch.addEventListener('change', function(e) {
                if (e.target.checked) {
                    document.body.classList.add('dark-theme');
                } else {
                    document.body.classList.remove('dark-theme');
                }
            });
        }

        // Обработчик кликов по карте для получения информации
        const infoToolBtn = document.getElementById('info-tool');
        if (infoToolBtn) {
            infoToolBtn.addEventListener('click', function() {
                // Включаем/выключаем режим получения информации
                this.classList.toggle('active');
                
                if (this.classList.contains('active')) {
                    // Если режим активен, добавляем обработчик клика
                    if (map) {
                        map.on('singleclick', handleMapClick);
                        map.getViewport().style.cursor = 'help';
                    }
                } else {
                    // Если режим не активен, удаляем обработчик
                    if (map) {
                        map.un('singleclick', handleMapClick);
                        map.getViewport().style.cursor = 'default';
                    }
                    
                    // Скрываем попап
                    const popup = document.getElementById('map-popup');
                    if (popup) {
                        popup.style.display = 'none';
                    }
                }
            });
        }
        
        console.log('Обработчики событий успешно настроены');
    } catch (error) {
        console.error('Ошибка при настройке обработчиков событий:', error);
    }
}

/**
 * Обработчик клика по карте для получения информации о точке
 * @param {ol.MapBrowserEvent} evt - Событие клика
 */
function handleMapClick(evt) {
    try {
        // Получаем все видимые слои, для которых можно запросить информацию
        const layers = map.getLayers().getArray().filter(layer => 
            layer.getVisible() && 
            layer.getSource() && 
            typeof layer.getSource().getFeatureInfoUrl === 'function'
        );
        
        // Если нет видимых слоев с данными, выходим
        if (layers.length === 0) return;
        
        // Запрашиваем информацию по точке для всех видимых слоев
        getPointInfo(map, layers, evt.pixel);
    } catch (error) {
        console.error('Ошибка при обработке клика по карте:', error);
    }
}

/**
 * Приближение к растровому слою
 */
function zoomToRasterLayer() {
    try {
        console.log('Запрошено приближение к растровому слою');
        
        // Проверяем, включен ли слой
        if (rasterLayer && !rasterLayer.getVisible()) {
            console.log('Растровый слой не включен. Включаем...');
            // Если слой не включен, включаем его
            rasterLayer.setVisible(true);
            
            const rasterLayerCheckbox = document.getElementById('raster-layer');
            if (rasterLayerCheckbox) {
                rasterLayerCheckbox.checked = true;
            }
        }
        
        // Показываем индикатор загрузки
        const loader = document.createElement('div');
        loader.className = 'layer-loader';
        loader.innerHTML = 'Загрузка границ слоя...';
        document.body.appendChild(loader);
        
        console.log('Запрашиваем экстент растрового слоя...');
        
        // Получаем экстент растрового слоя
        getLayerExtent(workspace, layerName, function(extent) {
            // Скрываем индикатор загрузки
            if (loader.parentNode) {
                document.body.removeChild(loader);
            }
            
            if (extent && map) {
                console.log('Получен экстент слоя:', extent);
                
                // Приближаем к экстенту слоя с отступом
                map.getView().fit(extent, {
                    padding: [50, 50, 50, 50],
                    duration: 1000
                });
                
                // Показываем сообщение об успешном приближении
                const message = document.createElement('div');
                message.className = 'layer-message success';
                message.innerHTML = 'Карта приближена к границам растрового слоя';
                document.body.appendChild(message);
                
                // Автоматически скрываем сообщение через 3 секунды
                setTimeout(function() {
                    if (message.parentNode) {
                        document.body.removeChild(message);
                    }
                }, 3000);
            } else {
                console.warn('Не удалось получить границы растрового слоя');
                
                // Если не удалось получить экстент, отображаем сообщение
                const warning = document.createElement('div');
                warning.className = 'layer-warning';
                warning.innerHTML = `
                    <div class="warning-icon">⚠️</div>
                    <div class="warning-text">Не удалось получить границы растрового слоя "${workspace}:${layerName}". Возможно, слой еще не настроен в GeoServer.</div>
                    <button class="warning-close" onclick="this.parentNode.remove();">✕</button>
                `;
                document.body.appendChild(warning);
                
                // Отправляем запрос напрямую для проверки доступности слоя
                checkRasterLayerAvailability();
            }
        });
    } catch (error) {
        console.error('Ошибка при приближении к растровому слою:', error);
    }
}

/**
 * Проверка доступности растрового слоя в GeoServer
 */
function checkRasterLayerAvailability() {
    try {
        console.log('Проверка доступности растрового слоя в GeoServer...');
        
        // Формируем URL для запроса GetCapabilities
        const capabilitiesUrl = `${geoserverUrl}/${rasterInstance}/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetCapabilities`;
        
        fetch(capabilitiesUrl)
            .then(response => {
                if (!response.ok) {
                    throw new Error(`HTTP error! status: ${response.status}`);
                }
                return response.text();
            })
            .then(text => {
                // Проверяем наличие нашего слоя в ответе
                const layerIdentifier = `${workspace}:${layerName}`;
                if (text.includes(layerIdentifier)) {
                    console.log(`Слой ${layerIdentifier} найден в GeoServer`);
                    
                    // Показываем сообщение, что слой доступен
                    const message = document.createElement('div');
                    message.className = 'layer-message';
                    message.innerHTML = `
                        <div class="message-icon">✓</div>
                        <div class="message-text">Слой "${layerIdentifier}" доступен в GeoServer, но возможны проблемы с отображением. Проверьте параметры слоя.</div>
                        <button class="message-close" onclick="this.parentNode.remove();">✕</button>
                    `;
                    document.body.appendChild(message);
                    
                    // Автоматически скрываем сообщение через 10 секунд
                    setTimeout(function() {
                        if (message.parentNode) {
                            message.remove();
                        }
                    }, 10000);
                } else {
                    console.warn(`Слой ${layerIdentifier} не найден в GeoServer`);
                    
                    // Показываем сообщение, что слой не найден
                    const warning = document.createElement('div');
                    warning.className = 'layer-warning';
                    warning.innerHTML = `
                        <div class="warning-icon">⚠️</div>
                        <div class="warning-text">Слой "${layerIdentifier}" не найден в GeoServer. Проверьте, что слой опубликован с указанным именем.</div>
                        <button class="warning-close" onclick="this.parentNode.remove();">✕</button>
                    `;
                    document.body.appendChild(warning);
                }
            })
            .catch(error => {
                console.error('Ошибка при проверке доступности слоя:', error);
                
                // Показываем сообщение об ошибке
                const errorMessage = document.createElement('div');
                errorMessage.className = 'layer-error';
                errorMessage.innerHTML = `
                    <div class="error-icon">❌</div>
                    <div class="error-text">Ошибка при проверке доступности слоя: ${error.message}</div>
                    <button class="error-close" onclick="this.parentNode.remove();">✕</button>
                `;
                document.body.appendChild(errorMessage);
            });
    } catch (error) {
        console.error('Ошибка при проверке доступности слоя:', error);
    }
}

// Функция для получения информации о слое (GetFeatureInfo)
function getFeatureInfo(pixel) {
    try {
        if (!map || !rasterLayer || !rasterLayer.getSource()) {
            console.warn('Карта или растровый слой не инициализированы');
            return;
        }
        
        const viewResolution = map.getView().getResolution();
        const url = rasterLayer.getSource().getFeatureInfoUrl(
            map.getCoordinateFromPixel(pixel),
            viewResolution,
            'EPSG:3857',
            {'INFO_FORMAT': 'application/json'}
        );
        
        if (url) {
            fetch(url)
                .then(response => {
                    if (!response.ok) {
                        throw new Error(`HTTP error! status: ${response.status}`);
                    }
                    return response.json();
                })
                .then(data => {
                    // Обработка данных о точке
                    console.log('Данные о точке:', data);
                    // Здесь можно добавить отображение данных в попапе или боковой панели
                })
                .catch(error => console.error('Ошибка при получении данных:', error));
        } else {
            console.warn('Не удалось сформировать URL для запроса информации о точке');
        }
    } catch (error) {
        console.error('Ошибка при запросе информации о точке:', error);
    }
}

// Динамическая загрузка информации о слоях
function loadLayerInfo() {
    try {
        // Эта функция может использоваться для загрузки метаданных о слое
        // с сервера GeoServer через WMS GetCapabilities
        
        if (!rasterLayer || !rasterLayer.getSource() || !rasterLayer.getSource().getUrls) {
            console.warn('Растровый слой не инициализирован или не поддерживает getUrls');
            return;
        }
        
        const wmsSource = rasterLayer.getSource();
        const urls = wmsSource.getUrls();
        
        if (!urls || urls.length === 0) {
            console.warn('Нет доступных URL для источника WMS');
            return;
        }
        
        const wmsUrl = urls[0];
        const capabilitiesUrl = wmsUrl + '?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetCapabilities';
        
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
                
                // Обработка метаданных слоя
                console.log('Метаданные WMS:', capabilities);
                
                // Здесь можно обновить информацию об экстенте слоя
                // на основе полученных метаданных
            })
            .catch(error => console.error('Ошибка при получении метаданных:', error));
    } catch (error) {
        console.error('Ошибка при загрузке информации о слоях:', error);
    }
}

/**
 * Обновление панели управления базовыми слоями
 */
function updateLayerPanel() {
    // Получаем элемент для списка слоев
    const layerList = document.getElementById('layer-list');
    if (!layerList) return;
    
    // Очищаем текущее содержимое
    layerList.innerHTML = '';
    
    // Создаем группу для базовых слоев
    const baseLayerGroup = document.createElement('div');
    baseLayerGroup.className = 'layer-group';
    baseLayerGroup.innerHTML = '<h3>Базовые карты</h3>';
    
    // Добавляем радиокнопки для базовых слоев
    Object.entries(baseLayers).forEach(([key, layer]) => {
        const layerItem = document.createElement('div');
        layerItem.className = 'layer-item';
        
        const layerInput = document.createElement('input');
        layerInput.type = 'radio';
        layerInput.name = 'base-layer';
        layerInput.id = `base-${key}`;
        layerInput.className = 'layer-radio';
        layerInput.checked = layer.getVisible();
        layerInput.addEventListener('change', function() {
            // Скрываем все базовые слои
            Object.values(baseLayers).forEach(baseLayer => baseLayer.setVisible(false));
            // Показываем выбранный слой
            layer.setVisible(true);
            activeBaseLayer = layer;
        });
        
        const layerLabel = document.createElement('label');
        layerLabel.htmlFor = `base-${key}`;
        layerLabel.className = 'layer-name';
        layerLabel.textContent = layer.get('title') || key;
        
        layerItem.appendChild(layerInput);
        layerItem.appendChild(layerLabel);
        baseLayerGroup.appendChild(layerItem);
    });
    
    // Добавляем группу базовых слоев в панель
    layerList.appendChild(baseLayerGroup);
    
    // Создаем группу для оверлейных слоев
    const overlayGroup = document.createElement('div');
    overlayGroup.className = 'layer-group';
    overlayGroup.innerHTML = '<h3>Слои данных</h3>';
    
    // Добавляем растровый слой
    const rasterItem = document.createElement('div');
    rasterItem.className = 'layer-item';
    
    const rasterInput = document.createElement('input');
    rasterInput.type = 'checkbox';
    rasterInput.id = 'raster-layer';
    rasterInput.className = 'layer-checkbox';
    rasterInput.checked = rasterLayer.getVisible();
    rasterInput.addEventListener('change', function(e) {
        rasterLayer.setVisible(e.target.checked);
    });
    
    const rasterLabel = document.createElement('label');
    rasterLabel.htmlFor = 'raster-layer';
    rasterLabel.className = 'layer-name';
    rasterLabel.textContent = `${workspace}:${layerName} (ECW)`;
    
    const actions = document.createElement('div');
    actions.className = 'layer-actions';
    actions.innerHTML = `
        <button class="layer-action-btn" onclick="zoomToRasterLayer()">⎋</button>
        <button class="layer-action-btn" onclick="displayLayerMetadata('${workspace}', '${layerName}')">ℹ</button>
    `;
    
    rasterItem.appendChild(rasterInput);
    rasterItem.appendChild(rasterLabel);
    rasterItem.appendChild(actions);
    overlayGroup.appendChild(rasterItem);
    
    // Добавляем группу оверлейных слоев в панель
    layerList.appendChild(overlayGroup);
}

/**
 * Функция для переключения на следующий доступный базовый слой
 */
function tryNextBaseLayer() {
    // Получаем массив ключей слоев
    const layerKeys = Object.keys(baseLayers);
    
    // Находим индекс текущего активного слоя
    const currentIndex = layerKeys.findIndex(key => baseLayers[key] === activeBaseLayer);
    
    // Пробуем следующий слой
    if (currentIndex !== -1 && layerKeys.length > 1) {
        // Выбираем следующий слой (или первый, если текущий последний)
        const nextIndex = (currentIndex + 1) % layerKeys.length;
        const nextLayerKey = layerKeys[nextIndex];
        
        // Деактивируем все слои
        Object.values(baseLayers).forEach(layer => layer.setVisible(false));
        
        // Активируем следующий слой
        baseLayers[nextLayerKey].setVisible(true);
        activeBaseLayer = baseLayers[nextLayerKey];
        
        console.log(`Переключение на базовый слой: ${baseLayers[nextLayerKey].get('title')}`);
        
        // Обновляем UI
        updateLayerPanel();
    }
} 