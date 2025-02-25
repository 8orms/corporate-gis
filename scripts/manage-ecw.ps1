# Скрипт для управления ECW файлами и пользовательскими проекциями
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("list", "import", "register", "move", "help")]
    [string]$Action = "help",
    
    [Parameter(Mandatory=$false)]
    [string]$FilePath,
    
    [Parameter(Mandatory=$false)]
    [string]$TargetPath,
    
    [Parameter(Mandatory=$false)]
    [string]$ProjectionFile,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force
)

# Константы
$ECW_DIR = "data/raster-storage/ecw"
$PROJ_DIR = "data/user-projections"
$GEOSERVER_CONTAINER = "corporate-gis-geoserver-1"

function Show-Help {
    Write-Host "Утилита для управления ECW файлами и пользовательскими проекциями" -ForegroundColor Cyan
    Write-Host "Использование:" -ForegroundColor White
    Write-Host "  ./scripts/manage-ecw.ps1 -Action <действие> [параметры]" -ForegroundColor Yellow
    
    Write-Host "`nДоступные действия:" -ForegroundColor Cyan
    Write-Host "  list       - Показать список ECW файлов и проекций" -ForegroundColor White
    Write-Host "  import     - Импортировать ECW файл в директорию хранения" -ForegroundColor White
    Write-Host "  register   - Зарегистрировать файл проекции" -ForegroundColor White
    Write-Host "  move       - Переместить ECW файл внутри хранилища" -ForegroundColor White
    Write-Host "  help       - Показать эту справку" -ForegroundColor White
    
    Write-Host "`nПримеры:" -ForegroundColor Cyan
    Write-Host "  ./scripts/manage-ecw.ps1 -Action list" -ForegroundColor Yellow
    Write-Host "  ./scripts/manage-ecw.ps1 -Action import -FilePath D:/temp/map.ecw" -ForegroundColor Yellow
    Write-Host "  ./scripts/manage-ecw.ps1 -Action register -FilePath D:/temp/custom.prj" -ForegroundColor Yellow
    Write-Host "  ./scripts/manage-ecw.ps1 -Action move -FilePath data/raster-storage/ecw/old.ecw -TargetPath data/raster-storage/ecw/archive/" -ForegroundColor Yellow
}

function List-Files {
    # Проверка существования директорий
    if (-not (Test-Path $ECW_DIR)) {
        Write-Host "Директория ECW файлов не существует: $ECW_DIR" -ForegroundColor Red
        New-Item -ItemType Directory -Force -Path $ECW_DIR | Out-Null
        Write-Host "Директория создана." -ForegroundColor Green
    }
    
    if (-not (Test-Path $PROJ_DIR)) {
        Write-Host "Директория файлов проекций не существует: $PROJ_DIR" -ForegroundColor Red
        New-Item -ItemType Directory -Force -Path $PROJ_DIR | Out-Null
        Write-Host "Директория создана." -ForegroundColor Green
    }
    
    # Вывод ECW файлов
    Write-Host "`nECW файлы в директории $ECW_DIR:" -ForegroundColor Cyan
    
    $ecwFiles = Get-ChildItem -Path $ECW_DIR -Filter "*.ecw" -File -Recurse | Sort-Object Length -Descending
    
    if ($ecwFiles.Count -eq 0) {
        Write-Host "  ECW файлы не найдены" -ForegroundColor Yellow
    }
    else {
        foreach ($file in $ecwFiles) {
            $relativePath = $file.FullName.Replace((Get-Location).Path + "\", "")
            $sizeGB = [math]::Round($file.Length / 1GB, 2)
            $sizeFormatted = if ($sizeGB -ge 1) { "$sizeGB ГБ" } else { "$([math]::Round($file.Length / 1MB, 2)) МБ" }
            
            Write-Host "  $relativePath - $sizeFormatted" -ForegroundColor White
        }
        
        Write-Host "`nВсего файлов: $($ecwFiles.Count)" -ForegroundColor Green
        Write-Host "Общий размер: $([math]::Round(($ecwFiles | Measure-Object -Property Length -Sum).Sum / 1GB, 2)) ГБ" -ForegroundColor Green
    }
    
    # Вывод файлов проекций
    Write-Host "`nФайлы проекций в директории $PROJ_DIR:" -ForegroundColor Cyan
    
    $projFiles = Get-ChildItem -Path $PROJ_DIR -File | Sort-Object Name
    
    if ($projFiles.Count -eq 0) {
        Write-Host "  Файлы проекций не найдены" -ForegroundColor Yellow
    }
    else {
        foreach ($file in $projFiles) {
            $relativePath = $file.FullName.Replace((Get-Location).Path + "\", "")
            Write-Host "  $relativePath - $([math]::Round($file.Length / 1KB, 2)) КБ" -ForegroundColor White
        }
        
        Write-Host "`nВсего файлов проекций: $($projFiles.Count)" -ForegroundColor Green
    }
}

function Import-ECW {
    if (-not $FilePath) {
        Write-Host "Ошибка: не указан путь к ECW файлу." -ForegroundColor Red
        Write-Host "Используйте: ./scripts/manage-ecw.ps1 -Action import -FilePath <путь_к_файлу>" -ForegroundColor Yellow
        return
    }
    
    if (-not (Test-Path $FilePath)) {
        Write-Host "Ошибка: файл не найден: $FilePath" -ForegroundColor Red
        return
    }
    
    # Проверка расширения файла
    $extension = [System.IO.Path]::GetExtension($FilePath).ToLower()
    if ($extension -ne ".ecw") {
        Write-Host "Ошибка: файл не имеет расширения .ecw: $FilePath" -ForegroundColor Red
        return
    }
    
    # Создание директории назначения, если она не существует
    if (-not (Test-Path $ECW_DIR)) {
        New-Item -ItemType Directory -Force -Path $ECW_DIR | Out-Null
        Write-Host "Создана директория: $ECW_DIR" -ForegroundColor Green
    }
    
    # Копирование файла
    $fileName = [System.IO.Path]::GetFileName($FilePath)
    $destination = Join-Path $ECW_DIR $fileName
    
    if (Test-Path $destination) {
        if (-not $Force) {
            Write-Host "Файл уже существует в директории назначения: $destination" -ForegroundColor Yellow
            $confirmation = Read-Host "Перезаписать? (y/n)"
            if ($confirmation -ne "y") {
                Write-Host "Операция отменена." -ForegroundColor Yellow
                return
            }
        }
        Write-Host "Файл будет перезаписан." -ForegroundColor Yellow
    }
    
    Write-Host "Копирование файла в $destination..." -ForegroundColor Cyan
    
    # Получение размера файла
    $fileSize = (Get-Item $FilePath).Length
    $fileSizeGB = [math]::Round($fileSize / 1GB, 2)
    
    Write-Host "Размер файла: $fileSizeGB ГБ" -ForegroundColor Cyan
    
    if ($fileSizeGB -gt 10) {
        Write-Host "Внимание: копирование большого файла может занять продолжительное время." -ForegroundColor Yellow
    }
    
    try {
        Copy-Item -Path $FilePath -Destination $destination -Force
        Write-Host "Файл успешно скопирован в $destination" -ForegroundColor Green
        
        Write-Host "`nДля регистрации файла в GeoServer:" -ForegroundColor Cyan
        Write-Host "1. Откройте веб-интерфейс GeoServer: http://localhost/geoserver/ecw/" -ForegroundColor White
        Write-Host "2. Перейдите в раздел 'Хранилища данных' -> 'Добавить новое хранилище'" -ForegroundColor White
        Write-Host "3. Выберите 'ECW' в разделе растровых форматов" -ForegroundColor White
        Write-Host "4. Укажите путь к файлу: /opt/geoserver/data_dir/raster-data/ecw/$fileName" -ForegroundColor White
    }
    catch {
        Write-Host "Ошибка при копировании файла: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Register-Projection {
    if (-not $FilePath) {
        Write-Host "Ошибка: не указан путь к файлу проекции." -ForegroundColor Red
        Write-Host "Используйте: ./scripts/manage-ecw.ps1 -Action register -FilePath <путь_к_файлу>" -ForegroundColor Yellow
        return
    }
    
    if (-not (Test-Path $FilePath)) {
        Write-Host "Ошибка: файл не найден: $FilePath" -ForegroundColor Red
        return
    }
    
    # Создание директории назначения, если она не существует
    if (-not (Test-Path $PROJ_DIR)) {
        New-Item -ItemType Directory -Force -Path $PROJ_DIR | Out-Null
        Write-Host "Создана директория: $PROJ_DIR" -ForegroundColor Green
    }
    
    # Копирование файла
    $fileName = [System.IO.Path]::GetFileName($FilePath)
    $destination = Join-Path $PROJ_DIR $fileName
    
    if (Test-Path $destination) {
        if (-not $Force) {
            Write-Host "Файл уже существует в директории назначения: $destination" -ForegroundColor Yellow
            $confirmation = Read-Host "Перезаписать? (y/n)"
            if ($confirmation -ne "y") {
                Write-Host "Операция отменена." -ForegroundColor Yellow
                return
            }
        }
        Write-Host "Файл будет перезаписан." -ForegroundColor Yellow
    }
    
    try {
        Copy-Item -Path $FilePath -Destination $destination -Force
        Write-Host "Файл проекции успешно скопирован в $destination" -ForegroundColor Green
        
        Write-Host "`nПерезапуск GeoServer для применения новой проекции..." -ForegroundColor Cyan
        docker-compose restart geoserver-vector geoserver-ecw
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "GeoServer успешно перезапущен. Новая проекция будет доступна в течение нескольких минут." -ForegroundColor Green
        }
        else {
            Write-Host "Ошибка при перезапуске GeoServer. Перезапустите его вручную с помощью команды: ./manage-gis.ps1 restart" -ForegroundColor Yellow
        }
        
        Write-Host "`nПосле перезапуска GeoServer проекция будет доступна при создании хранилищ данных." -ForegroundColor Cyan
    }
    catch {
        Write-Host "Ошибка при копировании файла: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Move-ECW {
    if (-not $FilePath) {
        Write-Host "Ошибка: не указан путь к ECW файлу." -ForegroundColor Red
        Write-Host "Используйте: ./scripts/manage-ecw.ps1 -Action move -FilePath <путь_к_файлу> -TargetPath <путь_назначения>" -ForegroundColor Yellow
        return
    }
    
    if (-not $TargetPath) {
        Write-Host "Ошибка: не указан путь назначения." -ForegroundColor Red
        Write-Host "Используйте: ./scripts/manage-ecw.ps1 -Action move -FilePath <путь_к_файлу> -TargetPath <путь_назначения>" -ForegroundColor Yellow
        return
    }
    
    if (-not (Test-Path $FilePath)) {
        Write-Host "Ошибка: файл не найден: $FilePath" -ForegroundColor Red
        return
    }
    
    # Создание директории назначения, если она не существует
    if (-not (Test-Path $TargetPath)) {
        New-Item -ItemType Directory -Force -Path $TargetPath | Out-Null
        Write-Host "Создана директория: $TargetPath" -ForegroundColor Green
    }
    
    # Перемещение файла
    $fileName = [System.IO.Path]::GetFileName($FilePath)
    $destination = Join-Path $TargetPath $fileName
    
    if (Test-Path $destination) {
        if (-not $Force) {
            Write-Host "Файл уже существует в директории назначения: $destination" -ForegroundColor Yellow
            $confirmation = Read-Host "Перезаписать? (y/n)"
            if ($confirmation -ne "y") {
                Write-Host "Операция отменена." -ForegroundColor Yellow
                return
            }
        }
        Write-Host "Файл будет перезаписан." -ForegroundColor Yellow
    }
    
    try {
        Move-Item -Path $FilePath -Destination $destination -Force
        Write-Host "Файл успешно перемещен в $destination" -ForegroundColor Green
        
        Write-Host "`nВнимание: Если файл был зарегистрирован в GeoServer, необходимо обновить путь к нему в настройках." -ForegroundColor Yellow
    }
    catch {
        Write-Host "Ошибка при перемещении файла: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Основная логика скрипта
switch ($Action) {
    "list" {
        List-Files
    }
    "import" {
        Import-ECW
    }
    "register" {
        Register-Projection
    }
    "move" {
        Move-ECW
    }
    "help" {
        Show-Help
    }
    default {
        Write-Host "Неизвестное действие: $Action" -ForegroundColor Red
        Show-Help
    }
} 