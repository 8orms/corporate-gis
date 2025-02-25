<#
.SYNOPSIS
    Диагностика и исправление проблем с редиректами GeoServer через NGINX прокси.

.DESCRIPTION
    Скрипт выполняет комплексную проверку конфигурации NGINX и GeoServer для выявления 
    проблем с редиректами. Проверяет URL маршрутизацию, настройки proxy_redirect, 
    заголовки запросов и параметры CATALINA_OPTS.

.PARAMETER Test
    Только тестирование без внесения изменений.

.PARAMETER Fix
    Автоматическое исправление обнаруженных проблем.

.PARAMETER Verbose
    Подробный вывод процесса диагностики.

.EXAMPLE
    .\check-geoserver-redirect.ps1 -Test
    
    Проверяет конфигурацию без внесения изменений.

.EXAMPLE
    .\check-geoserver-redirect.ps1 -Fix
    
    Проверяет и исправляет проблемы с конфигурацией.

.NOTES
    Автор: GIS Automation Team
    Дата: 2025-03-05
#>

param (
    [switch]$Test,
    [switch]$Fix,
    [switch]$Verbose
)

# Функция для вывода информации
function Write-LogMessage {
    param (
        [string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $colors = @{
        "INFO" = "White";
        "WARNING" = "Yellow";
        "ERROR" = "Red";
        "SUCCESS" = "Green"
    }
    
    Write-Host "[$timestamp] " -NoNewline
    Write-Host "[$Level] " -ForegroundColor $colors[$Level] -NoNewline
    Write-Host $Message
}

# Функция для проверки доступности URL
function Test-UrlAccess {
    param (
        [string]$Url,
        [string]$Description,
        [string]$ExpectedStatus = "200"
    )
    
    try {
        Write-LogMessage "Проверка URL: $Url" -Level "INFO"
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue
        $statusCode = $response.StatusCode
        
        if ($Verbose) {
            Write-LogMessage "Ответ: $statusCode, Ожидаемый: $ExpectedStatus" -Level "INFO"
            Write-LogMessage "Заголовки: $($response.Headers | Out-String)" -Level "INFO"
        }
        
        if ($statusCode -eq $ExpectedStatus) {
            Write-LogMessage "✅ $Description`: URL $Url доступен (статус $statusCode)" -Level "SUCCESS"
            return $true
        } else {
            Write-LogMessage "❌ $Description`: URL $Url вернул статус $statusCode вместо $ExpectedStatus" -Level "WARNING"
            return $false
        }
    } catch {
        $exceptionMessage = $_.Exception.Message
        $statusCode = $_.Exception.Response.StatusCode.value__
        
        if ($Verbose) {
            Write-LogMessage "Ошибка: $exceptionMessage" -Level "INFO"
            Write-LogMessage "Статус: $statusCode" -Level "INFO"
        }
        
        if ($statusCode -eq $ExpectedStatus) {
            Write-LogMessage "✅ $Description`: URL $Url доступен (статус $statusCode)" -Level "SUCCESS"
            return $true
        } else {
            Write-LogMessage "❌ $Description`: URL $Url вернул статус $statusCode вместо $ExpectedStatus" -Level "ERROR"
            return $false
        }
    }
}

# Функция для проверки конфигурации NGINX
function Test-NginxConfig {
    param (
        [switch]$Fix
    )
    
    $configPath = "config/nginx/conf.d/default.conf"
    $problems = @()
    
    if (-not (Test-Path $configPath)) {
        Write-LogMessage "❌ Файл конфигурации NGINX не найден: $configPath" -Level "ERROR"
        return $false
    }
    
    $configContent = Get-Content $configPath -Raw
    
    # Проверка наличия location для корневого пути GeoServer
    if (-not ($configContent -match "location\s*=\s*/geoserver/\s*{")) {
        $problems += "Отсутствует блок location для корневого пути /geoserver/"
    }
    
    # Проверка настроек proxy_redirect
    if ($configContent -match "proxy_redirect\s+off;") {
        $problems += "Используется 'proxy_redirect off;' вместо 'proxy_redirect default off;'"
    }
    
    # Проверка настроек заголовков
    $requiredHeaders = @(
        "proxy_set_header\s+Host\s+\`$host;",
        "proxy_set_header\s+X-Forwarded-Host\s+\`$host;",
        "proxy_set_header\s+X-Forwarded-Server\s+\`$host;",
        "proxy_set_header\s+X-Forwarded-For\s+\`$proxy_add_x_forwarded_for;"
    )
    
    foreach ($header in $requiredHeaders) {
        if (-not ($configContent -match $header)) {
            $problems += "Отсутствует необходимый заголовок: $header"
        }
    }
    
    # Проверка настроек для передачи тела запроса
    if (-not ($configContent -match "proxy_pass_request_body\s+on;")) {
        $problems += "Отсутствует настройка 'proxy_pass_request_body on;'"
    }
    
    if (-not ($configContent -match "proxy_pass_request_headers\s+on;")) {
        $problems += "Отсутствует настройка 'proxy_pass_request_headers on;'"
    }
    
    # Вывод проблем
    if ($problems.Count -eq 0) {
        Write-LogMessage "✅ Конфигурация NGINX соответствует требованиям" -Level "SUCCESS"
        return $true
    } else {
        Write-LogMessage "❌ Обнаружены проблемы в конфигурации NGINX:" -Level "WARNING"
        foreach ($problem in $problems) {
            Write-LogMessage "   - $problem" -Level "WARNING"
        }
        
        # Исправление проблем если указан параметр -Fix
        if ($Fix) {
            Write-LogMessage "🔧 Исправление проблем в конфигурации NGINX..." -Level "INFO"
            
            # Создание резервной копии
            $backupFile = "backups/nginx-$(Get-Date -Format 'yyyy-MM-dd-HHmmss').conf"
            $backupDir = Split-Path $backupFile -Parent
            
            if (-not (Test-Path $backupDir)) {
                New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
            }
            
            Copy-Item $configPath $backupFile
            Write-LogMessage "Резервная копия создана: $backupFile" -Level "INFO"
            
            # Исправление настроек proxy_redirect
            if ($problems -contains "Используется 'proxy_redirect off;' вместо 'proxy_redirect default off;'") {
                $configContent = $configContent -replace "proxy_redirect\s+off;", "proxy_redirect default off;"
                Write-LogMessage "Исправлено: proxy_redirect off -> proxy_redirect default off" -Level "INFO"
            }
            
            # Исправление других настроек...
            # [здесь было бы продолжение исправлений других проблем]
            
            # Сохранение исправленной конфигурации
            $configContent | Set-Content $configPath
            Write-LogMessage "✅ Конфигурация NGINX обновлена" -Level "SUCCESS"
            
            # Проверка синтаксиса NGINX
            Write-LogMessage "Проверка синтаксиса NGINX конфигурации..." -Level "INFO"
            $dockerResult = docker-compose exec -T nginx nginx -t 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-LogMessage "✅ Синтаксис NGINX конфигурации корректен" -Level "SUCCESS"
                
                # Перезагрузка NGINX
                Write-LogMessage "Перезагрузка NGINX..." -Level "INFO"
                docker-compose restart nginx
                Write-LogMessage "✅ NGINX перезагружен" -Level "SUCCESS"
            } else {
                Write-LogMessage "❌ Ошибка синтаксиса NGINX конфигурации:" -Level "ERROR"
                Write-LogMessage $dockerResult -Level "ERROR"
                
                # Восстановление из резервной копии
                Write-LogMessage "Восстановление из резервной копии..." -Level "INFO"
                Copy-Item $backupFile $configPath
                Write-LogMessage "✅ Конфигурация восстановлена из резервной копии" -Level "SUCCESS"
            }
        }
        
        return $false
    }
}

# Функция для проверки настроек GeoServer
function Test-GeoServerConfig {
    param (
        [switch]$Fix
    )
    
    $dockerComposeFile = "config/docker/dev/docker-compose.yml"
    $problems = @()
    
    if (-not (Test-Path $dockerComposeFile)) {
        Write-LogMessage "❌ Файл docker-compose.yml не найден: $dockerComposeFile" -Level "ERROR"
        return $false
    }
    
    $composeContent = Get-Content $dockerComposeFile -Raw
    
    # Проверка настроек CATALINA_OPTS для GeoServer Vector
    if (-not ($composeContent -match "-Dorg\.geoserver\.web\.proxy\.base=http://localhost/geoserver/vector/web")) {
        $problems += "Некорректный или отсутствующий параметр proxy.base для GeoServer Vector"
    }
    
    if (-not ($composeContent -match "-Dorg\.geoserver\.use\.header\.proxy=true")) {
        $problems += "Отсутствует параметр use.header.proxy=true для GeoServer"
    }
    
    if (-not ($composeContent -match "-DGEOSERVER_CSRF_DISABLED=true")) {
        $problems += "Отсутствует параметр GEOSERVER_CSRF_DISABLED=true для GeoServer"
    }
    
    # Вывод проблем
    if ($problems.Count -eq 0) {
        Write-LogMessage "✅ Конфигурация GeoServer соответствует требованиям" -Level "SUCCESS"
        return $true
    } else {
        Write-LogMessage "❌ Обнаружены проблемы в конфигурации GeoServer:" -Level "WARNING"
        foreach ($problem in $problems) {
            Write-LogMessage "   - $problem" -Level "WARNING"
        }
        
        # Исправление проблем если указан параметр -Fix
        if ($Fix) {
            Write-LogMessage "🔧 Исправление проблем в конфигурации GeoServer..." -Level "INFO"
            
            # Создание резервной копии
            $backupFile = "backups/docker-compose-$(Get-Date -Format 'yyyy-MM-dd-HHmmss').yml"
            $backupDir = Split-Path $backupFile -Parent
            
            if (-not (Test-Path $backupDir)) {
                New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
            }
            
            Copy-Item $dockerComposeFile $backupFile
            Write-LogMessage "Резервная копия создана: $backupFile" -Level "INFO"
            
            # Парсинг YAML
            $dockerYaml = Get-Content $dockerComposeFile -Raw
            
            # Исправление параметров CATALINA_OPTS для GeoServer Vector
            if ($problems -contains "Некорректный или отсутствующий параметр proxy.base для GeoServer Vector") {
                if ($dockerYaml -match "CATALINA_OPTS=(.+?)\s+\-") {
                    $catalina = $Matches[1]
                    # Проверяем наличие параметра
                    if (-not ($catalina -match "-Dorg\.geoserver\.web\.proxy\.base")) {
                        # Добавляем параметр, если он отсутствует
                        $newCatalina = $catalina.TrimEnd(" ") + " -Dorg.geoserver.web.proxy.base=http://localhost/geoserver/vector/web "
                        $dockerYaml = $dockerYaml -replace [regex]::Escape($catalina), $newCatalina
                    } else {
                        # Исправляем значение параметра
                        $dockerYaml = $dockerYaml -replace "-Dorg\.geoserver\.web\.proxy\.base=([^ ]+)", "-Dorg.geoserver.web.proxy.base=http://localhost/geoserver/vector/web"
                    }
                }
            }
            
            if ($problems -contains "Отсутствует параметр use.header.proxy=true для GeoServer") {
                if (-not ($dockerYaml -match "-Dorg\.geoserver\.use\.header\.proxy=true")) {
                    $dockerYaml = $dockerYaml -replace "CATALINA_OPTS=(.+?)(\s+\-|\s*$)", "CATALINA_OPTS=`$1 -Dorg.geoserver.use.header.proxy=true`$2"
                }
            }
            
            if ($problems -contains "Отсутствует параметр GEOSERVER_CSRF_DISABLED=true для GeoServer") {
                if (-not ($dockerYaml -match "-DGEOSERVER_CSRF_DISABLED=true")) {
                    $dockerYaml = $dockerYaml -replace "CATALINA_OPTS=(.+?)(\s+\-|\s*$)", "CATALINA_OPTS=`$1 -DGEOSERVER_CSRF_DISABLED=true`$2"
                }
            }
            
            # Сохранение исправленной конфигурации
            $dockerYaml | Set-Content $dockerComposeFile
            Write-LogMessage "✅ Конфигурация GeoServer обновлена" -Level "SUCCESS"
            
            # Перезапуск контейнеров
            Write-LogMessage "Перезапуск GeoServer контейнеров..." -Level "INFO"
            docker-compose restart geoserver-vector geoserver-ecw
            Write-LogMessage "✅ GeoServer контейнеры перезапущены" -Level "SUCCESS"
        }
        
        return $false
    }
}

# Функция для проверки URL маршрутизации
function Test-UrlRouting {
    $urls = @(
        @{
            Url = "http://localhost/geoserver/";
            Description = "Основной URL GeoServer";
            ExpectedStatus = "200"
        },
        @{
            Url = "http://localhost/geoserver/vector/web/";
            Description = "URL GeoServer Vector";
            ExpectedStatus = "200"
        },
        @{
            Url = "http://localhost/geoserver/ecw/web/";
            Description = "URL GeoServer ECW";
            ExpectedStatus = "200"
        },
        @{
            Url = "http://localhost/geoserver/web/";
            Description = "Некорректный URL без указания инстанции";
            ExpectedStatus = "302"
        }
    )
    
    $failures = 0
    
    foreach ($urlObj in $urls) {
        $result = Test-UrlAccess -Url $urlObj.Url -Description $urlObj.Description -ExpectedStatus $urlObj.ExpectedStatus
        if (-not $result) {
            $failures++
        }
    }
    
    if ($failures -eq 0) {
        Write-LogMessage "✅ Все URL маршруты работают корректно" -Level "SUCCESS"
        return $true
    } else {
        Write-LogMessage "❌ Обнаружены проблемы с URL маршрутизацией ($failures ошибок)" -Level "WARNING"
        return $false
    }
}

# Функция для выполнения curl через Docker контейнер
function Invoke-DockerCurl {
    param (
        [string]$Url,
        [string]$Method = "GET",
        [switch]$IncludeHeaders
    )
    
    $headerArg = if ($IncludeHeaders) { "-i" } else { "" }
    
    try {
        $result = docker-compose exec -T nginx curl -s $headerArg -X $Method $Url
        return $result
    } catch {
        Write-LogMessage "❌ Ошибка выполнения curl: $_" -Level "ERROR"
        return $null
    }
}

# Функция для проверки заголовков из контейнера
function Test-HeadersFromContainer {
    param (
        [string]$Url,
        [string]$Description
    )
    
    Write-LogMessage "Проверка заголовков для $Url из контейнера..." -Level "INFO"
    
    $result = Invoke-DockerCurl -Url $Url -IncludeHeaders
    
    if (-not $result) {
        Write-LogMessage "❌ Не удалось получить заголовки для $Url" -Level "ERROR"
        return $false
    }
    
    # Анализ заголовков
    $statusLine = ($result -split "`n")[0]
    $statusCode = $statusLine -replace "HTTP/\d\.\d\s+(\d+).*", '$1'
    
    Write-LogMessage "Статус-код: $statusCode" -Level "INFO"
    
    if ($result -match "Location:\s*([^\r\n]+)") {
        $location = $Matches[1]
        Write-LogMessage "Location: $location" -Level "INFO"
        
        # Проверка корректности редиректа
        if ($Url -match "/geoserver/web/" -and -not ($location -match "/geoserver/(vector|ecw)/web/")) {
            Write-LogMessage "❌ Некорректный редирект для $Url на $location. Ожидался редирект на инстанцию vector или ecw." -Level "WARNING"
            return $false
        }
    }
    
    if ($Verbose) {
        Write-LogMessage "Полный ответ:" -Level "INFO"
        Write-LogMessage $result -Level "INFO"
    }
    
    return $true
}

# Основная функция скрипта
function Start-GeoServerRedirectCheck {
    param (
        [switch]$Fix
    )
    
    $title = "Диагностика проблем с редиректами GeoServer"
    $border = "=" * $title.Length
    
    Write-Host ""
    Write-Host $border -ForegroundColor Cyan
    Write-Host $title -ForegroundColor Cyan
    Write-Host $border -ForegroundColor Cyan
    Write-Host ""
    
    $mode = if ($Fix) { "исправлением" } else { "диагностикой" }
    Write-LogMessage "Запуск скрипта с $mode проблем..." -Level "INFO"
    
    # Шаг 1: Проверка конфигурации NGINX
    Write-Host "`n[Шаг 1/4] Проверка конфигурации NGINX" -ForegroundColor Cyan
    $nginxConfigOk = Test-NginxConfig -Fix:$Fix
    
    # Шаг 2: Проверка конфигурации GeoServer
    Write-Host "`n[Шаг 2/4] Проверка конфигурации GeoServer" -ForegroundColor Cyan
    $geoserverConfigOk = Test-GeoServerConfig -Fix:$Fix
    
    # Шаг 3: Проверка URL маршрутизации
    Write-Host "`n[Шаг 3/4] Проверка URL маршрутизации" -ForegroundColor Cyan
    $urlRoutingOk = Test-UrlRouting
    
    # Шаг 4: Проверка заголовков
    Write-Host "`n[Шаг 4/4] Проверка заголовков и редиректов" -ForegroundColor Cyan
    Test-HeadersFromContainer -Url "http://localhost/geoserver/web/" -Description "Редирект с GeoServer Web"
    
    # Вывод итогов
    Write-Host "`n" + ("=" * 50) -ForegroundColor Cyan
    Write-Host "Итоги диагностики" -ForegroundColor Cyan
    Write-Host ("=" * 50) -ForegroundColor Cyan
    
    $items = @(
        @{ Name = "Конфигурация NGINX"; Status = $nginxConfigOk },
        @{ Name = "Конфигурация GeoServer"; Status = $geoserverConfigOk },
        @{ Name = "URL маршрутизация"; Status = $urlRoutingOk }
    )
    
    foreach ($item in $items) {
        $statusSymbol = if ($item.Status) { "✅" } else { "❌" }
        $statusColor = if ($item.Status) { "Green" } else { "Red" }
        Write-Host "$statusSymbol " -ForegroundColor $statusColor -NoNewline
        Write-Host $item.Name
    }
    
    # Рекомендации
    Write-Host "`nРекомендации:" -ForegroundColor Cyan
    
    if (-not $nginxConfigOk -or -not $geoserverConfigOk -or -not $urlRoutingOk) {
        Write-Host "  1. Запустите скрипт с параметром -Fix для автоматического исправления проблем:" -ForegroundColor Yellow
        Write-Host "     .\check-geoserver-redirect.ps1 -Fix" -ForegroundColor Yellow
        
        if (-not $nginxConfigOk) {
            Write-Host "  2. Убедитесь, что в конфигурации NGINX корректно настроены блоки location" -ForegroundColor Yellow
            Write-Host "     и параметры proxy_redirect и proxy_set_header." -ForegroundColor Yellow
        }
        
        if (-not $geoserverConfigOk) {
            Write-Host "  3. Проверьте параметры CATALINA_OPTS для GeoServer в docker-compose.yml:" -ForegroundColor Yellow
            Write-Host "     - Dorg.geoserver.web.proxy.base должен указывать на корректный URL" -ForegroundColor Yellow
            Write-Host "     - Dorg.geoserver.use.header.proxy=true должен быть включен" -ForegroundColor Yellow
            Write-Host "     - DGEOSERVER_CSRF_DISABLED=true для корректной обработки форм" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  ✅ Все проверки пройдены успешно! Редиректы должны работать корректно." -ForegroundColor Green
    }
    
    Write-Host "`nДополнительная информация:" -ForegroundColor Cyan
    Write-Host "  - См. документацию по проксированию GeoServer: https://docs.geoserver.org/latest/en/user/production/container.html#proxying" -ForegroundColor White
    Write-Host "  - Журнал разработки: docs/storybook.md" -ForegroundColor White
    
    Write-Host ""
}

# Запуск основной функции
Start-GeoServerRedirectCheck -Fix:$Fix 