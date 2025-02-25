# Главный скрипт управления проектом Corporate GIS
# Предоставляет единую точку входа для различных операций

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("init", "start", "stop", "restart", "status", "logs", "backup", "manage-ecw", "test", "setup-projections", "analyze-logs", "help")]
    [string]$Command = "help",
    
    [Parameter(Mandatory=$false, ValueFromRemainingArguments=$true)]
    [string[]]$Arguments
)

# Константы и переменные
$PROJECT_ROOT = (Get-Location).Path
$DOCKER_COMPOSE_FILE = "docker-compose.yml"
$BACKUP_DIR = "backups"

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

# Функция помощи
function Show-Help {
    Write-Title "Corporate GIS - Система управления"
    Write-Host "Использование: ./manage-gis.ps1 <команда> [аргументы]" -ForegroundColor White
    
    Write-Host "`nДоступные команды:" -ForegroundColor Cyan
    Write-Host "  init [dev|prod]      - Инициализация проекта (опционально: окружение)" -ForegroundColor White
    Write-Host "  start                - Запуск контейнеров" -ForegroundColor White
    Write-Host "  stop                 - Остановка контейнеров" -ForegroundColor White
    Write-Host "  restart              - Перезапуск контейнеров" -ForegroundColor White
    Write-Host "  status               - Просмотр статуса контейнеров и основных параметров" -ForegroundColor White
    Write-Host "  logs [сервис]        - Просмотр логов (опционально: имя сервиса)" -ForegroundColor White
    Write-Host "  backup               - Создание резервной копии конфигурации" -ForegroundColor White
    Write-Host "  manage-ecw <args>    - Управление ECW файлами и проекциями" -ForegroundColor White
    Write-Host "  setup-projections    - Настройка пользовательских проекций" -ForegroundColor White
    Write-Host "  test                 - Тестирование работоспособности системы" -ForegroundColor White
    Write-Host "  analyze-logs [args]  - Анализ логов контейнеров" -ForegroundColor White
    Write-Host "  help                 - Показать эту справку" -ForegroundColor White
    
    Write-Host "`nПримеры:" -ForegroundColor Cyan
    Write-Host "  ./manage-gis.ps1 init dev" -ForegroundColor Yellow
    Write-Host "  ./manage-gis.ps1 start" -ForegroundColor Yellow
    Write-Host "  ./manage-gis.ps1 status" -ForegroundColor Yellow
    Write-Host "  ./manage-gis.ps1 logs geoserver-ecw" -ForegroundColor Yellow
    Write-Host "  ./manage-gis.ps1 manage-ecw list" -ForegroundColor Yellow
    Write-Host "  ./manage-gis.ps1 analyze-logs -Since \"1h\" -IncludeInfo" -ForegroundColor Yellow
    
    Write-Host "`nПодробная документация доступна в директории docs/" -ForegroundColor White
}

# Инициализация проекта
function Initialize-Project {
    $environment = "dev"
    if ($Arguments.Count -gt 0 -and ($Arguments[0] -eq "dev" -or $Arguments[0] -eq "prod")) {
        $environment = $Arguments[0]
    }
    
    Write-Title "Инициализация проекта для окружения: $environment"
    
    # Запуск скрипта инициализации с выбранным окружением
    & "./scripts/initialize-project.ps1" -Environment $environment
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Ошибка при инициализации проекта!"
        return
    }
}

# Запуск контейнеров
function Start-GisServices {
    Write-Title "Запуск GIS сервисов"
    
    if (-not (Test-Path $DOCKER_COMPOSE_FILE)) {
        Write-Error "Файл docker-compose.yml не найден. Сначала выполните инициализацию проекта."
        Write-Host "  ./manage-gis.ps1 init" -ForegroundColor Yellow
        return
    }
    
    Write-Step "Запуск контейнеров..."
    docker-compose up -d
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Ошибка при запуске контейнеров!"
        return
    }
    
    Write-Success "Контейнеры успешно запущены"
    
    # Вывод информации о доступе
    Write-Host "`nДоступ к сервисам:" -ForegroundColor Cyan
    Write-Host "  - Веб-интерфейс: http://localhost/" -ForegroundColor White
    Write-Host "  - GeoServer Vector: http://localhost/geoserver/vector/" -ForegroundColor White
    Write-Host "  - GeoServer ECW: http://localhost/geoserver/ecw/" -ForegroundColor White
    Write-Host "  - PostGIS: localhost:5432" -ForegroundColor White
    
    # Проверка состояния сервисов после запуска
    Write-Step "Проверка состояния сервисов..."
    docker-compose ps
}

# Остановка контейнеров
function Stop-GisServices {
    Write-Title "Остановка GIS сервисов"
    
    if (-not (Test-Path $DOCKER_COMPOSE_FILE)) {
        Write-Error "Файл docker-compose.yml не найден. Сначала выполните инициализацию проекта."
        return
    }
    
    Write-Step "Остановка контейнеров..."
    docker-compose down
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Ошибка при остановке контейнеров!"
        return
    }
    
    Write-Success "Контейнеры успешно остановлены"
}

# Перезапуск контейнеров
function Restart-GisServices {
    Write-Title "Перезапуск GIS сервисов"
    
    if (-not (Test-Path $DOCKER_COMPOSE_FILE)) {
        Write-Error "Файл docker-compose.yml не найден. Сначала выполните инициализацию проекта."
        return
    }
    
    Write-Step "Перезапуск контейнеров..."
    docker-compose restart
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Ошибка при перезапуске контейнеров!"
        return
    }
    
    Write-Success "Контейнеры успешно перезапущены"
    
    # Проверка состояния сервисов после перезапуска
    Write-Step "Проверка состояния сервисов..."
    docker-compose ps
}

# Просмотр статуса и основных параметров
function Show-Status {
    Write-Title "Статус GIS-платформы"
    
    if (-not (Test-Path $DOCKER_COMPOSE_FILE)) {
        Write-Error "Файл docker-compose.yml не найден. Сначала выполните инициализацию проекта."
        return
    }
    
    # Проверка наличия скрипта проверки здоровья
    $healthScript = "scripts/check-health.ps1"
    if (Test-Path $healthScript) {
        Write-Step "Запуск проверки здоровья сервисов..."
        & $healthScript
        Write-Host ""
    }
    
    # Вывод статуса контейнеров
    Write-Step "Статус контейнеров:"
    docker-compose ps
    
    # Проверка доступности сервисов
    Write-Step "Проверка доступности веб-сервисов..."
    
    $services = @(
        @{Name="Веб-интерфейс"; Url="http://localhost/"},
        @{Name="GeoServer Vector"; Url="http://localhost/geoserver/vector/"},
        @{Name="GeoServer ECW"; Url="http://localhost/geoserver/ecw/"}
    )
    
    foreach ($service in $services) {
        try {
            $response = Invoke-WebRequest -Uri $service.Url -UseBasicParsing -TimeoutSec 5 -ErrorAction SilentlyContinue
            if ($response.StatusCode -eq 200) {
                Write-Host "  $($service.Name): " -NoNewline -ForegroundColor White
                Write-Host "Доступен" -ForegroundColor Green
            }
            else {
                Write-Host "  $($service.Name): " -NoNewline -ForegroundColor White
                Write-Host "Ошибка (Код $($response.StatusCode))" -ForegroundColor Red
            }
        }
        catch {
            Write-Host "  $($service.Name): " -NoNewline -ForegroundColor White
            Write-Host "Недоступен" -ForegroundColor Red
        }
    }
    
    # Информация о дисковом пространстве
    Write-Step "Информация о дисковом пространстве:"
    
    $dataFolders = @(
        @{Name="Данные PostGIS"; Path="data/postgis"},
        @{Name="Данные GeoServer Vector"; Path="data/geoserver/vector"},
        @{Name="Данные GeoServer ECW"; Path="data/geoserver/ecw"},
        @{Name="Растровые данные"; Path="data/raster-storage"},
        @{Name="Векторные данные"; Path="data/vector-storage"}
    )
    
    foreach ($folder in $dataFolders) {
        if (Test-Path $folder.Path) {
            $size = (Get-ChildItem -Path $folder.Path -Recurse -File | Measure-Object -Property Length -Sum).Sum
            $sizeGB = [math]::Round($size / 1GB, 2)
            
            if ($sizeGB -ge 1) {
                $sizeText = "$sizeGB ГБ"
            }
            else {
                $sizeMB = [math]::Round($size / 1MB, 2)
                $sizeText = "$sizeMB МБ"
            }
            
            Write-Host "  $($folder.Name): $sizeText" -ForegroundColor White
        }
        else {
            Write-Host "  $($folder.Name): Директория не существует" -ForegroundColor Yellow
        }
    }
    
    # Проверка диска
    $drive = Get-PSDrive -Name (Split-Path -Path $PROJECT_ROOT -Qualifier).TrimEnd(":")
    $freeSpaceGB = [math]::Round($drive.Free / 1GB, 2)
    $totalSpaceGB = [math]::Round(($drive.Free + $drive.Used) / 1GB, 2)
    $usedPercentage = [math]::Round(($drive.Used / ($drive.Free + $drive.Used)) * 100, 2)
    
    Write-Host "`n  Свободно места на диске: $freeSpaceGB из $totalSpaceGB ГБ ($usedPercentage% использовано)" -ForegroundColor White
    
    if ($usedPercentage -gt 85) {
        Write-Warning "Критически мало места на диске! Рекомендуется очистить ненужные данные."
    }
    elseif ($usedPercentage -gt 70) {
        Write-Warning "Мало места на диске. Рекомендуется регулярно проверять свободное место."
    }
}

# Просмотр логов
function Show-Logs {
    Write-Title "Просмотр логов"
    
    if (-not (Test-Path $DOCKER_COMPOSE_FILE)) {
        Write-Error "Файл docker-compose.yml не найден. Сначала выполните инициализацию проекта."
        return
    }
    
    $service = ""
    if ($Arguments.Count -gt 0) {
        $service = $Arguments[0]
        Write-Step "Просмотр логов сервиса: $service"
    }
    else {
        Write-Step "Просмотр логов всех сервисов"
    }
    
    # Использование docker-compose logs
    if ([string]::IsNullOrEmpty($service)) {
        docker-compose logs --tail=100
    }
    else {
        docker-compose logs --tail=100 $service
    }
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Ошибка при получении логов!"
    }
}

# Создание резервной копии
function Backup-Configuration {
    Write-Title "Создание резервной копии конфигурации"
    
    # Проверка наличия директории для резервных копий
    if (-not (Test-Path $BACKUP_DIR)) {
        Write-Step "Создание директории для резервных копий: $BACKUP_DIR"
        New-Item -ItemType Directory -Path $BACKUP_DIR | Out-Null
    }
    
    # Формирование имени файла с датой и временем
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $backupFile = Join-Path $BACKUP_DIR "gis-config-backup-$timestamp.zip"
    
    Write-Step "Создание резервной копии: $backupFile"
    
    # Список директорий и файлов для включения в резервную копию
    $backupItems = @(
        "config",
        "scripts",
        ".env",
        ".env.example",
        "docker-compose.yml",
        "README.md",
        "docs"
    )
    
    # Фильтрация несуществующих элементов
    $existingItems = $backupItems | Where-Object { Test-Path $_ }
    
    if ($existingItems.Count -eq 0) {
        Write-Error "Не найдены элементы для резервного копирования!"
        return
    }
    
    # Создание архива
    try {
        Compress-Archive -Path $existingItems -DestinationPath $backupFile -Force
        Write-Success "Резервная копия успешно создана: $backupFile"
    }
    catch {
        Write-Error "Ошибка при создании резервной копии: $($_.Exception.Message)"
    }
}

# Управление ECW файлами через отдельный скрипт
function Manage-ECW {
    $ecwScript = "scripts/manage-ecw.ps1"
    
    if (-not (Test-Path $ecwScript)) {
        Write-Error "Скрипт управления ECW файлами не найден: $ecwScript"
        Write-Step "Сначала выполните инициализацию проекта:"
        Write-Host "  ./manage-gis.ps1 init" -ForegroundColor Yellow
        return
    }
    
    # Передача аргументов в скрипт управления ECW
    & $ecwScript -Action $Arguments[0] -FilePath $(if($Arguments.Count -gt 1) {$Arguments[1]} else {$null}) -TargetPath $(if($Arguments.Count -gt 2) {$Arguments[2]} else {$null})
}

# Тестирование работоспособности системы
function Test-Environment {
    Write-Title "Тестирование работоспособности системы"
    
    $testScript = "scripts/test-environment.ps1"
    
    if (-not (Test-Path $testScript)) {
        Write-Error "Скрипт тестирования не найден: $testScript"
        return
    }
    
    # Проверка наличия аргумента -Verbose
    $verboseArg = if ($Arguments -contains "-Verbose") { "-Verbose" } else { "" }
    
    # Запуск скрипта тестирования
    & $testScript $verboseArg
}

# Настройка пользовательских проекций
function Setup-Projections {
    Write-Title "Настройка пользовательских проекций"
    
    $projScript = "scripts/setup-projections.ps1"
    
    if (-not (Test-Path $projScript)) {
        Write-Error "Скрипт настройки проекций не найден: $projScript"
        return
    }
    
    # Проверка наличия аргумента -Force
    $forceArg = if ($Arguments -contains "-Force") { "-Force" } else { "" }
    
    # Запуск скрипта настройки проекций
    & $projScript $forceArg
    
    # Если контейнеры запущены, предложить перезапустить GeoServer
    $geoserverVector = docker inspect --format='{{.State.Status}}' corporate-gis-geoserver-vector 2>$null
    $geoserverEcw = docker inspect --format='{{.State.Status}}' corporate-gis-geoserver-ecw 2>$null
    
    if ($geoserverVector -eq "running" -or $geoserverEcw -eq "running") {
        Write-Host "`nОбнаружены запущенные инстанции GeoServer." -ForegroundColor Yellow
        $restart = Read-Host "Хотите перезапустить GeoServer для применения изменений проекций? (y/n)"
        
        if ($restart -eq "y") {
            Write-Step "Перезапуск GeoServer..."
            if ($geoserverVector -eq "running") {
                docker restart corporate-gis-geoserver-vector
            }
            if ($geoserverEcw -eq "running") {
                docker restart corporate-gis-geoserver-ecw
            }
            Write-Success "Перезапуск завершен. Изменения проекций применены."
        }
    }
}

# Сбор и анализ логов контейнеров
function Analyze-ContainerLogs {
    Write-Title "Анализ логов контейнеров"
    
    $collectScript = "scripts/collect-container-logs.ps1"
    
    if (-not (Test-Path $collectScript)) {
        Write-Error "Скрипт сбора логов не найден: $collectScript"
        return
    }
    
    # Передаем аргументы в скрипт сбора логов
    & $collectScript @Arguments
}

# Основная логика скрипта
switch ($Command) {
    "init" {
        Initialize-Project
    }
    "start" {
        Start-GisServices
    }
    "stop" {
        Stop-GisServices
    }
    "restart" {
        Restart-GisServices
    }
    "status" {
        Show-Status
    }
    "logs" {
        Show-Logs
    }
    "backup" {
        Backup-Configuration
    }
    "manage-ecw" {
        Manage-ECW
    }
    "test" {
        Test-Environment
    }
    "setup-projections" {
        Setup-Projections
    }
    "analyze-logs" {
        Analyze-ContainerLogs
    }
    "help" {
        Show-Help
    }
    default {
        Write-Error "Неизвестная команда: $Command"
        Show-Help
    }
} 