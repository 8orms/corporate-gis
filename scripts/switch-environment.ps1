# Скрипт для переключения между окружениями разработки и продакшена
# Использование: ./scripts/switch-environment.ps1 -Environment [dev|prod] [-Restart]

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "prod")]
    [string]$Environment,
    
    [Parameter(Mandatory=$false)]
    [switch]$Restart
)

# Функции для цветного вывода
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

# Функция для получения текущего окружения
function Get-CurrentEnvironment {
    # Проверяем наличие .env файла
    if (-not (Test-Path ".env")) {
        return "unknown"
    }
    
    # Читаем содержимое .env файла и ищем переменную ENVIRONMENT
    $envContent = Get-Content ".env"
    $envLine = $envContent | Where-Object { $_ -match "^ENVIRONMENT=(.+)$" }
    
    if ($envLine) {
        $environment = $matches[1].Trim()
        return $environment
    }
    
    return "unknown"
}

# Основная логика скрипта
Write-Title "Переключение окружения на: $Environment"

# Проверка текущего окружения
$currentEnv = Get-CurrentEnvironment
Write-Step "Текущее окружение: $currentEnv"

# Проверка наличия файлов окружения
$envFile = ".env.$Environment"
if (-not (Test-Path $envFile)) {
    Write-Error "Файл $envFile не найден. Сначала выполните инициализацию проекта."
    Write-Step "Выполните команду: ./manage-gis.ps1 init $Environment"
    exit 1
}

# Создание резервной копии текущего .env файла
if (Test-Path ".env") {
    $backupFile = ".env.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Write-Step "Создание резервной копии текущего .env файла: $backupFile"
    Copy-Item -Path ".env" -Destination $backupFile
}

# Копирование нового файла окружения
Write-Step "Копирование $envFile в .env"
Copy-Item -Path $envFile -Destination ".env" -Force

Write-Success "Окружение успешно переключено на: $Environment"

# Перезапуск контейнеров при необходимости
if ($Restart) {
    Write-Step "Перезапуск контейнеров..."
    & "./manage-gis.ps1" restart
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Ошибка при перезапуске контейнеров!"
    }
    else {
        Write-Success "Контейнеры успешно перезапущены с новым окружением: $Environment"
    }
}
else {
    Write-Warning "Контейнеры не были перезапущены. Для применения изменений выполните:"
    Write-Host "  ./manage-gis.ps1 restart" -ForegroundColor Yellow
}

# Вывод информации о доступе
Write-Host "`nДоступ к сервисам:" -ForegroundColor Cyan
Write-Host "  - Веб-интерфейс: http://localhost/" -ForegroundColor White
Write-Host "  - GeoServer Vector: http://localhost/geoserver/vector/" -ForegroundColor White
Write-Host "  - GeoServer ECW: http://localhost/geoserver/ecw/" -ForegroundColor White
Write-Host "  - PostGIS: localhost:5432" -ForegroundColor White 