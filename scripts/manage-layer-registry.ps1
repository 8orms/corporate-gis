# manage-layer-registry.ps1
#
# Интерактивное управление реестром метаданных слоев для корпоративной ГИС-платформы
#
# Автор: Claude
# Дата: 27.02.2025

param (
    [Parameter(Mandatory=$false)]
    [ValidateSet("add", "edit", "remove", "list", "help")]
    [string]$Action = "help",
    
    [Parameter(Mandatory=$false)]
    [string]$LayerId,
    
    [Parameter(Mandatory=$false)]
    [string]$RegistryPath = "config/layer-registry.json"
)

# Функция для проверки наличия файла
function Test-FileExists {
    param([string]$Path)
    
    if (-not (Test-Path -Path $Path)) {
        Write-Error "Файл не найден: $Path"
        return $false
    }
    return $true
}

# Функция для создания файла, если он не существует
function Ensure-FileExists {
    param([string]$Path)
    
    $directory = Split-Path -Path $Path -Parent
    if (-not (Test-Path -Path $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
        Write-Host "Создана директория: $directory" -ForegroundColor Green
    }
    
    if (-not (Test-Path -Path $Path)) {
        # Создаем шаблон JSON
        $template = @{
            layers = @()
            objects = @()
            categories = @(
                @{id="topo"; name="Топография"; icon="map"}
                @{id="ortho"; name="Ортофотопланы"; icon="image"}
                @{id="geology"; name="Геология"; icon="terrain"}
                @{id="hydro"; name="Гидрология"; icon="water"}
                @{id="ecology"; name="Экология"; icon="eco"}
            )
        }
        
        $template | ConvertTo-Json -Depth 10 | Set-Content -Path $Path -Encoding UTF8
        Write-Host "Создан новый файл реестра метаданных: $Path" -ForegroundColor Green
    }
}

# Функция для чтения реестра метаданных
function Read-LayerRegistry {
    param([string]$Path)
    
    try {
        $content = Get-Content -Path $Path -Raw -Encoding UTF8
        $registry = ConvertFrom-Json $content
        return $registry
    }
    catch {
        Write-Error "Ошибка при чтении файла метаданных: $_"
        exit 1
    }
}

# Функция для сохранения реестра метаданных
function Save-LayerRegistry {
    param(
        [PSObject]$Registry,
        [string]$Path
    )
    
    try {
        $Registry | ConvertTo-Json -Depth 10 | Set-Content -Path $Path -Encoding UTF8
        Write-Host "Реестр успешно сохранен: $Path" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Ошибка при сохранении файла метаданных: $_"
        return $false
    }
}

# Функция для запроса ввода с валидацией и значением по умолчанию
function Read-ValidatedInput {
    param(
        [string]$Prompt,
        [string]$DefaultValue = "",
        [switch]$Required,
        [scriptblock]$Validator = { $true }
    )
    
    $promptText = $Prompt
    if (-not [string]::IsNullOrEmpty($DefaultValue)) {
        $promptText += " (по умолчанию: $DefaultValue)"
    }
    $promptText += ": "
    
    while ($true) {
        $input = Read-Host -Prompt $promptText
        
        # Если ввод пустой, используем значение по умолчанию
        if ([string]::IsNullOrWhiteSpace($input) -and -not [string]::IsNullOrEmpty($DefaultValue)) {
            $input = $DefaultValue
        }
        
        # Проверка на обязательное поле
        if ($Required -and [string]::IsNullOrWhiteSpace($input)) {
            Write-Host "Это обязательное поле. Пожалуйста, введите значение." -ForegroundColor Yellow
            continue
        }
        
        # Валидация ввода
        $valid = & $Validator $input
        if ($valid -eq $true) {
            return $input
        }
        else {
            Write-Host "Ввод не соответствует требованиям: $valid" -ForegroundColor Yellow
        }
    }
}

# Функция для запроса массива значений
function Read-ArrayInput {
    param(
        [string]$Prompt,
        [string[]]$DefaultValue = @(),
        [switch]$Required
    )
    
    $promptText = "$Prompt (разделяйте элементы запятыми)"
    if ($DefaultValue.Count -gt 0) {
        $promptText += " (по умолчанию: $($DefaultValue -join ", "))"
    }
    $promptText += ": "
    
    while ($true) {
        $input = Read-Host -Prompt $promptText
        
        # Если ввод пустой, используем значение по умолчанию
        if ([string]::IsNullOrWhiteSpace($input) -and $DefaultValue.Count -gt 0) {
            return $DefaultValue
        }
        
        # Проверка на обязательное поле
        if ($Required -and [string]::IsNullOrWhiteSpace($input)) {
            Write-Host "Это обязательное поле. Пожалуйста, введите значение." -ForegroundColor Yellow
            continue
        }
        
        # Разделяем ввод по запятым и обрезаем пробелы
        $array = $input -split ',' | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        
        if ($Required -and $array.Count -eq 0) {
            Write-Host "Необходимо ввести хотя бы один элемент." -ForegroundColor Yellow
            continue
        }
        
        return $array
    }
}

# Функция для запроса координат bbox
function Read-BboxInput {
    param(
        [string]$Prompt,
        [double[]]$DefaultValue = @()
    )
    
    $promptText = "$Prompt (формат: minX,minY,maxX,maxY)"
    if ($DefaultValue.Count -eq 4) {
        $promptText += " (по умолчанию: $($DefaultValue -join ", "))"
    }
    $promptText += ": "
    
    while ($true) {
        $input = Read-Host -Prompt $promptText
        
        # Если ввод пустой, используем значение по умолчанию
        if ([string]::IsNullOrWhiteSpace($input) -and $DefaultValue.Count -eq 4) {
            return $DefaultValue
        }
        
        # Разделяем ввод по запятым и обрезаем пробелы
        $coords = $input -split ',' | ForEach-Object { $_.Trim() }
        
        # Проверяем, что получили 4 координаты
        if ($coords.Count -ne 4) {
            Write-Host "Должно быть 4 координаты (minX,minY,maxX,maxY)." -ForegroundColor Yellow
            continue
        }
        
        # Проверяем, что все координаты - числа
        $valid = $true
        $parsed = @()
        foreach ($coord in $coords) {
            $number = 0
            if ([double]::TryParse($coord, [ref]$number)) {
                $parsed += $number
            }
            else {
                $valid = $false
                break
            }
        }
        
        if (-not $valid) {
            Write-Host "Координаты должны быть числами." -ForegroundColor Yellow
            continue
        }
        
        # Проверяем, что minX < maxX и minY < maxY
        if ($parsed[0] -ge $parsed[2] -or $parsed[1] -ge $parsed[3]) {
            Write-Host "Неверные координаты: minX должен быть меньше maxX, minY должен быть меньше maxY." -ForegroundColor Yellow
            continue
        }
        
        return $parsed
    }
}

# Функция для запроса boolean значения
function Read-BooleanInput {
    param(
        [string]$Prompt,
        [bool]$DefaultValue = $false
    )
    
    $defaultText = if ($DefaultValue) { "да" } else { "нет" }
    $promptText = "$Prompt (да/нет, по умолчанию: $defaultText): "
    
    while ($true) {
        $input = Read-Host -Prompt $promptText
        
        # Если ввод пустой, используем значение по умолчанию
        if ([string]::IsNullOrWhiteSpace($input)) {
            return $DefaultValue
        }
        
        switch ($input.ToLower()) {
            { $_ -in @("да", "д", "yes", "y", "true", "1") } { return $true }
            { $_ -in @("нет", "н", "no", "n", "false", "0") } { return $false }
            default {
                Write-Host "Пожалуйста, введите 'да' или 'нет'." -ForegroundColor Yellow
            }
        }
    }
}

# Функция для вывода списка слоев
function Show-Layers {
    param([PSObject]$Registry)
    
    $layers = $Registry.layers
    
    if ($layers.Count -eq 0) {
        Write-Host "В реестре нет слоев." -ForegroundColor Yellow
        return
    }
    
    Write-Host "Список слоев в реестре:" -ForegroundColor Cyan
    Write-Host "ID                 | Тип     | Объект  | Категория | Название" -ForegroundColor White
    Write-Host "--------------------|---------|---------|-----------|---------------------------------------" -ForegroundColor White
    
    foreach ($layer in $layers) {
        $layerId = $layer.id.PadRight(18)
        $layerType = $layer.type.PadRight(7)
        $objectId = $layer.objectId.PadRight(7)
        $category = $layer.category.PadRight(9)
        Write-Host "$layerId | $layerType | $objectId | $category | $($layer.title)" -ForegroundColor Gray
    }
}

# Функция для вывода списка объектов
function Show-Objects {
    param([PSObject]$Registry)
    
    $objects = $Registry.objects
    
    if ($objects.Count -eq 0) {
        Write-Host "В реестре нет объектов." -ForegroundColor Yellow
        return
    }
    
    Write-Host "`nСписок объектов:" -ForegroundColor Cyan
    Write-Host "ID      | Название" -ForegroundColor White
    Write-Host "--------|------------------------------------------" -ForegroundColor White
    
    foreach ($obj in $objects) {
        $objId = $obj.id.PadRight(6)
        Write-Host "$objId | $($obj.name)" -ForegroundColor Gray
    }
}

# Функция для вывода списка категорий
function Show-Categories {
    param([PSObject]$Registry)
    
    $categories = $Registry.categories
    
    if ($categories.Count -eq 0) {
        Write-Host "В реестре нет категорий." -ForegroundColor Yellow
        return
    }
    
    Write-Host "`nСписок категорий:" -ForegroundColor Cyan
    Write-Host "ID      | Название        | Иконка" -ForegroundColor White
    Write-Host "--------|-----------------|--------" -ForegroundColor White
    
    foreach ($cat in $categories) {
        $catId = $cat.id.PadRight(6)
        $catName = $cat.name.PadRight(16)
        Write-Host "$catId | $catName | $($cat.icon)" -ForegroundColor Gray
    }
}

# Функция для добавления нового слоя
function Add-Layer {
    param([PSObject]$Registry)
    
    Write-Host "`n=== Добавление нового слоя ===" -ForegroundColor Cyan
    
    # Показываем существующие объекты и категории
    Show-Objects -Registry $Registry
    Show-Categories -Registry $Registry
    
    # Основная информация о слое
    $layerId = Read-ValidatedInput -Prompt "`nID слоя (например, obj1-topo-2023)" -Required -Validator {
        param($id)
        if ($Registry.layers | Where-Object { $_.id -eq $id }) {
            return "Слой с ID '$id' уже существует"
        }
        if ($id -notmatch '^[a-zA-Z0-9_-]+$') {
            return "ID должен содержать только латинские буквы, цифры, дефис и подчеркивание"
        }
        return $true
    }
    
    $layerType = Read-ValidatedInput -Prompt "Тип слоя" -DefaultValue "raster" -Validator {
        param($type)
        if ($type -notin @("raster", "vector")) {
            return "Тип должен быть 'raster' или 'vector'"
        }
        return $true
    }
    
    $title = Read-ValidatedInput -Prompt "Название слоя" -Required
    
    # Проверяем, существует ли объект
    $objectId = Read-ValidatedInput -Prompt "ID объекта" -Required -Validator {
        param($id)
        if (-not ($Registry.objects | Where-Object { $_.id -eq $id })) {
            # Если объект не существует, спрашиваем, хочет ли пользователь создать его
            Write-Host "Объект с ID '$id' не найден в реестре." -ForegroundColor Yellow
            $create = Read-BooleanInput -Prompt "Создать новый объект?"
            if ($create) {
                $objName = Read-ValidatedInput -Prompt "Название объекта" -Required
                $bbox = Read-BboxInput -Prompt "Границы объекта" -DefaultValue @(37.0, 55.0, 38.0, 56.0)
                
                $Registry.objects += @{
                    id = $id
                    name = $objName
                    bbox = $bbox
                }
                
                Write-Host "Объект '$id' добавлен в реестр." -ForegroundColor Green
                return $true
            }
            else {
                return "Необходимо указать существующий ID объекта"
            }
        }
        return $true
    }
    
    # Проверяем, существует ли категория
    $category = Read-ValidatedInput -Prompt "ID категории" -Required -Validator {
        param($id)
        if (-not ($Registry.categories | Where-Object { $_.id -eq $id })) {
            # Если категория не существует, спрашиваем, хочет ли пользователь создать её
            Write-Host "Категория с ID '$id' не найдена в реестре." -ForegroundColor Yellow
            $create = Read-BooleanInput -Prompt "Создать новую категорию?"
            if ($create) {
                $catName = Read-ValidatedInput -Prompt "Название категории" -Required
                $icon = Read-ValidatedInput -Prompt "Иконка категории" -DefaultValue "map"
                
                $Registry.categories += @{
                    id = $id
                    name = $catName
                    icon = $icon
                }
                
                Write-Host "Категория '$id' добавлена в реестр." -ForegroundColor Green
                return $true
            }
            else {
                return "Необходимо указать существующий ID категории"
            }
        }
        return $true
    }
    
    # Информация о слое зависит от его типа
    $workspace = Read-ValidatedInput -Prompt "Workspace в GeoServer" -Required
    $layerName = Read-ValidatedInput -Prompt "Имя слоя в GeoServer" -Required
    $instance = Read-ValidatedInput -Prompt "Инстанс GeoServer" -DefaultValue $(if ($layerType -eq "raster") { "ecw" } else { "vector" })
    $year = Read-ValidatedInput -Prompt "Год данных"
    $visible = Read-BooleanInput -Prompt "Видимость слоя по умолчанию" -DefaultValue $false
    $tags = Read-ArrayInput -Prompt "Теги (через запятую)"
    
    # Специфичные поля в зависимости от типа слоя
    $layer = @{
        id = $layerId
        type = $layerType
        title = $title
        workspace = $workspace
        layerName = $layerName
        instance = $instance
        objectId = $objectId
        category = $category
        year = $year
        visible = $visible
        tags = $tags
    }
    
    if ($layerType -eq "raster") {
        $filePath = Read-ValidatedInput -Prompt "Путь к файлу ECW в контейнере GeoServer" -DefaultValue "/opt/geoserver/data_dir/raster-data/ecw/$objectId/$layerName.ecw"
        $layer.filePath = $filePath
    }
    elseif ($layerType -eq "vector") {
        $dataStore = Read-ValidatedInput -Prompt "Data Store" -DefaultValue "postgis"
        $tableName = Read-ValidatedInput -Prompt "Имя таблицы в PostGIS" -DefaultValue "$category.${objectId}_${layerName}"
        $layer.dataStore = $dataStore
        $layer.tableName = $tableName
    }
    
    # Добавляем слой в реестр
    $Registry.layers += $layer
    
    Write-Host "`nСлой '$layerId' успешно добавлен в реестр." -ForegroundColor Green
    
    return $Registry
}

# Функция для редактирования существующего слоя
function Edit-Layer {
    param(
        [PSObject]$Registry,
        [string]$LayerId
    )
    
    # Находим слой по ID
    $layerIndex = 0
    $layer = $null
    for ($i = 0; $i -lt $Registry.layers.Count; $i++) {
        if ($Registry.layers[$i].id -eq $LayerId) {
            $layer = $Registry.layers[$i]
            $layerIndex = $i
            break
        }
    }
    
    if ($null -eq $layer) {
        Write-Host "Слой с ID '$LayerId' не найден." -ForegroundColor Red
        return $Registry
    }
    
    Write-Host "`n=== Редактирование слоя '$LayerId' ===" -ForegroundColor Cyan
    Write-Host "Оставьте поле пустым, чтобы сохранить текущее значение." -ForegroundColor Yellow
    
    # Показываем существующие объекты и категории
    Show-Objects -Registry $Registry
    Show-Categories -Registry $Registry
    
    # Основная информация о слое
    $title = Read-ValidatedInput -Prompt "Название слоя" -DefaultValue $layer.title
    
    $objectId = Read-ValidatedInput -Prompt "ID объекта" -DefaultValue $layer.objectId -Validator {
        param($id)
        if ([string]::IsNullOrWhiteSpace($id)) {
            return "Необходимо указать ID объекта"
        }
        if (-not ($Registry.objects | Where-Object { $_.id -eq $id })) {
            # Если объект не существует, спрашиваем, хочет ли пользователь создать его
            Write-Host "Объект с ID '$id' не найден в реестре." -ForegroundColor Yellow
            $create = Read-BooleanInput -Prompt "Создать новый объект?"
            if ($create) {
                $objName = Read-ValidatedInput -Prompt "Название объекта" -Required
                $bbox = Read-BboxInput -Prompt "Границы объекта" -DefaultValue @(37.0, 55.0, 38.0, 56.0)
                
                $Registry.objects += @{
                    id = $id
                    name = $objName
                    bbox = $bbox
                }
                
                Write-Host "Объект '$id' добавлен в реестр." -ForegroundColor Green
                return $true
            }
            else {
                return "Необходимо указать существующий ID объекта"
            }
        }
        return $true
    }
    
    $category = Read-ValidatedInput -Prompt "ID категории" -DefaultValue $layer.category -Validator {
        param($id)
        if ([string]::IsNullOrWhiteSpace($id)) {
            return "Необходимо указать ID категории"
        }
        if (-not ($Registry.categories | Where-Object { $_.id -eq $id })) {
            # Если категория не существует, спрашиваем, хочет ли пользователь создать её
            Write-Host "Категория с ID '$id' не найдена в реестре." -ForegroundColor Yellow
            $create = Read-BooleanInput -Prompt "Создать новую категорию?"
            if ($create) {
                $catName = Read-ValidatedInput -Prompt "Название категории" -Required
                $icon = Read-ValidatedInput -Prompt "Иконка категории" -DefaultValue "map"
                
                $Registry.categories += @{
                    id = $id
                    name = $catName
                    icon = $icon
                }
                
                Write-Host "Категория '$id' добавлена в реестр." -ForegroundColor Green
                return $true
            }
            else {
                return "Необходимо указать существующий ID категории"
            }
        }
        return $true
    }
    
    $workspace = Read-ValidatedInput -Prompt "Workspace в GeoServer" -DefaultValue $layer.workspace
    $layerName = Read-ValidatedInput -Prompt "Имя слоя в GeoServer" -DefaultValue $layer.layerName
    $instance = Read-ValidatedInput -Prompt "Инстанс GeoServer" -DefaultValue $layer.instance
    $year = Read-ValidatedInput -Prompt "Год данных" -DefaultValue $layer.year
    $visible = Read-BooleanInput -Prompt "Видимость слоя по умолчанию" -DefaultValue $layer.visible
    $tags = Read-ArrayInput -Prompt "Теги (через запятую)" -DefaultValue $layer.tags
    
    # Обновляем слой
    $layer.title = $title
    $layer.objectId = $objectId
    $layer.category = $category
    $layer.workspace = $workspace
    $layer.layerName = $layerName
    $layer.instance = $instance
    $layer.year = $year
    $layer.visible = $visible
    $layer.tags = $tags
    
    # Обновляем специфичные поля в зависимости от типа слоя
    if ($layer.type -eq "raster") {
        $filePath = Read-ValidatedInput -Prompt "Путь к файлу ECW в контейнере GeoServer" -DefaultValue $layer.filePath
        $layer.filePath = $filePath
    }
    elseif ($layer.type -eq "vector") {
        $dataStore = Read-ValidatedInput -Prompt "Data Store" -DefaultValue $layer.dataStore
        $tableName = Read-ValidatedInput -Prompt "Имя таблицы в PostGIS" -DefaultValue $layer.tableName
        $layer.dataStore = $dataStore
        $layer.tableName = $tableName
    }
    
    # Обновляем слой в реестре
    $Registry.layers[$layerIndex] = $layer
    
    Write-Host "`nСлой '$LayerId' успешно обновлен в реестре." -ForegroundColor Green
    
    return $Registry
}

# Функция для удаления слоя
function Remove-LayerFromRegistry {
    param(
        [PSObject]$Registry,
        [string]$LayerId
    )
    
    # Находим слой по ID
    $layer = $Registry.layers | Where-Object { $_.id -eq $LayerId }
    
    if ($null -eq $layer) {
        Write-Host "Слой с ID '$LayerId' не найден." -ForegroundColor Red
        return $Registry
    }
    
    Write-Host "`n=== Удаление слоя '$LayerId' ===" -ForegroundColor Cyan
    Write-Host "Название: $($layer.title)" -ForegroundColor White
    Write-Host "Тип: $($layer.type)" -ForegroundColor White
    Write-Host "Объект: $($layer.objectId)" -ForegroundColor White
    Write-Host "Категория: $($layer.category)" -ForegroundColor White
    
    $confirm = Read-BooleanInput -Prompt "Вы уверены, что хотите удалить этот слой?" -DefaultValue $false
    
    if ($confirm) {
        # Удаляем слой
        $Registry.layers = $Registry.layers | Where-Object { $_.id -ne $LayerId }
        Write-Host "Слой '$LayerId' успешно удален из реестра." -ForegroundColor Green
    }
    else {
        Write-Host "Удаление отменено." -ForegroundColor Yellow
    }
    
    return $Registry
}

# Функция для отображения справки
function Show-Help {
    Write-Host "Интерактивное управление реестром метаданных слоев" -ForegroundColor Cyan
    Write-Host "Использование: .\scripts\manage-layer-registry.ps1 [Action] [LayerId] [RegistryPath]" -ForegroundColor White
    Write-Host ""
    Write-Host "Actions:" -ForegroundColor Cyan
    Write-Host "  add    - Добавление нового слоя"
    Write-Host "  edit   - Редактирование существующего слоя (требуется LayerId)"
    Write-Host "  remove - Удаление слоя (требуется LayerId)"
    Write-Host "  list   - Отображение списка слоев"
    Write-Host "  help   - Отображение этой справки"
    Write-Host ""
    Write-Host "Примеры:" -ForegroundColor Cyan
    Write-Host "  .\scripts\manage-layer-registry.ps1 add"
    Write-Host "  .\scripts\manage-layer-registry.ps1 edit obj1-topo-2023"
    Write-Host "  .\scripts\manage-layer-registry.ps1 remove obj1-topo-2023"
    Write-Host "  .\scripts\manage-layer-registry.ps1 list"
    Write-Host "  .\scripts\manage-layer-registry.ps1 add -RegistryPath ""path/to/registry.json"""
}

# Функция для автоматической генерации JavaScript после изменения реестра
function Generate-LayerJs {
    param(
        [string]$MetadataPath,
        [string]$JsOutputPath = "src/web-interface/js/generated-layers.js"
    )
    
    # Проверяем существование скрипта генерации
    $scriptPath = "scripts/generate-layer-config.ps1"
    if (-not (Test-Path $scriptPath)) {
        Write-Host "Скрипт генерации конфигурации не найден: $scriptPath" -ForegroundColor Yellow
        return
    }
    
    $generate = Read-BooleanInput -Prompt "Сгенерировать JavaScript конфигурацию из обновленного реестра?" -DefaultValue $true
    
    if ($generate) {
        Write-Host "`nГенерация JavaScript конфигурации..." -ForegroundColor Cyan
        & $scriptPath -MetadataPath $MetadataPath -OutputJsPath $JsOutputPath
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "JavaScript конфигурация успешно сгенерирована: $JsOutputPath" -ForegroundColor Green
        }
        else {
            Write-Host "Ошибка при генерации JavaScript конфигурации." -ForegroundColor Red
        }
    }
}

# Главная логика скрипта
# Проверяем и создаем файл реестра, если он не существует
Ensure-FileExists -Path $RegistryPath

# Проверяем наличие файла
if (-not (Test-FileExists -Path $RegistryPath)) {
    exit 1
}

# Читаем реестр
$registry = Read-LayerRegistry -Path $RegistryPath
$modified = $false

# Выполняем действие
switch ($Action) {
    "add" {
        $registry = Add-Layer -Registry $registry
        $modified = $true
    }
    "edit" {
        if ([string]::IsNullOrWhiteSpace($LayerId)) {
            Write-Host "Для редактирования необходимо указать LayerId." -ForegroundColor Red
            Show-Layers -Registry $registry
            $LayerId = Read-ValidatedInput -Prompt "`nВведите ID слоя для редактирования" -Required -Validator {
                param($id)
                if (-not ($registry.layers | Where-Object { $_.id -eq $id })) {
                    return "Слой с ID '$id' не найден"
                }
                return $true
            }
        }
        
        $registry = Edit-Layer -Registry $registry -LayerId $LayerId
        $modified = $true
    }
    "remove" {
        if ([string]::IsNullOrWhiteSpace($LayerId)) {
            Write-Host "Для удаления необходимо указать LayerId." -ForegroundColor Red
            Show-Layers -Registry $registry
            $LayerId = Read-ValidatedInput -Prompt "`nВведите ID слоя для удаления" -Required -Validator {
                param($id)
                if (-not ($registry.layers | Where-Object { $_.id -eq $id })) {
                    return "Слой с ID '$id' не найден"
                }
                return $true
            }
        }
        
        $registry = Remove-LayerFromRegistry -Registry $registry -LayerId $LayerId
        $modified = $true
    }
    "list" {
        Show-Layers -Registry $registry
        Show-Objects -Registry $registry
        Show-Categories -Registry $registry
    }
    "help" {
        Show-Help
    }
}

# Если были изменения, сохраняем реестр
if ($modified) {
    $saved = Save-LayerRegistry -Registry $registry -Path $RegistryPath
    
    if ($saved) {
        # Генерируем JavaScript конфигурацию
        Generate-LayerJs -MetadataPath $RegistryPath
    }
} 