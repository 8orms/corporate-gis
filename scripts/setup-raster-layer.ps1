#Requires -Version 5.1

<#
.SYNOPSIS
    Скрипт для настройки растрового слоя в GeoServer.

.DESCRIPTION
    Скрипт позволяет загрузить и опубликовать растровый слой в GeoServer.
    Поддерживает форматы GeoTIFF, ECW, JPEG2000 и другие, доступные в GeoServer.
    Настраивает рабочее пространство, хранилище данных и публикует слой.

.PARAMETER GeoServerUrl
    URL GeoServer, включая порт и путь к API REST.

.PARAMETER AdminUser
    Имя пользователя администратора GeoServer.

.PARAMETER AdminPassword
    Пароль администратора GeoServer.

.PARAMETER WorkspaceName
    Имя рабочего пространства для публикации растрового слоя.

.PARAMETER DatastoreName
    Имя хранилища данных для растрового слоя.

.PARAMETER LayerName
    Имя публикуемого слоя.

.PARAMETER RasterFilePath
    Полный путь к растровому файлу.

.PARAMETER CoverageSRS
    Система координат растрового слоя (EPSG код).

.EXAMPLE
    ./setup-raster-layer.ps1 -GeoServerUrl "http://localhost:8080/geoserver/rest" -AdminUser "admin" -AdminPassword "geoserver" -WorkspaceName "raster" -DatastoreName "ecw_store" -LayerName "landsat" -RasterFilePath "D:\data\imagery\landsat.ecw" -CoverageSRS "EPSG:4326"

.NOTES
    Автор: Корпоративная ГИС-платформа
    Версия: 1.0
    Дата: 25.02.2025
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$GeoServerUrl,
    
    [Parameter(Mandatory = $true)]
    [string]$AdminUser,
    
    [Parameter(Mandatory = $true)]
    [string]$AdminPassword,
    
    [Parameter(Mandatory = $true)]
    [string]$WorkspaceName,
    
    [Parameter(Mandatory = $true)]
    [string]$DatastoreName,
    
    [Parameter(Mandatory = $true)]
    [string]$LayerName,
    
    [Parameter(Mandatory = $true)]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [string]$RasterFilePath,
    
    [Parameter(Mandatory = $false)]
    [string]$CoverageSRS = "EPSG:4326"
)

function Write-Log {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage
    
    # Можно добавить логирование в файл
    # Add-Content -Path "raster_layer_setup.log" -Value $logMessage
}

function Test-GeoServerConnection {
    param (
        [string]$Url,
        [string]$Username,
        [string]$Password
    )
    
    try {
        $headers = @{
            "Authorization" = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($Username):$($Password)"))
            "Accept" = "application/json"
        }
        
        $response = Invoke-RestMethod -Uri "${Url}/about/version" -Method Get -Headers $headers -ErrorAction Stop
        Write-Log "Успешное подключение к GeoServer версии $($response.about.resource.Version)"
        return $true
    }
    catch {
        Write-Log "Ошибка подключения к GeoServer: $_" -Level "ERROR"
        return $false
    }
}

function Create-Workspace {
    param (
        [string]$Url,
        [string]$Username,
        [string]$Password,
        [string]$Workspace
    )
    
    try {
        $headers = @{
            "Authorization" = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($Username):$($Password)"))
            "Content-Type" = "application/json"
        }
        
        # Проверяем существование рабочего пространства
        try {
            $response = Invoke-RestMethod -Uri "${Url}/workspaces/${Workspace}" -Method Get -Headers $headers -ErrorAction Stop
            Write-Log "Рабочее пространство ${Workspace} уже существует" -Level "INFO"
            return $true
        }
        catch {
            # Рабочее пространство не существует, создаем его
            $body = @{
                workspace = @{
                    name = $Workspace
                }
            } | ConvertTo-Json
            
            $response = Invoke-RestMethod -Uri "${Url}/workspaces" -Method Post -Headers $headers -Body $body -ErrorAction Stop
            Write-Log "Создано рабочее пространство ${Workspace}" -Level "INFO"
            return $true
        }
    }
    catch {
        Write-Log "Ошибка при создании рабочего пространства ${Workspace}: $_" -Level "ERROR"
        return $false
    }
}

function Create-CoverageStore {
    param (
        [string]$Url,
        [string]$Username,
        [string]$Password,
        [string]$Workspace,
        [string]$Datastore,
        [string]$FilePath
    )
    
    try {
        $headers = @{
            "Authorization" = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($Username):$($Password)"))
            "Content-Type" = "application/json"
        }
        
        # Получаем расширение файла для определения типа хранилища
        $extension = [System.IO.Path]::GetExtension($FilePath).ToLower()
        $storeType = switch ($extension) {
            ".tif" { "GeoTIFF" }
            ".tiff" { "GeoTIFF" }
            ".ecw" { "ECW" }
            ".jp2" { "JP2K" }
            ".sid" { "MrSID" }
            default { "GeoTIFF" }  # По умолчанию используем GeoTIFF
        }
        
        # Проверяем существование хранилища
        try {
            $response = Invoke-RestMethod -Uri "${Url}/workspaces/${Workspace}/coveragestores/${Datastore}" -Method Get -Headers $headers -ErrorAction Stop
            Write-Log "Хранилище данных ${Datastore} уже существует" -Level "INFO"
            return $true
        }
        catch {
            # Формируем URL для загрузки файла с указанием имени хранилища
            $fileUrl = "file:" + ($FilePath -replace "\\", "/")
            
            $body = @{
                coverageStore = @{
                    name = $Datastore
                    type = $storeType
                    enabled = $true
                    workspace = @{
                        name = $Workspace
                    }
                    url = $fileUrl
                }
            } | ConvertTo-Json
            
            $response = Invoke-RestMethod -Uri "${Url}/workspaces/${Workspace}/coveragestores" -Method Post -Headers $headers -Body $body -ErrorAction Stop
            Write-Log "Создано хранилище данных ${Datastore} типа ${storeType}" -Level "INFO"
            return $true
        }
    }
    catch {
        Write-Log "Ошибка при создании хранилища данных ${Datastore}: $_" -Level "ERROR"
        return $false
    }
}

function Publish-Coverage {
    param (
        [string]$Url,
        [string]$Username,
        [string]$Password,
        [string]$Workspace,
        [string]$Datastore,
        [string]$LayerName,
        [string]$SRS
    )
    
    try {
        $headers = @{
            "Authorization" = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($Username):$($Password)"))
            "Content-Type" = "application/json"
        }
        
        # Проверяем существование слоя
        try {
            $response = Invoke-RestMethod -Uri "${Url}/workspaces/${Workspace}/coveragestores/${Datastore}/coverages/${LayerName}" -Method Get -Headers $headers -ErrorAction Stop
            Write-Log "Слой ${LayerName} уже опубликован" -Level "INFO"
            return $true
        }
        catch {
            # Публикуем слой
            $body = @{
                coverage = @{
                    name = $LayerName
                    title = $LayerName
                    nativeCRS = $SRS
                    srs = $SRS
                    enabled = $true
                    metadata = @{
                        entry = @(@{
                            '@key' = "dirName"
                            $LayerName = $LayerName
                        })
                    }
                }
            } | ConvertTo-Json -Depth 10
            
            $response = Invoke-RestMethod -Uri "${Url}/workspaces/${Workspace}/coveragestores/${Datastore}/coverages" -Method Post -Headers $headers -Body $body -ErrorAction Stop
            Write-Log "Слой ${LayerName} успешно опубликован" -Level "INFO"
            return $true
        }
    }
    catch {
        Write-Log "Ошибка при публикации слоя ${LayerName}: $_" -Level "ERROR"
        return $false
    }
}

function Set-LayerStyles {
    param (
        [string]$Url,
        [string]$Username,
        [string]$Password,
        [string]$Workspace,
        [string]$LayerName,
        [string]$StyleName = "raster"
    )
    
    try {
        $headers = @{
            "Authorization" = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($Username):$($Password)"))
            "Content-Type" = "application/json"
        }
        
        $body = @{
            layer = @{
                defaultStyle = @{
                    name = $StyleName
                }
            }
        } | ConvertTo-Json
        
        $layerPath = $Workspace + ":" + $LayerName
        $response = Invoke-RestMethod -Uri "${Url}/layers/${layerPath}" -Method Put -Headers $headers -Body $body -ErrorAction Stop
        Write-Log "Стиль ${StyleName} успешно применен к слою ${LayerName}" -Level "INFO"
        return $true
    }
    catch {
        Write-Log "Ошибка при применении стиля к слою ${LayerName}: $_" -Level "ERROR"
        return $false
    }
}

function Test-RasterLayer {
    param (
        [string]$GeoServerBaseUrl,
        [string]$Workspace,
        [string]$LayerName
    )
    
    try {
        # Получаем GetCapabilities для проверки слоя
        $url = "${GeoServerBaseUrl}/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetCapabilities"
        
        Write-Log "Проверка слоя через WMS GetCapabilities: $url" -Level "INFO"
        
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing
        
        if ($response.StatusCode -eq 200) {
            Write-Log "WMS сервис доступен, проверьте наличие слоя ${Workspace}:${LayerName} в GetCapabilities ответе" -Level "INFO"
            return $true
        }
        else {
            Write-Log "Ошибка доступа к WMS сервису: $($response.StatusCode)" -Level "ERROR"
            return $false
        }
    }
    catch {
        Write-Log "Ошибка при проверке WMS слоя: $_" -Level "ERROR"
        return $false
    }
}

# Основной блок скрипта
Write-Log "Начало настройки растрового слоя в GeoServer" -Level "INFO"

# Удаляем завершающий слеш из URL, если он есть
$GeoServerUrl = $GeoServerUrl.TrimEnd('/')

# Проверка подключения к GeoServer
if (-not (Test-GeoServerConnection -Url $GeoServerUrl -Username $AdminUser -Password $AdminPassword)) {
    Write-Log "Невозможно продолжить без подключения к GeoServer" -Level "ERROR"
    exit 1
}

# Проверка файла растра
if (-not (Test-Path $RasterFilePath)) {
    Write-Log "Файл растра не найден: $RasterFilePath" -Level "ERROR"
    exit 1
}

Write-Log "Используется файл растра: $RasterFilePath" -Level "INFO"

# Создание рабочего пространства
if (-not (Create-Workspace -Url $GeoServerUrl -Username $AdminUser -Password $AdminPassword -Workspace $WorkspaceName)) {
    Write-Log "Невозможно продолжить без создания рабочего пространства" -Level "ERROR"
    exit 1
}

# Создание хранилища данных
if (-not (Create-CoverageStore -Url $GeoServerUrl -Username $AdminUser -Password $AdminPassword -Workspace $WorkspaceName -Datastore $DatastoreName -FilePath $RasterFilePath)) {
    Write-Log "Невозможно продолжить без создания хранилища данных" -Level "ERROR"
    exit 1
}

# Публикация слоя
if (-not (Publish-Coverage -Url $GeoServerUrl -Username $AdminUser -Password $AdminPassword -Workspace $WorkspaceName -Datastore $DatastoreName -LayerName $LayerName -SRS $CoverageSRS)) {
    Write-Log "Ошибка при публикации слоя" -Level "ERROR"
    exit 1
}

# Применение стилей
Set-LayerStyles -Url $GeoServerUrl -Username $AdminUser -Password $AdminPassword -Workspace $WorkspaceName -LayerName $LayerName

# Проверяем доступность слоя через WMS
$geoServerBaseUrl = $GeoServerUrl -replace "/rest$", ""
Test-RasterLayer -GeoServerBaseUrl $geoServerBaseUrl -Workspace $WorkspaceName -LayerName $LayerName

Write-Log "Настройка растрового слоя успешно завершена" -Level "INFO"
$layerPath = $WorkspaceName + ":" + $LayerName
Write-Log "Слой доступен по адресу: $geoServerBaseUrl/$WorkspaceName/wms?service=WMS&version=1.3.0&request=GetMap&layers=$layerPath" -Level "INFO" 