# Мониторинг и автоматический перезапуск GeoServer

В данном документе описаны инструменты для мониторинга и автоматического перезапуска инстанций GeoServer в Corporate GIS Platform.

## Обзор

Corporate GIS Platform использует две отдельные инстанции GeoServer для оптимальной работы с разными типами геоданных:

1. **Vector GeoServer** - оптимизирован для работы с векторными данными (шейп-файлы, PostGIS и т.д.)
2. **ECW GeoServer** - оптимизирован для работы с растровыми данными в формате ECW

Для обеспечения высокой доступности этих сервисов разработаны специальные инструменты мониторинга и автоматического перезапуска.

## Инструменты мониторинга

### 1. Скрипт проверки маршрутизации (`check-geoserver-routing.ps1`)

Скрипт проверяет корректность маршрутизации запросов к разным инстанциям GeoServer через NGINX.

```powershell
# Базовая проверка
.\scripts\check-geoserver-routing.ps1

# Проверка с выводом подробной информации
.\scripts\check-geoserver-routing.ps1 -Verbose

# Проверка с автоматическим исправлением проблем
.\scripts\check-geoserver-routing.ps1 -Fix
```

### 2. Скрипт тестирования WMS-сервисов (`test-wms-services.ps1`)

Скрипт проверяет доступность WMS-сервисов обеих инстанций GeoServer и создает тестовые запросы GetMap.

```powershell
# Базовое тестирование
.\scripts\test-wms-services.ps1

# Тестирование с генерацией HTML-отчета
.\scripts\test-wms-services.ps1 -GenerateHtml

# Тестирование с открытием результатов
.\scripts\test-wms-services.ps1 -GenerateHtml -OpenResults
```

### 3. Скрипт перезапуска GeoServer (`restart-geoserver-instances.ps1`)

Скрипт проверяет состояние инстанций GeoServer и автоматически перезапускает их при необходимости.

```powershell
# Проверка и перезапуск при необходимости
.\scripts\restart-geoserver-instances.ps1

# Принудительный перезапуск всех инстанций
.\scripts\restart-geoserver-instances.ps1 -Force

# Проверка и перезапуск только Vector GeoServer
.\scripts\restart-geoserver-instances.ps1 -InstanceType "vector"

# Проверка и перезапуск только ECW GeoServer
.\scripts\restart-geoserver-instances.ps1 -InstanceType "ecw"

# Тестовый режим без фактического перезапуска
.\scripts\restart-geoserver-instances.ps1 -DryRun

# Отправка уведомлений при перезапуске
.\scripts\restart-geoserver-instances.ps1 -NotifyOnRestart
```

### 4. Скрипт настройки расписания мониторинга (`schedule-geoserver-monitoring.ps1`)

Скрипт для настройки автоматического мониторинга и перезапуска GeoServer по расписанию.

```powershell
# Проверка текущего статуса задачи мониторинга
.\scripts\schedule-geoserver-monitoring.ps1 -Action Status

# Установка задачи мониторинга (каждые 15 минут)
.\scripts\schedule-geoserver-monitoring.ps1 -Action Install -IntervalMinutes 15

# Установка задачи мониторинга с уведомлениями
.\scripts\schedule-geoserver-monitoring.ps1 -Action Install -EnableNotifications

# Установка задачи мониторинга с принудительным перезапуском
.\scripts\schedule-geoserver-monitoring.ps1 -Action Install -Force

# Удаление задачи мониторинга
.\scripts\schedule-geoserver-monitoring.ps1 -Action Uninstall
```

## Подробное описание скриптов

### Скрипт перезапуска GeoServer (`restart-geoserver-instances.ps1`)

#### Параметры

| Параметр | Тип | Описание | Значение по умолчанию |
|----------|-----|----------|----------------------|
| `-Force` | switch | Принудительный перезапуск без проверки | `$false` |
| `-Verbose` | switch | Подробный вывод | `$false` |
| `-DryRun` | switch | Режим без фактического перезапуска (только проверка) | `$false` |
| `-MaxRetries` | int | Максимальное количество попыток перезапуска | `3` |
| `-RetryDelay` | int | Задержка между попытками в секундах | `30` |
| `-InstanceType` | string | Тип инстанции: "vector", "ecw" или "all" | `"all"` |
| `-NotifyOnRestart` | switch | Отправлять уведомление при перезапуске | `$false` |

#### Алгоритм работы

1. **Проверка состояния контейнеров**:
   - Проверка статуса контейнера (running, stopped, etc.)
   - Проверка здоровья контейнера (healthy, unhealthy)

2. **Проверка доступности сервисов**:
   - Проверка доступности веб-интерфейса GeoServer
   - Проверка доступности WMS-сервиса
   - Проверка доступности через NGINX

3. **Принятие решения о перезапуске**:
   - Если указан параметр `-Force`, перезапуск выполняется безусловно
   - Если контейнер не запущен или имеет статус unhealthy
   - Если веб-интерфейс или WMS-сервис недоступны

4. **Перезапуск**:
   - Выполняется до `MaxRetries` попыток перезапуска
   - Между попытками выдерживается пауза `RetryDelay` секунд
   - После перезапуска проверяется доступность сервисов

5. **Уведомления**:
   - Если указан параметр `-NotifyOnRestart`, отправляется уведомление о перезапуске
   - В уведомлении указывается статус сервисов после перезапуска

### Скрипт настройки расписания мониторинга (`schedule-geoserver-monitoring.ps1`)

#### Параметры

| Параметр | Тип | Описание | Значение по умолчанию |
|----------|-----|----------|----------------------|
| `-Action` | string | Действие: "Install", "Uninstall", "Status" | `"Status"` |
| `-IntervalMinutes` | int | Интервал запуска в минутах | `15` |
| `-EnableNotifications` | switch | Включить уведомления при перезапуске | `$false` |
| `-Force` | switch | Включить принудительный перезапуск | `$false` |

#### Алгоритм работы

1. **Проверка прав администратора**:
   - Для установки и удаления задач в планировщике требуются права администратора

2. **Проверка наличия скрипта перезапуска**:
   - Проверяется наличие файла `restart-geoserver-instances.ps1`

3. **Управление задачей в планировщике**:
   - **Install**: Создание задачи в планировщике задач Windows
   - **Uninstall**: Удаление задачи из планировщика
   - **Status**: Отображение текущего статуса задачи

4. **Настройка параметров задачи**:
   - Интервал запуска (каждые X минут)
   - Передача параметров скрипту перезапуска (Force, NotifyOnRestart)
   - Настройка запуска от имени SYSTEM с повышенными привилегиями

## Рекомендации по использованию

### Рекомендуемые настройки для продакшена

1. **Интервал мониторинга**:
   - Рекомендуемый интервал: 15-30 минут
   - Слишком частые проверки могут создавать дополнительную нагрузку
   - Слишком редкие проверки увеличивают время простоя при сбоях

2. **Уведомления**:
   - Рекомендуется включить уведомления для оперативного реагирования
   - Настройте отправку уведомлений на email или в корпоративный мессенджер

3. **Принудительный перезапуск**:
   - В продакшене рекомендуется отключить принудительный перезапуск
   - Перезапуск должен выполняться только при реальных проблемах

### Настройка уведомлений

Для настройки отправки уведомлений необходимо отредактировать функцию `Send-Notification` в скрипте `restart-geoserver-instances.ps1`:

1. **Email-уведомления**:
   ```powershell
   $smtpServer = "smtp.your-company.com"
   $smtpPort = 587
   $smtpUser = "alerts@your-company.com"
   $smtpPassword = "your-password"
   $from = "GIS Platform Alerts <alerts@your-company.com>"
   $to = "admin@your-company.com"
   
   $securePassword = ConvertTo-SecureString $smtpPassword -AsPlainText -Force
   $credential = New-Object System.Management.Automation.PSCredential($smtpUser, $securePassword)
   
   Send-MailMessage -From $from -To $to -Subject $Subject -Body $Message -SmtpServer $smtpServer -Port $smtpPort -Credential $credential -UseSsl
   ```

2. **Slack-уведомления**:
   ```powershell
   $slackWebhookUrl = "https://hooks.slack.com/services/TXXXXXXXX/BXXXXXXXX/XXXXXXXXXXXXXXXXXXXXXXXX"
   $payload = @{
       text = "$Subject`n$Message"
       username = "GeoServer Monitor"
       icon_emoji = ":warning:"
   } | ConvertTo-Json
   
   Invoke-RestMethod -Uri $slackWebhookUrl -Method Post -Body $payload -ContentType "application/json"
   ```

3. **Teams-уведомления**:
   ```powershell
   $teamsWebhookUrl = "https://outlook.office.com/webhook/XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX@XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX/IncomingWebhook/XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX/XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
   $payload = @{
       "@type" = "MessageCard"
       "@context" = "http://schema.org/extensions"
       "summary" = $Subject
       "themeColor" = "0078D7"
       "title" = $Subject
       "text" = $Message
   } | ConvertTo-Json
   
   Invoke-RestMethod -Uri $teamsWebhookUrl -Method Post -Body $payload -ContentType "application/json"
   ```

## Устранение неполадок

### Распространенные проблемы

1. **Ошибка "Access denied" при установке задачи**:
   - Запустите PowerShell от имени администратора
   - Проверьте политику выполнения скриптов: `Get-ExecutionPolicy`
   - При необходимости измените политику: `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`

2. **Задача не запускается по расписанию**:
   - Проверьте журнал событий Windows (Event Viewer)
   - Убедитесь, что служба планировщика задач запущена
   - Проверьте настройки задачи в планировщике задач

3. **Скрипт перезапуска не может перезапустить контейнер**:
   - Убедитесь, что Docker запущен
   - Проверьте права доступа пользователя, от имени которого запускается задача
   - Проверьте логи Docker: `docker logs geoserver-vector`

### Проверка логов

```powershell
# Проверка логов планировщика задач
Get-WinEvent -LogName "Microsoft-Windows-TaskScheduler/Operational" | Where-Object { $_.Message -like "*GeoServerMonitoring*" } | Select-Object TimeCreated, Message -First 10

# Проверка логов Docker
docker logs geoserver-vector --tail 50
docker logs geoserver-ecw --tail 50
docker logs dev-nginx-1 --tail 50
```

## Дополнительная информация

- [Документация по маршрутизации GeoServer](./geoserver-routing.md)
- [Руководство администратора](./admin-guide.md)
- [PowerShell инструменты](./powershell-tools.md) 