# Скрипт для создания структуры директорий GIS-проекта
Write-Host "Создание структуры директорий для корпоративной ГИС-платформы..." -ForegroundColor Green

# Создание директорий для документации
New-Item -ItemType Directory -Force -Path "docs" | Out-Null
Write-Host "✓ Создана директория для документации" -ForegroundColor Cyan

# Создание директорий для конфигурации
$configDirs = @(
    "config/docker/dev",
    "config/docker/prod",
    "config/nginx/conf.d",
    "config/nginx/html",
    "config/geoserver/projections",
    "config/geoserver/styles"
)

foreach ($dir in $configDirs) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
}
Write-Host "✓ Созданы директории для конфигурации" -ForegroundColor Cyan

# Создание директорий для данных
$dataDirs = @(
    "data/postgis",
    "data/geoserver/vector",
    "data/geoserver/raster",
    "data/raster-storage/ecw",
    "data/raster-storage/geotiff",
    "data/raster-storage/panoramas",
    "data/vector-storage/shapefiles",
    "data/vector-storage/lidar"
)

foreach ($dir in $dataDirs) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
}
Write-Host "✓ Созданы директории для данных" -ForegroundColor Cyan

# Создание директорий для скриптов
New-Item -ItemType Directory -Force -Path "scripts" | Out-Null
Write-Host "✓ Создана директория для скриптов" -ForegroundColor Cyan

# Создание директорий для исходного кода
$srcDirs = @(
    "src/web-interface/css",
    "src/web-interface/js",
    "src/web-interface/libs",
    "src/admin-panel"
)

foreach ($dir in $srcDirs) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
}
Write-Host "✓ Созданы директории для исходного кода" -ForegroundColor Cyan

# Перемещение существующих файлов в правильные директории
if (Test-Path "storybook.md") {
    Move-Item -Path "storybook.md" -Destination "docs/storybook.md" -Force
    Write-Host "✓ Файл storybook.md перемещен в директорию docs/" -ForegroundColor Green
}

# Создание .gitignore файла
$gitignoreContent = @"
# Игнорирование данных
/data/*
!/data/.gitkeep

# Игнорирование настроек среды разработки
.vscode/
.idea/

# Игнорирование временных файлов
*.tmp
*.log
*.bak

# Игнорирование конфиденциальных данных
.env.prod
secrets/
"@

$gitignoreContent | Out-File -FilePath ".gitignore" -Encoding utf8 -Force
Write-Host "✓ Создан файл .gitignore" -ForegroundColor Green

# Создание пустых файлов .gitkeep в директориях данных
foreach ($dir in $dataDirs) {
    New-Item -ItemType File -Force -Path "$dir/.gitkeep" | Out-Null
}
Write-Host "✓ Созданы файлы .gitkeep в директориях данных" -ForegroundColor Cyan

# Создание примера docker-compose.yml для разработки
$dockerComposeDevContent = @"
version: '3.8'

services:
  postgis:
    image: postgis/postgis:15-3.3
    environment:
      - POSTGRES_DB=gis
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
      - PGDATA=/var/lib/postgresql/data/pgdata
    ports:
      - "5432:5432"
    networks:
      - gis_network
    volumes:
      - ../../../data/postgis:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

  geoserver:
    image: kartoza/geoserver:2.26.1
    environment:
      - GEOSERVER_DATA_DIR=/opt/geoserver/data_dir
      - GEOSERVER_ADMIN_USER=admin
      - GEOSERVER_ADMIN_PASSWORD=geoserver
      - CATALINA_OPTS=-Dorg.geoserver.web.proxy.base=http://localhost:8080/geoserver
      - "INITIAL_MEMORY=512M"
      - "MAXIMUM_MEMORY=1G"
    ports:
      - "8080:8080"
    networks:
      - gis_network
    volumes:
      - ../../../data/geoserver/vector:/opt/geoserver/data_dir
      - ../../../data/raster-storage:/opt/geoserver/data_dir/raster-data
      - ../../../config/geoserver/projections:/opt/geoserver/data_dir/user_projections
    depends_on:
      - postgis
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/geoserver/web/"]
      interval: 30s
      timeout: 10s
      retries: 5

  nginx:
    image: nginx:stable
    ports:
      - "80:80"
    volumes:
      - ../../nginx/conf.d:/etc/nginx/conf.d
      - ../../nginx/html:/usr/share/nginx/html
      - ../../../src/web-interface:/usr/share/nginx/html/webgis
    networks:
      - gis_network
    depends_on:
      - geoserver

networks:
  gis_network:
    driver: bridge
"@

$dockerComposeDevContent | Out-File -FilePath "config/docker/dev/docker-compose.yml" -Encoding utf8 -Force
Write-Host "✓ Создан пример docker-compose.yml для разработки" -ForegroundColor Green

# Создание примера конфигурации NGINX
$nginxConfigContent = @"
server {
    listen 80;
    server_name localhost;
    
    # GeoServer
    location /geoserver/ {
        proxy_pass http://geoserver:8080/geoserver/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # WebGIS интерфейс
    location /webgis/ {
        root /usr/share/nginx/html;
        index index.html;
        try_files \$uri \$uri/ /webgis/index.html;
    }
    
    # Корневая страница
    location / {
        root /usr/share/nginx/html;
        index index.html;
    }
}
"@

$nginxConfigContent | Out-File -FilePath "config/nginx/conf.d/default.conf" -Encoding utf8 -Force
Write-Host "✓ Создан пример конфигурации NGINX" -ForegroundColor Green

# Создание примера HTML страницы
$htmlContent = @"
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Корпоративная ГИС-платформа</title>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/ol@7.3.0/ol.css">
    <style>
        body, html { margin: 0; padding: 0; height: 100%; font-family: Arial, sans-serif; }
        #map { width: 100%; height: 85vh; }
        #header { background-color: #3a7bdb; color: white; padding: 10px 20px; }
        #footer { background-color: #f3f3f3; text-align: center; padding: 10px; font-size: 12px; }
        .ol-attribution { font-size: 10px; }
    </style>
</head>
<body>
    <div id="header">
        <h1>Корпоративная ГИС-платформа</h1>
    </div>
    
    <div id="map"></div>
    
    <div id="footer">
        <p>Версия 0.1 | &copy; 2024 Корпоративная ГИС</p>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/ol@7.3.0/dist/ol.js"></script>
    <script>
        // Базовая OSM карта для начала
        const baseLayer = new ol.layer.Tile({
            source: new ol.source.OSM(),
            title: 'OpenStreetMap'
        });
        
        // Пример подключения WMS слоя из GeoServer
        // Раскомментируйте после настройки GeoServer и добавления слоев
        /*
        const wmsLayer = new ol.layer.Tile({
            source: new ol.source.TileWMS({
                url: '/geoserver/wms',
                params: {
                    'LAYERS': 'workspace:layer_name',
                    'TILED': true
                },
                serverType: 'geoserver'
            }),
            title: 'Векторный слой'
        });
        */
        
        const map = new ol.Map({
            target: 'map',
            layers: [baseLayer], // Добавьте wmsLayer когда он будет готов
            view: new ol.View({
                center: ol.proj.fromLonLat([37.618423, 55.751244]), // Москва
                zoom: 10
            })
        });
    </script>
</body>
</html>
"@

$htmlContent | Out-File -FilePath "src/web-interface/index.html" -Encoding utf8 -Force
Write-Host "✓ Создана примерная HTML страница" -ForegroundColor Green

# Создание корневого docker-compose.yml, который включает конфигурацию для разработки
$rootDockerComposeContent = @"
# Корневой docker-compose.yml, который подключает конфигурацию для разработки
version: '3.8'

include:
  - ./config/docker/dev/docker-compose.yml
"@

$rootDockerComposeContent | Out-File -FilePath "docker-compose.yml" -Encoding utf8 -Force
Write-Host "✓ Создан корневой docker-compose.yml" -ForegroundColor Green

# Создание примера .env файла
$envContent = @"
# PostgreSQL
POSTGRES_DB=gis
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_HOST=postgis
POSTGRES_PORT=5432

# GeoServer
GEOSERVER_ADMIN_USER=admin
GEOSERVER_ADMIN_PASSWORD=geoserver
GEOSERVER_PORT=8080

# Другие настройки
TZ=Europe/Moscow
"@

$envContent | Out-File -FilePath ".env" -Encoding utf8 -Force
Write-Host "✓ Создан пример .env файла" -ForegroundColor Green

Write-Host "`nСтруктура директорий успешно создана!" -ForegroundColor Green
Write-Host "Для запуска системы выполните:" -ForegroundColor Cyan
Write-Host "docker-compose up -d" -ForegroundColor Yellow 