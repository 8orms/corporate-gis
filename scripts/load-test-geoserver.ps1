#!/usr/bin/env pwsh
# GeoServer Load Testing Script
# -----------------------------
# Скрипт для нагрузочного тестирования GeoServer с помощью параллельных запросов
# Использование: ./load-test-geoserver.ps1 [количество запросов] [степень параллелизма]

param(
    [int]$TotalRequests = 100,    # Общее количество запросов (по умолчанию 100)
    [int]$Parallelism = 5,        # Количество параллельных запросов (по умолчанию 5)
    [int]$Delay = 0,              # Задержка между запросами в миллисекундах (по умолчанию 0)
    [string]$LogFile = "geoserver-load-test.log"  # Имя файла журнала
)

# Создаем или очищаем файл лога
"# GeoServer Load Test - $(Get-Date) #" | Out-File -FilePath $LogFile
"# Параметры: Запросов=$TotalRequests, Параллелизм=$Parallelism, Задержка=$Delay мс #" | Add-Content -Path $LogFile

Write-Host "Начинаю нагрузочное тестирование GeoServer."
Write-Host "Параметры: Запросов=$TotalRequests, Параллелизм=$Parallelism, Задержка=$Delay мс"
Write-Host "Результаты сохраняются в файл: $LogFile"
Write-Host "-------------------------------------------------"

# Записываем заголовки в лог-файл
"RequestID,Type,URL,StatusCode,StartTime,EndTime,Duration" | Add-Content -Path $LogFile

# Массив тестовых запросов (различные типы и параметры)
$requests = @(
    @{Type="WMS GetMap"; URL="http://localhost/geoserver/ecw/wms?service=WMS&version=1.1.0&request=GetMap&layers=TEST:2020-2021&styles=&bbox=2657408.0,7480000.0,2657508.0,7480100.0&width=768&height=677&srs=EPSG:3857&format=image/png"},
    @{Type="WMS GetCapabilities"; URL="http://localhost/geoserver/ecw/wms?service=WMS&version=1.1.0&request=GetCapabilities"},
    @{Type="WFS GetCapabilities"; URL="http://localhost/geoserver/vector/wfs?service=WFS&version=1.1.0&request=GetCapabilities"},
    @{Type="WFS GetFeature"; URL="http://localhost/geoserver/vector/wfs?service=WFS&version=1.1.0&request=GetFeature&typename=test:cities&outputFormat=application/json&maxFeatures=100"},
    @{Type="WMS GetFeatureInfo"; URL="http://localhost/geoserver/ecw/wms?SERVICE=WMS&VERSION=1.1.1&REQUEST=GetFeatureInfo&QUERY_LAYERS=TEST:2020-2021&STYLES=&LAYERS=TEST:2020-2021&INFO_FORMAT=application/json&FEATURE_COUNT=50&X=50&Y=50&SRS=EPSG:3857&WIDTH=101&HEIGHT=101&BBOX=2657408.0,7480000.0,2657508.0,7480100.0"}
)

# Создаем счетчик для отслеживания прогресса
$completedRequests = 0
$successfulRequests = 0
$totalDuration = 0

# Функция для выполнения одного запроса
function Invoke-GeoServerRequest {
    param(
        [int]$RequestID,
        [string]$Type,
        [string]$URL
    )
    
    try {
        $startTime = Get-Date
        $formattedStartTime = $startTime.ToString("yyyy-MM-dd HH:mm:ss.fff")
        
        # Выполняем запрос и замеряем время
        $response = Invoke-WebRequest -Uri $URL -UseBasicParsing -TimeoutSec 30
        
        $endTime = Get-Date
        $formattedEndTime = $endTime.ToString("yyyy-MM-dd HH:mm:ss.fff")
        $duration = ($endTime - $startTime).TotalMilliseconds
        
        # Записываем результат в лог
        "$RequestID,$Type,$URL,$($response.StatusCode),$formattedStartTime,$formattedEndTime,$([math]::Round($duration, 2))" | Add-Content -Path $LogFile
        
        return @{
            Success = $true
            Duration = $duration
            StatusCode = $response.StatusCode
        }
    }
    catch {
        $endTime = Get-Date
        $formattedEndTime = $endTime.ToString("yyyy-MM-dd HH:mm:ss.fff")
        $duration = ($endTime - $startTime).TotalMilliseconds
        $statusCode = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.value__ } else { "Error" }
        
        # Записываем ошибку в лог
        "$RequestID,$Type,$URL,$statusCode,$formattedStartTime,$formattedEndTime,$([math]::Round($duration, 2))" | Add-Content -Path $LogFile
        
        return @{
            Success = $false
            Duration = $duration
            StatusCode = $statusCode
            Error = $_.Exception.Message
        }
    }
}

# Функция прогресс-бара
function Write-Progress {
    param(
        [int]$Completed,
        [int]$Total
    )
    
    $percentComplete = [math]::Round(($Completed / $Total) * 100, 0)
    $progressBar = "[" + ("#" * [math]::Floor($percentComplete / 5)) + (" " * [math]::Ceiling((100 - $percentComplete) / 5)) + "]"
    
    Write-Host "`r$progressBar $percentComplete% ($Completed/$Total)" -NoNewline
}

# Измеряем общее время выполнения
$totalStartTime = Get-Date

# Создаем jobs для запросов
$jobs = @()

for ($i = 1; $i -le $TotalRequests; $i++) {
    # Выбираем случайный запрос из массива
    $requestIndex = Get-Random -Minimum 0 -Maximum $requests.Count
    $request = $requests[$requestIndex]
    
    # Создаем job для асинхронного выполнения
    $job = Start-Job -ScriptBlock {
        param($RequestID, $Type, $URL)
        
        # Создаем функцию внутри job
        function Invoke-GeoServerRequestInJob {
            param($ID, $T, $U)
            
            try {
                $startTime = Get-Date
                $response = Invoke-WebRequest -Uri $U -UseBasicParsing -TimeoutSec 30
                $endTime = Get-Date
                $duration = ($endTime - $startTime).TotalMilliseconds
                
                return @{
                    RequestID = $ID
                    Type = $T
                    URL = $U
                    StatusCode = $response.StatusCode
                    StartTime = $startTime.ToString("yyyy-MM-dd HH:mm:ss.fff")
                    EndTime = $endTime.ToString("yyyy-MM-dd HH:mm:ss.fff")
                    Duration = $duration
                    Success = $true
                }
            }
            catch {
                $endTime = Get-Date
                $duration = ($endTime - $startTime).TotalMilliseconds
                $statusCode = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.value__ } else { "Error" }
                
                return @{
                    RequestID = $ID
                    Type = $T
                    URL = $U
                    StatusCode = $statusCode
                    StartTime = $startTime.ToString("yyyy-MM-dd HH:mm:ss.fff")
                    EndTime = $endTime.ToString("yyyy-MM-dd HH:mm:ss.fff")
                    Duration = $duration
                    Success = $false
                    Error = $_.Exception.Message
                }
            }
        }
        
        # Выполняем запрос
        Invoke-GeoServerRequestInJob -ID $RequestID -T $Type -U $URL
    } -ArgumentList $i, $request.Type, $request.URL
    
    $jobs += $job
    
    # Ограничиваем количество параллельных запросов
    while ((Get-Job -State Running).Count -ge $Parallelism) {
        $completedJob = Wait-Job -Any -Timeout 1
        if ($completedJob) {
            $result = Receive-Job $completedJob
            Remove-Job $completedJob
            
            $completedRequests++
            Write-Progress -Completed $completedRequests -Total $TotalRequests
            
            # Записываем результат в лог
            "$($result.RequestID),$($result.Type),$($result.URL),$($result.StatusCode),$($result.StartTime),$($result.EndTime),$([math]::Round($result.Duration, 2))" | 
                Add-Content -Path $LogFile
            
            if ($result.Success) {
                $successfulRequests++
                $totalDuration += $result.Duration
            }
        }
    }
    
    # Добавляем задержку между запросками, если указана
    if ($Delay -gt 0) {
        Start-Sleep -Milliseconds $Delay
    }
}

# Ожидаем завершения всех оставшихся jobs
while (Get-Job) {
    $completedJob = Wait-Job -Any -Timeout 1
    if ($completedJob) {
        $result = Receive-Job $completedJob
        Remove-Job $completedJob
        
        $completedRequests++
        Write-Progress -Completed $completedRequests -Total $TotalRequests
        
        # Записываем результат в лог
        "$($result.RequestID),$($result.Type),$($result.URL),$($result.StatusCode),$($result.StartTime),$($result.EndTime),$([math]::Round($result.Duration, 2))" | 
            Add-Content -Path $LogFile
        
        if ($result.Success) {
            $successfulRequests++
            $totalDuration += $result.Duration
        }
    }
}

# Завершаем прогресс-бар
Write-Host ""

# Измеряем общее время выполнения
$totalEndTime = Get-Date
$totalExecutionTime = ($totalEndTime - $totalStartTime).TotalSeconds

# Выводим статистику
Write-Host "-------------------------------------------------"
Write-Host "Нагрузочное тестирование завершено."
Write-Host "Общее время выполнения: $([math]::Round($totalExecutionTime, 2)) секунд"
Write-Host "Успешных запросов: $successfulRequests из $TotalRequests ($(([math]::Round(($successfulRequests/$TotalRequests)*100, 1)))%)"

if ($successfulRequests -gt 0) {
    $averageDuration = $totalDuration / $successfulRequests
    Write-Host "Среднее время ответа: $([math]::Round($averageDuration, 2)) мс"
}

Write-Host "Подробные результаты сохранены в файл: $LogFile"

# Анализируем результаты по типам запросов
Write-Host ""
Write-Host "Статистика по типам запросов:"
Write-Host "-------------------------------------------------"

# Загружаем данные из лог-файла
$logData = Import-Csv -Path $LogFile

# Группируем по типу запроса
$requestTypes = $logData | Group-Object -Property Type

foreach ($type in $requestTypes) {
    $durations = $type.Group | Where-Object { $_.StatusCode -eq "200" } | ForEach-Object { [double]$_.Duration }
    
    if ($durations.Count -gt 0) {
        $avgDuration = ($durations | Measure-Object -Average).Average
        $maxDuration = ($durations | Measure-Object -Maximum).Maximum
        $minDuration = ($durations | Measure-Object -Minimum).Minimum
        
        $successCount = $durations.Count
        $totalCount = $type.Group.Count
        $successRate = [math]::Round(($successCount / $totalCount) * 100, 1)
        
        Write-Host "Тип запроса: $($type.Name)"
        Write-Host "  Успешных запросов: $successCount из $totalCount ($successRate%)"
        Write-Host "  Среднее время ответа: $([math]::Round($avgDuration, 2)) мс"
        Write-Host "  Минимальное время: $([math]::Round($minDuration, 2)) мс"
        Write-Host "  Максимальное время: $([math]::Round($maxDuration, 2)) мс"
        Write-Host ""
    } else {
        Write-Host "Тип запроса: $($type.Name)"
        Write-Host "  Нет успешных запросов из $($type.Group.Count) попыток"
        Write-Host ""
    }
} 