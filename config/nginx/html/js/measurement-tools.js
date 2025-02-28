/**
 * Модуль для работы с инструментами измерения в ГИС
 * Поддерживает измерение расстояний и площадей с учетом проекции
 */

class MeasurementTools {
    /**
     * Инициализация инструментов измерения
     * @param {ol.Map} map Объект карты OpenLayers
     * @param {Object} options Дополнительные настройки
     */
    constructor(map, options = {}) {
        this.map = map;
        this.options = Object.assign({
            distanceUnit: 'kilometers', // 'meters', 'kilometers', 'miles'
            areaUnit: 'hectares',       // 'squareMeters', 'hectares', 'squareKilometers'
            precision: 2,                // Количество знаков после запятой
            language: 'ru'               // Язык для отображения единиц измерения
        }, options);

        // Слой для отображения измерений
        this.measurementSource = new ol.source.Vector();
        this.measurementLayer = new ol.layer.Vector({
            source: this.measurementSource,
            style: this._createMeasurementStyle()
        });
        this.map.addLayer(this.measurementLayer);

        // Текущее взаимодействие (draw)
        this.currentInteraction = null;
        this.sketch = null;
        this.measureTooltipElement = null;
        this.measureTooltip = null;
        this.helpTooltipElement = null;
        this.helpTooltip = null;

        // Активен ли режим измерения
        this.active = false;
        this.measureType = null; // 'distance' или 'area'

        // Привязка методов к контексту
        this._pointerMoveHandler = this._pointerMoveHandler.bind(this);
    }

    /**
     * Создает стиль для отображения измерений
     * @private
     * @returns {ol.style.Style} Стиль для векторного слоя
     */
    _createMeasurementStyle() {
        return new ol.style.Style({
            fill: new ol.style.Fill({
                color: 'rgba(255, 255, 255, 0.2)'
            }),
            stroke: new ol.style.Stroke({
                color: '#ffcc33',
                width: 2
            }),
            image: new ol.style.Circle({
                radius: 7,
                fill: new ol.style.Fill({
                    color: '#ffcc33'
                })
            })
        });
    }

    /**
     * Активирует режим измерения расстояний
     */
    startMeasureDistance() {
        this._clearMeasurement();
        this.measureType = 'distance';
        this.active = true;
        this._addInteraction();
        this._createHelpTooltip();
        this._createMeasureTooltip();
        
        // Добавляем обработчик движения мыши
        this.map.on('pointermove', this._pointerMoveHandler);
    }

    /**
     * Активирует режим измерения площадей
     */
    startMeasureArea() {
        this._clearMeasurement();
        this.measureType = 'area';
        this.active = true;
        this._addInteraction();
        this._createHelpTooltip();
        this._createMeasureTooltip();
        
        // Добавляем обработчик движения мыши
        this.map.on('pointermove', this._pointerMoveHandler);
    }

    /**
     * Деактивирует режим измерения
     */
    stopMeasure() {
        if (this.currentInteraction) {
            this.map.removeInteraction(this.currentInteraction);
            this.currentInteraction = null;
        }
        
        this.map.un('pointermove', this._pointerMoveHandler);
        this.active = false;
        this.measureType = null;
        
        this._removeHelpTooltip();
        this._removeMeasureTooltip();
    }

    /**
     * Очищает все измерения
     */
    clearMeasurements() {
        this.stopMeasure();
        this.measurementSource.clear();
    }

    /**
     * Добавляет взаимодействие для рисования
     * @private
     */
    _addInteraction() {
        const type = this.measureType === 'area' ? 'Polygon' : 'LineString';
        
        this.currentInteraction = new ol.interaction.Draw({
            source: this.measurementSource,
            type: type,
            style: new ol.style.Style({
                fill: new ol.style.Fill({
                    color: 'rgba(255, 255, 255, 0.2)'
                }),
                stroke: new ol.style.Stroke({
                    color: 'rgba(0, 0, 0, 0.5)',
                    lineDash: [10, 10],
                    width: 2
                }),
                image: new ol.style.Circle({
                    radius: 5,
                    stroke: new ol.style.Stroke({
                        color: 'rgba(0, 0, 0, 0.7)'
                    }),
                    fill: new ol.style.Fill({
                        color: 'rgba(255, 255, 255, 0.2)'
                    })
                })
            })
        });
        
        this.map.addInteraction(this.currentInteraction);
        
        this.currentInteraction.on('drawstart', this._onDrawStart.bind(this));
        this.currentInteraction.on('drawend', this._onDrawEnd.bind(this));
    }

    /**
     * Обработчик начала рисования
     * @private
     * @param {Object} evt Событие
     */
    _onDrawStart(evt) {
        this.sketch = evt.feature;

        // Слушаем геометрию
        this.sketch.getGeometry().on('change', this._onGeometryChange.bind(this));
    }

    /**
     * Обработчик завершения рисования
     * @private
     * @param {Object} evt Событие
     */
    _onDrawEnd(evt) {
        // Фиксируем тултип
        this.measureTooltipElement.className = 'ol-tooltip ol-tooltip-static';
        this.measureTooltip.setOffset([0, -7]);
        
        // Сбрасываем объекты
        this.sketch = null;
        this.measureTooltipElement = null;
        
        // Создаем новый тултип для следующего измерения
        this._createMeasureTooltip();
    }

    /**
     * Обработчик изменения геометрии
     * @private
     * @param {Object} evt Событие
     */
    _onGeometryChange(evt) {
        const geom = evt.target;
        let measure;
        
        if (this.measureType === 'area' && geom instanceof ol.geom.Polygon) {
            measure = this._formatArea(geom);
            this.measureTooltipElement.innerHTML = measure;
        } else if (this.measureType === 'distance' && geom instanceof ol.geom.LineString) {
            measure = this._formatLength(geom);
            this.measureTooltipElement.innerHTML = measure;
        }
    }

    /**
     * Форматирует длину линии с учетом выбранных единиц измерения
     * @private
     * @param {ol.geom.LineString} line Линия
     * @returns {string} Отформатированная длина
     */
    _formatLength(line) {
        const length = this._getLineLength(line);
        let output;
        
        if (this.options.distanceUnit === 'kilometers') {
            output = (length / 1000).toFixed(this.options.precision) + ' км';
        } else if (this.options.distanceUnit === 'miles') {
            output = (length / 1609.34).toFixed(this.options.precision) + ' миль';
        } else {
            output = length.toFixed(this.options.precision) + ' м';
        }
        
        return output;
    }

    /**
     * Вычисляет длину линии с учетом проекции
     * @private
     * @param {ol.geom.LineString} line Линия
     * @returns {number} Длина в метрах
     */
    _getLineLength(line) {
        const sourceProj = this.map.getView().getProjection();
        let length = 0;
        
        // Копируем линию и преобразуем в WGS84 для геодезических вычислений
        const coordinates = line.getCoordinates();
        if (coordinates.length > 1) {
            for (let i = 0, ii = coordinates.length - 1; i < ii; ++i) {
                const c1 = ol.proj.transform(coordinates[i], sourceProj, 'EPSG:4326');
                const c2 = ol.proj.transform(coordinates[i + 1], sourceProj, 'EPSG:4326');
                length += this._haversineDistance(c1, c2);
            }
        }
        
        return length;
    }

    /**
     * Вычисляет расстояние между двумя точками по формуле гаверсинуса
     * @private
     * @param {Array<number>} coord1 Координаты первой точки [lon, lat]
     * @param {Array<number>} coord2 Координаты второй точки [lon, lat]
     * @returns {number} Расстояние в метрах
     */
    _haversineDistance(coord1, coord2) {
        const R = 6371000; // Радиус Земли в метрах
        const dLat = this._toRad(coord2[1] - coord1[1]);
        const dLon = this._toRad(coord2[0] - coord1[0]);
        
        const a = 
            Math.sin(dLat/2) * Math.sin(dLat/2) +
            Math.cos(this._toRad(coord1[1])) * Math.cos(this._toRad(coord2[1])) *
            Math.sin(dLon/2) * Math.sin(dLon/2);
        
        const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
        const d = R * c;
        
        return d;
    }

    /**
     * Преобразует градусы в радианы
     * @private
     * @param {number} deg Градусы
     * @returns {number} Радианы
     */
    _toRad(deg) {
        return deg * Math.PI / 180;
    }

    /**
     * Форматирует площадь полигона с учетом выбранных единиц измерения
     * @private
     * @param {ol.geom.Polygon} polygon Полигон
     * @returns {string} Отформатированная площадь
     */
    _formatArea(polygon) {
        const area = this._getPolygonArea(polygon);
        let output;
        
        if (this.options.areaUnit === 'hectares') {
            output = (area / 10000).toFixed(this.options.precision) + ' га';
        } else if (this.options.areaUnit === 'squareKilometers') {
            output = (area / 1000000).toFixed(this.options.precision) + ' км²';
        } else {
            output = area.toFixed(this.options.precision) + ' м²';
        }
        
        return output;
    }

    /**
     * Вычисляет площадь полигона с учетом проекции
     * @private
     * @param {ol.geom.Polygon} polygon Полигон
     * @returns {number} Площадь в квадратных метрах
     */
    _getPolygonArea(polygon) {
        const sourceProj = this.map.getView().getProjection();
        
        // Копируем полигон и преобразуем в WGS84 для геодезических вычислений
        const geom = polygon.clone().transform(sourceProj, 'EPSG:4326');
        
        // Вычисляем площадь с учетом сфероида
        const coordinates = geom.getCoordinates();
        // Используем первый набор координат (внешний контур полигона)
        return Math.abs(this._computeSphericalArea(coordinates[0]));
    }

    /**
     * Вычисляет площадь на сферической поверхности
     * @private
     * @param {Array<Array<number>>} coordinates Массив координат [lon, lat]
     * @returns {number} Площадь в квадратных метрах
     */
    _computeSphericalArea(coordinates) {
        const R = 6371000; // Радиус Земли в метрах
        
        if (coordinates.length < 3) {
            return 0;
        }
        
        let total = 0;
        const len = coordinates.length;
        
        for (let i = 0; i < len; i++) {
            const j = (i + 1) % len;
            const p1 = coordinates[i];
            const p2 = coordinates[j];
            
            const lon1 = this._toRad(p1[0]);
            const lat1 = this._toRad(p1[1]);
            const lon2 = this._toRad(p2[0]);
            const lat2 = this._toRad(p2[1]);
            
            total += (lon2 - lon1) * (2 + Math.sin(lat1) + Math.sin(lat2));
        }
        
        total = total * R * R / 2;
        
        return Math.abs(total);
    }

    /**
     * Обработчик движения указателя
     * @private
     * @param {ol.MapBrowserEvent} evt Событие
     */
    _pointerMoveHandler(evt) {
        if (evt.dragging) {
            return;
        }

        if (this.sketch) {
            const geom = this.sketch.getGeometry();
            if (geom instanceof ol.geom.Polygon) {
                // Устанавливаем положение тултипа в середине полигона
                this.measureTooltip.setPosition(geom.getInteriorPoint().getCoordinates());
            } else if (geom instanceof ol.geom.LineString) {
                // Устанавливаем положение тултипа на конце линии
                this.measureTooltip.setPosition(geom.getLastCoordinate());
            }
        }
        
        // Обновляем позицию вспомогательного тултипа
        if (this.helpTooltipElement) {
            this.helpTooltip.setPosition(evt.coordinate);
            
            this.helpTooltipElement.classList.remove('hidden');
            
            const helpText = this.measureType === 'area' ? 
                'Кликните для добавления вершины полигона' :
                'Кликните для добавления точки';
                
            this.helpTooltipElement.innerHTML = helpText;
        }
    }

    /**
     * Создает всплывающую подсказку для измерений
     * @private
     */
    _createMeasureTooltip() {
        if (this.measureTooltipElement) {
            this.measureTooltipElement.parentNode.removeChild(this.measureTooltipElement);
        }
        
        this.measureTooltipElement = document.createElement('div');
        this.measureTooltipElement.className = 'ol-tooltip ol-tooltip-measure';
        
        this.measureTooltip = new ol.Overlay({
            element: this.measureTooltipElement,
            offset: [0, -15],
            positioning: 'bottom-center',
            stopEvent: false
        });
        
        this.map.addOverlay(this.measureTooltip);
    }

    /**
     * Создает вспомогательную всплывающую подсказку
     * @private
     */
    _createHelpTooltip() {
        if (this.helpTooltipElement) {
            this.helpTooltipElement.parentNode.removeChild(this.helpTooltipElement);
        }
        
        this.helpTooltipElement = document.createElement('div');
        this.helpTooltipElement.className = 'ol-tooltip';
        
        this.helpTooltip = new ol.Overlay({
            element: this.helpTooltipElement,
            offset: [15, 0],
            positioning: 'center-left'
        });
        
        this.map.addOverlay(this.helpTooltip);
    }

    /**
     * Удаляет всплывающую подсказку для измерений
     * @private
     */
    _removeMeasureTooltip() {
        if (this.measureTooltipElement) {
            this.measureTooltipElement.parentNode.removeChild(this.measureTooltipElement);
            this.measureTooltipElement = null;
        }
        
        if (this.measureTooltip) {
            this.map.removeOverlay(this.measureTooltip);
            this.measureTooltip = null;
        }
    }

    /**
     * Удаляет вспомогательную всплывающую подсказку
     * @private
     */
    _removeHelpTooltip() {
        if (this.helpTooltipElement) {
            this.helpTooltipElement.parentNode.removeChild(this.helpTooltipElement);
            this.helpTooltipElement = null;
        }
        
        if (this.helpTooltip) {
            this.map.removeOverlay(this.helpTooltip);
            this.helpTooltip = null;
        }
    }

    /**
     * Очищает текущее измерение
     * @private
     */
    _clearMeasurement() {
        this.stopMeasure();
        this.measurementSource.clear();
    }
} 