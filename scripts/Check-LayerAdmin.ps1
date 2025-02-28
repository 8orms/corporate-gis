# Скрипт для проверки работы Django-админки с реестром слоев

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("dev", "prod")]
    [string]$Environment = "dev"
)

# Функция для загрузки переменных окружения из .env файла
function Get-EnvVariables {
    param (
        [string]$EnvFile = ".env"
    )
    
    $envVars = @{}
    
    if (Test-Path $EnvFile) {
        Get-Content $EnvFile | ForEach-Object {
            if ($_ -match "^\s*([^#][^=]+)=(.*)$") {
                $key = $matches[1].Trim()
                $value = $matches[2].Trim()
                $envVars[$key] = $value
            }
        }
    }
    
    return $envVars
}

# Функция для проверки доступности сервера
function Test-ServerAvailability {
    param (
        [string]$Url,
        [int]$MaxTries = 30,
        [int]$DelaySeconds = 5
    )
    
    Write-Host "Проверка доступности $Url..." -ForegroundColor Cyan
    
    $counter = 0
    while ($counter -lt $MaxTries) {
        try {
            $response = Invoke-WebRequest -Uri $Url -Method Head -UseBasicParsing -TimeoutSec 2 -ErrorAction SilentlyContinue
            if ($response.StatusCode -eq 200 -or $response.StatusCode -eq 302) {
                Write-Host "Сервер $Url доступен!" -ForegroundColor Green
                return $true
            }
        }
        catch {
            # Сервер недоступен, продолжаем попытки
        }
        
        $counter++
        Write-Host "Ожидание доступности сервера... ($counter/$MaxTries)" -ForegroundColor Yellow
        Start-Sleep -Seconds $DelaySeconds
    }
    
    Write-Host "Ошибка: Не удалось подключиться к $Url после $MaxTries попыток." -ForegroundColor Red
    return $false
}

# Функция для проверки API доступности
function Test-ApiAvailability {
    param (
        [string]$Url
    )
    
    Write-Host "Проверка API: $Url..." -ForegroundColor Cyan
    
    try {
        $response = Invoke-WebRequest -Uri $Url -Method Get -UseBasicParsing -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200 -or $response.StatusCode -eq 302) {
            Write-Host "API $Url доступен!" -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "Ошибка: API недоступен. Код ответа: $($response.StatusCode)" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "Ошибка при обращении к API: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Функция для проверки наличия файла реестра слоев
function Test-LayerRegistry {
    param (
        [string]$Path = "config/layer-registry.json"
    )
    
    Write-Host "Проверка доступности JSON-реестра слоев..." -ForegroundColor Cyan
    
    if (Test-Path -Path $Path) {
        Write-Host "JSON-реестр слоев найден!" -ForegroundColor Green
        return $true
    }
    else {
        Write-Host "Предупреждение: Файл JSON-реестра слоев не найден." -ForegroundColor Yellow
        return $false
    }
}

# Основная логика проверки
Write-Host "=== Проверка работы Django-админки с реестром слоев ===" -ForegroundColor Cyan
Write-Host "Используемое окружение: $Environment" -ForegroundColor Cyan

# Загрузка переменных окружения
$envFile = if ($Environment -eq "dev") { ".env.dev" } else { ".env.prod" }
if (-not (Test-Path $envFile)) {
    $envFile = ".env"
}

$envVars = Get-EnvVariables -EnvFile $envFile
Write-Host "Используемый файл переменных окружения: $envFile" -ForegroundColor Cyan

# Получение порта Django из переменных окружения
$djangoPort = if ($envVars.ContainsKey("DJANGO_PORT")) { $envVars["DJANGO_PORT"] } else { "8000" }
$adminUrl = "http://localhost:$djangoPort/admin/"
$apiUrl = "http://localhost:$djangoPort/admin/data_manager/layer/"

Write-Host "URL Django-админки: $adminUrl" -ForegroundColor Cyan

# Проверка доступности Django-админки
$adminAvailable = Test-ServerAvailability -Url $adminUrl
if (-not $adminAvailable) {
    Write-Host "Критическая ошибка: Django-админка недоступна." -ForegroundColor Red
    exit 1
}

# Проверка API для слоев
$apiAvailable = Test-ApiAvailability -Url $apiUrl
if (-not $apiAvailable) {
    Write-Host "Критическая ошибка: API для слоев недоступен." -ForegroundColor Red
    exit 1
}

# Проверка файла реестра слоев
$registryAvailable = Test-LayerRegistry
if (-not $registryAvailable) {
    Write-Host "Предупреждение: JSON-реестр слоев не найден. Будет создан при первом сохранении." -ForegroundColor Yellow
}

Write-Host "Проверка успешно завершена!" -ForegroundColor Green
exit 0 