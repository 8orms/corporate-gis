#!/usr/bin/env pwsh
# GeoServer Monitoring Script
# --------------------------
# Мониторинг нагрузки на GeoServer контейнеры и запись статистики
# Использование: ./monitor-geoserver.ps1 [интервал в секундах] [длительность в минутах]

param(
    [int]$Interval = 5,         # Интервал мониторинга в секундах (по умолчанию 5)
    [int]$Duration = 10,        # Длительность мониторинга в минутах (по умолчанию 10)
    [string]$LogFile = "geoserver-monitoring.log"  # Имя файла журнала
)

# Рассчитываем общее количество итераций
$TotalIterations = ($Duration * 60) / $Interval
$CurrentIteration = 0

# Создаем или очищаем файл лога
"# GeoServer Monitoring Log - $(Get-Date) #" | Out-File -FilePath $LogFile

Write-Host "Начинаю мониторинг GeoServer. Интервал: $Interval сек., Длительность: $Duration мин."
Write-Host "Результаты сохраняются в файл: $LogFile"
Write-Host "Нажмите Ctrl+C для остановки мониторинга"
Write-Host "-------------------------------------------------"

# Записываем заголовки в лог-файл
"Timestamp,Container,CPU %,Memory Usage (MiB),Memory %,Network IN,Network OUT" | Add-Content -Path $LogFile

# Функция для получения статистики контейнера
function Get-ContainerStats {
    param([string]$ContainerName)
    
    # Получаем статистику через docker stats
    $stats = docker stats --no-stream $ContainerName | Select-Object -Skip 1
    
    if ($stats) {
        # Парсим строку статистики
        $statsLine = $stats -replace '\s+', ' ' -replace '^\s+', ''
        $statsArray = $statsLine -split ' '
        
        # Индексы зависят от формата вывода docker stats
        if ($statsArray.Count -ge 7) {
            $containerID = $statsArray[0]
            $name = $statsArray[1]
            $cpu = $statsArray[2] -replace '%', ''
            $memUsage = ($statsArray[3] -split '/')[0]
            $memPercentage = $statsArray[5] -replace '%', ''
            $netIO = $statsArray[6] -split '/'
            $netIn = $netIO[0]
            $netOut = $netIO[1]
            
            # Преобразуем память в МБ для единообразия
            if ($memUsage -match 'GiB') {
                $memUsage = [math]::Round([double]($memUsage -replace 'GiB', '') * 1024, 2)
            } else {
                $memUsage = [math]::Round([double]($memUsage -replace 'MiB', ''), 2)
            }
            
            # Возвращаем объект с результатами
            return @{
                'Name' = $name
                'CPU' = $cpu
                'MemoryUsage' = $memUsage
                'MemoryPercentage' = $memPercentage
                'NetworkIn' = $netIn
                'NetworkOut' = $netOut
            }
        }
    }
    
    # Если не удалось получить статистику
    return $null
}

# Основной цикл мониторинга
try {
    while ($CurrentIteration -lt $TotalIterations) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        
        # Получаем статистику для geoserver-vector
        $vectorStats = Get-ContainerStats -ContainerName "geoserver-vector"
        if ($vectorStats) {
            "$timestamp,geoserver-vector,$($vectorStats.CPU),$($vectorStats.MemoryUsage),$($vectorStats.MemoryPercentage),$($vectorStats.NetworkIn),$($vectorStats.NetworkOut)" | 
                Add-Content -Path $LogFile
                
            Write-Host "[$timestamp] geoserver-vector: CPU: $($vectorStats.CPU)%, Память: $($vectorStats.MemoryUsage) МБ"
        }
        
        # Получаем статистику для geoserver-ecw
        $ecwStats = Get-ContainerStats -ContainerName "geoserver-ecw"
        if ($ecwStats) {
            "$timestamp,geoserver-ecw,$($ecwStats.CPU),$($ecwStats.MemoryUsage),$($ecwStats.MemoryPercentage),$($ecwStats.NetworkIn),$($ecwStats.NetworkOut)" | 
                Add-Content -Path $LogFile
                
            Write-Host "[$timestamp] geoserver-ecw: CPU: $($ecwStats.CPU)%, Память: $($ecwStats.MemoryUsage) МБ"
        }
        
        $CurrentIteration++
        Start-Sleep -Seconds $Interval
    }
}
catch {
    Write-Host "Мониторинг прерван: $_" -ForegroundColor Red
}
finally {
    Write-Host "-------------------------------------------------"
    Write-Host "Мониторинг завершен. Результаты сохранены в файл: $LogFile"
    
    # Выводим простую статистику из собранных данных
    Write-Host "Расчет статистики..."
    
    # Загружаем данные из лог-файла
    $logData = Import-Csv -Path $LogFile
    
    # Группируем по имени контейнера и вычисляем статистику
    $containers = $logData | Group-Object -Property Container
    
    foreach ($container in $containers) {
        $cpuStats = $container.Group | ForEach-Object { [double]$_.'CPU %' }
        $memStats = $container.Group | ForEach-Object { [double]$_.'Memory Usage (MiB)' }
        
        $avgCpu = ($cpuStats | Measure-Object -Average).Average
        $maxCpu = ($cpuStats | Measure-Object -Maximum).Maximum
        $avgMem = ($memStats | Measure-Object -Average).Average
        $maxMem = ($memStats | Measure-Object -Maximum).Maximum
        
        Write-Host ""
        Write-Host "Статистика для $($container.Name):"
        Write-Host "  Среднее CPU: $([math]::Round($avgCpu, 2))%"
        Write-Host "  Максимальное CPU: $([math]::Round($maxCpu, 2))%"
        Write-Host "  Средняя память: $([math]::Round($avgMem, 2)) МБ"
        Write-Host "  Максимальная память: $([math]::Round($maxMem, 2)) МБ"
    }
} 