/**
 * Модуль для управления и отображения панорамных изображений
 * с использованием библиотеки Pannellum.
 * 
 * Автор: GIS Team
 * Дата: 01.03.2025
 * Версия: 1.0
 */

class PanoramaViewer {
    /**
     * Создает экземпляр PanoramaViewer
     * @param {Object} options - Опции инициализации
     * @param {string} options.containerId - ID DOM-элемента для контейнера панорамы
     * @param {string} options.viewerId - ID DOM-элемента для viewer Pannellum
     * @param {string} options.closeButtonSelector - CSS-селектор кнопки закрытия
     * @param {Function} options.onClose - Функция, вызываемая при закрытии панорамы
     * @param {Function} options.onLoad - Функция, вызываемая при загрузке панорамы
     * @param {Function} options.onError - Функция, вызываемая при ошибке загрузки
     */
    constructor(options) {
        this.options = Object.assign({
            containerId: 'panorama-container',
            viewerId: 'panorama',
            closeButtonSelector: '.panorama-close',
            onClose: null,
            onLoad: null,
            onError: null
        }, options);

        this.container = document.getElementById(this.options.containerId);
        this.viewer = document.getElementById(this.options.viewerId);
        this.closeButton = document.querySelector(this.options.closeButtonSelector);
        this.pannellumViewer = null;
        
        // Инициализация событий
        this._initEvents();
    }

    /**
     * Инициализирует события
     * @private
     */
    _initEvents() {
        if (this.closeButton) {
            this.closeButton.addEventListener('click', () => this.close());
        }
    }

    /**
     * Показывает панорамное изображение
     * @param {Object} panoramaData - Данные панорамы
     * @param {string} panoramaData.url - URL панорамного изображения
     * @param {string} panoramaData.type - Тип панорамы (equirectangular, cubemap, multires)
     * @param {string} panoramaData.name - Название панорамы
     * @param {number} panoramaData.heading - Смещение севера (в градусах)
     * @returns {Object} - Экземпляр viewer Pannellum
     */
    show(panoramaData) {
        if (!this.container || !this.viewer) {
            console.error('Контейнер или viewer не найдены');
            return null;
        }

        // Отображаем контейнер
        this.container.style.display = 'block';

        // Опции Pannellum
        const viewerOptions = {
            type: panoramaData.type || 'equirectangular',
            panorama: panoramaData.url,
            autoLoad: true,
            compass: true,
            northOffset: panoramaData.heading || 0,
            showFullscreenCtrl: true,
            showZoomCtrl: true,
            keyboardZoom: true,
            mouseZoom: true,
            draggable: true,
            disableKeyboardCtrl: false,
            title: panoramaData.name || '',
            author: panoramaData.author || 'Корпоративная ГИС',
            sceneFadeDuration: 1000
        };

        // Добавляем обработчики событий, если они предоставлены
        if (typeof this.options.onLoad === 'function') {
            viewerOptions.onLoad = this.options.onLoad;
        }

        if (typeof this.options.onError === 'function') {
            viewerOptions.onError = this.options.onError;
        }

        // Создаем viewer Pannellum
        try {
            this.pannellumViewer = pannellum.viewer(this.options.viewerId, viewerOptions);
            return this.pannellumViewer;
        } catch (error) {
            console.error('Ошибка при инициализации Pannellum:', error);
            if (typeof this.options.onError === 'function') {
                this.options.onError(error);
            }
            return null;
        }
    }

    /**
     * Закрывает просмотрщик панорам
     */
    close() {
        if (this.container) {
            this.container.style.display = 'none';
        }

        // Уничтожаем viewer Pannellum для освобождения ресурсов
        if (this.pannellumViewer) {
            this.pannellumViewer.destroy();
            this.pannellumViewer = null;
        }

        // Очищаем DOM-элемент viewer
        if (this.viewer) {
            while (this.viewer.firstChild) {
                this.viewer.removeChild(this.viewer.firstChild);
            }
        }

        // Вызываем пользовательский обработчик закрытия
        if (typeof this.options.onClose === 'function') {
            this.options.onClose();
        }
    }

    /**
     * Проверяет, отображается ли панорама в данный момент
     * @returns {boolean} true, если панорама отображается
     */
    isVisible() {
        return this.container && this.container.style.display === 'block';
    }

    /**
     * Обновляет опции просмотрщика панорам
     * @param {Object} options - Новые опции
     */
    updateOptions(options) {
        this.options = Object.assign(this.options, options);
    }

    /**
     * Получает информацию о текущем состоянии просмотра
     * @returns {Object|null} Объект с информацией о состоянии или null, если просмотрщик не инициализирован
     */
    getViewerState() {
        if (!this.pannellumViewer) {
            return null;
        }

        return {
            pitch: this.pannellumViewer.getPitch(),
            yaw: this.pannellumViewer.getYaw(),
            hfov: this.pannellumViewer.getHfov()
        };
    }

    /**
     * Устанавливает угол обзора по вертикали (pitch)
     * @param {number} pitch - Угол в градусах
     */
    setPitch(pitch) {
        if (this.pannellumViewer) {
            this.pannellumViewer.setPitch(pitch);
        }
    }

    /**
     * Устанавливает угол обзора по горизонтали (yaw)
     * @param {number} yaw - Угол в градусах
     */
    setYaw(yaw) {
        if (this.pannellumViewer) {
            this.pannellumViewer.setYaw(yaw);
        }
    }

    /**
     * Устанавливает поле зрения (hfov)
     * @param {number} hfov - Горизонтальное поле зрения в градусах
     */
    setHfov(hfov) {
        if (this.pannellumViewer) {
            this.pannellumViewer.setHfov(hfov);
        }
    }
}

/**
 * Класс для управления коллекцией панорам и их отображением на карте OpenLayers
 */
class PanoramaManager {
    /**
     * Создает экземпляр PanoramaManager
     * @param {Object} options - Опции инициализации
     * @param {ol.Map} options.map - Экземпляр карты OpenLayers
     * @param {PanoramaViewer} options.viewer - Экземпляр PanoramaViewer
     * @param {Function} options.onMarkerClick - Обработчик клика по маркеру
     * @param {Function} options.onMarkerAdd - Обработчик добавления маркера
     * @param {Array} options.panoramas - Начальный массив панорам
     */
    constructor(options) {
        this.options = Object.assign({
            map: null,
            viewer: null,
            onMarkerClick: null,
            onMarkerAdd: null,
            panoramas: []
        }, options);

        this.map = this.options.map;
        this.viewer = this.options.viewer;
        this.panoramas = this.options.panoramas || [];
        
        // Создаем слой для маркеров
        this.source = new ol.source.Vector();
        this.layer = new ol.layer.Vector({
            source: this.source,
            style: this._createMarkerStyle()
        });

        // Если карта предоставлена, добавляем слой и настраиваем взаимодействие
        if (this.map) {
            this.map.addLayer(this.layer);
            this._setupMapInteraction();
        }

        // Добавляем начальные панорамы
        if (this.panoramas.length > 0) {
            this.addPanoramas(this.panoramas);
        }
    }

    /**
     * Создает стиль маркера для панорамы
     * @returns {ol.style.Style} Стиль маркера
     * @private
     */
    _createMarkerStyle(feature) {
        return new ol.style.Style({
            image: new ol.style.Circle({
                radius: 14,
                fill: new ol.style.Fill({
                    color: 'rgba(255, 0, 0, 0.6)'
                }),
                stroke: new ol.style.Stroke({
                    color: 'white',
                    width: 2
                })
            })
        });
    }

    /**
     * Настраивает взаимодействие с картой
     * @private
     */
    _setupMapInteraction() {
        // Обработка клика по маркеру
        this.map.on('click', (e) => {
            const feature = this.map.forEachFeatureAtPixel(e.pixel, (feature) => feature);
            
            if (feature && feature.get('panoramaData')) {
                const panoramaData = feature.get('panoramaData');
                
                // Показываем панораму
                if (this.viewer) {
                    this.viewer.show(panoramaData);
                }
                
                // Вызываем пользовательский обработчик
                if (typeof this.options.onMarkerClick === 'function') {
                    this.options.onMarkerClick(panoramaData, feature);
                }
            }
        });
    }

    /**
     * Добавляет панораму на карту
     * @param {Object} panorama - Данные панорамы
     * @param {string} panorama.name - Название панорамы
     * @param {Array} panorama.coordinates - Координаты [lon, lat]
     * @param {string} panorama.url - URL изображения
     * @param {string} panorama.type - Тип панорамы
     * @param {number} panorama.heading - Направление (heading)
     * @returns {ol.Feature} Созданный маркер
     */
    addPanorama(panorama) {
        if (!panorama || !panorama.coordinates) {
            console.error('Некорректные данные панорамы');
            return null;
        }

        // Создаем маркер
        const marker = new ol.Feature({
            geometry: new ol.geom.Point(ol.proj.fromLonLat(panorama.coordinates)),
            name: panorama.name || 'Панорама',
            panoramaData: panorama
        });

        // Добавляем маркер на слой
        this.source.addFeature(marker);
        
        // Добавляем панораму в массив
        this.panoramas.push(panorama);
        
        // Вызываем пользовательский обработчик
        if (typeof this.options.onMarkerAdd === 'function') {
            this.options.onMarkerAdd(panorama, marker);
        }
        
        return marker;
    }

    /**
     * Добавляет несколько панорам на карту
     * @param {Array} panoramas - Массив данных панорам
     * @returns {Array} Массив созданных маркеров
     */
    addPanoramas(panoramas) {
        if (!Array.isArray(panoramas)) {
            console.error('Ожидается массив панорам');
            return [];
        }

        return panoramas.map(panorama => this.addPanorama(panorama));
    }

    /**
     * Удаляет панораму с карты
     * @param {string|number} id - Идентификатор панорамы
     * @returns {boolean} true, если панорама успешно удалена
     */
    removePanorama(id) {
        // Находим панораму в массиве
        const index = this.panoramas.findIndex(p => p.id === id);
        
        if (index === -1) {
            return false;
        }
        
        // Удаляем панораму из массива
        const panorama = this.panoramas.splice(index, 1)[0];
        
        // Находим и удаляем соответствующий маркер
        const features = this.source.getFeatures();
        const feature = features.find(f => {
            const data = f.get('panoramaData');
            return data && data.id === id;
        });
        
        if (feature) {
            this.source.removeFeature(feature);
            return true;
        }
        
        return false;
    }

    /**
     * Очищает все панорамы с карты
     */
    clearPanoramas() {
        this.source.clear();
        this.panoramas = [];
    }

    /**
     * Получает все панорамы
     * @returns {Array} Массив панорам
     */
    getPanoramas() {
        return [...this.panoramas];
    }

    /**
     * Получает панораму по идентификатору
     * @param {string|number} id - Идентификатор панорамы
     * @returns {Object|null} Данные панорамы или null, если не найдена
     */
    getPanorama(id) {
        return this.panoramas.find(p => p.id === id) || null;
    }

    /**
     * Переключает видимость слоя с панорамами
     * @param {boolean} visible - Флаг видимости
     */
    setVisible(visible) {
        if (this.layer) {
            this.layer.setVisible(visible);
        }
    }

    /**
     * Проверяет, видим ли слой с панорамами
     * @returns {boolean} true, если слой видим
     */
    isVisible() {
        return this.layer && this.layer.getVisible();
    }
}

// Экспортируем классы для использования в других модулях
window.PanoramaViewer = PanoramaViewer;
window.PanoramaManager = PanoramaManager; 