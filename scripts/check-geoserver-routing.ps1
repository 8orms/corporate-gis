# check-geoserver-routing.ps1
# Скрипт для проверки корректности маршрутизации запросов к разным инстанциям GeoServer
# Автор: Corporate GIS Team
# Дата: 27.02.2025

param (
    [switch]$Verbose,
    [switch]$Fix,
    [string]$BaseUrl = "http://localhost"
)

# Функция для вывода сообщений с цветовой кодировкой
function Write-ColorMessage {
    param (
        [string]$Message,
        [string]$Color = "White",
        [switch]$NoNewLine
    )
    
    if ($NoNewLine) {
        Write-Host $Message -ForegroundColor $Color -NoNewline
    } else {
        Write-Host $Message -ForegroundColor $Color
    }
}

# Функция для проверки доступности URL
function Test-Url {
    param (
        [string]$Url,
        [string]$Description,
        [string]$ExpectedInstance = $null
    )
    
    Write-ColorMessage "Проверка $Description... " -Color Cyan -NoNewLine
    
    try {
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -Method Head -ErrorAction Stop
        
        # Проверка статуса ответа
        if ($response.StatusCode -eq 200) {
            Write-ColorMessage "OK (200)" -Color Green
            
            # Проверка заголовка X-GeoServer-Instance, если ожидается определенная инстанция
            if ($ExpectedInstance -and $response.Headers.ContainsKey("X-GeoServer-Instance")) {
                $instance = $response.Headers["X-GeoServer-Instance"]
                if ($instance -eq $ExpectedInstance) {
                    Write-ColorMessage "  ✓ Инстанция: $instance (ожидалась: $ExpectedInstance)" -Color Green
                } else {
                    Write-ColorMessage "  ✗ Инстанция: $instance (ожидалась: $ExpectedInstance)" -Color Red
                }
            }
            
            # Вывод дополнительной информации в режиме Verbose
            if ($Verbose) {
                Write-ColorMessage "  URL: $Url" -Color Gray
                Write-ColorMessage "  Заголовки ответа:" -Color Gray
                foreach ($header in $response.Headers.GetEnumerator()) {
                    Write-ColorMessage "    $($header.Key): $($header.Value)" -Color Gray
                }
            }
            
            return $true
        } else {
            Write-ColorMessage "Ошибка ($($response.StatusCode))" -Color Red
            return $false
        }
    } catch {
        Write-ColorMessage "Ошибка: $_" -Color Red
        return $false
    }
}

# Функция для проверки WMS запроса
function Test-WmsRequest {
    param (
        [string]$Url,
        [string]$Instance
    )
    
    $wmsUrl = "$Url/geoserver/$Instance/wms?service=WMS&version=1.1.0&request=GetCapabilities"
    Test-Url -Url $wmsUrl -Description "WMS GetCapabilities для $Instance" -ExpectedInstance $Instance
}

# Функция для исправления проблем с маршрутизацией
function Fix-RoutingIssues {
    param (
        [string]$NginxConfigPath = "config/nginx/conf.d/default.conf"
    )
    
    Write-ColorMessage "Проверка конфигурации NGINX..." -Color Yellow
    
    # Проверка существования файла конфигурации
    if (-not (Test-Path $NginxConfigPath)) {
        Write-ColorMessage "Ошибка: Файл конфигурации NGINX не найден по пути $NginxConfigPath" -Color Red
        return $false
    }
    
    # Создание резервной копии
    $backupPath = "$NginxConfigPath.bak.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Copy-Item -Path $NginxConfigPath -Destination $backupPath
    Write-ColorMessage "Создана резервная копия: $backupPath" -Color Green
    
    # Чтение конфигурации
    $config = Get-Content -Path $NginxConfigPath -Raw
    
    # Проверка и исправление проблем с маршрутизацией
    $modified = $false
    
    # 1. Проверка наличия заголовков X-GeoServer-Instance
    if (-not ($config -match "add_header X-GeoServer-Instance")) {
        Write-ColorMessage "Добавление заголовков X-GeoServer-Instance для идентификации инстанций..." -Color Yellow
        
        # Добавление заголовков для Vector GeoServer
        $config = $config -replace "(location /geoserver/vector/.*?{.*?proxy_read_timeout \d+;)", "`$1`n        # Добавляем заголовок для идентификации инстанции`n        add_header X-GeoServer-Instance `"vector`" always;"
        
        # Добавление заголовков для ECW GeoServer
        $config = $config -replace "(location /geoserver/ecw/.*?{.*?proxy_read_timeout \d+;)", "`$1`n        # Добавляем заголовок для идентификации инстанции`n        add_header X-GeoServer-Instance `"ecw`" always;"
        
        $modified = $true
    }
    
    # 2. Проверка наличия блоков для WFS и WCS
    if (-not ($config -match "location ~ \^/geoserver/vector/wfs")) {
        Write-ColorMessage "Добавление блока для WFS запросов к Vector GeoServer..." -Color Yellow
        
        # Добавление блока WFS для Vector GeoServer
        $wfsBlock = @"
    # Обработка WFS запросов для Vector GeoServer
    location ~ ^/geoserver/vector/wfs {
        proxy_pass http://geoserver_vector/geoserver/wfs;
        proxy_set_header Host `$host;
        proxy_set_header X-Real-IP `$remote_addr;
        proxy_set_header X-Forwarded-For `$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto `$scheme;
        
        # Добавляем заголовок для идентификации инстанции
        add_header X-GeoServer-Instance "vector" always;
    }

"@
        
        # Вставка блока WFS после блока WMS для Vector GeoServer
        $config = $config -replace "(# Обработка WMS запросов для Vector GeoServer.*?proxy_busy_buffers_size \d+k;\s*})", "`$1`n`n$wfsBlock"
        
        $modified = $true
    }
    
    if (-not ($config -match "location ~ \^/geoserver/ecw/wcs")) {
        Write-ColorMessage "Добавление блока для WCS запросов к ECW GeoServer..." -Color Yellow
        
        # Добавление блока WCS для ECW GeoServer
        $wcsBlock = @"
    # Обработка WCS запросов для ECW GeoServer (для растровых данных)
    location ~ ^/geoserver/ecw/wcs {
        proxy_pass http://geoserver_ecw/geoserver/wcs;
        proxy_set_header Host `$host;
        proxy_set_header X-Real-IP `$remote_addr;
        proxy_set_header X-Forwarded-For `$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto `$scheme;
        
        # Добавляем заголовок для идентификации инстанции
        add_header X-GeoServer-Instance "ecw" always;
    }

"@
        
        # Вставка блока WCS после блока WMS для ECW GeoServer
        $config = $config -replace "(# Обработка WMS запросов для ECW GeoServer.*?proxy_busy_buffers_size \d+k;\s*})", "`$1`n`n$wcsBlock"
        
        $modified = $true
    }
    
    # 3. Проверка наличия логирования маршрутизации
    if (-not ($config -match "log_format geoserver_routing")) {
        Write-ColorMessage "Добавление настройки логирования маршрутизации..." -Color Yellow
        
        # Добавление формата логирования
        $logFormat = @"
# Настройка логов для отслеживания маршрутизации запросов
log_format geoserver_routing '`$remote_addr - `$remote_user [`$time_local] '
                           '"`$request" `$status `$body_bytes_sent '
                           '"`$http_referer" "`$http_user_agent" '
                           'routing=`$upstream_addr';

"@
        
        # Вставка формата логирования после определения upstream
        $config = $config -replace "(upstream geoserver_ecw {.*?})", "`$1`n`n$logFormat"
        
        # Добавление использования формата логирования в server блок
        $config = $config -replace "(server {.*?index index.html;)", "`$1`n`n    # Включение логирования маршрутизации для отладки`n    access_log /var/log/nginx/access.log geoserver_routing;`n    error_log /var/log/nginx/error.log warn;"
        
        $modified = $true
    }
    
    # Сохранение изменений, если были модификации
    if ($modified) {
        Set-Content -Path $NginxConfigPath -Value $config
        Write-ColorMessage "Конфигурация NGINX обновлена. Необходимо перезапустить NGINX." -Color Green
        
        # Перезапуск NGINX
        Write-ColorMessage "Перезапуск NGINX..." -Color Yellow
        docker restart dev-nginx-1
        
        Write-ColorMessage "NGINX перезапущен." -Color Green
        return $true
    } else {
        Write-ColorMessage "Конфигурация NGINX уже содержит все необходимые настройки." -Color Green
        return $true
    }
}

# Основная функция проверки маршрутизации
function Check-GeoServerRouting {
    Write-ColorMessage "=== Проверка маршрутизации запросов к GeoServer ===" -Color Magenta
    Write-ColorMessage "Базовый URL: $BaseUrl" -Color Yellow
    Write-ColorMessage "Дата и время: $(Get-Date)" -Color Yellow
    Write-ColorMessage "=======================================" -Color Magenta
    
    # Проверка доступности NGINX
    $nginxOk = Test-Url -Url $BaseUrl -Description "Доступность NGINX"
    if (-not $nginxOk) {
        Write-ColorMessage "NGINX недоступен. Проверьте, запущен ли контейнер." -Color Red
        return
    }
    
    # Проверка страницы выбора GeoServer
    $selectionPageOk = Test-Url -Url "$BaseUrl/geoserver/" -Description "Страница выбора GeoServer"
    
    # Проверка доступности Vector GeoServer
    $vectorOk = Test-Url -Url "$BaseUrl/geoserver/vector/web/" -Description "Vector GeoServer Web UI" -ExpectedInstance "vector"
    
    # Проверка доступности ECW GeoServer
    $ecwOk = Test-Url -Url "$BaseUrl/geoserver/ecw/web/" -Description "ECW GeoServer Web UI" -ExpectedInstance "ecw"
    
    # Проверка WMS запросов
    Write-ColorMessage "`nПроверка WMS запросов:" -Color Magenta
    $vectorWmsOk = Test-WmsRequest -Url $BaseUrl -Instance "vector"
    $ecwWmsOk = Test-WmsRequest -Url $BaseUrl -Instance "ecw"
    
    # Проверка прямого доступа к GeoServer (должен быть через NGINX)
    Write-ColorMessage "`nПроверка прямого доступа к GeoServer:" -Color Magenta
    $directVectorOk = Test-Url -Url "http://localhost:8080/geoserver/web/" -Description "Прямой доступ к Vector GeoServer"
    $directEcwOk = Test-Url -Url "http://localhost:8081/geoserver/web/" -Description "Прямой доступ к ECW GeoServer"
    
    # Вывод итогов проверки
    Write-ColorMessage "`n=== Итоги проверки ===" -Color Magenta
    Write-ColorMessage "NGINX: $(if ($nginxOk) { "✓" } else { "✗" })" -Color $(if ($nginxOk) { "Green" } else { "Red" })
    Write-ColorMessage "Страница выбора GeoServer: $(if ($selectionPageOk) { "✓" } else { "✗" })" -Color $(if ($selectionPageOk) { "Green" } else { "Red" })
    Write-ColorMessage "Vector GeoServer Web UI: $(if ($vectorOk) { "✓" } else { "✗" })" -Color $(if ($vectorOk) { "Green" } else { "Red" })
    Write-ColorMessage "ECW GeoServer Web UI: $(if ($ecwOk) { "✓" } else { "✗" })" -Color $(if ($ecwOk) { "Green" } else { "Red" })
    Write-ColorMessage "Vector GeoServer WMS: $(if ($vectorWmsOk) { "✓" } else { "✗" })" -Color $(if ($vectorWmsOk) { "Green" } else { "Red" })
    Write-ColorMessage "ECW GeoServer WMS: $(if ($ecwWmsOk) { "✓" } else { "✗" })" -Color $(if ($ecwWmsOk) { "Green" } else { "Red" })
    
    # Проверка на наличие проблем
    $hasIssues = -not ($nginxOk -and $selectionPageOk -and $vectorOk -and $ecwOk -and $vectorWmsOk -and $ecwWmsOk)
    
    if ($hasIssues) {
        Write-ColorMessage "`nОбнаружены проблемы с маршрутизацией запросов к GeoServer." -Color Red
        
        if ($Fix) {
            Write-ColorMessage "Попытка автоматического исправления проблем..." -Color Yellow
            Fix-RoutingIssues
        } else {
            Write-ColorMessage "Для автоматического исправления проблем запустите скрипт с параметром -Fix" -Color Yellow
        }
    } else {
        Write-ColorMessage "`nМаршрутизация запросов к GeoServer работает корректно." -Color Green
    }
}

# Запуск основной функции
Check-GeoServerRouting 