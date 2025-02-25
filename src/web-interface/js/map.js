/**
 * Инициализация и управление картой ГИС-платформы
 */

// Конфигурация GeoServer
const geoserverUrl = '/geoserver';
const workspace = 'raster';  // Рабочее пространство для растровых данных
const layerName = 'landsat';  // Имя слоя растровых данных

// Инициализация карты при загрузке страницы
document.addEventListener('DOMContentLoaded', function() {
    initMap();
    setupEventListeners();
});

// Глобальные переменные для доступа к карте и слоям
let map;
let baseLayer;
let rasterLayer;
let view;

/**
 * Инициализация карты с базовыми слоями
 */
function initMap() {
    // Показываем индикатор загрузки
    document.getElementById('map-loader').style.display = 'block';
    
    // Создаем базовый слой (OpenStreetMap)
    baseLayer = new ol.layer.Tile({
        title: 'Базовая карта',
        source: new ol.source.OSM(),
        visible: true
    });

    // Создаем слой с растровыми данными из GeoServer
    rasterLayer = new ol.layer.Tile({
        title: 'Растровый слой',
        source: new ol.source.TileWMS({
            url: `${geoserverUrl}/${workspace}/wms`,
            params: {
                'LAYERS': `${workspace}:${layerName}`,
                'TILED': true,
                'FORMAT': 'image/png'
            },
            serverType: 'geoserver',
            crossOrigin: 'anonymous'
        }),
        visible: false
    });

    // Создаем представление карты
    view = new ol.View({
        center: ol.proj.fromLonLat([37.618423, 55.751244]), // Москва
        zoom: 6,
        minZoom: 2,
        maxZoom: 19
    });

    // Создаем карту
    map = new ol.Map({
        target: 'map',
        layers: [baseLayer, rasterLayer],
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

    // Скрываем индикатор загрузки когда карта загружена
    map.once('rendercomplete', function() {
        document.getElementById('map-loader').style.display = 'none';
    });

    // Инициализация чекбоксов слоев
    document.getElementById('base-layer').checked = baseLayer.getVisible();
    document.getElementById('raster-layer').checked = rasterLayer.getVisible();
}

/**
 * Настройка обработчиков событий
 */
function setupEventListeners() {
    // Обработчик видимости базового слоя
    document.getElementById('base-layer').addEventListener('change', function(e) {
        baseLayer.setVisible(e.target.checked);
    });

    // Обработчик видимости растрового слоя
    document.getElementById('raster-layer').addEventListener('change', function(e) {
        rasterLayer.setVisible(e.target.checked);
    });

    // Кнопки масштабирования
    document.getElementById('zoom-in').addEventListener('click', function() {
        view.animate({
            zoom: view.getZoom() + 1,
            duration: 250
        });
    });

    document.getElementById('zoom-out').addEventListener('click', function() {
        view.animate({
            zoom: view.getZoom() - 1,
            duration: 250
        });
    });

    // Кнопка "домой"
    document.querySelector('.home-btn').addEventListener('click', function() {
        view.animate({
            center: ol.proj.fromLonLat([37.618423, 55.751244]), // Москва
            zoom: 6,
            duration: 500
        });
    });

    // Переключатель темы
    document.getElementById('theme-switch').addEventListener('change', function(e) {
        if (e.target.checked) {
            document.body.classList.add('dark-theme');
        } else {
            document.body.classList.remove('dark-theme');
        }
    });

    // Обработчик кликов по карте для получения информации
    document.getElementById('info-tool').addEventListener('click', function() {
        // Включаем/выключаем режим получения информации
        this.classList.toggle('active');
        
        if (this.classList.contains('active')) {
            // Если режим активен, добавляем обработчик клика
            map.on('singleclick', handleMapClick);
            map.getViewport().style.cursor = 'help';
        } else {
            // Если режим не активен, удаляем обработчик
            map.un('singleclick', handleMapClick);
            map.getViewport().style.cursor = 'default';
            
            // Скрываем попап
            document.getElementById('map-popup').style.display = 'none';
        }
    });
}

/**
 * Обработчик клика по карте для получения информации о точке
 * @param {ol.MapBrowserEvent} evt - Событие клика
 */
function handleMapClick(evt) {
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
}

/**
 * Приближение к растровому слою
 */
function zoomToRasterLayer() {
    // Проверяем, включен ли слой
    if (!rasterLayer.getVisible()) {
        // Если слой не включен, включаем его
        rasterLayer.setVisible(true);
        document.getElementById('raster-layer').checked = true;
    }
    
    // Получаем экстент растрового слоя
    getLayerExtent(workspace, layerName, function(extent) {
        if (extent) {
            // Приближаем к экстенту слоя с отступом
            map.getView().fit(extent, {
                padding: [50, 50, 50, 50],
                duration: 1000
            });
        } else {
            // Если не удалось получить экстент, отображаем сообщение
            console.warn('Не удалось получить границы растрового слоя');
            // Можно добавить уведомление пользователю
        }
    });
}

// Функция для получения информации о слое (GetFeatureInfo)
function getFeatureInfo(pixel) {
    const viewResolution = map.getView().getResolution();
    const url = rasterLayer.getSource().getFeatureInfoUrl(
        map.getCoordinateFromPixel(pixel),
        viewResolution,
        'EPSG:3857',
        {'INFO_FORMAT': 'application/json'}
    );
    
    if (url) {
        fetch(url)
            .then(response => response.json())
            .then(data => {
                // Обработка данных о точке
                console.log(data);
                // Здесь можно добавить отображение данных в попапе или боковой панели
            })
            .catch(error => console.error('Ошибка при получении данных:', error));
    }
}

// Динамическая загрузка информации о слоях
function loadLayerInfo() {
    // Эта функция может использоваться для загрузки метаданных о слое
    // с сервера GeoServer через WMS GetCapabilities
    
    const wmsSource = rasterLayer.getSource();
    const wmsUrl = wmsSource.getUrls()[0];
    const capabilitiesUrl = wmsUrl + '?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetCapabilities';
    
    fetch(capabilitiesUrl)
        .then(response => response.text())
        .then(text => {
            const parser = new ol.format.WMSCapabilities();
            const capabilities = parser.read(text);
            
            // Обработка метаданных слоя
            console.log('Метаданные WMS:', capabilities);
            
            // Здесь можно обновить информацию об экстенте слоя
            // на основе полученных метаданных
        })
        .catch(error => console.error('Ошибка при получении метаданных:', error));
} 