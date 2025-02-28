# restart-geoserver-instances.ps1
# Скрипт для мониторинга и автоматического перезапуска инстанций GeoServer при необходимости
# Автор: Corporate GIS Team
# Дата: 27.02.2025

param (
    [switch]$Force,                      # Принудительный перезапуск без проверки
    [switch]$Verbose,                    # Подробный вывод
    [switch]$DryRun,                     # Режим без фактического перезапуска (только проверка)
    [int]$MaxRetries = 3,                # Максимальное количество попыток перезапуска
    [int]$RetryDelay = 30,               # Задержка между попытками в секундах
    [string]$InstanceType = "all",       # Тип инстанции: "vector", "ecw" или "all"
    [switch]$NotifyOnRestart             # Отправлять уведомление при перезапуске
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
        [string]$Description,
        [int]$Timeout = 10
    )
    
    Write-ColorMessage "Проверка $Description... " -Color Cyan -NoNewLine
    
    try {
        $request = [System.Net.WebRequest]::Create($Url)
        $request.Method = "HEAD"
        $request.Timeout = $Timeout * 1000
        
        $response = $request.GetResponse()
        $statusCode = [int]$response.StatusCode
        $response.Close()
        
        if ($statusCode -eq 200) {
            Write-ColorMessage "OK (200)" -Color Green
            return $true
        } else {
            Write-ColorMessage "Ошибка ($statusCode)" -Color Red
            return $false
        }
    } catch {
        Write-ColorMessage "Ошибка: $_" -Color Red
        return $false
    }
}

# Функция для проверки состояния контейнера
function Get-ContainerStatus {
    param (
        [string]$ContainerName
    )
    
    try {
        $status = docker inspect --format="{{.State.Status}}" $ContainerName 2>&1
        if ($LASTEXITCODE -ne 0) {
            return "unknown"
        }
        return $status
    } catch {
        return "unknown"
    }
}

# Функция для проверки здоровья контейнера
function Get-ContainerHealth {
    param (
        [string]$ContainerName
    )
    
    try {
        $health = docker inspect --format="{{.State.Health.Status}}" $ContainerName 2>&1
        if ($LASTEXITCODE -ne 0) {
            return "unknown"
        }
        return $health
    } catch {
        return "unknown"
    }
}

# Функция для перезапуска контейнера
function Restart-Container {
    param (
        [string]$ContainerName,
        [switch]$DryRun
    )
    
    Write-ColorMessage "Перезапуск контейнера $ContainerName... " -Color Yellow -NoNewLine
    
    if ($DryRun) {
        Write-ColorMessage "ПРОПУЩЕНО (режим DryRun)" -Color Yellow
        return $true
    }
    
    try {
        $output = docker restart $ContainerName 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-ColorMessage "OK" -Color Green
            return $true
        } else {
            Write-ColorMessage "ОШИБКА" -Color Red
            Write-ColorMessage "Детали: $output" -Color Red
            return $false
        }
    } catch {
        Write-ColorMessage "ОШИБКА" -Color Red
        Write-ColorMessage "Детали: $_" -Color Red
        return $false
    }
}

# Функция для отправки уведомления
function Send-Notification {
    param (
        [string]$Subject,
        [string]$Message
    )
    
    Write-ColorMessage "Отправка уведомления: $Subject" -Color Yellow
    
    # Здесь можно реализовать отправку уведомлений через email, Slack, Teams и т.д.
    # Пример отправки через email:
    <#
    $smtpServer = "smtp.example.com"
    $smtpPort = 587
    $smtpUser = "alerts@example.com"
    $smtpPassword = "your-password"
    $from = "GIS Platform Alerts <alerts@example.com>"
    $to = "admin@example.com"
    
    $securePassword = ConvertTo-SecureString $smtpPassword -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential($smtpUser, $securePassword)
    
    Send-MailMessage -From $from -To $to -Subject $Subject -Body $Message -SmtpServer $smtpServer -Port $smtpPort -Credential $credential -UseSsl
    #>
    
    # Для демонстрации просто выводим сообщение
    Write-ColorMessage "Тема: $Subject" -Color Yellow
    Write-ColorMessage "Сообщение: $Message" -Color Yellow
}

# Функция для проверки и перезапуска GeoServer Vector
function Check-And-Restart-GeoServerVector {
    param (
        [switch]$Force,
        [switch]$DryRun,
        [int]$MaxRetries,
        [int]$RetryDelay
    )
    
    Write-ColorMessage "`n=== Проверка GeoServer Vector ===" -Color Magenta
    
    # Проверка состояния контейнера
    $containerStatus = Get-ContainerStatus -ContainerName "geoserver-vector"
    $containerHealth = Get-ContainerHealth -ContainerName "geoserver-vector"
    
    Write-ColorMessage "Статус контейнера: $containerStatus" -Color $(if ($containerStatus -eq "running") { "Green" } else { "Red" })
    if ($containerHealth -ne "unknown") {
        Write-ColorMessage "Здоровье контейнера: $containerHealth" -Color $(if ($containerHealth -eq "healthy") { "Green" } elseif ($containerHealth -eq "unhealthy") { "Red" } else { "Yellow" })
    }
    
    # Проверка доступности веб-интерфейса
    $webUiAccessible = Test-Url -Url "http://localhost:8080/geoserver/web/" -Description "Прямой доступ к веб-интерфейсу GeoServer Vector"
    
    # Проверка доступности WMS
    $wmsAccessible = Test-Url -Url "http://localhost:8080/geoserver/wms?service=WMS&version=1.1.0&request=GetCapabilities" -Description "Прямой доступ к WMS GeoServer Vector"
    
    # Проверка доступности через NGINX
    $nginxAccessible = Test-Url -Url "http://localhost/geoserver/vector/web/" -Description "Доступ через NGINX к GeoServer Vector"
    
    # Решение о необходимости перезапуска
    $needsRestart = $Force -or 
                   ($containerStatus -ne "running") -or 
                   ($containerHealth -eq "unhealthy") -or 
                   (-not $webUiAccessible) -or 
                   (-not $wmsAccessible)
    
    if ($needsRestart) {
        Write-ColorMessage "`nGeoServer Vector требует перезапуска." -Color Yellow
        
        $restartSuccess = $false
        $retryCount = 0
        
        while (-not $restartSuccess -and $retryCount -lt $MaxRetries) {
            $retryCount++
            Write-ColorMessage "Попытка $retryCount из $MaxRetries..." -Color Yellow
            
            $restartSuccess = Restart-Container -ContainerName "geoserver-vector" -DryRun:$DryRun
            
            if (-not $restartSuccess -and $retryCount -lt $MaxRetries) {
                Write-ColorMessage "Ожидание $RetryDelay секунд перед следующей попыткой..." -Color Yellow
                Start-Sleep -Seconds $RetryDelay
            }
        }
        
        if ($restartSuccess) {
            Write-ColorMessage "GeoServer Vector успешно перезапущен." -Color Green
            
            # Ожидание запуска сервиса
            Write-ColorMessage "Ожидание запуска сервиса..." -Color Yellow
            Start-Sleep -Seconds 30
            
            # Проверка после перезапуска
            $webUiAccessible = Test-Url -Url "http://localhost:8080/geoserver/web/" -Description "Веб-интерфейс GeoServer Vector после перезапуска"
            $wmsAccessible = Test-Url -Url "http://localhost:8080/geoserver/wms?service=WMS&version=1.1.0&request=GetCapabilities" -Description "WMS GeoServer Vector после перезапуска"
            
            if ($NotifyOnRestart) {
                $subject = "GeoServer Vector перезапущен"
                $message = "GeoServer Vector был перезапущен в $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss').`n`n"
                $message += "Статус после перезапуска:`n"
                $message += "- Веб-интерфейс: $(if ($webUiAccessible) { 'Доступен' } else { 'Недоступен' })`n"
                $message += "- WMS: $(if ($wmsAccessible) { 'Доступен' } else { 'Недоступен' })`n"
                
                Send-Notification -Subject $subject -Message $message
            }
        } else {
            Write-ColorMessage "Не удалось перезапустить GeoServer Vector после $MaxRetries попыток." -Color Red
            
            if ($NotifyOnRestart) {
                $subject = "ОШИБКА: Не удалось перезапустить GeoServer Vector"
                $message = "Не удалось перезапустить GeoServer Vector после $MaxRetries попыток в $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss').`n"
                $message += "Требуется ручное вмешательство."
                
                Send-Notification -Subject $subject -Message $message
            }
        }
    } else {
        Write-ColorMessage "`nGeoServer Vector работает нормально." -Color Green
    }
}

# Функция для проверки и перезапуска GeoServer ECW
function Check-And-Restart-GeoServerECW {
    param (
        [switch]$Force,
        [switch]$DryRun,
        [int]$MaxRetries,
        [int]$RetryDelay
    )
    
    Write-ColorMessage "`n=== Проверка GeoServer ECW ===" -Color Magenta
    
    # Проверка состояния контейнера
    $containerStatus = Get-ContainerStatus -ContainerName "geoserver-ecw"
    $containerHealth = Get-ContainerHealth -ContainerName "geoserver-ecw"
    
    Write-ColorMessage "Статус контейнера: $containerStatus" -Color $(if ($containerStatus -eq "running") { "Green" } else { "Red" })
    if ($containerHealth -ne "unknown") {
        Write-ColorMessage "Здоровье контейнера: $containerHealth" -Color $(if ($containerHealth -eq "healthy") { "Green" } elseif ($containerHealth -eq "unhealthy") { "Red" } else { "Yellow" })
    }
    
    # Проверка доступности веб-интерфейса
    $webUiAccessible = Test-Url -Url "http://localhost:8081/geoserver/web/" -Description "Прямой доступ к веб-интерфейсу GeoServer ECW"
    
    # Проверка доступности WMS
    $wmsAccessible = Test-Url -Url "http://localhost:8081/geoserver/wms?service=WMS&version=1.1.0&request=GetCapabilities" -Description "Прямой доступ к WMS GeoServer ECW"
    
    # Проверка доступности через NGINX
    $nginxAccessible = Test-Url -Url "http://localhost/geoserver/ecw/web/" -Description "Доступ через NGINX к GeoServer ECW"
    
    # Решение о необходимости перезапуска
    $needsRestart = $Force -or 
                   ($containerStatus -ne "running") -or 
                   ($containerHealth -eq "unhealthy") -or 
                   (-not $webUiAccessible) -or 
                   (-not $wmsAccessible)
    
    if ($needsRestart) {
        Write-ColorMessage "`nGeoServer ECW требует перезапуска." -Color Yellow
        
        $restartSuccess = $false
        $retryCount = 0
        
        while (-not $restartSuccess -and $retryCount -lt $MaxRetries) {
            $retryCount++
            Write-ColorMessage "Попытка $retryCount из $MaxRetries..." -Color Yellow
            
            $restartSuccess = Restart-Container -ContainerName "geoserver-ecw" -DryRun:$DryRun
            
            if (-not $restartSuccess -and $retryCount -lt $MaxRetries) {
                Write-ColorMessage "Ожидание $RetryDelay секунд перед следующей попыткой..." -Color Yellow
                Start-Sleep -Seconds $RetryDelay
            }
        }
        
        if ($restartSuccess) {
            Write-ColorMessage "GeoServer ECW успешно перезапущен." -Color Green
            
            # Ожидание запуска сервиса
            Write-ColorMessage "Ожидание запуска сервиса..." -Color Yellow
            Start-Sleep -Seconds 30
            
            # Проверка после перезапуска
            $webUiAccessible = Test-Url -Url "http://localhost:8081/geoserver/web/" -Description "Веб-интерфейс GeoServer ECW после перезапуска"
            $wmsAccessible = Test-Url -Url "http://localhost:8081/geoserver/wms?service=WMS&version=1.1.0&request=GetCapabilities" -Description "WMS GeoServer ECW после перезапуска"
            
            if ($NotifyOnRestart) {
                $subject = "GeoServer ECW перезапущен"
                $message = "GeoServer ECW был перезапущен в $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss').`n`n"
                $message += "Статус после перезапуска:`n"
                $message += "- Веб-интерфейс: $(if ($webUiAccessible) { 'Доступен' } else { 'Недоступен' })`n"
                $message += "- WMS: $(if ($wmsAccessible) { 'Доступен' } else { 'Недоступен' })`n"
                
                Send-Notification -Subject $subject -Message $message
            }
        } else {
            Write-ColorMessage "Не удалось перезапустить GeoServer ECW после $MaxRetries попыток." -Color Red
            
            if ($NotifyOnRestart) {
                $subject = "ОШИБКА: Не удалось перезапустить GeoServer ECW"
                $message = "Не удалось перезапустить GeoServer ECW после $MaxRetries попыток в $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss').`n"
                $message += "Требуется ручное вмешательство."
                
                Send-Notification -Subject $subject -Message $message
            }
        }
    } else {
        Write-ColorMessage "`nGeoServer ECW работает нормально." -Color Green
    }
}

# Функция для проверки и перезапуска NGINX
function Check-And-Restart-Nginx {
    param (
        [switch]$Force,
        [switch]$DryRun,
        [int]$MaxRetries,
        [int]$RetryDelay
    )
    
    Write-ColorMessage "`n=== Проверка NGINX ===" -Color Magenta
    
    # Проверка состояния контейнера
    $containerStatus = Get-ContainerStatus -ContainerName "dev-nginx-1"
    
    Write-ColorMessage "Статус контейнера: $containerStatus" -Color $(if ($containerStatus -eq "running") { "Green" } else { "Red" })
    
    # Проверка доступности NGINX
    $nginxAccessible = Test-Url -Url "http://localhost/" -Description "Доступ к NGINX"
    
    # Решение о необходимости перезапуска
    $needsRestart = $Force -or ($containerStatus -ne "running") -or (-not $nginxAccessible)
    
    if ($needsRestart) {
        Write-ColorMessage "`nNGINX требует перезапуска." -Color Yellow
        
        $restartSuccess = $false
        $retryCount = 0
        
        while (-not $restartSuccess -and $retryCount -lt $MaxRetries) {
            $retryCount++
            Write-ColorMessage "Попытка $retryCount из $MaxRetries..." -Color Yellow
            
            $restartSuccess = Restart-Container -ContainerName "dev-nginx-1" -DryRun:$DryRun
            
            if (-not $restartSuccess -and $retryCount -lt $MaxRetries) {
                Write-ColorMessage "Ожидание $RetryDelay секунд перед следующей попыткой..." -Color Yellow
                Start-Sleep -Seconds $RetryDelay
            }
        }
        
        if ($restartSuccess) {
            Write-ColorMessage "NGINX успешно перезапущен." -Color Green
            
            # Ожидание запуска сервиса
            Write-ColorMessage "Ожидание запуска сервиса..." -Color Yellow
            Start-Sleep -Seconds 10
            
            # Проверка после перезапуска
            $nginxAccessible = Test-Url -Url "http://localhost/" -Description "Доступ к NGINX после перезапуска"
            
            if ($NotifyOnRestart) {
                $subject = "NGINX перезапущен"
                $message = "NGINX был перезапущен в $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss').`n`n"
                $message += "Статус после перезапуска: $(if ($nginxAccessible) { 'Доступен' } else { 'Недоступен' })"
                
                Send-Notification -Subject $subject -Message $message
            }
        } else {
            Write-ColorMessage "Не удалось перезапустить NGINX после $MaxRetries попыток." -Color Red
            
            if ($NotifyOnRestart) {
                $subject = "ОШИБКА: Не удалось перезапустить NGINX"
                $message = "Не удалось перезапустить NGINX после $MaxRetries попыток в $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss').`n"
                $message += "Требуется ручное вмешательство."
                
                Send-Notification -Subject $subject -Message $message
            }
        }
    } else {
        Write-ColorMessage "`nNGINX работает нормально." -Color Green
    }
}

# Основная функция
function Main {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-ColorMessage "=== Проверка и перезапуск GeoServer ($timestamp) ===" -Color Magenta
    Write-ColorMessage "Режим: $(if ($DryRun) { 'Тестовый (без фактического перезапуска)' } else { 'Рабочий' })" -Color Yellow
    Write-ColorMessage "Принудительный перезапуск: $(if ($Force) { 'Да' } else { 'Нет' })" -Color Yellow
    Write-ColorMessage "Тип инстанции: $InstanceType" -Color Yellow
    Write-ColorMessage "Максимальное количество попыток: $MaxRetries" -Color Yellow
    Write-ColorMessage "Задержка между попытками: $RetryDelay секунд" -Color Yellow
    Write-ColorMessage "Уведомления: $(if ($NotifyOnRestart) { 'Включены' } else { 'Отключены' })" -Color Yellow
    Write-ColorMessage "=======================================" -Color Magenta
    
    # Проверка и перезапуск NGINX
    Check-And-Restart-Nginx -Force:$Force -DryRun:$DryRun -MaxRetries $MaxRetries -RetryDelay $RetryDelay
    
    # Проверка и перезапуск GeoServer Vector
    if ($InstanceType -eq "all" -or $InstanceType -eq "vector") {
        Check-And-Restart-GeoServerVector -Force:$Force -DryRun:$DryRun -MaxRetries $MaxRetries -RetryDelay $RetryDelay
    }
    
    # Проверка и перезапуск GeoServer ECW
    if ($InstanceType -eq "all" -or $InstanceType -eq "ecw") {
        Check-And-Restart-GeoServerECW -Force:$Force -DryRun:$DryRun -MaxRetries $MaxRetries -RetryDelay $RetryDelay
    }
    
    Write-ColorMessage "`n=== Проверка и перезапуск завершены ===" -Color Magenta
}

# Запуск основной функции
Main 