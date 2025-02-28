# generate-layer-config.ps1
#
# Скрипт для генерации конфигурации слоев на основе реестра метаданных
# 
# Использование: 
#   ./scripts/generate-layer-config.ps1 -MetadataPath "config/layer-registry.json" -OutputJsPath "src/web-interface/js/generated-layers.js"
#
# Автор: Claude
# Дата: 26.02.2025

param(
    [Parameter(Mandatory=$true)]
    [string]$MetadataPath,
    
    [Parameter(Mandatory=$true)]
    [string]$OutputJsPath
)

# Функция для проверки наличия файла
function Test-FileExists {
    param([string]$Path)
    
    if (-not (Test-Path -Path $Path)) {
        Write-Error "Файл не найден: $Path"
        exit 1
    }
}

# Функция для создания директории, если она не существует
function Ensure-DirectoryExists {
    param([string]$Path)
    
    $directory = Split-Path -Path $Path -Parent
    if (-not (Test-Path -Path $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
        Write-Host "Создана директория: $directory"
    }
}

# Проверка наличия файла метаданных
Test-FileExists -Path $MetadataPath

# Чтение JSON файла с метаданными
try {
    $metadata = Get-Content -Path $MetadataPath -Raw | ConvertFrom-Json
    Write-Host "Метаданные успешно загружены из $MetadataPath"
}
catch {
    Write-Error "Ошибка при чтении файла метаданных: $_"
    exit 1
}

# Создание директории для выходного файла, если она не существует
Ensure-DirectoryExists -Path $OutputJsPath

# Генерация JavaScript кода для слоев
$jsContent = @"
/**
 * АВТОМАТИЧЕСКИ СГЕНЕРИРОВАННЫЙ ФАЙЛ
 * Создан: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
 * 
 * НЕ РЕДАКТИРУЙТЕ ЭТОТ ФАЙЛ ВРУЧНУЮ!
 * Для изменения конфигурации слоев отредактируйте файл $MetadataPath
 * и запустите скрипт generate-layer-config.ps1
 */

// Конфигурация слоев
const layerConfig = {
    // Растровые слои
    rasterLayers: [
"@

# Добавление растровых слоев
$rasterLayers = $metadata.layers | Where-Object { $_.type -eq "raster" }
foreach ($layer in $rasterLayers) {
    $jsContent += @"
        {
            id: "$($layer.id)",
            title: "$($layer.title)",
            workspace: "$($layer.workspace)",
            layerName: "$($layer.layerName)",
            instance: "$($layer.instance)",
            objectId: "$($layer.objectId)",
            category: "$($layer.category)",
            year: "$($layer.year)",
            visible: $($layer.visible.ToString().ToLower()),
            tags: [$(($layer.tags | ForEach-Object { "`"$_`"" }) -join ", ")]
        },
"@
}

# Удаление последней запятой для растровых слоев
if ($rasterLayers.Count -gt 0) {
    $jsContent = $jsContent.TrimEnd(",`r`n")
}

$jsContent += @"

    ],
    
    // Векторные слои
    vectorLayers: [
"@

# Добавление векторных слоев
$vectorLayers = $metadata.layers | Where-Object { $_.type -eq "vector" }
foreach ($layer in $vectorLayers) {
    $jsContent += @"
        {
            id: "$($layer.id)",
            title: "$($layer.title)",
            workspace: "$($layer.workspace)",
            layerName: "$($layer.layerName)",
            instance: "$($layer.instance)",
            objectId: "$($layer.objectId)",
            category: "$($layer.category)",
            year: "$($layer.year)",
            dataStore: "$($layer.dataStore)",
            tableName: "$($layer.tableName)",
            visible: $($layer.visible.ToString().ToLower()),
            tags: [$(($layer.tags | ForEach-Object { "`"$_`"" }) -join ", ")]
        },
"@
}

# Удаление последней запятой для векторных слоев
if ($vectorLayers.Count -gt 0) {
    $jsContent = $jsContent.TrimEnd(",`r`n")
}

$jsContent += @"

    ],
    
    // Объекты
    objects: [
"@

# Добавление объектов
foreach ($obj in $metadata.objects) {
    $jsContent += @"
        {
            id: "$($obj.id)",
            name: "$($obj.name)",
            bbox: [$($obj.bbox -join ", ")]
        },
"@
}

# Удаление последней запятой для объектов
if ($metadata.objects.Count -gt 0) {
    $jsContent = $jsContent.TrimEnd(",`r`n")
}

$jsContent += @"

    ],
    
    // Категории
    categories: [
"@

# Добавление категорий
foreach ($category in $metadata.categories) {
    $jsContent += @"
        {
            id: "$($category.id)",
            name: "$($category.name)",
            icon: "$($category.icon)"
        },
"@
}

# Удаление последней запятой для категорий
if ($metadata.categories.Count -gt 0) {
    $jsContent = $jsContent.TrimEnd(",`r`n")
}

$jsContent += @"

    ]
};

// Вспомогательные функции для работы с конфигурацией
const LayerUtils = {
    /**
     * Получить все слои для конкретного объекта
     * @param {string} objectId - ID объекта
     * @returns {Array} - Массив слоев
     */
    getLayersByObject: function(objectId) {
        const result = [];
        result.push(...layerConfig.rasterLayers.filter(layer => layer.objectId === objectId));
        result.push(...layerConfig.vectorLayers.filter(layer => layer.objectId === objectId));
        return result;
    },
    
    /**
     * Получить все слои по категории
     * @param {string} categoryId - ID категории
     * @returns {Array} - Массив слоев
     */
    getLayersByCategory: function(categoryId) {
        const result = [];
        result.push(...layerConfig.rasterLayers.filter(layer => layer.category === categoryId));
        result.push(...layerConfig.vectorLayers.filter(layer => layer.category === categoryId));
        return result;
    },
    
    /**
     * Получить слой по ID
     * @param {string} layerId - ID слоя
     * @returns {Object|null} - Объект слоя или null
     */
    getLayerById: function(layerId) {
        let layer = layerConfig.rasterLayers.find(layer => layer.id === layerId);
        if (!layer) {
            layer = layerConfig.vectorLayers.find(layer => layer.id === layerId);
        }
        return layer || null;
    },
    
    /**
     * Получить объект по ID
     * @param {string} objectId - ID объекта
     * @returns {Object|null} - Объект или null
     */
    getObjectById: function(objectId) {
        return layerConfig.objects.find(obj => obj.id === objectId) || null;
    },
    
    /**
     * Получить категорию по ID
     * @param {string} categoryId - ID категории
     * @returns {Object|null} - Категория или null
     */
    getCategoryById: function(categoryId) {
        return layerConfig.categories.find(cat => cat.id === categoryId) || null;
    }
};

// Экспорт конфигурации и утилит
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { layerConfig, LayerUtils };
}
"@

# Запись JavaScript кода в файл
try {
    $jsContent | Out-File -FilePath $OutputJsPath -Encoding utf8
    Write-Host "Конфигурация слоев успешно сгенерирована в файл $OutputJsPath"
}
catch {
    Write-Error "Ошибка при записи файла: $_"
    exit 1
} 