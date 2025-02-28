# Скрипт для автоматизации обновления storybook.md
# update-storybook.ps1
param (
    [Parameter(Mandatory=$true)]
    [string]$TaskName,

    [Parameter(Mandatory=$true)]
    [string]$Comment,

    [Parameter(Mandatory=$false)]
    [string]$Status = "✅",

    [Parameter(Mandatory=$false)]
    [string]$StorybookPath = "docs/storybook.md"
)

# Функция для текущей даты в формате [DD.MM.YYYY]
function Get-FormattedDate {
    return "[" + (Get-Date -Format "dd.MM.yyyy") + "]"
}

Write-Host "Запуск обновления storybook..." -ForegroundColor Cyan
Write-Host "TaskName: $TaskName" -ForegroundColor White
Write-Host "Comment: $Comment" -ForegroundColor White
Write-Host "Status: $Status" -ForegroundColor White
Write-Host "StorybookPath: $StorybookPath" -ForegroundColor White

# Проверка существования файла storybook.md
if (-not (Test-Path $StorybookPath)) {
    Write-Error "Файл $StorybookPath не найден. Проверьте путь и повторите попытку."
    exit 1
}

try {
    # Чтение содержимого файла
    $content = Get-Content $StorybookPath -Raw

    # Поиск раздела "Журнал работ"
    $journalSectionPattern = '## 📒 Журнал работ[\s\S]*?\| Дата \| Задача \| Статус \| Комментарии \|[\s\S]*?\|[-]+\|[-]+\|[-]+\|[-]+\|'
    if ($content -match $journalSectionPattern) {
        Write-Host "Найден раздел журнала работ." -ForegroundColor Green
        $journalSection = $matches[0]
        
        # Создание новой записи
        $date = Get-FormattedDate
        $newEntry = "| $date | $TaskName | $Status | $Comment |`n"
        
        # Вставка новой записи после таблицы заголовков
        $updatedContent = $content -replace '(\| Дата \| Задача \| Статус \| Комментарии \|[\s\S]*?\|[-]+\|[-]+\|[-]+\|[-]+\|)', "`$1`n$newEntry"
        
        # Запись обновленного содержимого в файл
        Set-Content -Path $StorybookPath -Value $updatedContent -Encoding UTF8
        
        Write-Host "Запись успешно добавлена в storybook!" -ForegroundColor Green
        Write-Host "Добавлено: $date | $TaskName | $Status | $Comment" -ForegroundColor Cyan
    }
    else {
        Write-Error "Не найден раздел 'Журнал работ' в файле $StorybookPath."
        exit 1
    }
}
catch {
    Write-Error "Произошла ошибка при обновлении storybook: $_"
    exit 1
}

# Примеры использования:
# ./scripts/update-storybook.ps1 -TaskName "Оптимизация запросов к PostGIS" -Comment "Улучшена производительность запросов к геометрическим данным"
# ./scripts/update-storybook.ps1 -TaskName "Исправление ошибки аутентификации" -Comment "Решена проблема с аутентификацией в GeoServer" -Status "✅"
# ./scripts/update-storybook.ps1 -TaskName "Доработка UI компонентов" -Comment "В процессе реализации улучшений интерфейса" -Status "🔄" 