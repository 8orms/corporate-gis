# schedule-geoserver-monitoring.ps1
# Скрипт для настройки расписания мониторинга и автоматического перезапуска GeoServer
# Автор: Corporate GIS Team
# Дата: 27.02.2025

param (
    [Parameter(Mandatory = $false)]
    [ValidateSet("Install", "Uninstall", "Status")]
    [string]$Action = "Status",
    
    [Parameter(Mandatory = $false)]
    [int]$IntervalMinutes = 15,
    
    [Parameter(Mandatory = $false)]
    [switch]$EnableNotifications,
    
    [Parameter(Mandatory = $false)]
    [switch]$Force
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

# Функция для проверки прав администратора
function Test-Administrator {
    $user = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal $user
    return $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

# Функция для создания задачи в планировщике задач Windows
function Install-ScheduledTask {
    param (
        [int]$IntervalMinutes,
        [switch]$EnableNotifications,
        [switch]$Force
    )
    
    # Проверка прав администратора
    if (-not (Test-Administrator)) {
        Write-ColorMessage "Для установки задачи в планировщик требуются права администратора." -Color Red
        Write-ColorMessage "Пожалуйста, запустите скрипт от имени администратора." -Color Red
        return $false
    }
    
    # Получение полного пути к скрипту restart-geoserver-instances.ps1
    $scriptPath = Join-Path -Path $PSScriptRoot -ChildPath "restart-geoserver-instances.ps1"
    
    if (-not (Test-Path -Path $scriptPath)) {
        Write-ColorMessage "Скрипт restart-geoserver-instances.ps1 не найден по пути: $scriptPath" -Color Red
        return $false
    }
    
    # Формирование аргументов для скрипта
    $scriptArguments = "-ExecutionPolicy Bypass -File `"$scriptPath`""
    
    if ($Force) {
        $scriptArguments += " -Force"
    }
    
    if ($EnableNotifications) {
        $scriptArguments += " -NotifyOnRestart"
    }
    
    # Имя задачи
    $taskName = "GeoServerMonitoring"
    
    # Проверка существования задачи
    $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    
    if ($existingTask) {
        Write-ColorMessage "Задача '$taskName' уже существует. Удаление..." -Color Yellow
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    }
    
    # Создание действия
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $scriptArguments
    
    # Создание триггера (запуск каждые X минут)
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes) -RepetitionDuration ([TimeSpan]::MaxValue)
    
    # Настройки задачи
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable -WakeToRun
    
    # Создание задачи
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    
    # Регистрация задачи
    try {
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force
        
        Write-ColorMessage "Задача '$taskName' успешно создана." -Color Green
        Write-ColorMessage "Интервал запуска: каждые $IntervalMinutes минут" -Color Green
        Write-ColorMessage "Принудительный перезапуск: $(if ($Force) { 'Включен' } else { 'Отключен' })" -Color Green
        Write-ColorMessage "Уведомления: $(if ($EnableNotifications) { 'Включены' } else { 'Отключены' })" -Color Green
        
        return $true
    } catch {
        Write-ColorMessage "Ошибка при создании задачи: $_" -Color Red
        return $false
    }
}

# Функция для удаления задачи из планировщика задач Windows
function Uninstall-ScheduledTask {
    # Проверка прав администратора
    if (-not (Test-Administrator)) {
        Write-ColorMessage "Для удаления задачи из планировщика требуются права администратора." -Color Red
        Write-ColorMessage "Пожалуйста, запустите скрипт от имени администратора." -Color Red
        return $false
    }
    
    # Имя задачи
    $taskName = "GeoServerMonitoring"
    
    # Проверка существования задачи
    $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    
    if ($existingTask) {
        try {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
            Write-ColorMessage "Задача '$taskName' успешно удалена." -Color Green
            return $true
        } catch {
            Write-ColorMessage "Ошибка при удалении задачи: $_" -Color Red
            return $false
        }
    } else {
        Write-ColorMessage "Задача '$taskName' не найдена." -Color Yellow
        return $true
    }
}

# Функция для проверки статуса задачи
function Get-ScheduledTaskStatus {
    # Имя задачи
    $taskName = "GeoServerMonitoring"
    
    # Проверка существования задачи
    $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    
    if ($existingTask) {
        $taskInfo = Get-ScheduledTaskInfo -TaskName $taskName
        
        Write-ColorMessage "=== Статус задачи мониторинга GeoServer ===" -Color Magenta
        Write-ColorMessage "Имя задачи: $taskName" -Color Cyan
        Write-ColorMessage "Статус: $($existingTask.State)" -Color $(if ($existingTask.State -eq "Running") { "Green" } elseif ($existingTask.State -eq "Ready") { "Green" } else { "Yellow" })
        Write-ColorMessage "Последний запуск: $(if ($taskInfo.LastRunTime -eq [DateTime]::MinValue) { 'Никогда' } else { $taskInfo.LastRunTime })" -Color Cyan
        Write-ColorMessage "Следующий запуск: $(if ($taskInfo.NextRunTime -eq [DateTime]::MinValue) { 'Не запланирован' } else { $taskInfo.NextRunTime })" -Color Cyan
        Write-ColorMessage "Результат последнего запуска: $(if ($taskInfo.LastTaskResult -eq 0) { 'Успешно' } else { "Ошибка (код $($taskInfo.LastTaskResult))" })" -Color $(if ($taskInfo.LastTaskResult -eq 0) { "Green" } elseif ($taskInfo.LastTaskResult -eq 267009) { "Yellow" } else { "Red" })
        
        # Получение информации о триггере
        $triggerInfo = $existingTask.Triggers | Where-Object { $_ -is [Microsoft.Management.Infrastructure.CimInstance] }
        if ($triggerInfo -and $triggerInfo.Repetition.Interval) {
            $interval = $triggerInfo.Repetition.Interval
            if ($interval -match "PT(\d+)M") {
                $minutes = [int]$Matches[1]
                Write-ColorMessage "Интервал запуска: Каждые $minutes минут" -Color Cyan
            } else {
                Write-ColorMessage "Интервал запуска: $interval" -Color Cyan
            }
        }
        
        # Получение информации о действии
        $actionInfo = $existingTask.Actions | Where-Object { $_ -is [Microsoft.Management.Infrastructure.CimInstance] }
        if ($actionInfo) {
            Write-ColorMessage "Команда: $($actionInfo.Execute) $($actionInfo.Arguments)" -Color Cyan
            
            # Анализ аргументов для определения параметров
            $forceEnabled = $actionInfo.Arguments -match "-Force"
            $notifyEnabled = $actionInfo.Arguments -match "-NotifyOnRestart"
            
            Write-ColorMessage "Принудительный перезапуск: $(if ($forceEnabled) { 'Включен' } else { 'Отключен' })" -Color Cyan
            Write-ColorMessage "Уведомления: $(if ($notifyEnabled) { 'Включены' } else { 'Отключены' })" -Color Cyan
        }
        
        return $true
    } else {
        Write-ColorMessage "Задача '$taskName' не найдена в планировщике задач." -Color Yellow
        return $false
    }
}

# Функция для проверки наличия скрипта restart-geoserver-instances.ps1
function Test-RestartScript {
    $scriptPath = Join-Path -Path $PSScriptRoot -ChildPath "restart-geoserver-instances.ps1"
    
    if (Test-Path -Path $scriptPath) {
        Write-ColorMessage "Скрипт restart-geoserver-instances.ps1 найден." -Color Green
        return $true
    } else {
        Write-ColorMessage "Скрипт restart-geoserver-instances.ps1 не найден по пути: $scriptPath" -Color Red
        Write-ColorMessage "Пожалуйста, убедитесь, что скрипт существует перед настройкой расписания." -Color Red
        return $false
    }
}

# Основная функция
function Main {
    Write-ColorMessage "=== Настройка расписания мониторинга GeoServer ===" -Color Magenta
    Write-ColorMessage "Действие: $Action" -Color Yellow
    
    # Проверка наличия скрипта restart-geoserver-instances.ps1
    if (-not (Test-RestartScript) -and $Action -ne "Status" -and $Action -ne "Uninstall") {
        return
    }
    
    # Выполнение действия
    switch ($Action) {
        "Install" {
            Write-ColorMessage "Установка задачи мониторинга GeoServer..." -Color Yellow
            Write-ColorMessage "Интервал: $IntervalMinutes минут" -Color Yellow
            Write-ColorMessage "Уведомления: $(if ($EnableNotifications) { 'Включены' } else { 'Отключены' })" -Color Yellow
            Write-ColorMessage "Принудительный перезапуск: $(if ($Force) { 'Включен' } else { 'Отключен' })" -Color Yellow
            
            $result = Install-ScheduledTask -IntervalMinutes $IntervalMinutes -EnableNotifications:$EnableNotifications -Force:$Force
            
            if ($result) {
                Write-ColorMessage "Задача мониторинга GeoServer успешно установлена." -Color Green
            } else {
                Write-ColorMessage "Не удалось установить задачу мониторинга GeoServer." -Color Red
            }
        }
        "Uninstall" {
            Write-ColorMessage "Удаление задачи мониторинга GeoServer..." -Color Yellow
            
            $result = Uninstall-ScheduledTask
            
            if ($result) {
                Write-ColorMessage "Задача мониторинга GeoServer успешно удалена." -Color Green
            } else {
                Write-ColorMessage "Не удалось удалить задачу мониторинга GeoServer." -Color Red
            }
        }
        "Status" {
            Get-ScheduledTaskStatus
        }
    }
}

# Запуск основной функции
Main 