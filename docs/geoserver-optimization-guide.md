# Руководство по оптимизации GeoServer

Этот документ содержит рекомендации и настройки для оптимизации производительности GeoServer в корпоративной ГИС.

## Содержание

1. [Настройки JVM и Tomcat](#1-настройки-jvm-и-tomcat)
2. [Control-Flow](#2-control-flow)
3. [Кэширование (GeoWebCache)](#3-кэширование-geowebcache)
4. [Оптимизация векторных слоев](#4-оптимизация-векторных-слоев)
5. [Оптимизация растровых данных](#5-оптимизация-растровых-данных)
6. [Настройки производительности OpenLayers](#6-настройки-производительности-openlayers)
7. [Мониторинг производительности](#7-мониторинг-производительности)
8. [Дополнительные рекомендации](#8-дополнительные-рекомендации)

## 1. Настройки JVM и Tomcat

### Оптимальные параметры JVM

```properties
# Установите в .env файле
GEOSERVER_INITIAL_MEMORY=1G
GEOSERVER_MAXIMUM_MEMORY=2G
GEOSERVER_JVM_OPTS=-XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:ParallelGCThreads=4 -Djava.awt.headless=true -Dorg.geotools.referencing.forceXY=true -Dorg.geotools.shapefile.datetime=true -DGEOSERVER_CSRF_DISABLED=true
```

### Описание параметров

- `-XX:+UseG1GC` - использование сборщика мусора G1GC, который лучше подходит для больших объемов данных
- `-XX:MaxGCPauseMillis=200` - максимальная пауза сборки мусора в 200 мс
- `-XX:ParallelGCThreads=4` - использование 4 потоков для параллельной сборки мусора
- `-Djava.awt.headless=true` - запуск в headless режиме для серверных систем
- `-Dorg.geotools.referencing.forceXY=true` - обеспечивает корректную работу с координатными системами
- `-Dorg.geotools.shapefile.datetime=true` - улучшает поддержку полей с датами в шейп-файлах

### Применение параметров

В `docker-compose.yml` добавьте для контейнеров GeoServer:

```yaml
environment:
  - "JAVA_OPTS=${GEOSERVER_JVM_OPTS}"
```

## 2. Control-Flow

Control-Flow позволяет ограничить количество одновременных запросов к GeoServer, предотвращая перегрузку системы.

### Конфигурация файла controlflow.properties

```properties
# Глобальные настройки
timeout=90

# Ограничения для WFS
ows.wfs.getfeature=5

# Ограничения для GetCapabilities
ows.wfs.getcapabilities=5/s
ows.wms.getcapabilities=5/s

# Ограничения по IP
ip.192.168.1.*=6
ip.192.168.2.*=3
```

### Описание параметров

- `timeout` - глобальный таймаут в секундах
- `ows.wfs.getfeature` - максимальное количество одновременных WFS запросов
- `ows.wfs.getcapabilities=5/s` - максимум 5 запросов GetCapabilities в секунду
- `ip.192.168.1.*=6` - ограничение для конкретного диапазона IP-адресов

## 3. Кэширование (GeoWebCache)

### Оптимальные настройки в gwc-gs.xml

```xml
<innerCachingEnabled>true</innerCachingEnabled>
<cacheConfigurations>
  <entry>
    <string>class org.geowebcache.storage.blobstore.memory.guava.GuavaCacheProvider</string>
    <InnerCacheConfiguration>
      <hardMemoryLimit>64</hardMemoryLimit>
      <policy>LEAST_FREQUENTLY_USED</policy>
      <concurrencyLevel>8</concurrencyLevel>
      <evictionTime>300</evictionTime>
    </InnerCacheConfiguration>
  </entry>
</cacheConfigurations>
<metaTilingX>8</metaTilingX>
<metaTilingY>8</metaTilingY>
```

### Описание параметров

- `innerCachingEnabled` - включает внутреннее кэширование
- `hardMemoryLimit` - объем памяти для кэша (МБ)
- `policy` - политика вытеснения (LEAST_FREQUENTLY_USED - наименее часто используемые)
- `concurrencyLevel` - уровень параллелизма для операций с кэшем
- `evictionTime` - время (в секундах) до вытеснения неиспользуемых элементов
- `metaTilingX/Y` - размер метатайла для улучшения производительности рендеринга

### Добавление поддержки формата GeoJSON

Добавьте `application/json` в список форматов для векторных слоев:

```xml
<defaultVectorCacheFormats>
  <string>application/vnd.mapbox-vector-tile</string>
  <string>application/json</string>
  <string>image/png</string>
  <string>image/jpeg</string>
</defaultVectorCacheFormats>
```

## 4. Оптимизация векторных слоев

### Индексирование и кластеризация

1. Для PostGIS слоев добавляйте пространственные индексы:
   ```sql
   CREATE INDEX idx_geom ON table_name USING GIST (geom);
   ```

2. Используйте кластеризацию данных для больших наборов:
   ```sql
   CLUSTER table_name USING idx_geom;
   ```

### Оптимизация стилей SLD

1. Используйте правила масштабирования для ограничения отображения:
   ```xml
   <MinScaleDenominator>5000</MinScaleDenominator>
   <MaxScaleDenominator>50000</MaxScaleDenominator>
   ```

2. Упрощайте геометрию для маленьких масштабов:
   ```xml
   <ogc:Function name="simplify">
     <ogc:PropertyName>geometry</ogc:PropertyName>
     <ogc:Literal>10</ogc:Literal>
   </ogc:Function>
   ```

### Предварительная генерация тайлов

Для часто запрашиваемых векторных слоев используйте предварительную генерацию тайлов через интерфейс GeoWebCache.

## 5. Оптимизация растровых данных

### Пирамиды изображений

1. Создавайте внешние пирамиды для больших растров:
   ```bash
   gdal_retile.py -ps 256 256 -levels 4 -co "TILED=YES" -co "COMPRESS=JPEG" input.tif output/
   ```

2. Используйте формат GeoTIFF с внутренними обзорами:
   ```bash
   gdaladdo -r average input.tif 2 4 8 16
   ```

### Сжатие данных

Предпочтительные форматы сжатия:
- JPEG с качеством 75-85% для аэро/космоснимков
- PNG для карт с четкими границами и текстом
- WebP для веб-приложений (хорошее сжатие с сохранением качества)

## 6. Настройки производительности OpenLayers

### Кэширование на стороне клиента

```javascript
// Кэширование GetCapabilities
const capabilitiesCache = {};
function getCachedCapabilities(url) {
    if (!capabilitiesCache[url]) {
        capabilitiesCache[url] = fetch(url)
            .then(response => response.text())
            .then(text => new DOMParser().parseFromString(text, 'application/xml'));
    }
    return capabilitiesCache[url];
}
```

### Ограничение разрешения для векторных слоев

```javascript
// Отображение только при определенном масштабе
vectorLayer.setMinResolution(0.1); // минимальное разрешение
vectorLayer.setMaxResolution(20);  // максимальное разрешение
```

### Стратегия загрузки

```javascript
// Стратегия загрузки с максимальным числом объектов
const vectorSource = new ol.source.Vector({
    format: new ol.format.GeoJSON(),
    strategy: ol.loadingstrategy.bbox,
    loader: function(extent, resolution, projection) {
        const url = `${wfsUrl}?service=WFS&version=1.1.0&request=GetFeature&typename=${layerName}` +
                    `&outputFormat=application/json&srsname=${projection.getCode()}` +
                    `&bbox=${extent.join(',')},${projection.getCode()}&maxFeatures=500`;
        
        // Добавьте механизм повторных попыток
        const fetchWithRetry = (url, retries = 3, delay = 1000) => {
            return fetch(url)
                .then(response => {
                    if (!response.ok) throw new Error(`HTTP error ${response.status}`);
                    return response.json();
                })
                .catch(error => {
                    if (retries === 0) throw error;
                    return new Promise(resolve => setTimeout(resolve, delay))
                        .then(() => fetchWithRetry(url, retries - 1, delay * 2));
                });
        };
        
        fetchWithRetry(url)
            .then(data => {
                vectorSource.addFeatures(vectorSource.getFormat().readFeatures(data));
            })
            .catch(error => {
                console.error('Error loading features:', error);
                // Показать информативное сообщение пользователю
                showErrorMessage('Ошибка загрузки данных. Попробуйте позже или обратитесь к администратору.');
            });
    }
});
```

## 7. Мониторинг производительности

### Скрипт monitor-geoserver.ps1

Используйте созданный скрипт `scripts/monitor-geoserver.ps1` для мониторинга GeoServer:

```powershell
./scripts/monitor-geoserver.ps1 -Interval 5 -Duration 10
```

### Нагрузочное тестирование

Используйте скрипт `scripts/load-test-geoserver.ps1` для тестирования под нагрузкой:

```powershell
./scripts/load-test-geoserver.ps1 -TotalRequests 100 -Parallelism 5 -Delay 100
```

### Анализ журналов

Регулярно анализируйте логи GeoServer на наличие ошибок или предупреждений:

```bash
docker logs geoserver-vector | grep ERROR
docker logs geoserver-vector | grep WARN
```

## 8. Дополнительные рекомендации

### Оптимизация баз данных PostgreSQL/PostGIS

1. Настройте автовакуум для больших таблиц:
   ```sql
   ALTER TABLE large_table SET (autovacuum_vacuum_scale_factor = 0.01, autovacuum_analyze_scale_factor = 0.005);
   ```

2. Увеличьте shared_buffers и работу с памятью:
   ```
   shared_buffers = 2GB
   work_mem = 64MB
   maintenance_work_mem = 256MB
   ```

### Сетевые настройки

1. Проверьте и оптимизируйте настройки nginx для проксирования GeoServer:
   ```nginx
   location /geoserver/ {
       proxy_pass http://geoserver-vector:8080/geoserver/;
       proxy_set_header Host $host;
       proxy_set_header X-Real-IP $remote_addr;
       proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
       proxy_set_header X-Forwarded-Proto $scheme;
       
       # Оптимизации для долгих запросов
       proxy_read_timeout 600;
       proxy_connect_timeout 600;
       proxy_send_timeout 600;
       
       # Буферизация
       proxy_buffering on;
       proxy_buffer_size 128k;
       proxy_buffers 4 256k;
       proxy_busy_buffers_size 256k;
       
       # Сжатие
       gzip on;
       gzip_types text/plain text/css application/json application/javascript text/xml application/xml;
   }
   ```

### Регулярное обслуживание

1. Периодически очищайте кэш GeoWebCache:
   ```bash
   rm -rf data/geoserver/*/gwc/diskquota_page_store/* data/geoserver/*/gwc_cache_disk/*
   ```

2. Архивируйте старые логи:
   ```bash
   find data/geoserver/*/logs -name "*.log" -mtime +30 -exec gzip {} \;
   ```

3. Выполняйте регулярные бэкапы:
   ```bash
   docker exec -t postgis pg_dumpall -c -U postgres > backup/$(date +%Y%m%d).sql
   ```

## Заключение

Применение данных рекомендаций позволит значительно повысить производительность GeoServer и обеспечить стабильную работу корпоративной ГИС даже при высоких нагрузках.

Для получения более детальной информации о текущей производительности системы, обратитесь к документу [Результаты оптимизации GeoServer](optimization-results.md). 