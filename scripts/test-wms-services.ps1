# test-wms-services.ps1
# Скрипт для тестирования WMS-сервисов обеих инстанций GeoServer и отображения примеров карт
# Автор: Corporate GIS Team
# Дата: 27.02.2025

param (
    [string]$BaseUrl = "http://localhost",
    [string]$OutputDir = ".\wms-test-results",
    [switch]$OpenResults,
    [switch]$GenerateHtml
)

# Функция для вывода сообщений с цветовой кодировкой
function Write-ColorMessage {
    param (
        [string]$Message,
        [string]$Color = "White",
        [switch]$NoNewLine
    )
    
    if ($NoNewLine) {
        Write-Host $Message -ForegroundColor $Color -NoNewline
    } else {
        Write-Host $Message -ForegroundColor $Color
    }
}

# Функция для проверки доступности URL
function Test-Url {
    param (
        [string]$Url,
        [string]$Description
    )
    
    Write-ColorMessage "Проверка $Description... " -Color Cyan -NoNewLine
    
    try {
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -Method Head -ErrorAction Stop
        
        # Проверка статуса ответа
        if ($response.StatusCode -eq 200) {
            Write-ColorMessage "OK (200)" -Color Green
            return $true
        } else {
            Write-ColorMessage "Ошибка ($($response.StatusCode))" -Color Red
            return $false
        }
    } catch {
        Write-ColorMessage "Ошибка: $_" -Color Red
        return $false
    }
}

# Функция для получения списка слоев из GetCapabilities
function Get-WmsLayers {
    param (
        [string]$Url,
        [string]$Instance
    )
    
    $wmsUrl = "$Url/geoserver/$Instance/wms?service=WMS&version=1.1.0&request=GetCapabilities"
    Write-ColorMessage "Получение списка слоев из $Instance GeoServer... " -Color Cyan -NoNewLine
    
    try {
        $response = Invoke-WebRequest -Uri $wmsUrl -UseBasicParsing -ErrorAction Stop
        
        # Проверка статуса ответа
        if ($response.StatusCode -eq 200) {
            Write-ColorMessage "OK" -Color Green
            
            # Сохранение XML ответа во временный файл
            $tempFile = [System.IO.Path]::GetTempFileName()
            Set-Content -Path $tempFile -Value $response.Content
            
            # Загрузка XML
            [xml]$xml = Get-Content -Path $tempFile
            
            # Получение списка слоев
            $layers = @()
            $layerNodes = $xml.SelectNodes("//Layer[Name]")
            
            foreach ($layerNode in $layerNodes) {
                $nameNode = $layerNode.SelectSingleNode("Name")
                $titleNode = $layerNode.SelectSingleNode("Title")
                
                if ($nameNode -and $nameNode.InnerText -and -not $nameNode.InnerText.Contains("workspace:")) {
                    $layer = @{
                        Name = $nameNode.InnerText
                        Title = if ($titleNode) { $titleNode.InnerText } else { $nameNode.InnerText }
                    }
                    $layers += $layer
                }
            }
            
            # Удаление временного файла
            Remove-Item -Path $tempFile -Force
            
            return $layers
        } else {
            Write-ColorMessage "Ошибка ($($response.StatusCode))" -Color Red
            return @()
        }
    } catch {
        Write-ColorMessage "Ошибка: $_" -Color Red
        return @()
    }
}

# Функция для получения изображения карты через WMS
function Get-WmsMap {
    param (
        [string]$Url,
        [string]$Instance,
        [string]$Layer,
        [string]$OutputPath,
        [int]$Width = 800,
        [int]$Height = 600,
        [string]$Format = "image/png",
        [string]$Bbox = "-180,-90,180,90"
    )
    
    $wmsUrl = "$Url/geoserver/$Instance/wms?service=WMS&version=1.1.0&request=GetMap&layers=$Layer&styles=&bbox=$Bbox&width=$Width&height=$Height&srs=EPSG:4326&format=$Format"
    Write-ColorMessage "Получение карты для слоя $Layer из $Instance GeoServer... " -Color Cyan -NoNewLine
    
    try {
        Invoke-WebRequest -Uri $wmsUrl -OutFile $OutputPath -ErrorAction Stop
        
        if (Test-Path $OutputPath) {
            $fileSize = (Get-Item $OutputPath).Length
            if ($fileSize -gt 0) {
                Write-ColorMessage "OK (сохранено в $OutputPath, размер: $([math]::Round($fileSize/1KB, 2)) KB)" -Color Green
                return $true
            } else {
                Write-ColorMessage "Ошибка (файл пустой)" -Color Red
                Remove-Item -Path $OutputPath -Force
                return $false
            }
        } else {
            Write-ColorMessage "Ошибка (файл не создан)" -Color Red
            return $false
        }
    } catch {
        Write-ColorMessage "Ошибка: $_" -Color Red
        return $false
    }
}

# Функция для создания HTML-отчета
function Create-HtmlReport {
    param (
        [string]$OutputDir,
        [array]$VectorResults,
        [array]$EcwResults,
        [string]$BaseUrl
    )
    
    $htmlPath = Join-Path -Path $OutputDir -ChildPath "wms-test-report.html"
    Write-ColorMessage "Создание HTML-отчета... " -Color Cyan -NoNewLine
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    $html = @"
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Отчет о тестировании WMS-сервисов GeoServer</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            margin: 0;
            padding: 20px;
            color: #333;
        }
        h1 {
            color: #2c3e50;
            border-bottom: 2px solid #3498db;
            padding-bottom: 10px;
        }
        h2 {
            color: #2980b9;
            margin-top: 30px;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        .info-box {
            background-color: #f8f9fa;
            border-left: 4px solid #3498db;
            padding: 15px;
            margin-bottom: 20px;
        }
        .gallery {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
            gap: 20px;
            margin-top: 20px;
        }
        .map-item {
            border: 1px solid #ddd;
            border-radius: 5px;
            overflow: hidden;
            box-shadow: 0 2px 5px rgba(0,0,0,0.1);
        }
        .map-item img {
            width: 100%;
            height: 225px;
            object-fit: cover;
            display: block;
        }
        .map-info {
            padding: 10px;
            background-color: #f8f9fa;
        }
        .map-title {
            font-weight: bold;
            margin-bottom: 5px;
        }
        .map-layer {
            font-size: 0.9em;
            color: #666;
        }
        .vector-section {
            border-top: 3px solid #27ae60;
            padding-top: 10px;
        }
        .ecw-section {
            border-top: 3px solid #e74c3c;
            padding-top: 10px;
        }
        .footer {
            margin-top: 40px;
            padding-top: 20px;
            border-top: 1px solid #ddd;
            text-align: center;
            font-size: 0.9em;
            color: #777;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Отчет о тестировании WMS-сервисов GeoServer</h1>
        
        <div class="info-box">
            <p><strong>Дата и время:</strong> $timestamp</p>
            <p><strong>Базовый URL:</strong> $BaseUrl</p>
            <p><strong>Количество протестированных слоев Vector GeoServer:</strong> $($VectorResults.Count)</p>
            <p><strong>Количество протестированных слоев ECW GeoServer:</strong> $($EcwResults.Count)</p>
        </div>
        
        <h2 class="vector-section">Слои Vector GeoServer</h2>
        <div class="gallery">
"@

    foreach ($result in $VectorResults) {
        $relativePath = $result.ImagePath -replace [regex]::Escape($OutputDir), ""
        $relativePath = $relativePath.TrimStart("\")
        
        $html += @"
            <div class="map-item">
                <img src="$relativePath" alt="$($result.Title)">
                <div class="map-info">
                    <div class="map-title">$($result.Title)</div>
                    <div class="map-layer">Слой: $($result.Layer)</div>
                </div>
            </div>
"@
    }

    $html += @"
        </div>
        
        <h2 class="ecw-section">Слои ECW GeoServer</h2>
        <div class="gallery">
"@

    foreach ($result in $EcwResults) {
        $relativePath = $result.ImagePath -replace [regex]::Escape($OutputDir), ""
        $relativePath = $relativePath.TrimStart("\")
        
        $html += @"
            <div class="map-item">
                <img src="$relativePath" alt="$($result.Title)">
                <div class="map-info">
                    <div class="map-title">$($result.Title)</div>
                    <div class="map-layer">Слой: $($result.Layer)</div>
                </div>
            </div>
"@
    }

    $html += @"
        </div>
        
        <div class="footer">
            <p>Сгенерировано скриптом test-wms-services.ps1 | Corporate GIS Platform</p>
        </div>
    </div>
</body>
</html>
"@

    Set-Content -Path $htmlPath -Value $html
    
    if (Test-Path $htmlPath) {
        Write-ColorMessage "OK (сохранено в $htmlPath)" -Color Green
        return $htmlPath
    } else {
        Write-ColorMessage "Ошибка (файл не создан)" -Color Red
        return $null
    }
}

# Основная функция тестирования WMS-сервисов
function Test-WmsServices {
    Write-ColorMessage "=== Тестирование WMS-сервисов GeoServer ===" -Color Magenta
    Write-ColorMessage "Базовый URL: $BaseUrl" -Color Yellow
    Write-ColorMessage "Выходной каталог: $OutputDir" -Color Yellow
    Write-ColorMessage "Дата и время: $(Get-Date)" -Color Yellow
    Write-ColorMessage "=======================================" -Color Magenta
    
    # Проверка и создание выходного каталога
    if (-not (Test-Path $OutputDir)) {
        Write-ColorMessage "Создание выходного каталога $OutputDir..." -Color Cyan
        New-Item -Path $OutputDir -ItemType Directory -Force | Out-Null
    }
    
    # Создание подкаталогов для каждой инстанции
    $vectorDir = Join-Path -Path $OutputDir -ChildPath "vector"
    $ecwDir = Join-Path -Path $OutputDir -ChildPath "ecw"
    
    if (-not (Test-Path $vectorDir)) {
        New-Item -Path $vectorDir -ItemType Directory -Force | Out-Null
    }
    
    if (-not (Test-Path $ecwDir)) {
        New-Item -Path $ecwDir -ItemType Directory -Force | Out-Null
    }
    
    # Проверка доступности WMS-сервисов
    $vectorWmsOk = Test-Url -Url "$BaseUrl/geoserver/vector/wms?service=WMS&version=1.1.0&request=GetCapabilities" -Description "WMS Vector GeoServer"
    $ecwWmsOk = Test-Url -Url "$BaseUrl/geoserver/ecw/wms?service=WMS&version=1.1.0&request=GetCapabilities" -Description "WMS ECW GeoServer"
    
    $vectorResults = @()
    $ecwResults = @()
    
    # Тестирование Vector GeoServer
    if ($vectorWmsOk) {
        Write-ColorMessage "`nТестирование слоев Vector GeoServer:" -Color Magenta
        
        $vectorLayers = Get-WmsLayers -Url $BaseUrl -Instance "vector"
        
        if ($vectorLayers.Count -gt 0) {
            Write-ColorMessage "Найдено $($vectorLayers.Count) слоев в Vector GeoServer" -Color Green
            
            # Ограничение количества тестируемых слоев (не более 10)
            $layersToTest = if ($vectorLayers.Count -gt 10) { $vectorLayers[0..9] } else { $vectorLayers }
            
            foreach ($layer in $layersToTest) {
                $outputPath = Join-Path -Path $vectorDir -ChildPath "$($layer.Name).png"
                $success = Get-WmsMap -Url $BaseUrl -Instance "vector" -Layer $layer.Name -OutputPath $outputPath
                
                if ($success) {
                    $vectorResults += @{
                        Layer = $layer.Name
                        Title = $layer.Title
                        ImagePath = $outputPath
                    }
                }
            }
        } else {
            Write-ColorMessage "Не найдено слоев в Vector GeoServer" -Color Yellow
        }
    }
    
    # Тестирование ECW GeoServer
    if ($ecwWmsOk) {
        Write-ColorMessage "`nТестирование слоев ECW GeoServer:" -Color Magenta
        
        $ecwLayers = Get-WmsLayers -Url $BaseUrl -Instance "ecw"
        
        if ($ecwLayers.Count -gt 0) {
            Write-ColorMessage "Найдено $($ecwLayers.Count) слоев в ECW GeoServer" -Color Green
            
            # Ограничение количества тестируемых слоев (не более 10)
            $layersToTest = if ($ecwLayers.Count -gt 10) { $ecwLayers[0..9] } else { $ecwLayers }
            
            foreach ($layer in $layersToTest) {
                $outputPath = Join-Path -Path $ecwDir -ChildPath "$($layer.Name).png"
                $success = Get-WmsMap -Url $BaseUrl -Instance "ecw" -Layer $layer.Name -OutputPath $outputPath
                
                if ($success) {
                    $ecwResults += @{
                        Layer = $layer.Name
                        Title = $layer.Title
                        ImagePath = $outputPath
                    }
                }
            }
        } else {
            Write-ColorMessage "Не найдено слоев в ECW GeoServer" -Color Yellow
        }
    }
    
    # Вывод итогов тестирования
    Write-ColorMessage "`n=== Итоги тестирования ===" -Color Magenta
    Write-ColorMessage "Vector GeoServer: протестировано $($vectorResults.Count) слоев" -Color $(if ($vectorResults.Count -gt 0) { "Green" } else { "Yellow" })
    Write-ColorMessage "ECW GeoServer: протестировано $($ecwResults.Count) слоев" -Color $(if ($ecwResults.Count -gt 0) { "Green" } else { "Yellow" })
    
    # Создание HTML-отчета, если указан параметр
    $htmlReportPath = $null
    if ($GenerateHtml) {
        $htmlReportPath = Create-HtmlReport -OutputDir $OutputDir -VectorResults $vectorResults -EcwResults $ecwResults -BaseUrl $BaseUrl
    }
    
    # Открытие результатов, если указан параметр
    if ($OpenResults -and (Test-Path $OutputDir)) {
        if ($htmlReportPath -and (Test-Path $htmlReportPath)) {
            Write-ColorMessage "Открытие HTML-отчета..." -Color Cyan
            Start-Process $htmlReportPath
        } else {
            Write-ColorMessage "Открытие каталога с результатами..." -Color Cyan
            Start-Process $OutputDir
        }
    }
    
    Write-ColorMessage "`nТестирование WMS-сервисов завершено." -Color Green
}

# Запуск основной функции
Test-WmsServices 