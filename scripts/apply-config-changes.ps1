<#
.SYNOPSIS
    Скрипт для применения изменений в конфигурации и перезапуска контейнеров.
    
.DESCRIPTION
    Этот скрипт проверяет обновленную конфигурацию NGINX на ошибки,
    перезапускает контейнеры GeoServer и NGINX, проверяет их статус,
    а также выполняет тестовые запросы для проверки доступности сервисов.
    
.NOTES
    Файл: apply-config-changes.ps1
    Автор: Корпоративная ГИС-платформа
    Версия: 1.0
#>

# Проверка наличия docker-compose
if (-not (Get-Command "docker-compose" -ErrorAction SilentlyContinue)) {
    Write-Error "Docker Compose не найден. Пожалуйста, установите Docker Compose."
    exit 1
}

# Функция для проверки статуса контейнера
function Check-ContainerStatus {
    param (
        [string]$containerName
    )
    
    $status = docker ps --filter "name=$containerName" --format "{{.Status}}"
    
    if ([string]::IsNullOrEmpty($status)) {
        return "Не запущен"
    }
    else {
        return "Запущен"
    }
}

# Функция для проверки доступности сервиса по HTTP
function Check-ServiceAvailability {
    param (
        [string]$url,
        [string]$description
    )
    
    Write-Host "Проверка доступности $description..." -ForegroundColor Yellow
    
    try {
        $response = Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing -TimeoutSec 5
        if ($response.StatusCode -eq 200) {
            Write-Host "Сервис $description доступен (код $($response.StatusCode))" -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "Сервис $description вернул код $($response.StatusCode)" -ForegroundColor Yellow
            return $false
        }
    }
    catch {
        Write-Host "Не удалось подключиться к $description. Ошибка: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

Write-Host "=== Применение изменений конфигурации ===" -ForegroundColor Cyan

# Проверка синтаксиса NGINX
Write-Host "Проверка синтаксиса NGINX..." -ForegroundColor Yellow
docker exec -it nginx nginx -t
if ($LASTEXITCODE -ne 0) {
    Write-Error "Ошибка в конфигурации NGINX. Исправьте ошибки и попробуйте снова."
    exit 1
}

# Перезапуск NGINX
Write-Host "Перезапуск NGINX..." -ForegroundColor Yellow
docker exec -it nginx nginx -s reload
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Перезапуск NGINX через nginx -s reload не удался. Перезапуск контейнера..."
    docker-compose restart nginx
}

# Перезапуск GeoServer контейнеров
Write-Host "Перезапуск GeoServer контейнеров..." -ForegroundColor Yellow
docker-compose restart geoserver-vector geoserver-ecw

# Ожидание запуска контейнеров
Write-Host "Ожидание запуска контейнеров..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

# Проверка статуса контейнеров
Write-Host "Проверка статуса контейнеров:" -ForegroundColor Cyan
Write-Host "NGINX: $(Check-ContainerStatus 'nginx')"
Write-Host "GeoServer Vector: $(Check-ContainerStatus 'geoserver-vector')"
Write-Host "GeoServer ECW: $(Check-ContainerStatus 'geoserver-ecw')"

# Подождем дополнительное время для полного запуска GeoServer
Write-Host "Ожидание полного запуска сервисов (15 секунд)..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

# Проверка доступности сервисов
Write-Host "Проверка доступности сервисов:" -ForegroundColor Cyan
$nginx = Check-ServiceAvailability "http://localhost/health" "NGINX Health"
$geoserverSelect = Check-ServiceAvailability "http://localhost/geoserver/" "Страница выбора GeoServer"
$geoserverVector = Check-ServiceAvailability "http://localhost/geoserver/vector/web/" "GeoServer Vector"
$geoserverEcw = Check-ServiceAvailability "http://localhost/geoserver/ecw/web/" "GeoServer ECW"

# Вывод итоговой информации
Write-Host "`n=== Результаты применения изменений ===" -ForegroundColor Cyan
if ($nginx) {
    Write-Host "NGINX Health: Доступен" 
} else {
    Write-Host "NGINX Health: Недоступен" -ForegroundColor Red
}

if ($geoserverSelect) {
    Write-Host "Страница выбора GeoServer: Доступна"
} else {
    Write-Host "Страница выбора GeoServer: Недоступна" -ForegroundColor Red
}

if ($geoserverVector) {
    Write-Host "GeoServer Vector: Доступен"
} else {
    Write-Host "GeoServer Vector: Недоступен" -ForegroundColor Red
}

if ($geoserverEcw) {
    Write-Host "GeoServer ECW: Доступен"
} else {
    Write-Host "GeoServer ECW: Недоступен" -ForegroundColor Red
}

Write-Host "`nИнструкции по проверке:" -ForegroundColor Green
Write-Host "1. Откройте http://localhost/geoserver/ и выберите нужный GeoServer."
Write-Host "2. Попробуйте авторизоваться с учетными данными: admin/geoserver"
Write-Host "3. После авторизации вы должны увидеть административный интерфейс."
Write-Host "`nЕсли проблема с доступом сохраняется, проверьте логи контейнеров:"
Write-Host "docker logs nginx"
Write-Host "docker logs geoserver-vector"
Write-Host "docker logs geoserver-ecw" 