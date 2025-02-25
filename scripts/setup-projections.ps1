# Скрипт для настройки пользовательских проекций
param(
    [switch]$Force
)

Write-Host "Настройка пользовательских проекций для GeoServer..." -ForegroundColor Cyan

# Константы
$USER_PROJ_DIR = "data/user-projections"
$EPSG_PROPERTIES = "$USER_PROJ_DIR/epsg.properties"

# Создание директории, если она не существует
if (-not (Test-Path $USER_PROJ_DIR)) {
    Write-Host "Создание директории для пользовательских проекций: $USER_PROJ_DIR" -ForegroundColor Green
    New-Item -ItemType Directory -Force -Path $USER_PROJ_DIR | Out-Null
}
else {
    Write-Host "Директория пользовательских проекций уже существует: $USER_PROJ_DIR" -ForegroundColor Yellow
}

# Проверка наличия epsg.properties и создание пустого файла, если его нет
if (-not (Test-Path $EPSG_PROPERTIES) -or $Force) {
    Write-Host "Создание пустого файла epsg.properties..." -ForegroundColor Green
    
    # Базовое содержимое файла epsg.properties
    $epsgContent = @"
# Пользовательские определения проекций для GeoServer
# Формат: <код EPSG>=<определение_проекции>
# Пример: 
# 54004=PROJCS["World_Mercator", GEOGCS["GCS_WGS_1984", DATUM["D_WGS_1984", SPHEROID["WGS_1984", 6378137.0, 298.257223563]], PRIMEM["Greenwich", 0.0], UNIT["Degree", 0.0174532925199433]], PROJECTION["Mercator"], PARAMETER["False_Easting", 0.0], PARAMETER["False_Northing", 0.0], PARAMETER["Central_Meridian", 0.0], PARAMETER["Standard_Parallel_1", 0.0], UNIT["Meter", 1.0]]

# Добавляйте ваши определения проекций ниже:

"@
    
    # Запись в файл
    Set-Content -Path $EPSG_PROPERTIES -Value $epsgContent
    Write-Host "Файл epsg.properties создан: $EPSG_PROPERTIES" -ForegroundColor Green
}
else {
    Write-Host "Файл epsg.properties уже существует: $EPSG_PROPERTIES" -ForegroundColor Yellow
}

Write-Host "`nНастройка пользовательских проекций завершена." -ForegroundColor Cyan
Write-Host "Для добавления пользовательских проекций, отредактируйте файл: $EPSG_PROPERTIES" -ForegroundColor White
Write-Host "Или поместите файлы .prj в директорию: $USER_PROJ_DIR" -ForegroundColor White
Write-Host "`nПосле изменения файлов проекций требуется перезапуск GeoServer:" -ForegroundColor Yellow
Write-Host "  ./manage-gis.ps1 restart" -ForegroundColor White 