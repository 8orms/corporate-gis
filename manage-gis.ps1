# Главный скрипт управления проектом Corporate GIS
# Предоставляет единую точку входа для различных операций

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("init", "start", "stop", "restart", "status", "logs", "backup", "manage-ecw", "test", "setup-projections", "analyze-logs", "update-storybook", "help", "generate-config", "rebuild", "check-layer-admin", "switch-env")]
    [string]$Command = "help",
    
    [Parameter(Mandatory=$false, ValueFromRemainingArguments=$true)]
    [string[]]$Arguments
)

# Константы и переменные
$PROJECT_ROOT = (Get-Location).Path
$ScriptsDirectory = Join-Path $PROJECT_ROOT "scripts"
$ENV_FILE = ".env"
$ENV_DEV_FILE = ".env.dev"
$ENV_PROD_FILE = ".env.prod"
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
    Write-Host "  start                - Запуск всех сервисов" -ForegroundColor White
    Write-Host "  stop                 - Остановка всех сервисов" -ForegroundColor White
    Write-Host "  restart              - Перезапуск всех сервисов" -ForegroundColor White
    Write-Host "  status               - Проверка статуса сервисов" -ForegroundColor White
    Write-Host "  logs [сервис]        - Просмотр логов (опционально: имя сервиса)" -ForegroundColor White
    Write-Host "  backup               - Создание резервной копии конфигурации" -ForegroundColor White
    Write-Host "  manage-ecw <команда> - Управление ECW файлами" -ForegroundColor White
    Write-Host "  test                 - Запуск тестов" -ForegroundColor White
    Write-Host "  setup-projections    - Настройка пользовательских проекций" -ForegroundColor White
    Write-Host "  analyze-logs         - Анализ логов на наличие ошибок" -ForegroundColor White
    Write-Host "  update-storybook     - Обновление журнала разработки" -ForegroundColor White
    Write-Host "  generate-config      - Генерация конфигурационного файла" -ForegroundColor White
    Write-Host "  rebuild              - Полная пересборка системы" -ForegroundColor White
    Write-Host "  check-layer-admin    - Проверка работоспособности Django-админки" -ForegroundColor White
    Write-Host "  switch-env <env>     - Переключение окружения (dev|prod)" -ForegroundColor White
    Write-Host "  help                 - Показать эту справку" -ForegroundColor White
    
    Write-Host "`nПримеры:" -ForegroundColor Cyan
    Write-Host "  ./manage-gis.ps1 init dev" -ForegroundColor White
    Write-Host "  ./manage-gis.ps1 start" -ForegroundColor White
    Write-Host "  ./manage-gis.ps1 logs postgis" -ForegroundColor White
    Write-Host "  ./manage-gis.ps1 switch-env prod" -ForegroundColor White
}

# Функция для определения текущего окружения
function Get-CurrentEnvironment {
    # Проверяем наличие .env файла
    if (-not (Test-Path $ENV_FILE)) {
        return "dev" # По умолчанию используем dev
    }
    
    # Читаем содержимое .env файла и ищем переменную ENVIRONMENT
    $envContent = Get-Content $ENV_FILE
    $envLine = $envContent | Where-Object { $_ -match "^ENVIRONMENT=(.+)$" }
    
    if ($envLine) {
        $environment = $matches[1].Trim()
        return $environment
    }
    
    return "dev" # По умолчанию используем dev
}

# Функция для получения пути к docker-compose файлу
function Get-DockerComposePath {
    param(
        [Parameter(Mandatory=$false)]
        [string]$Environment = ""
    )
    
    if (-not $Environment) {
        $Environment = Get-CurrentEnvironment
    }
    
    $dockerComposePath = "config/docker/$Environment/docker-compose.yml"
    
    if (-not (Test-Path $dockerComposePath)) {
        Write-Warning "Файл docker-compose для окружения $Environment не найден. Используем стандартный docker-compose.yml"
        $dockerComposePath = "docker-compose.yml"
    }
    
    return $dockerComposePath
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
    
    $environment = Get-CurrentEnvironment
    $dockerComposePath = Get-DockerComposePath -Environment $environment
    
    if (-not (Test-Path $dockerComposePath)) {
        Write-Error "Файл $dockerComposePath не найден. Сначала выполните инициализацию проекта."
        Write-Host "  ./manage-gis.ps1 init $environment" -ForegroundColor Yellow
        return
    }
    
    Write-Step "Запуск контейнеров для окружения: $environment..."
    # Проверяем наличие .env файла и явно указываем его
    if (Test-Path ".env") {
        docker-compose -f $dockerComposePath --env-file .env up -d
    } else {
        Write-Warning "Файл .env не найден. Используем переменные окружения по умолчанию."
        docker-compose -f $dockerComposePath up -d
    }
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Ошибка при запуске контейнеров!"
        return
    }
    
    Write-Success "Контейнеры успешно запущены"
    Write-Step "Проверка статуса контейнеров..."
    docker-compose -f $dockerComposePath ps
}

# Остановка контейнеров
function Stop-GisServices {
    Write-Title "Остановка GIS сервисов"
    
    $environment = Get-CurrentEnvironment
    $dockerComposePath = Get-DockerComposePath -Environment $environment
    
    if (-not (Test-Path $dockerComposePath)) {
        Write-Error "Файл $dockerComposePath не найден. Сначала выполните инициализацию проекта."
        Write-Host "  ./manage-gis.ps1 init $environment" -ForegroundColor Yellow
        return
    }
    
    Write-Step "Остановка контейнеров..."
    # Проверяем наличие .env файла и явно указываем его
    if (Test-Path ".env") {
        docker-compose -f $dockerComposePath --env-file .env down
    } else {
        Write-Warning "Файл .env не найден. Используем переменные окружения по умолчанию."
        docker-compose -f $dockerComposePath down
    }
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Ошибка при остановке контейнеров!"
        return
    }
    
    Write-Success "Контейнеры успешно остановлены"
}

# Перезапуск контейнеров
function Restart-GisServices {
    Write-Title "Перезапуск GIS сервисов"
    
    $environment = Get-CurrentEnvironment
    $dockerComposePath = Get-DockerComposePath -Environment $environment
    
    if (-not (Test-Path $dockerComposePath)) {
        Write-Error "Файл $dockerComposePath не найден. Сначала выполните инициализацию проекта."
        Write-Host "  ./manage-gis.ps1 init $environment" -ForegroundColor Yellow
        return
    }
    
    Write-Step "Перезапуск контейнеров..."
    # Проверяем наличие .env файла и явно указываем его
    if (Test-Path ".env") {
        docker-compose -f $dockerComposePath --env-file .env restart
    } else {
        Write-Warning "Файл .env не найден. Используем переменные окружения по умолчанию."
        docker-compose -f $dockerComposePath restart
    }
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Ошибка при перезапуске контейнеров!"
        return
    }
    
    Write-Success "Контейнеры успешно перезапущены"
    Write-Step "Проверка статуса контейнеров..."
    docker-compose -f $dockerComposePath ps
}

# Проверка статуса контейнеров
function Get-GisServicesStatus {
    Write-Title "Статус GIS сервисов"
    
    $environment = Get-CurrentEnvironment
    $dockerComposePath = Get-DockerComposePath -Environment $environment
    
    if (-not (Test-Path $dockerComposePath)) {
        Write-Error "Файл $dockerComposePath не найден. Сначала выполните инициализацию проекта."
        Write-Host "  ./manage-gis.ps1 init $environment" -ForegroundColor Yellow
        return
    }
    
    Write-Step "Текущее окружение: $environment"
    Write-Step "Используемый файл docker-compose: $dockerComposePath"
    Write-Step "Статус контейнеров:"
    
    # Проверяем наличие .env файла и явно указываем его
    if (Test-Path ".env") {
        docker-compose -f $dockerComposePath --env-file .env ps
    } else {
        Write-Warning "Файл .env не найден. Используем переменные окружения по умолчанию."
        docker-compose -f $dockerComposePath ps
    }
}

# Просмотр логов
function Show-Logs {
    Write-Title "Просмотр логов"
    
    $environment = Get-CurrentEnvironment
    $dockerComposePath = Get-DockerComposePath -Environment $environment
    
    if (-not (Test-Path $dockerComposePath)) {
        Write-Error "Файл $dockerComposePath не найден. Сначала выполните инициализацию проекта."
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
    
    # Проверяем наличие .env файла и явно указываем его
    if (Test-Path ".env") {
        # Использование docker-compose logs
        if ([string]::IsNullOrEmpty($service)) {
            docker-compose -f $dockerComposePath --env-file .env logs --tail=100
        }
        else {
            docker-compose -f $dockerComposePath --env-file .env logs --tail=100 $service
        }
    } else {
        Write-Warning "Файл .env не найден. Используем переменные окружения по умолчанию."
        # Использование docker-compose logs
        if ([string]::IsNullOrEmpty($service)) {
            docker-compose -f $dockerComposePath logs --tail=100
        }
        else {
            docker-compose -f $dockerComposePath logs --tail=100 $service
        }
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

# Функция для добавления записи в storybook
function Update-Storybook {
    Write-Title "Обновление storybook"
    
    $updateScript = "scripts/update-storybook.ps1"
    
    if (-not (Test-Path $updateScript)) {
        Write-Error "Скрипт обновления storybook не найден: $updateScript"
        return
    }
    
    # Обработка аргументов как именованных параметров
    $taskName = ""
    $comment = ""
    $status = "✅"
    
    # Парсинг аргументов
    for ($i = 0; $i -lt $Arguments.Count; $i++) {
        if ($Arguments[$i] -eq "-TaskName" -and $i+1 -lt $Arguments.Count) {
            $taskName = $Arguments[$i+1]
            $i++
        }
        elseif ($Arguments[$i] -eq "-Comment" -and $i+1 -lt $Arguments.Count) {
            $comment = $Arguments[$i+1]
            $i++
        }
        elseif ($Arguments[$i] -eq "-Status" -and $i+1 -lt $Arguments.Count) {
            $status = $Arguments[$i+1]
            $i++
        }
    }
    
    # Проверка обязательных параметров
    if ([string]::IsNullOrWhiteSpace($taskName) -or [string]::IsNullOrWhiteSpace($comment)) {
        Write-Warning "Недостаточно аргументов. Необходимо указать название задачи и комментарий."
        Write-Host "Использование: ./manage-gis.ps1 update-storybook -TaskName ""Название задачи"" -Comment ""Комментарий""" -ForegroundColor White
        Write-Host "Дополнительные параметры: -Status ""✅/🔄/⚠️/❌"" (по умолчанию ✅)" -ForegroundColor White
        return
    }
    
    # Вызов скрипта с параметрами
    & $updateScript -TaskName $taskName -Comment $comment -Status $status
}

# Функция генерации конфигурации слоев
function Generate-LayerConfig {
    param(
        [Parameter(Mandatory=$false)]
        [string]$MetadataPath = "config/layer-registry.json",
        
        [Parameter(Mandatory=$false)]
        [string]$OutputJsPath = "src/web-interface/js/generated-layers.js"
    )
    
    Write-Host "========== Генерация конфигурации слоев ==========" -ForegroundColor Green
    
    # Проверяем существование файла метаданных
    if (-not (Test-Path -Path $MetadataPath)) {
        Write-Error "Файл метаданных не найден: $MetadataPath"
        Write-Host "Убедитесь, что файл слоев $MetadataPath существует." -ForegroundColor Yellow
        return
    }
    
    # Запускаем скрипт генерации конфигурации
    try {
        & "$ScriptsDirectory\generate-layer-config.ps1" -MetadataPath $MetadataPath -OutputJsPath $OutputJsPath
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Конфигурация слоев успешно сгенерирована в $OutputJsPath" -ForegroundColor Green
        } else {
            Write-Error "Ошибка при генерации конфигурации слоев: Exit code $LASTEXITCODE"
        }
    } catch {
        Write-Error "Ошибка при выполнении скрипта generate-layer-config.ps1: $_"
    }
}

# Полная пересборка системы
function Rebuild-GisSystem {
    Write-Title "Полная пересборка GIS-платформы"
    
    $environment = Get-CurrentEnvironment
    $dockerComposePath = Get-DockerComposePath -Environment $environment
    
    # Останавливаем все контейнеры
    Write-Step "Остановка всех контейнеров..."
    if (Test-Path $dockerComposePath) {
        docker-compose -f $dockerComposePath down
    } else {
        Write-Warning "Файл $dockerComposePath не найден. Пропуск остановки контейнеров."
    }
    
    # Удаляем все тома
    Write-Step "Удаление томов..."
    $volumes = docker volume ls -q --filter "name=corporate-gis"
    if ($volumes) {
        docker volume rm $volumes
        Write-Step "Тома удалены: $volumes"
    } else {
        Write-Step "Томов для удаления не найдено"
    }
    
    # Очистка кэша Docker
    Write-Step "Очистка кэша Docker..."
    docker system prune -f
    
    # Инициализируем проект
    Write-Step "Инициализация проекта для окружения: $environment..."
    Initialize-Project
    
    # Запускаем все сервисы
    Write-Step "Запуск контейнеров..."
    $dockerComposePath = Get-DockerComposePath -Environment $environment # Получаем путь заново после инициализации
    docker-compose -f $dockerComposePath up -d --build
    
    # Проверяем состояние сервисов
    Write-Step "Проверка состояния сервисов..."
    docker-compose -f $dockerComposePath ps
    
    Write-Success "Пересборка GIS-платформы успешно завершена!"
}

# Функция проверки работоспособности Django-админки
function Check-LayerAdminHealth {
    Write-Title "Проверка работоспособности Django-админки"
    
    $environment = Get-CurrentEnvironment
    Write-Step "Текущее окружение: $environment"
    
    $layerAdminScript = Join-Path $ScriptsDirectory "Check-LayerAdmin.ps1"
    
    if (-not (Test-Path $layerAdminScript)) {
        Write-Error "Скрипт проверки Django-админки не найден: $layerAdminScript"
        return
    }
    
    # Выполняем скрипт проверки
    & $layerAdminScript -Environment $environment
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Django-админка работает корректно"
    } else {
        Write-Error "Обнаружены проблемы с Django-админкой. Код завершения: $LASTEXITCODE"
    }
}

# Функция для переключения окружения
function Switch-Environment {
    if ($Arguments.Count -lt 1) {
        Write-Error "Не указано окружение для переключения. Используйте: dev или prod"
        Write-Host "Пример: ./manage-gis.ps1 switch-env dev" -ForegroundColor Yellow
        return
    }
    
    $environment = $Arguments[0]
    if ($environment -ne "dev" -and $environment -ne "prod") {
        Write-Error "Неверное окружение. Используйте: dev или prod"
        return
    }
    
    $restartFlag = if ($Arguments.Count -gt 1 -and $Arguments[1] -eq "-restart") { "-Restart" } else { "" }
    
    # Запуск скрипта переключения окружения
    & "$ScriptsDirectory\switch-environment.ps1" -Environment $environment $restartFlag
}

# Основная функция для обработки команд
function Process-Command {
    param (
        [string]$Command,
        [string[]]$Arguments
    )
    
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
            Get-GisServicesStatus
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
        "update-storybook" {
            Update-Storybook
        }
        "generate-config" {
            if ($Arguments.Count -ge 1) {
                Generate-LayerConfig -MetadataPath $Arguments[0]
            } else {
                Generate-LayerConfig
            }
        }
        "rebuild" {
            Rebuild-GisSystem
        }
        "check-layer-admin" {
            Check-LayerAdminHealth
        }
        "switch-env" {
            Switch-Environment
        }
        "help" {
            Show-Help
        }
        default {
            Write-Error "Неизвестная команда: $Command"
            Show-Help
        }
    }
}

# Основная логика скрипта
Process-Command -Command $Command -Arguments $Arguments 