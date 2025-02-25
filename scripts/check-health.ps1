# Скрипт для проверки состояния сервисов
param(
    [switch]$Verbose,
    [switch]$FixProblems
)

Write-Host "Проверка состояния сервисов ГИС-платформы..." -ForegroundColor Cyan

$services = @("postgis", "geoserver-vector", "geoserver-ecw", "nginx")
$prefix = ""
$suffix = ""
$healthy = $true
$needsAttention = @()

# Проверка запущены ли контейнеры
Write-Host "`nПроверка контейнеров Docker..." -ForegroundColor Cyan
foreach ($service in $services) {
    try {
        $containerName = "$prefix$service$suffix"
        $container = docker ps -a --filter "name=$containerName" --format "{{.Names}} | {{.Status}}" 2>$null
        
        if ([string]::IsNullOrEmpty($container)) {
            Write-Host "❌ ${service}: контейнер не найден" -ForegroundColor Red
            $healthy = $false
            $needsAttention += $service
            continue
        }

        $containerParts = $container -split ' \| '
        $containerStatus = $containerParts[1]
        
        if ($containerStatus -match "^Up ") {
            $status = docker inspect --format='{{.State.Health.Status}}' $containerName 2>$null
            
            if ($status -eq "healthy") {
                Write-Host "✓ ${service}: работает нормально" -ForegroundColor Green
            } 
            elseif ($status -eq "starting") {
                Write-Host "⚠️ ${service}: запускается - пожалуйста, подождите..." -ForegroundColor Yellow
                $healthy = $false
                $needsAttention += $service
            }
            else {
                Write-Host "❌ ${service}: запущен, но не в здоровом состоянии" -ForegroundColor Red
                $healthy = $false
                $needsAttention += $service
                
                if ($Verbose) {
                    Write-Host "`nПоследние 10 строк лога для ${service}:" -ForegroundColor Cyan
                    docker logs --tail 10 $containerName
                }
            }
        }
        else {
            Write-Host "❌ ${service}: не запущен" -ForegroundColor Red
            $healthy = $false
            $needsAttention += $service
            
            if ($FixProblems) {
                Write-Host "🔄 Попытка запуска ${service}..." -ForegroundColor Yellow
                docker start $containerName
                Start-Sleep -Seconds 2
                
                $newStatus = docker inspect --format='{{.State.Status}}' $containerName 2>$null
                if ($newStatus -eq "running") {
                    Write-Host "✓ ${service}: успешно запущен" -ForegroundColor Green
                }
                else {
                    Write-Host "❌ ${service}: не удалось запустить" -ForegroundColor Red
                }
            }
        }
    }
    catch {
        Write-Host "❌ ${service}: ошибка проверки статуса - $($_.Exception.Message)" -ForegroundColor Red
        $healthy = $false
        $needsAttention += $service
    }
}

# Проверка доступности сервисов через HTTP
Write-Host "`nПроверка доступности веб-сервисов..." -ForegroundColor Cyan

$endpoints = @{
    "WebGIS" = "http://localhost/webgis/";
    "GeoServer" = "http://localhost/geoserver/";
}

foreach ($endpoint in $endpoints.GetEnumerator()) {
    try {
        $response = Invoke-WebRequest -Uri $endpoint.Value -Method Head -UseBasicParsing -TimeoutSec 5 -ErrorAction SilentlyContinue
        
        if ($response.StatusCode -eq 200) {
            Write-Host "✓ $($endpoint.Key): доступен" -ForegroundColor Green
        }
        else {
            Write-Host "⚠️ $($endpoint.Key): статус $($response.StatusCode)" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "❌ $($endpoint.Key): недоступен - $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Проверка подключения к PostGIS
Write-Host "`nПроверка подключения к PostGIS..." -ForegroundColor Cyan
try {
    $result = docker exec -it postgis psql -U postgres -d gis -c "SELECT PostGIS_version();" -t 2>$null
    if ($LASTEXITCODE -eq 0) {
        $version = $result.Trim()
        Write-Host "✓ PostGIS: подключение успешно, версия $version" -ForegroundColor Green
    }
    else {
        Write-Host "❌ PostGIS: не удалось выполнить запрос" -ForegroundColor Red
    }
}
catch {
    Write-Host "❌ PostGIS: ошибка подключения - $($_.Exception.Message)" -ForegroundColor Red
}

# Проверка использования дискового пространства
Write-Host "`nПроверка использования дискового пространства..." -ForegroundColor Cyan
$dockerInfo = docker system df --format '{{.TotalCount}} {{.Size}}'
$dockerInfoParts = $dockerInfo -split "\s+"
$dockerImagesCount = $dockerInfoParts[0]
$dockerSpaceUsage = $dockerInfoParts[1]

Write-Host "Docker: $dockerImagesCount образов, используется $dockerSpaceUsage пространства" -ForegroundColor White

# Проверка больших ECW файлов
$ecwPath = "data/raster-storage/ecw"
if (Test-Path $ecwPath) {
    $ecwFiles = Get-ChildItem -Path $ecwPath -Filter "*.ecw" -File | Sort-Object Length -Descending
    
    if ($ecwFiles.Count -gt 0) {
        Write-Host "`nНайдено $($ecwFiles.Count) ECW файлов:" -ForegroundColor Cyan
        
        foreach ($file in $ecwFiles | Select-Object -First 5) {
            $sizeGB = [math]::Round($file.Length / 1GB, 2)
            Write-Host "$($file.Name): $sizeGB ГБ" -ForegroundColor White
        }
        
        if ($ecwFiles.Count -gt 5) {
            Write-Host "... и еще $($ecwFiles.Count - 5) файлов" -ForegroundColor Gray
        }
    }
    else {
        Write-Host "`nECW файлы не найдены в $ecwPath" -ForegroundColor Yellow
    }
}
else {
    Write-Host "`nДиректория $ecwPath не существует" -ForegroundColor Yellow
}

# Итоговый статус
if ($healthy) {
    Write-Host "`n✅ Все сервисы работают нормально!" -ForegroundColor Green
}
else {
    Write-Host "`n⚠️ Следующие сервисы требуют внимания:" -ForegroundColor Red
    foreach ($service in $needsAttention) {
        Write-Host "  - $service" -ForegroundColor Red
    }
    
    Write-Host "`nРекомендации по решению проблем:" -ForegroundColor Yellow
    Write-Host "1. Перезапустить проблемные сервисы: docker-compose restart $($needsAttention -join ' ')" -ForegroundColor White
    Write-Host "2. Проверить логи: docker-compose logs $($needsAttention -join ' ')" -ForegroundColor White
    Write-Host "3. Перезапустить все сервисы: docker-compose down && docker-compose up -d" -ForegroundColor White
    
    if ($FixProblems) {
        Write-Host "`nБыла выполнена попытка автоматического исправления проблем." -ForegroundColor Cyan
        Write-Host "Запустите скрипт проверки еще раз для подтверждения результатов." -ForegroundColor Cyan
    }
    else {
        Write-Host "`nДля автоматической попытки исправления запустите:" -ForegroundColor Cyan
        Write-Host ".\scripts\check-health.ps1 -FixProblems" -ForegroundColor White
    }
}

Write-Host "`nПроверка завершена." -ForegroundColor Cyan 