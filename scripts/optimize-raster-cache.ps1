# optimize-raster-cache.ps1
#
# Скрипт для оптимизации кэширования растровых слоев в GeoServer
# Использует REST API GeoServer для настройки GeoWebCache и отправки задач на генерацию тайлов
#
# Автор: GIS Team
# Дата: 01.03.2025
# Версия: 1.0

# Параметры скрипта
param (
    [Parameter(Mandatory=$false)]
    [string]$GeoServerUrl = "", # Инициализируется из .env
    
    [Parameter(Mandatory=$false)]
    [string]$AdminUser = "", # Инициализируется из .env
    
    [Parameter(Mandatory=$false)]
    [string]$AdminPassword = "", # Инициализируется из .env
    
    [Parameter(Mandatory=$false)]
    [string]$WorkspaceName = "TEST",
    
    [Parameter(Mandatory=$false)]
    [string]$LayerName = "",
    
    [Parameter(Mandatory=$false)]
    [switch]$OptimizeAll = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$GenerateTiles = $false,
    
    [Parameter(Mandatory=$false)]
    [int]$ZoomStart = 0,
    
    [Parameter(Mandatory=$false)]
    [int]$ZoomStop = 16,
    
    [Parameter(Mandatory=$false)]
    [int]$ThreadCount = 4,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("WebP", "PNG8", "JPEG", "PNG", "GIF")]
    [string]$PrimaryFormat = "WebP",
    
    [Parameter(Mandatory=$false)]
    [switch]$ConfigureNginx = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$TestPerformance = $false,
    
    [Parameter(Mandatory=$false)]
    [string]$EnvFile = ".env"
)

# Функция для загрузки переменных из .env файла
function Import-DotEnv {
    param(
        [string]$EnvFile = ".env"
    )
    
    if (-not (Test-Path $EnvFile)) {
        Write-Host "Файл $EnvFile не найден." -ForegroundColor Red
        return $false
    }
    
    try {
        # Создаем хэш-таблицу для хранения переменных
        $envVars = @{}
        
        # Читаем файл .env
        $content = Get-Content $EnvFile
        
        foreach ($line in $content) {
            # Пропускаем комментарии и пустые строки
            if ($line.Trim() -eq "" -or $line.Trim().StartsWith("#")) {
                continue
            }
            
            # Парсим переменные в формате KEY=VALUE
            $key, $value = $line.Split('=', 2)
            if ($key -and $value) {
                $key = $key.Trim()
                $value = $value.Trim()
                
                # Удаляем кавычки, если они есть
                if ($value.StartsWith('"') -and $value.EndsWith('"')) {
                    $value = $value.Substring(1, $value.Length - 2)
                }
                elseif ($value.StartsWith("'") -and $value.EndsWith("'")) {
                    $value = $value.Substring(1, $value.Length - 2)
                }
                
                # Добавляем переменную в хэш-таблицу
                $envVars[$key] = $value
            }
        }
        
        return $envVars
    }
    catch {
        Write-Host "Ошибка при чтении файла $EnvFile: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Цвета для вывода сообщений
$Colors = @{
    Success = 'Green'
    Warning = 'Yellow'
    Error = 'Red'
    Info = 'Cyan'
}

# Функция для вывода сообщений
function Write-Message {
    param (
        [string]$Message,
        [string]$Level = 'Info'
    )
    
    $color = $Colors[$Level]
    Write-Host "[$Level] $Message" -ForegroundColor $color
}

# Загружаем переменные окружения из .env файла
$envVariables = Import-DotEnv -EnvFile $EnvFile

if (-not $envVariables) {
    Write-Message "Не удалось загрузить переменные окружения. Используются значения по умолчанию или указанные параметры." -Level 'Warning'
}
else {
    Write-Message "Переменные окружения успешно загружены из файла $EnvFile." -Level 'Success'
    
    # Устанавливаем параметры из переменных окружения, если они не указаны явно
    if (-not $GeoServerUrl -and $envVariables.ContainsKey("GEOSERVER_PROXY_BASE_URL")) {
        $GeoServerUrl = $envVariables["GEOSERVER_PROXY_BASE_URL"] + "/ecw/rest"
        Write-Message "GeoServerUrl установлен из .env: $GeoServerUrl" -Level 'Info'
    }
    
    if (-not $AdminUser -and $envVariables.ContainsKey("GEOSERVER_ADMIN_USER")) {
        $AdminUser = $envVariables["GEOSERVER_ADMIN_USER"]
        Write-Message "AdminUser установлен из .env: $AdminUser" -Level 'Info'
    }
    
    if (-not $AdminPassword -and $envVariables.ContainsKey("GEOSERVER_ADMIN_PASSWORD")) {
        $AdminPassword = $envVariables["GEOSERVER_ADMIN_PASSWORD"]
        Write-Message "AdminPassword установлен из .env" -Level 'Info'
    }
}

# Установка значений по умолчанию, если они не указаны и не найдены в .env
if (-not $GeoServerUrl) {
    $GeoServerUrl = "http://localhost/geoserver/ecw/rest"
    Write-Message "GeoServerUrl не указан и не найден в .env. Используется значение по умолчанию: $GeoServerUrl" -Level 'Warning'
}

if (-not $AdminUser) {
    $AdminUser = "admin"
    Write-Message "AdminUser не указан и не найден в .env. Используется значение по умолчанию: $AdminUser" -Level 'Warning'
}

if (-not $AdminPassword) {
    $AdminPassword = "geoserver"
    Write-Message "AdminPassword не указан и не найден в .env. Используется значение по умолчанию" -Level 'Warning'
}

# Функция для создания заголовков авторизации
function Get-AuthHeader {
    $base64Auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${AdminUser}:${AdminPassword}"))
    return @{
        "Authorization" = "Basic $base64Auth"
    }
}

# Функция для проверки доступности GeoServer
function Test-GeoServerConnection {
    try {
        $headers = Get-AuthHeader
        $response = Invoke-WebRequest -Uri "$GeoServerUrl/about/version" -Method GET -Headers $headers -UseBasicParsing
        
        if ($response.StatusCode -eq 200) {
            $xml = [xml]$response.Content
            $version = $xml.about.resource.Version
            Write-Message "Соединение с GeoServer установлено. Версия: $version" -Level 'Success'
            return $true
        }
        else {
            Write-Message "Ошибка подключения к GeoServer: $($response.StatusCode)" -Level 'Error'
            return $false
        }
    }
    catch {
        Write-Message "Не удалось подключиться к GeoServer: $($_.Exception.Message)" -Level 'Error'
        return $false
    }
}

# Функция для получения списка слоев
function Get-Layers {
    param (
        [string]$WorkspaceName = ""
    )
    
    try {
        $headers = Get-AuthHeader
        $url = if ($WorkspaceName) {
            "$GeoServerUrl/workspaces/$WorkspaceName/layers"
        }
        else {
            "$GeoServerUrl/layers"
        }
        
        $response = Invoke-WebRequest -Uri $url -Method GET -Headers $headers -UseBasicParsing
        
        if ($response.StatusCode -eq 200) {
            $xml = [xml]$response.Content
            return $xml.layers.layer
        }
        else {
            Write-Message "Ошибка получения слоев: $($response.StatusCode)" -Level 'Error'
            return $null
        }
    }
    catch {
        Write-Message "Не удалось получить список слоев: $($_.Exception.Message)" -Level 'Error'
        return $null
    }
}

# Функция для настройки параметров кэширования слоя
function Set-LayerCaching {
    param (
        [string]$WorkspaceName,
        [string]$LayerName,
        [string]$PrimaryFormat = "WebP",
        [string[]]$AdditionalFormats = @("PNG8", "JPEG"),
        [string[]]$GridSets = @("EPSG:3857", "EPSG:4326"),
        [int]$GutterSize = 10,
        [int]$MetaTilingX = 4,
        [int]$MetaTilingY = 4,
        [int]$ExpireDays = 7
    )
    
    try {
        $headers = Get-AuthHeader
        $headers["Content-Type"] = "application/xml"
        
        # Получение текущей конфигурации слоя
        $layerUrl = "$GeoServerUrl/layers/$WorkspaceName`:$LayerName"
        $response = Invoke-WebRequest -Uri $layerUrl -Method GET -Headers $headers -UseBasicParsing
        
        if ($response.StatusCode -ne 200) {
            Write-Message "Слой $WorkspaceName`:$LayerName не найден." -Level 'Error'
            return $false
        }
        
        # Настройка GeoWebCache
        $gwcUrl = "$GeoServerUrl/gwc/rest/layers/$WorkspaceName`:$LayerName.xml"
        
        # Форматирование списков для XML
        $formatsList = "<string>$PrimaryFormat</string>"
        foreach ($format in $AdditionalFormats) {
            $formatsList += "<string>$format</string>"
        }
        
        $gridSetsList = ""
        foreach ($gridSet in $GridSets) {
            $gridSetsList += "<string>$gridSet</string>"
        }
        
        # Создание конфигурации слоя для GeoWebCache
        $gwcConfig = @"
<GeoServerLayer>
  <enabled>true</enabled>
  <name>$WorkspaceName`:$LayerName</name>
  <mimeFormats>
    $formatsList
  </mimeFormats>
  <gridSubsets>
    $gridSetsList
  </gridSubsets>
  <metaWidthHeight>
    <int>$MetaTilingX</int>
    <int>$MetaTilingY</int>
  </metaWidthHeight>
  <gutter>$GutterSize</gutter>
  <expireCache>$($ExpireDays * 86400)</expireCache>
  <expireClients>$($ExpireDays * 86400)</expireClients>
  <parameterFilters>
    <stringParameterFilter>
      <key>STYLES</key>
      <defaultValue></defaultValue>
    </stringParameterFilter>
  </parameterFilters>
</GeoServerLayer>
"@
        
        try {
            # Сначала проверим, существует ли уже конфигурация
            $checkResponse = Invoke-WebRequest -Uri $gwcUrl -Method GET -Headers $headers -UseBasicParsing -ErrorAction SilentlyContinue
            $method = "PUT"
        }
        catch {
            # Если конфигурация не существует, используем POST
            $method = "POST"
            $gwcUrl = "$GeoServerUrl/gwc/rest/layers"
        }
        
        $response = Invoke-WebRequest -Uri $gwcUrl -Method $method -Headers $headers -Body $gwcConfig -UseBasicParsing
        
        if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 300) {
            Write-Message "Настройки кэширования для слоя $WorkspaceName`:$LayerName успешно применены." -Level 'Success'
            return $true
        }
        else {
            Write-Message "Ошибка при настройке кэширования: $($response.StatusCode)" -Level 'Error'
            return $false
        }
    }
    catch {
        Write-Message "Не удалось настроить кэширование: $($_.Exception.Message)" -Level 'Error'
        return $false
    }
}

# Функция для запуска задачи создания тайлов
function Start-TileGeneration {
    param (
        [string]$WorkspaceName,
        [string]$LayerName,
        [string]$GridSet = "EPSG:3857",
        [string]$Format = "image/webp",
        [int]$ZoomStart = 0,
        [int]$ZoomStop = 16,
        [int]$ThreadCount = 4
    )
    
    try {
        $headers = Get-AuthHeader
        $headers["Content-Type"] = "application/xml"
        
        # Формирование запроса на генерацию тайлов
        $seedRequest = @"
<seedRequest>
  <name>$WorkspaceName`:$LayerName</name>
  <gridSetId>$GridSet</gridSetId>
  <zoomStart>$ZoomStart</zoomStart>
  <zoomStop>$ZoomStop</zoomStop>
  <format>$Format</format>
  <type>seed</type>
  <threadCount>$ThreadCount</threadCount>
</seedRequest>
"@
        
        $seedUrl = "$GeoServerUrl/gwc/rest/seed/$WorkspaceName`:$LayerName.xml"
        $response = Invoke-WebRequest -Uri $seedUrl -Method POST -Headers $headers -Body $seedRequest -UseBasicParsing
        
        if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 300) {
            Write-Message "Задача генерации тайлов для слоя $WorkspaceName`:$LayerName успешно запущена." -Level 'Success'
            return $true
        }
        else {
            Write-Message "Ошибка при запуске генерации тайлов: $($response.StatusCode)" -Level 'Error'
            return $false
        }
    }
    catch {
        Write-Message "Не удалось запустить генерацию тайлов: $($_.Exception.Message)" -Level 'Error'
        return $false
    }
}

# Функция для настройки кэширования в NGINX
function Set-NginxCaching {
    param (
        [string]$CachePath = "/var/cache/nginx/tiles",
        [string]$KeysZone = "TILE_CACHE:10m",
        [string]$MaxSize = "10g",
        [string]$InactiveTime = "7d"
    )
    
    try {
        # Путь к конфигурационному файлу NGINX
        $nginxConfigPath = "config/nginx/conf.d/default.conf"
        
        # Проверка существования файла
        if (-not (Test-Path $nginxConfigPath)) {
            Write-Message "Файл конфигурации NGINX не найден: $nginxConfigPath" -Level 'Error'
            return $false
        }
        
        # Чтение текущей конфигурации
        $nginxConfig = Get-Content $nginxConfigPath -Raw
        
        # Проверка, есть ли уже настройки кэширования
        if ($nginxConfig -match "proxy_cache_path\s+$CachePath") {
            Write-Message "Настройки кэширования NGINX уже существуют." -Level 'Info'
            return $true
        }
        
        # Создание настроек кэширования
        $cacheConfig = @"

# Кэширование тайлов GeoServer
proxy_cache_path $CachePath levels=1:2 keys_zone=$KeysZone max_size=$MaxSize inactive=$InactiveTime use_temp_path=off;

# Настройки для GeoServer ECW WMS/WMTS
location ~ ^/geoserver/ecw/(wms|gwc/service/wms|gwc/service/wmts) {
    proxy_pass http://geoserver-ecw;
    proxy_cache TILE_CACHE;
    proxy_cache_valid 200 204 302 $InactiveTime;
    proxy_cache_methods GET HEAD;
    proxy_cache_key "\$request_uri\$arg_bbox\$arg_width\$arg_height\$arg_layers\$arg_styles\$arg_format";
    add_header X-Cache-Status \$upstream_cache_status;
    expires $InactiveTime;
    
    # Включаем gzip для тайлов
    gzip on;
    gzip_types image/jpeg image/png image/webp application/x-protobuf;
    gzip_comp_level 6;
    gzip_min_length 256;
}
"@
        
        # Ищем последнюю закрывающую скобку в server блоке
        $serverBlockEnd = $nginxConfig.LastIndexOf("}")
        
        if ($serverBlockEnd -eq -1) {
            Write-Message "Не удалось найти закрывающую скобку server блока в конфигурации NGINX." -Level 'Error'
            return $false
        }
        
        # Вставляем настройки кэширования перед закрывающей скобкой
        $newConfig = $nginxConfig.Substring(0, $serverBlockEnd) + $cacheConfig + $nginxConfig.Substring($serverBlockEnd)
        
        # Создаем резервную копию
        Copy-Item $nginxConfigPath "$nginxConfigPath.bak"
        
        # Сохраняем новую конфигурацию
        $newConfig | Set-Content $nginxConfigPath
        
        Write-Message "Настройки кэширования NGINX успешно добавлены. Создана резервная копия конфигурации: $nginxConfigPath.bak" -Level 'Success'
        
        # Проверка конфигурации NGINX (нужно запустить внутри контейнера)
        $testResult = docker-compose exec nginx nginx -t
        
        if ($LASTEXITCODE -ne 0) {
            Write-Message "Ошибка в конфигурации NGINX. Восстанавливаем из резервной копии." -Level 'Error'
            Copy-Item "$nginxConfigPath.bak" $nginxConfigPath
            return $false
        }
        
        # Перезапуск NGINX
        docker-compose restart nginx
        
        if ($LASTEXITCODE -ne 0) {
            Write-Message "Ошибка при перезапуске NGINX. Проверьте логи контейнера." -Level 'Error'
            return $false
        }
        
        Write-Message "NGINX успешно перезапущен с новыми настройками кэширования." -Level 'Success'
        return $true
    }
    catch {
        Write-Message "Не удалось настроить кэширование NGINX: $($_.Exception.Message)" -Level 'Error'
        return $false
    }
}

# Функция для создания скрипта проверки производительности
function New-PerformanceTestScript {
    $scriptPath = "scripts/check-tile-performance.ps1"
    
    $scriptContent = @'
param (
    [string]$LayerName = "TEST:2020-2021",
    [int]$NumRequests = 10,
    [string]$EnvFile = ".env"
)

# Функция для загрузки переменных из .env файла
function Import-DotEnv {
    param(
        [string]$EnvFile = ".env"
    )
    
    if (-not (Test-Path $EnvFile)) {
        Write-Host "Файл $EnvFile не найден." -ForegroundColor Red
        return $false
    }
    
    try {
        # Создаем хэш-таблицу для хранения переменных
        $envVars = @{}
        
        # Читаем файл .env
        $content = Get-Content $EnvFile
        
        foreach ($line in $content) {
            # Пропускаем комментарии и пустые строки
            if ($line.Trim() -eq "" -or $line.Trim().StartsWith("#")) {
                continue
            }
            
            # Парсим переменные в формате KEY=VALUE
            $key, $value = $line.Split('=', 2)
            if ($key -and $value) {
                $key = $key.Trim()
                $value = $value.Trim()
                
                # Удаляем кавычки, если они есть
                if ($value.StartsWith('"') -and $value.EndsWith('"')) {
                    $value = $value.Substring(1, $value.Length - 2)
                }
                elseif ($value.StartsWith("'") -and $value.EndsWith("'")) {
                    $value = $value.Substring(1, $value.Length - 2)
                }
                
                # Добавляем переменную в хэш-таблицу
                $envVars[$key] = $value
            }
        }
        
        return $envVars
    }
    catch {
        Write-Host "Ошибка при чтении файла $EnvFile: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Загружаем переменные окружения
$env = Import-DotEnv -EnvFile $EnvFile
$baseUrl = if ($env -and $env.ContainsKey("GEOSERVER_PROXY_BASE_URL")) {
    $env["GEOSERVER_PROXY_BASE_URL"].TrimEnd('/') + "/ecw"
} else {
    "http://localhost/geoserver/ecw"
}

$startTime = Get-Date
$successCount = 0
$totalTime = 0

Write-Host "Testing tile load performance for layer: $LayerName"
Write-Host "Base URL: $baseUrl"
Write-Host "Making $NumRequests requests..."

for ($i = 0; $i -lt $NumRequests; $i++) {
    $zoom = Get-Random -Minimum 10 -Maximum 16
    $x = Get-Random -Minimum 0 -Maximum ([Math]::Pow(2, $zoom) - 1)
    $y = Get-Random -Minimum 0 -Maximum ([Math]::Pow(2, $zoom) - 1)
    
    $url = "$baseUrl/gwc/service/wmts?layer=$LayerName&style=&tilematrixset=EPSG:3857&Service=WMTS&Request=GetTile&Version=1.0.0&Format=image/webp&TileMatrix=EPSG:3857:$zoom&TileCol=$x&TileRow=$y"
    
    $requestStart = Get-Date
    try {
        $response = Invoke-WebRequest -Uri $url -Method GET -UseBasicParsing
        $requestEnd = Get-Date
        $requestTime = ($requestEnd - $requestStart).TotalMilliseconds
        $totalTime += $requestTime
        $successCount++
        
        $cacheStatus = if ($response.Headers.ContainsKey("X-Cache-Status")) { 
            $response.Headers["X-Cache-Status"] 
        } else { 
            "Unknown" 
        }
        
        Write-Host "Request $($i+1): $requestTime ms ($cacheStatus)"
    }
    catch {
        Write-Host "Request $($i+1): Failed - $($_.Exception.Message)" -ForegroundColor Red
    }
}

$endTime = Get-Date
$totalExecutionTime = ($endTime - $startTime).TotalSeconds
$avgResponseTime = if ($successCount -gt 0) { $totalTime / $successCount } else { 0 }

Write-Host "`nResults:"
Write-Host "- Total execution time: $totalExecutionTime seconds"
Write-Host "- Successful requests: $successCount / $NumRequests"
Write-Host "- Average response time: $avgResponseTime ms"
'@
    
    $scriptContent | Out-File -FilePath $scriptPath -Encoding utf8
    
    if (Test-Path $scriptPath) {
        Write-Message "Скрипт проверки производительности создан: $scriptPath" -Level 'Success'
        return $true
    }
    else {
        Write-Message "Не удалось создать скрипт проверки производительности" -Level 'Error'
        return $false
    }
}

# Главная функция
function Main {
    Write-Message "=== Оптимизация кэширования растровых слоев в GeoServer ===" -Level 'Info'
    Write-Message "Параметры:"
    Write-Message "- GeoServer URL: $GeoServerUrl"
    Write-Message "- Пользователь: $AdminUser"
    Write-Message "- Рабочее пространство: $WorkspaceName"
    Write-Message "- Слой: $(if ($LayerName) { $LayerName } else { '<все слои>' })"
    Write-Message "- Генерация тайлов: $GenerateTiles"
    Write-Message "- Диапазон масштабов: $ZoomStart-$ZoomStop"
    Write-Message "- Основной формат: $PrimaryFormat"
    Write-Message "- Настроить NGINX: $ConfigureNginx"
    Write-Message "- Тестирование производительности: $TestPerformance"
    Write-Message "- Файл переменных окружения: $EnvFile"
    
    # Проверка соединения с GeoServer
    if (-not (Test-GeoServerConnection)) {
        Write-Message "Невозможно продолжить без подключения к GeoServer" -Level 'Error'
        return
    }
    
    # Получение списка слоев для оптимизации
    $layers = @()
    
    if ($LayerName) {
        $layers += @{
            "name" = $LayerName
            "workspace" = $WorkspaceName
        }
    }
    else {
        $layerList = Get-Layers -WorkspaceName $WorkspaceName
        
        if (-not $layerList) {
            Write-Message "Не удалось получить список слоев для рабочего пространства $WorkspaceName" -Level 'Error'
            return
        }
        
        foreach ($layer in $layerList) {
            $layerName = $layer.name
            
            # Извлекаем имя без префикса рабочего пространства
            if ($layerName.Contains(':')) {
                $parts = $layerName.Split(':')
                $workspace = $parts[0]
                $simpleName = $parts[1]
            }
            else {
                $workspace = $WorkspaceName
                $simpleName = $layerName
            }
            
            $layers += @{
                "name" = $simpleName
                "workspace" = $workspace
            }
        }
    }
    
    Write-Message "Найдено слоев для оптимизации: $($layers.Count)" -Level 'Info'
    
    # Настройка кэширования для каждого слоя
    foreach ($layer in $layers) {
        $layerName = $layer.name
        $workspace = $layer.workspace
        
        Write-Message "Оптимизация слоя $workspace`:$layerName..." -Level 'Info'
        
        # Настройка кэширования
        $result = Set-LayerCaching -WorkspaceName $workspace -LayerName $layerName -PrimaryFormat $PrimaryFormat
        
        if ($result -and $GenerateTiles) {
            # Запуск генерации тайлов в соответствии с форматом
            $formatMap = @{
                "WebP" = "image/webp"
                "PNG8" = "image/png8"
                "JPEG" = "image/jpeg"
                "PNG" = "image/png"
                "GIF" = "image/gif"
            }
            
            $formatMime = $formatMap[$PrimaryFormat]
            
            Start-TileGeneration -WorkspaceName $workspace -LayerName $layerName -Format $formatMime -ZoomStart $ZoomStart -ZoomStop $ZoomStop -ThreadCount $ThreadCount
        }
    }
    
    # Настройка кэширования в NGINX
    if ($ConfigureNginx) {
        Write-Message "Настройка кэширования в NGINX..." -Level 'Info'
        Set-NginxCaching
    }
    
    # Создание скрипта тестирования производительности
    if ($TestPerformance) {
        Write-Message "Создание скрипта тестирования производительности..." -Level 'Info'
        New-PerformanceTestScript
        
        # Рекомендации по тестированию
        Write-Message "Скрипт тестирования производительности создан. Для запуска выполните:" -Level 'Info'
        Write-Message ".\scripts\check-tile-performance.ps1 -LayerName `"$WorkspaceName`:$LayerName`" -NumRequests 20 -EnvFile $EnvFile" -Level 'Info'
    }
    
    Write-Message "=== Оптимизация кэширования завершена ===" -Level 'Success'
}

# Запуск главной функции
Main
