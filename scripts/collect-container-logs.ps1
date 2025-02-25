<#
.SYNOPSIS
    Скрипт для сбора и анализа логов из контейнеров Docker.
    
.DESCRIPTION
    Собирает логи из всех запущенных контейнеров, фильтрует сообщения об ошибках и предупреждениях,
    удаляет дубликаты и выводит результаты в структурированном виде.
    
.PARAMETER Lines
    Количество строк для извлечения из логов каждого контейнера (по умолчанию: 1000).
    
.PARAMETER OutputFile
    Путь к файлу для сохранения результатов (по умолчанию: logs/container-errors.log).
    
.PARAMETER IncludeInfo
    Включает информационные сообщения в дополнение к ошибкам и предупреждениям.
    
.PARAMETER NoConsoleOutput
    Отключает вывод результатов в консоль.
    
.PARAMETER Since
    Получает логи с указанной даты/времени. Пример: "2023-01-01T00:00:00" или "1h" (последний час).
    
.EXAMPLE
    ./scripts/collect-container-logs.ps1 -Lines 500 -Since "1h"
    
.NOTES
    Файл: collect-container-logs.ps1
    Автор: Корпоративная ГИС-платформа
    Версия: 1.0
#>

param (
    [Parameter(Mandatory=$false)]
    [int]$Lines = 1000,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputFile = "logs/container-errors.log",
    
    [Parameter(Mandatory=$false)]
    [switch]$IncludeInfo,
    
    [Parameter(Mandatory=$false)]
    [switch]$NoConsoleOutput,
    
    [Parameter(Mandatory=$false)]
    [string]$Since
)

# Функция для форматирования текста с цветами
function Format-Message {
    param (
        [string]$Message,
        [string]$ContainerName,
        [string]$Type
    )
    
    $colorTable = @{
        "ERROR" = "Red";
        "WARN" = "Yellow";
        "WARNING" = "Yellow";
        "INFO" = "Cyan";
        "DEBUG" = "Gray";
    }
    
    $color = $colorTable[$Type]
    if (-not $color) { $color = "White" }
    
    return @{
        Message = $Message;
        ContainerName = $ContainerName;
        Type = $Type;
        Color = $color;
    }
}

# Функция для определения типа сообщения
function Get-MessageType {
    param (
        [string]$Line
    )
    
    $lowercaseLine = $Line.ToLower()
    
    if ($lowercaseLine -match "error|exception|fail|fatal") {
        return "ERROR"
    }
    elseif ($lowercaseLine -match "warn") {
        return "WARN"
    }
    elseif ($lowercaseLine -match "info") {
        return "INFO"
    }
    else {
        return "DEBUG"
    }
}

# Создаем директорию для логов, если не существует
$logsDirectory = Split-Path -Path $OutputFile -Parent
if (-not (Test-Path $logsDirectory)) {
    New-Item -ItemType Directory -Force -Path $logsDirectory | Out-Null
    Write-Host "Создана директория для логов: $logsDirectory" -ForegroundColor Green
}

# Получение списка запущенных контейнеров
Write-Host "Получение списка запущенных контейнеров..." -ForegroundColor Cyan
$containers = docker ps --format "{{.Names}}" 2>$null

if (-not $containers) {
    Write-Host "Не найдено запущенных контейнеров!" -ForegroundColor Red
    exit 1
}

$containerCount = ($containers | Measure-Object).Count
Write-Host "Найдено контейнеров: $containerCount" -ForegroundColor Green

# Подготовка аргументов для docker logs
$logArgs = @()
if ($Lines -gt 0) {
    $logArgs += "--tail=$Lines"
}
if ($Since) {
    $logArgs += "--since=$Since"
}

# Создаем хэш-таблицу для хранения уникальных сообщений
$uniqueMessages = @{}
$formattedMessages = @()

# Сбор и анализ логов из контейнеров
foreach ($container in $containers) {
    Write-Host "Сбор логов из контейнера: $container" -ForegroundColor Cyan
    
    try {
        # Получение логов из контейнера
        $logs = docker logs $container $logArgs 2>&1
        
        if (-not $logs) {
            Write-Host "  Логи не найдены." -ForegroundColor Yellow
            continue
        }
        
        # Анализ каждой строки логов
        foreach ($line in $logs) {
            $lineContent = $line.ToString().Trim()
            if ([string]::IsNullOrWhiteSpace($lineContent)) { continue }
            
            # Определение типа сообщения
            $messageType = Get-MessageType -Line $lineContent
            
            # Фильтрация по типу сообщения
            if ($messageType -eq "ERROR" -or $messageType -eq "WARN" -or ($IncludeInfo -and $messageType -eq "INFO")) {
                # Использование хэш-функции для удаления дубликатов
                $hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash(
                    [System.Text.Encoding]::UTF8.GetBytes($lineContent)
                ) -join ""
                
                if (-not $uniqueMessages.ContainsKey($hash)) {
                    $uniqueMessages[$hash] = $true
                    $formattedMessage = Format-Message -Message $lineContent -ContainerName $container -Type $messageType
                    $formattedMessages += $formattedMessage
                }
            }
        }
    }
    catch {
        Write-Host "  Ошибка при сборе логов: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Сортировка сообщений по типу и контейнеру
$sortedMessages = $formattedMessages | Sort-Object -Property @{Expression = {$_.Type}; Descending = $true}, ContainerName

# Подготовка результатов для вывода
$resultContent = @()
$resultContent += "# Отчет по логам контейнеров - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$resultContent += "## Параметры сбора"
$resultContent += "- Количество строк: $Lines"
if ($Since) {
    $resultContent += "- Период: $Since"
}
$resultContent += "- Включение INFO-сообщений: $($IncludeInfo.ToString())"
$resultContent += "- Найдено контейнеров: $containerCount"

$errorCount = ($sortedMessages | Where-Object { $_.Type -eq "ERROR" } | Measure-Object).Count
$warnCount = ($sortedMessages | Where-Object { $_.Type -eq "WARN" } | Measure-Object).Count
$infoCount = ($sortedMessages | Where-Object { $_.Type -eq "INFO" } | Measure-Object).Count

$resultContent += "- Найдено уникальных сообщений: $($sortedMessages.Count) (Ошибок: $errorCount, Предупреждений: $warnCount, Информационных: $infoCount)"
$resultContent += ""

# Группировка сообщений по контейнеру и типу
$containerGroups = $sortedMessages | Group-Object -Property ContainerName

foreach ($containerGroup in $containerGroups) {
    $resultContent += "## Контейнер: $($containerGroup.Name)"
    
    $typeGroups = $containerGroup.Group | Group-Object -Property Type
    
    foreach ($typeGroup in $typeGroups) {
        $resultContent += "### $($typeGroup.Name) ($($typeGroup.Count))"
        
        foreach ($message in $typeGroup.Group) {
            $resultContent += "- $($message.Message)"
        }
        
        $resultContent += ""
    }
}

# Сохранение результатов в файл
$resultContent | Out-File -FilePath $OutputFile -Encoding utf8
Write-Host "Результаты сохранены в файл: $OutputFile" -ForegroundColor Green

# Вывод результатов в консоль
if (-not $NoConsoleOutput) {
    Write-Host "`n============== РЕЗУЛЬТАТЫ АНАЛИЗА ЛОГОВ ==============" -ForegroundColor Cyan
    Write-Host "Найдено уникальных сообщений: $($sortedMessages.Count)" -ForegroundColor Cyan
    Write-Host "Ошибок: $errorCount | Предупреждений: $warnCount | Информационных: $infoCount" -ForegroundColor Cyan
    
    foreach ($containerGroup in $containerGroups) {
        Write-Host "`nКонтейнер: $($containerGroup.Name)" -ForegroundColor Magenta
        
        $typeGroups = $containerGroup.Group | Group-Object -Property Type
        
        foreach ($typeGroup in $typeGroups) {
            Write-Host "  $($typeGroup.Name) ($($typeGroup.Count)):" -ForegroundColor $typeGroup.Group[0].Color
            
            foreach ($message in $typeGroup.Group) {
                Write-Host "    - $($message.Message)" -ForegroundColor $message.Color
            }
        }
    }
    
    Write-Host "`nПодробные результаты доступны в файле: $OutputFile" -ForegroundColor Green
}

# Возвращаем сводную статистику
return @{
    TotalContainers = $containerCount;
    TotalMessages = $sortedMessages.Count;
    ErrorCount = $errorCount;
    WarningCount = $warnCount;
    InfoCount = $infoCount;
} 