# Скрипт для проверки работоспособности среды после запуска
param(
    [switch]$Verbose
)

Write-Host "Проверка работоспособности GIS-окружения..." -ForegroundColor Cyan

# Функция для проверки доступности URL
function Test-Url {
    param(
        [string]$Url,
        [string]$Description
    )
    
    Write-Host "Проверка $Description... " -NoNewline
    
    try {
        $response = Invoke-WebRequest -Uri $Url -Method Head -UseBasicParsing -TimeoutSec 5 -ErrorAction SilentlyContinue
        
        if ($response.StatusCode -eq 200) {
            Write-Host "OK" -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "Ошибка (Код $($response.StatusCode))" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "Не доступен" -ForegroundColor Red
        if ($Verbose) {
            Write-Host "  Ошибка: $($_.Exception.Message)" -ForegroundColor Red
        }
        return $false
    }
}

# Функция для тестирования доступности контейнера
function Test-Container {
    param(
        [string]$ContainerName,
        [string]$Description
    )
    
    Write-Host "Проверка контейнера $Description... " -NoNewline
    
    try {
        $status = docker inspect --format='{{.State.Status}}' $ContainerName 2>$null
        
        if ($status -eq "running") {
            $health = docker inspect --format='{{.State.Health.Status}}' $ContainerName 2>$null
            
            if ($health -eq "healthy" -or $health -eq $null) {
                Write-Host "Работает" -ForegroundColor Green
                return $true
            }
            else {
                Write-Host "Запущен, но не здоров ($health)" -ForegroundColor Yellow
                return $false
            }
        }
        else {
            Write-Host "Не запущен ($status)" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "Не существует" -ForegroundColor Red
        if ($Verbose) {
            Write-Host "  Ошибка: $($_.Exception.Message)" -ForegroundColor Red
        }
        return $false
    }
}

# Проверка статуса контейнеров
Write-Host "Проверка статуса контейнеров:" -ForegroundColor Cyan
$postgisOk = Test-Container -ContainerName "corporate-gis-postgis" -Description "PostGIS"
$geoserverVectorOk = Test-Container -ContainerName "corporate-gis-geoserver-vector" -Description "GeoServer (векторный)"
$geoserverEcwOk = Test-Container -ContainerName "corporate-gis-geoserver-ecw" -Description "GeoServer (ECW)"
$nginxOk = Test-Container -ContainerName "corporate-gis-nginx" -Description "NGINX"

# Проверка доступности веб-сервисов
Write-Host "`nПроверка доступности веб-сервисов:" -ForegroundColor Cyan
$webInterfaceOk = Test-Url -Url "http://localhost/" -Description "Веб-интерфейс"
$geoserverVectorWebOk = Test-Url -Url "http://localhost/geoserver/vector/" -Description "GeoServer Vector Web UI"
$geoserverEcwWebOk = Test-Url -Url "http://localhost/geoserver/ecw/" -Description "GeoServer ECW Web UI"
$healthOk = Test-Url -Url "http://localhost/health" -Description "Health Check"

# Проверка наличия директории пользовательских проекций
Write-Host "`nПроверка пользовательских проекций:" -ForegroundColor Cyan
$projDir = "data/user-projections"
$epsgFile = "$projDir/epsg.properties"

if (Test-Path $projDir) {
    Write-Host "Директория пользовательских проекций: " -NoNewline
    Write-Host "Существует" -ForegroundColor Green
    
    $projFiles = Get-ChildItem -Path $projDir -File
    Write-Host "Найдено файлов: $($projFiles.Count)" -ForegroundColor White
    
    if (Test-Path $epsgFile) {
        Write-Host "Файл epsg.properties: " -NoNewline
        Write-Host "Существует" -ForegroundColor Green
        
        $epsgSize = (Get-Item $epsgFile).Length
        $epsgLines = (Get-Content $epsgFile | Measure-Object -Line).Lines
        Write-Host "  Размер: $epsgSize байт, $epsgLines строк" -ForegroundColor White
        
        # Проверка наличия пользовательских определений проекций
        $definedProjections = (Get-Content $epsgFile | Where-Object { $_ -match "^\d+" }).Count
        if ($definedProjections -gt 0) {
            Write-Host "  Определено пользовательских проекций: $definedProjections" -ForegroundColor Green
        }
        else {
            Write-Host "  Пользовательские проекции не определены в epsg.properties" -ForegroundColor Yellow
            Write-Host "  Для добавления проекций используйте команду:" -ForegroundColor White
            Write-Host "  ./manage-gis.ps1 setup-projections" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "Файл epsg.properties: " -NoNewline
        Write-Host "Отсутствует" -ForegroundColor Red
        Write-Host "Для создания файла выполните команду:" -ForegroundColor White
        Write-Host "  ./manage-gis.ps1 setup-projections" -ForegroundColor Yellow
    }
}
else {
    Write-Host "Директория пользовательских проекций: " -NoNewline
    Write-Host "Отсутствует" -ForegroundColor Red
    Write-Host "Для создания директории выполните команду:" -ForegroundColor White
    Write-Host "  ./manage-gis.ps1 setup-projections" -ForegroundColor Yellow
}

# Суммарный отчет
Write-Host "`nСуммарный отчет:" -ForegroundColor Cyan
$allChecks = @(
    $postgisOk, $geoserverVectorOk, $geoserverEcwOk, $nginxOk,
    $webInterfaceOk, $geoserverVectorWebOk, $geoserverEcwWebOk, $healthOk
)

$passedCount = ($allChecks | Where-Object { $_ -eq $true }).Count
$totalCount = $allChecks.Count
$successRate = [math]::Round(($passedCount / $totalCount) * 100)

Write-Host "Пройдено проверок: $passedCount из $totalCount ($successRate%)" -ForegroundColor $(if ($successRate -eq 100) { "Green" } elseif ($successRate -ge 75) { "Yellow" } else { "Red" })

# Рекомендации при проблемах
if ($successRate -lt 100) {
    Write-Host "`nРекомендации:" -ForegroundColor Yellow
    
    if (-not $postgisOk) {
        Write-Host "- Проверьте логи PostGIS: docker logs corporate-gis-postgis" -ForegroundColor White
    }
    
    if (-not $geoserverVectorOk -or -not $geoserverVectorWebOk) {
        Write-Host "- Проверьте логи GeoServer Vector: docker logs corporate-gis-geoserver-vector" -ForegroundColor White
    }
    
    if (-not $geoserverEcwOk -or -not $geoserverEcwWebOk) {
        Write-Host "- Проверьте логи GeoServer ECW: docker logs corporate-gis-geoserver-ecw" -ForegroundColor White
        Write-Host "- Убедитесь, что образ urbanits/geoserver доступен и содержит поддержку ECW" -ForegroundColor White
    }
    
    if (-not $nginxOk -or -not $webInterfaceOk -or -not $healthOk) {
        Write-Host "- Проверьте логи NGINX: docker logs corporate-gis-nginx" -ForegroundColor White
        Write-Host "- Проверьте конфигурацию NGINX в config/nginx/conf.d/default.conf" -ForegroundColor White
    }
}

# Полезные команды
Write-Host "`nПолезные команды:" -ForegroundColor Cyan
Write-Host "- Запустить все сервисы: ./manage-gis.ps1 start" -ForegroundColor White
Write-Host "- Остановить все сервисы: ./manage-gis.ps1 stop" -ForegroundColor White
Write-Host "- Перезапустить конкретный сервис: docker-compose restart [имя_сервиса]" -ForegroundColor White
Write-Host "- Просмотр логов: ./manage-gis.ps1 logs [имя_сервиса]" -ForegroundColor White
Write-Host "- Настройка проекций: ./manage-gis.ps1 setup-projections" -ForegroundColor White 