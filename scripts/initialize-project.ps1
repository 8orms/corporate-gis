# Скрипт инициализации проекта Corporate GIS
# Создает необходимые директории, настраивает конфигурационные файлы
# и подготавливает окружение для разработки

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("dev", "prod")]
    [string]$Environment = "dev",
    
    [Parameter(Mandatory=$false)]
    [switch]$Force
)

# Цветной вывод для лучшей читаемости
function Write-Title {
    param([string]$Text)
    Write-Host "`n========== $Text ==========" -ForegroundColor Cyan
}

function Write-Step {
    param([string]$Text)
    Write-Host ">> $Text" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Text)
    Write-Host "ВНИМАНИЕ: $Text" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Text)
    Write-Host "ОШИБКА: $Text" -ForegroundColor Red
}

function Write-Success {
    param([string]$Text)
    Write-Host "УСПЕХ: $Text" -ForegroundColor Green
}

# Проверка наличия Docker
function Test-DockerInstalled {
    try {
        $dockerVersion = & docker --version
        if ($LASTEXITCODE -eq 0) {
            Write-Step "Docker установлен: $dockerVersion"
            return $true
        }
    }
    catch {
        return $false
    }
    
    Write-Error "Docker не установлен или не доступен в PATH"
    Write-Host "Установите Docker Desktop с сайта: https://www.docker.com/products/docker-desktop/" -ForegroundColor White
    return $false
}

# Проверка наличия Docker Compose
function Test-DockerComposeAvailable {
    try {
        $composeVersion = & docker-compose --version
        if ($LASTEXITCODE -eq 0) {
            Write-Step "Docker Compose установлен: $composeVersion"
            return $true
        }
    }
    catch {
        return $false
    }
    
    # В новых версиях Docker Desktop compose может быть доступен через docker compose
    try {
        $composeVersion = & docker compose version
        if ($LASTEXITCODE -eq 0) {
            Write-Step "Docker Compose (новый синтаксис) установлен: $composeVersion"
            return $true
        }
    }
    catch {
        Write-Error "Docker Compose не установлен или не доступен"
        Write-Host "Docker Compose должен быть установлен вместе с Docker Desktop" -ForegroundColor White
        return $false
    }
}

# Проверка наличия Git
function Test-GitInstalled {
    try {
        $gitVersion = & git --version
        if ($LASTEXITCODE -eq 0) {
            Write-Step "Git установлен: $gitVersion"
            return $true
        }
    }
    catch {
        Write-Error "Git не установлен или не доступен в PATH"
        Write-Host "Установите Git с сайта: https://git-scm.com/downloads" -ForegroundColor White
        return $false
    }
}

# Создание структуры директорий
function Create-DirectoryStructure {
    Write-Title "Создание структуры директорий"
    
    $directories = @(
        "docs",
        "config/docker/dev",
        "config/docker/prod",
        "config/geoserver/vector",
        "config/geoserver/ecw",
        "config/nginx",
        "data/postgis",
        "data/geoserver/vector/data_dir",
        "data/geoserver/ecw/data_dir",
        "data/raster-storage/ecw",
        "data/vector-storage/shp",
        "data/vector-storage/kml",
        "data/user-projections",
        "scripts",
        "src/web-interface",
        "src/services"
    )
    
    foreach ($dir in $directories) {
        $path = $dir
        if (-not (Test-Path $path)) {
            Write-Step "Создание директории: $path"
            New-Item -ItemType Directory -Force -Path $path | Out-Null
        }
        else {
            Write-Host "Директория уже существует: $path" -ForegroundColor Gray
        }
    }
    
    Write-Success "Структура директорий создана"
}

# Создание файла .gitignore
function Create-GitIgnore {
    Write-Title "Создание файла .gitignore"
    
    $gitignorePath = ".gitignore"
    $gitignoreContent = @"
# Игнорировать директории с данными
/data/postgis/
/data/geoserver/*/data_dir/
/data/raster-storage/
/data/vector-storage/

# Игнорировать логи
*.log
logs/

# Игнорировать файлы среды
.env
.env.*
!.env.example

# Игнорировать временные файлы
*.tmp
*.temp
*.swp
*~

# Игнорировать файлы IDE
.idea/
.vscode/
*.iml
.vs/

# Игнорировать файлы Windows
Thumbs.db
desktop.ini

# Игнорировать файлы macOS
.DS_Store

# Игнорировать кэш Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
env/
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
*.egg-info/
.installed.cfg
*.egg

# Игнорировать пакеты Node.js
node_modules/
npm-debug.log
yarn-error.log
yarn-debug.log
"@
    
    if (-not (Test-Path $gitignorePath) -or $Force) {
        Write-Step "Создание файла .gitignore"
        Set-Content -Path $gitignorePath -Value $gitignoreContent
    }
    else {
        Write-Warning "Файл .gitignore уже существует. Пропуск."
    }
}

# Создание примера файла .env
function Create-EnvExample {
    Write-Title "Создание примера файла .env"
    
    $envExamplePath = ".env.example"
    $envExampleContent = @"
# Настройки базы данных PostGIS
POSTGRES_USER=gis_admin
POSTGRES_PASSWORD=strongpassword
POSTGRES_DB=gis_db
POSTGIS_HOST=postgis
POSTGIS_PORT=5432

# Настройки GeoServer
GEOSERVER_ADMIN_USER=admin
GEOSERVER_ADMIN_PASSWORD=geoserver
GEOSERVER_DATA_DIR=/opt/geoserver/data_dir
GEOSERVER_VECTOR_HTTP_PORT=8080
GEOSERVER_ECW_HTTP_PORT=8081

# Настройки путей хранения данных
VECTOR_DATA_PATH=./data/vector-storage
RASTER_DATA_PATH=./data/raster-storage
POSTGIS_DATA_PATH=./data/postgis

# Настройки для разработки
DEVELOPMENT_MODE=true
DEBUG=true

# Настройки для продакшена
# DEVELOPMENT_MODE=false
# DEBUG=false
"@
    
    if (-not (Test-Path $envExamplePath) -or $Force) {
        Write-Step "Создание файла $envExamplePath"
        Set-Content -Path $envExamplePath -Value $envExampleContent
    }
    else {
        Write-Warning "Файл $envExamplePath уже существует. Пропуск."
    }
    
    $envPath = ".env"
    if (-not (Test-Path $envPath)) {
        Write-Step "Создание файла .env на основе примера"
        Copy-Item -Path $envExamplePath -Destination $envPath
    }
    else {
        Write-Warning "Файл .env уже существует. Пропуск."
    }
}

# Создание файла Docker Compose для выбранного окружения
function Create-DockerCompose {
    param([string]$Environment)
    
    Write-Title "Создание файла docker-compose.yml для окружения: $Environment"
    
    $dockerComposePath = "docker-compose.yml"
    $dockerComposeDevPath = "config/docker/dev/docker-compose.yml"
    $dockerComposeProdPath = "config/docker/prod/docker-compose.yml"
    
    # Базовая конфигурация для разработки
    $dockerComposeDevContent = @"
version: '3.8'

services:
  postgis:
    image: postgis/postgis:15-3.3
    container_name: corporate-gis-postgis
    environment:
      - POSTGRES_USER=\${POSTGRES_USER:-gis_admin}
      - POSTGRES_PASSWORD=\${POSTGRES_PASSWORD:-strongpassword}
      - POSTGRES_DB=\${POSTGRES_DB:-gis_db}
    volumes:
      - \${POSTGIS_DATA_PATH:-./data/postgis}:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    networks:
      - gis_network
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U \${POSTGRES_USER:-gis_admin} -d \${POSTGRES_DB:-gis_db}"]
      interval: 10s
      timeout: 5s
      retries: 5

  geoserver-vector:
    image: kartoza/geoserver:2.21.2
    container_name: corporate-gis-geoserver-vector
    environment:
      - GEOSERVER_DATA_DIR=\${GEOSERVER_DATA_DIR:-/opt/geoserver/data_dir}
      - GEOSERVER_ADMIN_USER=\${GEOSERVER_ADMIN_USER:-admin}
      - GEOSERVER_ADMIN_PASSWORD=\${GEOSERVER_ADMIN_PASSWORD:-geoserver}
      - INITIAL_MEMORY=2G
      - MAXIMUM_MEMORY=4G
    volumes:
      - ./data/geoserver/vector/data_dir:\${GEOSERVER_DATA_DIR:-/opt/geoserver/data_dir}
      - \${VECTOR_DATA_PATH:-./data/vector-storage}:/opt/geoserver/vector-data
    ports:
      - "\${GEOSERVER_VECTOR_HTTP_PORT:-8080}:8080"
    depends_on:
      - postgis
    networks:
      - gis_network
    restart: unless-stopped
    healthcheck:
      test: curl --fail -s http://localhost:8080/geoserver/web/ || exit 1
      interval: 30s
      timeout: 10s
      retries: 3

  geoserver-ecw:
    image: kartoza/geoserver:2.21.2
    container_name: corporate-gis-geoserver-ecw
    environment:
      - GEOSERVER_DATA_DIR=\${GEOSERVER_DATA_DIR:-/opt/geoserver/data_dir}
      - GEOSERVER_ADMIN_USER=\${GEOSERVER_ADMIN_USER:-admin}
      - GEOSERVER_ADMIN_PASSWORD=\${GEOSERVER_ADMIN_PASSWORD:-geoserver}
      - INITIAL_MEMORY=2G
      - MAXIMUM_MEMORY=6G
    volumes:
      - ./data/geoserver/ecw/data_dir:\${GEOSERVER_DATA_DIR:-/opt/geoserver/data_dir}
      - \${RASTER_DATA_PATH:-./data/raster-storage}:/opt/geoserver/raster-data
      - ./config/geoserver/projections:/opt/geoserver/projections
    ports:
      - "\${GEOSERVER_ECW_HTTP_PORT:-8081}:8080"
    depends_on:
      - postgis
    networks:
      - gis_network
    restart: unless-stopped
    healthcheck:
      test: curl --fail -s http://localhost:8080/geoserver/web/ || exit 1
      interval: 30s
      timeout: 10s
      retries: 3

  nginx:
    image: nginx:1.23-alpine
    container_name: corporate-gis-nginx
    volumes:
      - ./config/nginx/nginx.conf:/etc/nginx/nginx.conf
      - ./config/nginx/conf.d:/etc/nginx/conf.d
      - ./src/web-interface:/usr/share/nginx/html
    ports:
      - "80:80"
    depends_on:
      - geoserver-vector
      - geoserver-ecw
    networks:
      - gis_network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  gis_network:
    driver: bridge
"@

    # Расширенная конфигурация для продакшена
    $dockerComposeProdContent = @"
version: '3.8'

services:
  postgis:
    image: postgis/postgis:15-3.3
    container_name: corporate-gis-postgis
    environment:
      - POSTGRES_USER=\${POSTGRES_USER:-gis_admin}
      - POSTGRES_PASSWORD=\${POSTGRES_PASSWORD:-strongpassword}
      - POSTGRES_DB=\${POSTGRES_DB:-gis_db}
    volumes:
      - \${POSTGIS_DATA_PATH:-./data/postgis}:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    networks:
      - gis_network
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U \${POSTGRES_USER:-gis_admin} -d \${POSTGRES_DB:-gis_db}"]
      interval: 10s
      timeout: 5s
      retries: 5
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 4G

  geoserver-vector:
    image: kartoza/geoserver:2.21.2
    container_name: corporate-gis-geoserver-vector
    environment:
      - GEOSERVER_DATA_DIR=\${GEOSERVER_DATA_DIR:-/opt/geoserver/data_dir}
      - GEOSERVER_ADMIN_USER=\${GEOSERVER_ADMIN_USER:-admin}
      - GEOSERVER_ADMIN_PASSWORD=\${GEOSERVER_ADMIN_PASSWORD:-geoserver}
      - INITIAL_MEMORY=2G
      - MAXIMUM_MEMORY=6G
    volumes:
      - ./data/geoserver/vector/data_dir:\${GEOSERVER_DATA_DIR:-/opt/geoserver/data_dir}
      - \${VECTOR_DATA_PATH:-./data/vector-storage}:/opt/geoserver/vector-data
    ports:
      - "\${GEOSERVER_VECTOR_HTTP_PORT:-8080}:8080"
    depends_on:
      - postgis
    networks:
      - gis_network
    restart: unless-stopped
    healthcheck:
      test: curl --fail -s http://localhost:8080/geoserver/web/ || exit 1
      interval: 30s
      timeout: 10s
      retries: 3
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 4G

  geoserver-ecw:
    image: kartoza/geoserver:2.21.2
    container_name: corporate-gis-geoserver-ecw
    environment:
      - GEOSERVER_DATA_DIR=\${GEOSERVER_DATA_DIR:-/opt/geoserver/data_dir}
      - GEOSERVER_ADMIN_USER=\${GEOSERVER_ADMIN_USER:-admin}
      - GEOSERVER_ADMIN_PASSWORD=\${GEOSERVER_ADMIN_PASSWORD:-geoserver}
      - INITIAL_MEMORY=4G
      - MAXIMUM_MEMORY=8G
    volumes:
      - ./data/geoserver/ecw/data_dir:\${GEOSERVER_DATA_DIR:-/opt/geoserver/data_dir}
      - \${RASTER_DATA_PATH:-./data/raster-storage}:/opt/geoserver/raster-data
      - ./config/geoserver/projections:/opt/geoserver/projections
    ports:
      - "\${GEOSERVER_ECW_HTTP_PORT:-8081}:8080"
    depends_on:
      - postgis
    networks:
      - gis_network
    restart: unless-stopped
    healthcheck:
      test: curl --fail -s http://localhost:8080/geoserver/web/ || exit 1
      interval: 30s
      timeout: 10s
      retries: 3
    deploy:
      resources:
        limits:
          cpus: '4'
          memory: 12G

  nginx:
    image: nginx:1.23-alpine
    container_name: corporate-gis-nginx
    volumes:
      - ./config/nginx/nginx.conf:/etc/nginx/nginx.conf
      - ./config/nginx/conf.d:/etc/nginx/conf.d
      - ./src/web-interface:/usr/share/nginx/html
      - nginx_cache:/var/cache/nginx
    ports:
      - "80:80"
      - "443:443"
    depends_on:
      - geoserver-vector
      - geoserver-ecw
    networks:
      - gis_network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 1G

volumes:
  nginx_cache:

networks:
  gis_network:
    driver: bridge
"@
    
    # Сохранение конфигураций в соответствующие директории
    if (-not (Test-Path $dockerComposeDevPath) -or $Force) {
        Write-Step "Создание файла конфигурации для разработки: $dockerComposeDevPath"
        Set-Content -Path $dockerComposeDevPath -Value $dockerComposeDevContent
    }
    else {
        Write-Warning "Файл $dockerComposeDevPath уже существует. Пропуск."
    }
    
    if (-not (Test-Path $dockerComposeProdPath) -or $Force) {
        Write-Step "Создание файла конфигурации для продакшена: $dockerComposeProdPath"
        Set-Content -Path $dockerComposeProdPath -Value $dockerComposeProdContent
    }
    else {
        Write-Warning "Файл $dockerComposeProdPath уже существует. Пропуск."
    }
    
    # Создание основного файла docker-compose.yml на основе выбранного окружения
    if ($Environment -eq "dev") {
        $sourcePath = $dockerComposeDevPath
    }
    else {
        $sourcePath = $dockerComposeProdPath
    }
    
    if (-not (Test-Path $dockerComposePath) -or $Force) {
        Write-Step "Создание основного файла docker-compose.yml для окружения $Environment"
        Copy-Item -Path $sourcePath -Destination $dockerComposePath
    }
    else {
        Write-Warning "Файл docker-compose.yml уже существует. Пропуск."
    }
    
    Write-Success "Файлы Docker Compose созданы"
}

# Создание файла конфигурации NGINX
function Create-NginxConfig {
    Write-Title "Создание конфигурации NGINX"
    
    $nginxConfPath = "config/nginx/nginx.conf"
    $nginxConfDirPath = "config/nginx/conf.d"
    $nginxDefaultConfPath = "config/nginx/conf.d/default.conf"
    
    # Основной файл конфигурации NGINX
    $nginxConfContent = @"
user  nginx;
worker_processes  auto;

error_log  /var/log/nginx/error.log notice;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    keepalive_timeout  65;

    gzip  on;
    gzip_disable "msie6";
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_buffers 16 8k;
    gzip_http_version 1.1;
    gzip_min_length 256;
    gzip_types
        application/atom+xml
        application/geo+json
        application/javascript
        application/json
        application/ld+json
        application/manifest+json
        application/rdf+xml
        application/rss+xml
        application/vnd.geo+json
        application/vnd.ms-fontobject
        application/x-font-ttf
        application/x-web-app-manifest+json
        application/xhtml+xml
        application/xml
        font/opentype
        image/bmp
        image/svg+xml
        image/x-icon
        text/cache-manifest
        text/css
        text/plain
        text/vcard
        text/vnd.rim.location.xloc
        text/vtt
        text/x-component
        text/x-cross-domain-policy;

    # Кэширование файлов GeoServer WMS
    proxy_cache_path /var/cache/nginx/geoserver_cache levels=1:2 keys_zone=geoserver_cache:10m max_size=10g inactive=60m;
    proxy_cache_valid 200 302 10m;
    proxy_cache_valid 404 1m;
    
    # Включение конфигураций из директории conf.d
    include /etc/nginx/conf.d/*.conf;
}
"@
    
    # Файл конфигурации по умолчанию
    $nginxDefaultConfContent = @"
# Настройка upstream для GeoServer Vector
upstream geoserver_vector {
    server geoserver-vector:8080;
}

# Настройка upstream для GeoServer ECW
upstream geoserver_ecw {
    server geoserver-ecw:8080;
}

# Настройка сервера по умолчанию
server {
    listen 80;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    # Кодировка по умолчанию
    charset utf-8;

    # Обработка запросов к статическим файлам
    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # Обработка запросов к GeoServer Vector
    location /geoserver/vector/ {
        proxy_pass http://geoserver_vector/geoserver/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 90;
    }

    # Обработка запросов к GeoServer ECW
    location /geoserver/ecw/ {
        proxy_pass http://geoserver_ecw/geoserver/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 90;
    }

    # Кэширование запросов WMS
    location ~ ^/geoserver/.*/wms {
        proxy_pass http://geoserver_vector\$request_uri;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Настройки кэширования
        proxy_cache geoserver_cache;
        proxy_cache_key \$request_uri;
        proxy_cache_valid 200 302 10m;
        proxy_cache_valid 404 1m;
        add_header X-Cache-Status \$upstream_cache_status;
        
        # Настройки буферизации
        proxy_buffers 16 4k;
        proxy_buffer_size 2k;
        proxy_max_temp_file_size 1024m;
        proxy_busy_buffers_size 8k;
    }

    # Проверка здоровья сервера
    location /health {
        access_log off;
        return 200 "OK";
    }

    # Обработка статических файлов
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg)$ {
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }

    # Обработка ошибок
    error_page 404 /404.html;
    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        root /usr/share/nginx/html;
    }
}
"@
    
    # Создание директории для конфигураций
    if (-not (Test-Path $nginxConfDirPath)) {
        Write-Step "Создание директории для конфигураций NGINX: $nginxConfDirPath"
        New-Item -ItemType Directory -Force -Path $nginxConfDirPath | Out-Null
    }
    
    # Создание файлов конфигурации
    if (-not (Test-Path $nginxConfPath) -or $Force) {
        Write-Step "Создание основного файла конфигурации NGINX: $nginxConfPath"
        Set-Content -Path $nginxConfPath -Value $nginxConfContent
    }
    else {
        Write-Warning "Файл $nginxConfPath уже существует. Пропуск."
    }
    
    if (-not (Test-Path $nginxDefaultConfPath) -or $Force) {
        Write-Step "Создание файла конфигурации NGINX по умолчанию: $nginxDefaultConfPath"
        Set-Content -Path $nginxDefaultConfPath -Value $nginxDefaultConfContent
    }
    else {
        Write-Warning "Файл $nginxDefaultConfPath уже существует. Пропуск."
    }
    
    Write-Success "Конфигурация NGINX создана"
}

# Создание простой HTML страницы для веб-интерфейса
function Create-HTMLInterface {
    Write-Title "Создание базового веб-интерфейса"
    
    $htmlPath = "src/web-interface/index.html"
    $htmlContent = @"
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Corporate GIS Platform</title>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/ol@v7.2.2/ol.css">
    <style>
        body {
            margin: 0;
            padding: 0;
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background-color: #f8f9fa;
        }
        .container {
            display: flex;
            flex-direction: column;
            height: 100vh;
        }
        header {
            background-color: #343a40;
            color: white;
            padding: 10px 20px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .logo {
            font-size: 20px;
            font-weight: bold;
        }
        .main-content {
            display: flex;
            flex: 1;
        }
        .sidebar {
            width: 300px;
            background-color: #f0f0f0;
            padding: 15px;
            overflow-y: auto;
        }
        .map-container {
            flex: 1;
            position: relative;
        }
        #map {
            position: absolute;
            top: 0;
            bottom: 0;
            left: 0;
            right: 0;
        }
        .layer-group {
            margin-bottom: 20px;
            border: 1px solid #ddd;
            border-radius: 4px;
            overflow: hidden;
        }
        .layer-group-header {
            background-color: #e9ecef;
            padding: 10px;
            font-weight: bold;
            cursor: pointer;
        }
        .layer-group-content {
            padding: 10px;
        }
        .layer-item {
            margin-bottom: 8px;
        }
        footer {
            background-color: #343a40;
            color: white;
            padding: 10px 20px;
            text-align: center;
            font-size: 14px;
        }
        .ol-zoom {
            top: 20px;
            left: auto;
            right: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <div class="logo">Corporate GIS Platform</div>
            <div>
                <span id="coordinates"></span>
            </div>
        </header>
        
        <div class="main-content">
            <div class="sidebar">
                <h3>Слои</h3>
                
                <div class="layer-group">
                    <div class="layer-group-header" onclick="toggleLayerGroup(this)">Базовые карты</div>
                    <div class="layer-group-content">
                        <div class="layer-item">
                            <input type="radio" name="baseLayer" id="osm" checked>
                            <label for="osm">OpenStreetMap</label>
                        </div>
                        <div class="layer-item">
                            <input type="radio" name="baseLayer" id="satellite">
                            <label for="satellite">Спутник</label>
                        </div>
                    </div>
                </div>
                
                <div class="layer-group">
                    <div class="layer-group-header" onclick="toggleLayerGroup(this)">Векторные данные</div>
                    <div class="layer-group-content">
                        <!-- Здесь будут отображаться доступные векторные слои -->
                        <div class="layer-item">
                            <input type="checkbox" id="vector-layer-1">
                            <label for="vector-layer-1">Пример векторного слоя</label>
                        </div>
                    </div>
                </div>
                
                <div class="layer-group">
                    <div class="layer-group-header" onclick="toggleLayerGroup(this)">Растровые данные</div>
                    <div class="layer-group-content">
                        <!-- Здесь будут отображаться доступные растровые слои -->
                        <div class="layer-item">
                            <input type="checkbox" id="raster-layer-1">
                            <label for="raster-layer-1">Пример растрового слоя</label>
                        </div>
                    </div>
                </div>
            </div>
            
            <div class="map-container">
                <div id="map"></div>
            </div>
        </div>
        
        <footer>
            &copy; 2023 Corporate GIS Platform
        </footer>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/ol@v7.2.2/dist/ol.js"></script>
    <script>
        // Функция для переключения видимости содержимого группы слоев
        function toggleLayerGroup(header) {
            const content = header.nextElementSibling;
            content.style.display = content.style.display === 'none' ? 'block' : 'none';
        }

        // Инициализация карты OpenLayers
        const map = new ol.Map({
            target: 'map',
            layers: [
                new ol.layer.Tile({
                    source: new ol.source.OSM(),
                    title: 'OpenStreetMap'
                })
            ],
            view: new ol.View({
                center: ol.proj.fromLonLat([37.618423, 55.751244]), // Москва
                zoom: 10
            })
        });

        // Отображение координат
        const coordinatesElement = document.getElementById('coordinates');
        map.on('pointermove', function(event) {
            const coords = ol.proj.toLonLat(event.coordinate);
            coordinatesElement.textContent = `Долгота: \${coords[0].toFixed(6)}, Широта: \${coords[1].toFixed(6)}`;
        });

        // Переключение базовых слоев
        document.getElementById('osm').addEventListener('change', function() {
            if (this.checked) {
                const layers = map.getLayers().getArray();
                layers[0].setSource(new ol.source.OSM());
            }
        });

        document.getElementById('satellite').addEventListener('change', function() {
            if (this.checked) {
                const layers = map.getLayers().getArray();
                // Использование спутниковых снимков Bing
                layers[0].setSource(new ol.source.XYZ({
                    url: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                    maxZoom: 19
                }));
            }
        });

        // Пример добавления WMS слоя из GeoServer
        document.getElementById('vector-layer-1').addEventListener('change', function() {
            // Удалить или добавить слой в зависимости от состояния чекбокса
            const layerId = 'vector-layer-1';
            const layerExists = map.getLayers().getArray().some(layer => layer.get('id') === layerId);
            
            if (this.checked && !layerExists) {
                // Добавление WMS слоя из GeoServer Vector
                const vectorLayer = new ol.layer.Tile({
                    source: new ol.source.TileWMS({
                        url: '/geoserver/vector/wms',
                        params: {
                            'LAYERS': 'workspace:layer_name',
                            'TILED': true
                        },
                        serverType: 'geoserver',
                        transition: 0
                    }),
                    id: layerId
                });
                map.addLayer(vectorLayer);
            } else if (!this.checked && layerExists) {
                // Удаление слоя
                const layers = map.getLayers().getArray();
                const layerToRemove = layers.find(layer => layer.get('id') === layerId);
                if (layerToRemove) {
                    map.removeLayer(layerToRemove);
                }
            }
        });

        // Пример добавления растрового слоя из GeoServer ECW
        document.getElementById('raster-layer-1').addEventListener('change', function() {
            const layerId = 'raster-layer-1';
            const layerExists = map.getLayers().getArray().some(layer => layer.get('id') === layerId);
            
            if (this.checked && !layerExists) {
                // Добавление WMS слоя из GeoServer ECW
                const rasterLayer = new ol.layer.Tile({
                    source: new ol.source.TileWMS({
                        url: '/geoserver/ecw/wms',
                        params: {
                            'LAYERS': 'workspace:ecw_layer',
                            'TILED': true
                        },
                        serverType: 'geoserver',
                        transition: 0
                    }),
                    id: layerId
                });
                map.addLayer(rasterLayer);
            } else if (!this.checked && layerExists) {
                // Удаление слоя
                const layers = map.getLayers().getArray();
                const layerToRemove = layers.find(layer => layer.get('id') === layerId);
                if (layerToRemove) {
                    map.removeLayer(layerToRemove);
                }
            }
        });

        // Функция для загрузки списка слоев из GeoServer
        // В реальном приложении здесь будет запрос к GeoServer API
        function loadLayersFromGeoServer() {
            // Пример реализации будет добавлен позже
            console.log('Загрузка слоев из GeoServer будет реализована позже');
        }

        // Вызов функции при загрузке страницы
        // loadLayersFromGeoServer();
    </script>
</body>
</html>
"@
    
    $cssPath = "src/web-interface/css"
    $jsPath = "src/web-interface/js"
    
    # Создание директорий для стилей и скриптов
    if (-not (Test-Path $cssPath)) {
        Write-Step "Создание директории для CSS: $cssPath"
        New-Item -ItemType Directory -Force -Path $cssPath | Out-Null
    }
    
    if (-not (Test-Path $jsPath)) {
        Write-Step "Создание директории для JavaScript: $jsPath"
        New-Item -ItemType Directory -Force -Path $jsPath | Out-Null
    }
    
    # Создание HTML страницы
    if (-not (Test-Path $htmlPath) -or $Force) {
        Write-Step "Создание файла HTML интерфейса: $htmlPath"
        Set-Content -Path $htmlPath -Value $htmlContent
    }
    else {
        Write-Warning "Файл $htmlPath уже существует. Пропуск."
    }
    
    Write-Success "Базовый веб-интерфейс создан"
}

# Основная функция инициализации проекта
function Initialize-Project {
    Write-Title "Инициализация проекта Corporate GIS"
    
    # Проверка предварительных условий
    $dockerInstalled = Test-DockerInstalled
    $dockerComposeAvailable = Test-DockerComposeAvailable
    $gitInstalled = Test-GitInstalled
    
    if (-not ($dockerInstalled -and $dockerComposeAvailable -and $gitInstalled)) {
        Write-Error "Не все предварительные условия выполнены. Установите недостающие компоненты и запустите скрипт снова."
        return
    }
    
    Write-Step "Используемое окружение: $Environment"
    
    # Создание структуры директорий и файлов
    Create-DirectoryStructure
    Create-GitIgnore
    Create-EnvExample
    Create-DockerCompose -Environment $Environment
    Create-NginxConfig
    Create-HTMLInterface
    
    # Настройка пользовательских проекций
    Write-Step "Настройка пользовательских проекций..."
    & "$PSScriptRoot\setup-projections.ps1" -Force:$Force
    
    Write-Title "Проект успешно инициализирован!"
    Write-Host "Теперь вы можете запустить проект с помощью команды:" -ForegroundColor Cyan
    Write-Host "  docker-compose up -d" -ForegroundColor Yellow
    
    Write-Host "`nДоступ к компонентам:" -ForegroundColor Cyan
    Write-Host "  - Веб-интерфейс: http://localhost/" -ForegroundColor White
    Write-Host "  - GeoServer Vector: http://localhost/geoserver/vector/" -ForegroundColor White
    Write-Host "  - GeoServer ECW: http://localhost/geoserver/ecw/" -ForegroundColor White
    Write-Host "  - PostGIS: localhost:5432" -ForegroundColor White
    
    Write-Host "`nДля дополнительной информации см. документацию в папке 'docs/'." -ForegroundColor Cyan
}

# Запуск основной функции
Initialize-Project
