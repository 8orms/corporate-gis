# PowerShell инструменты для управления ГИС-платформой

В этом документе описаны PowerShell скрипты, предназначенные для управления корпоративной ГИС-платформой. Данные инструменты помогают автоматизировать типовые задачи администрирования, такие как инициализация проекта, управление ECW-файлами, мониторинг состояния системы и т.д.

## Основной скрипт управления: `manage-gis.ps1`

Этот скрипт предоставляет единую точку входа для всех операций по управлению ГИС-платформой. Он объединяет функциональность других скриптов и предоставляет удобный интерфейс командной строки.

### Использование

```powershell
./manage-gis.ps1 <команда> [аргументы]
```

### Доступные команды

| Команда | Описание | Примеры использования |
|---------|----------|------------------------|
| `init` | Инициализация проекта с созданием структуры каталогов и конфигурационных файлов | `./manage-gis.ps1 init dev` |
| `start` | Запуск контейнеров Docker | `./manage-gis.ps1 start` |
| `stop` | Остановка контейнеров Docker | `./manage-gis.ps1 stop` |
| `restart` | Перезапуск контейнеров Docker | `./manage-gis.ps1 restart` |
| `status` | Проверка статуса системы и вывод основных параметров | `./manage-gis.ps1 status` |
| `logs` | Просмотр логов контейнеров | `./manage-gis.ps1 logs geoserver-ecw` |
| `backup` | Создание резервной копии конфигурации | `./manage-gis.ps1 backup` |
| `manage-ecw` | Управление ECW файлами и проекциями | `./manage-gis.ps1 manage-ecw list` |
| `generate-config` | Генерация конфигурации слоев из метаданных | `./manage-gis.ps1 generate-config config/layer-registry.json` |
| `rebuild` | Полная пересборка системы с удалением томов | `./manage-gis.ps1 rebuild` |
| `check-layer-admin` | Проверка работоспособности Django-админки и реестра слоев | `./manage-gis.ps1 check-layer-admin` |
| `help` | Показать справку по командам | `./manage-gis.ps1 help` |

### Примеры использования

Инициализация проекта для разработки:
```powershell
./manage-gis.ps1 init dev
```

Запуск всех контейнеров:
```powershell
./manage-gis.ps1 start
```

Проверка состояния системы:
```powershell
./manage-gis.ps1 status
```

## Скрипт инициализации: `scripts/initialize-project.ps1`

Этот скрипт отвечает за начальную настройку проекта. Он создаёт структуру директорий, базовые конфигурационные файлы, файл `.gitignore`, настройки Docker и NGINX, а также простой веб-интерфейс.

### Использование

```powershell
./scripts/initialize-project.ps1 -Environment <dev|prod> [-Force]
```

### Параметры

- `-Environment <dev|prod>` - Окружение, для которого будет создана конфигурация (по умолчанию: dev)
- `-Force` - Принудительная перезапись существующих файлов

### Что делает скрипт

1. Проверяет наличие Docker, Docker Compose и Git
2. Создаёт структуру директорий для проекта
3. Создаёт файл `.gitignore`
4. Создаёт файлы `.env.example` и `.env`
5. Создаёт конфигурации Docker Compose для разработки и продакшена
6. Создаёт конфигурационные файлы NGINX
7. Создаёт базовый веб-интерфейс на основе OpenLayers

## Управление ECW файлами: `scripts/manage-ecw.ps1`

Этот скрипт предназначен для управления ECW файлами и пользовательскими проекциями, которые часто используются в ГИС-системах.

### Использование

```powershell
./scripts/manage-ecw.ps1 -Action <действие> [параметры]
```

### Доступные действия

| Действие | Описание | Параметры |
|----------|----------|-----------|
| `list` | Показать список ECW файлов и проекций | - |
| `import` | Импортировать ECW файл в директорию хранения | `-FilePath <путь_к_файлу>` |
| `register` | Зарегистрировать файл проекции | `-FilePath <путь_к_файлу>` |
| `move` | Переместить ECW файл внутри хранилища | `-FilePath <путь_к_файлу> -TargetPath <путь_назначения>` |
| `help` | Показать справку | - |

### Параметры скрипта

- `-Action` - Действие, которое нужно выполнить
- `-FilePath` - Путь к исходному файлу
- `-TargetPath` - Путь назначения (для перемещения)
- `-Force` - Принудительная перезапись существующих файлов

### Примеры использования

Просмотр списка ECW файлов и проекций:
```powershell
./scripts/manage-ecw.ps1 -Action list
```

Импорт ECW файла:
```powershell
./scripts/manage-ecw.ps1 -Action import -FilePath D:/maps/city_map.ecw
```

Регистрация файла проекции:
```powershell
./scripts/manage-ecw.ps1 -Action register -FilePath D:/projections/custom.prj
```

Перемещение ECW файла:
```powershell
./scripts/manage-ecw.ps1 -Action move -FilePath data/raster-storage/ecw/old_map.ecw -TargetPath data/raster-storage/ecw/archive/
```

## Проверка здоровья системы: `scripts/check-health.ps1`

Этот скрипт проверяет состояние всех сервисов ГИС-платформы и выводит подробную информацию о работоспособности системы.

### Использование

```powershell
./scripts/check-health.ps1 [-Verbose] [-FixProblems]
```

### Параметры

- `-Verbose` - Вывод более подробной информации
- `-FixProblems` - Попытка автоматического исправления обнаруженных проблем

### Что проверяет скрипт

1. Состояние контейнеров Docker
2. Доступность веб-сервисов через HTTP
3. Подключение к PostGIS
4. Использование дискового пространства
5. Наличие и размер ECW файлов

## Проверка работы Django-админки: `scripts/Check-LayerAdmin.ps1`

Этот скрипт проверяет работоспособность Django-админки с реестром слоев. Он выполняет несколько проверок:
1. Проверяет доступность Django-админки через HTTP
2. Проверяет доступность API для работы с реестром слоев
3. Проверяет наличие JSON-файла с метаданными слоев

### Использование

```powershell
# Запуск через основной скрипт управления
./manage-gis.ps1 check-layer-admin

# Прямой запуск скрипта
./scripts/Check-LayerAdmin.ps1
```

### Что проверяет скрипт

Скрипт выполняет следующие проверки:
- Доступность Django-сервера по адресу `http://localhost:8000/admin/`
- Доступность API реестра слоев по адресу `http://localhost:8000/admin/data_manager/layer/`
- Наличие файла JSON-реестра слоев по пути `config/layer-registry.json`

### Интеграция с Docker

Скрипт интегрирован с системой проверки здоровья Docker (healthcheck) для контейнера Django. В Linux-окружении используется аналогичный скрипт `check-layer-admin.sh`.

## Создание структуры директорий: `scripts/create-directories.ps1`

Этот скрипт создаёт базовую структуру директорий для проекта. Он может использоваться как отдельно, так и вызываться из скрипта инициализации.

### Использование

```powershell
./scripts/create-directories.ps1
```

## Рекомендации по использованию

### Начало работы с проектом

1. Выполните инициализацию проекта:
   ```powershell
   ./manage-gis.ps1 init dev
   ```

2. Запустите контейнеры:
   ```powershell
   ./manage-gis.ps1 start
   ```

3. Проверьте статус системы:
   ```powershell
   ./manage-gis.ps1 status
   ```

### Регулярное обслуживание

1. Проверяйте состояние системы:
   ```powershell
   ./manage-gis.ps1 status
   ```

2. Создавайте регулярные резервные копии:
   ```powershell
   ./manage-gis.ps1 backup
   ```

3. При необходимости управляйте ECW файлами:
   ```powershell
   ./manage-gis.ps1 manage-ecw list
   ```

### Устранение неполадок

1. Проверьте логи сервисов:
   ```powershell
   ./manage-gis.ps1 logs
   ```

2. Запустите проверку здоровья с попыткой исправления:
   ```powershell
   ./scripts/check-health.ps1 -FixProblems
   ```

3. Перезапустите проблемные сервисы:
   ```powershell
   ./manage-gis.ps1 restart
   ```

## Интеграция с CI/CD

Описанные инструменты можно интегрировать в процессы непрерывной интеграции и доставки (CI/CD). Для этого можно использовать скрипты в неинтерактивном режиме с предопределёнными параметрами.

Например, для инициализации проекта в CI/CD пайплайне:
```powershell
./scripts/initialize-project.ps1 -Environment prod -Force
```

## Расширение функциональности

Инструменты спроектированы модульно, что позволяет легко добавлять новые функции. Для добавления нового функционала рекомендуется:

1. Создать отдельный скрипт в папке `scripts/`
2. Добавить вызов этого скрипта в общий скрипт управления `manage-gis.ps1`
3. Обновить документацию 

### Сбор и анализ логов контейнеров

Для сбора и анализа логов из всех контейнеров выполните:
```powershell
# Базовое использование
./scripts/collect-container-logs.ps1

# Получение логов за последний час
./scripts/collect-container-logs.ps1 -Since "1h"

# Сбор последних 500 строк с включением информационных сообщений
./scripts/collect-container-logs.ps1 -Lines 500 -IncludeInfo

# Сохранение результатов в указанный файл
./scripts/collect-container-logs.ps1 -OutputFile "logs/debug/containers.log"
```

Скрипт выполняет следующие операции:
1. Получает список всех запущенных контейнеров
2. Собирает логи из каждого контейнера
3. Фильтрует ошибки и предупреждения (опционально - информационные сообщения)
4. Удаляет дубликаты сообщений
5. Группирует сообщения по контейнерам и типам
6. Сохраняет результаты в файл и выводит на экран

Это позволяет быстро выявлять проблемы во всей инфраструктуре, не просматривая логи каждого контейнера в отдельности. 

## Общая информация

Все скрипты находятся в директории `scripts/` и могут быть запущены как напрямую, так и через основной скрипт управления `manage-gis.ps1`.

## Основной скрипт управления

### manage-gis.ps1

Основной скрипт для управления ГИС-платформой, который предоставляет единый интерфейс для всех операций.

```powershell
# Инициализация проекта
./manage-gis.ps1 init [dev|prod]

# Запуск и остановка сервисов
./manage-gis.ps1 start
./manage-gis.ps1 stop
./manage-gis.ps1 restart

# Проверка состояния
./manage-gis.ps1 status
./manage-gis.ps1 test

# Управление данными
./manage-gis.ps1 manage-ecw [list|import|register|move]
./manage-gis.ps1 setup-projections

# Обслуживание
./manage-gis.ps1 logs [service_name]
./manage-gis.ps1 backup
./manage-gis.ps1 collect-logs
./manage-gis.ps1 check-redirects
```

## Скрипты инициализации и настройки

### initialize-project.ps1

Скрипт для инициализации проекта, создания структуры директорий и настройки базовых компонентов.

**Параметры:**
- `-Environment <String>` - Окружение для инициализации (dev или prod)
- `-Force` - Принудительная инициализация (с перезаписью существующих файлов)

**Пример использования:**
```powershell
./scripts/initialize-project.ps1 -Environment dev
```

**Действия:**
1. Создает структуру директорий
2. Настраивает Docker Compose для выбранного окружения
3. Создает конфигурации NGINX
4. Создает базовый веб-интерфейс

### setup-projections.ps1

Скрипт для настройки пользовательских проекций в GeoServer.

**Параметры:**
- `-ForceRecreate` - Принудительное пересоздание директории проекций

**Пример использования:**
```powershell
./scripts/setup-projections.ps1
```

**Действия:**
1. Проверяет наличие директории для пользовательских проекций
2. Создает директорию, если она отсутствует
3. Создает пустой файл epsg.properties, если он отсутствует
4. Отображает информацию о настройке пользовательских проекций

## Скрипты управления данными

### manage-ecw.ps1

Скрипт для управления ECW файлами в Корпоративной ГИС-платформе.

**Команды:**
- `list` - Отображает список всех ECW файлов
- `import` - Импортирует ECW файл в систему
- `register` - Регистрирует файл проекции
- `move` - Перемещает ECW файл в директорию хранения

**Параметры:**
- `-FilePath <String>` - Путь к файлу для импорта/регистрации
- `-DestDir <String>` - Директория назначения (для команды move)

**Примеры использования:**
```powershell
# Список файлов
./scripts/manage-ecw.ps1 list

# Импорт ECW файла
./scripts/manage-ecw.ps1 import -FilePath C:\path\to\file.ecw

# Регистрация файла проекции
./scripts/manage-ecw.ps1 register -FilePath C:\path\to\file.prj
```

## Скрипты мониторинга и обслуживания

### check-health.ps1

Скрипт для проверки работоспособности всех компонентов ГИС-платформы.

**Параметры:**
- `-AutoFix` - Автоматическое исправление обнаруженных проблем
- `-Verbose` - Подробный вывод информации

**Пример использования:**
```powershell
./scripts/check-health.ps1 -Verbose
```

**Проверки:**
1. Статус контейнеров Docker
2. Доступность веб-сервисов
3. Наличие пользовательских проекций
4. Корректность конфигурации NGINX

### collect-container-logs.ps1

Скрипт для сбора и анализа логов из всех Docker-контейнеров.

**Параметры:**
- `-Lines <Int32>` - Количество строк логов для извлечения (по умолчанию 1000)
- `-OutputFile <String>` - Путь для сохранения результатов (по умолчанию logs/container-errors.log)
- `-IncludeInfo` - Включать информационные сообщения
- `-NoConsoleOutput` - Не выводить результаты в консоль
- `-Since <String>` - Извлекать логи с указанного времени (например, "2h" - за последние 2 часа)

**Пример использования:**
```powershell
# Базовый сбор логов
./scripts/collect-container-logs.ps1

# Расширенный сбор логов
./scripts/collect-container-logs.ps1 -Lines 2000 -IncludeInfo -Since "6h"
```

**Действия:**
1. Получает список всех запущенных контейнеров
2. Извлекает логи из каждого контейнера
3. Фильтрует логи по уровням (ERROR, WARN, INFO)
4. Удаляет дубликаты для повышения читаемости
5. Сохраняет результаты в файл и/или выводит в консоль

### check-geoserver-redirect.ps1

Скрипт для диагностики и исправления проблем с редиректами GeoServer через NGINX прокси.

**Параметры:**
- `-Test` - Только тестирование без внесения изменений
- `-Fix` - Автоматическое исправление обнаруженных проблем
- `-Verbose` - Подробный вывод процесса диагностики

**Пример использования:**
```powershell
# Тестирование конфигурации
./scripts/check-geoserver-redirect.ps1 -Test

# Автоматическое исправление проблем
./scripts/check-geoserver-redirect.ps1 -Fix
```

**Проверки:**
1. Конфигурация NGINX (location блоки, заголовки, настройки редиректов)
2. Конфигурация GeoServer (параметры CATALINA_OPTS)
3. URL маршрутизация (доступность различных URL)
4. Заголовки и редиректы (анализ заголовков HTTP)

**Действия при исправлении:**
1. Создает резервные копии всех изменяемых файлов
2. Исправляет некорректные настройки в конфигурации NGINX
3. Обновляет параметры CATALINA_OPTS для GeoServer
4. Перезапускает соответствующие сервисы для применения изменений 

## Планируемые инструменты для компромиссной модернизации

В рамках компромиссной модернизации платформы будут разработаны дополнительные PowerShell инструменты для управления новыми компонентами системы:

### 1. `scripts/update-django-admin.ps1` - Управление Django-админкой

```powershell
# Скрипт для управления Django-административной панелью

param (
    [Parameter(Mandatory=$true)]
    [ValidateSet("init", "update", "backup", "migrate", "create-superuser", "collect-static", "restart")]
    [string]$Command,
    
    [Parameter(Mandatory=$false)]
    [string]$Username,
    
    [Parameter(Mandatory=$false)]
    [string]$Email,
    
    [Parameter(Mandatory=$false)]
    [string]$Password,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force
)

# Функция для инициализации Django-проекта
function Initialize-DjangoProject {
    Write-Host "Инициализация Django-проекта..."
    # Проверка наличия директории
    if (-not (Test-Path "src/admin-panel")) {
        New-Item -Path "src/admin-panel" -ItemType Directory -Force | Out-Null
    }
    
    # Создание Dockerfile
    @"
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
"@ | Set-Content -Path "src/admin-panel/Dockerfile" -Encoding UTF8
    
    # Создание requirements.txt
    @"
Django==4.2.10
djangorestframework==3.14.0
django-filter==23.5
psycopg2-binary==2.9.9
django-cors-headers==4.3.1
django-extensions==3.2.3
django-environ==0.11.2
django-geonode-client==1.0.0
django-allauth==0.60.1
"@ | Set-Content -Path "src/admin-panel/requirements.txt" -Encoding UTF8
    
    # Запуск Docker контейнера для инициализации проекта
    docker run --rm -v ${PWD}/src/admin-panel:/app python:3.11-slim bash -c "
        pip install Django==4.2.10 &&
        django-admin startproject gis_admin . &&
        python manage.py startapp core &&
        python manage.py startapp geoserver_connector &&
        python manage.py startapp data_manager
    "
    
    Write-Host "Django-проект успешно инициализирован в директории src/admin-panel" -ForegroundColor Green
}

# Функция для создания суперпользователя Django
function Create-Superuser {
    param (
        [string]$Username,
        [string]$Email,
        [string]$Password
    )
    
    if (-not $Username) { $Username = Read-Host "Введите имя пользователя" }
    if (-not $Email) { $Email = Read-Host "Введите email" }
    if (-not $Password) { $Password = Read-Host "Введите пароль" -AsSecureString }
    
    # Преобразование SecureString в обычную строку
    if ($Password -is [System.Security.SecureString]) {
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
        $Password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
    }
    
    # Создание суперпользователя
    $script = @"
from django.contrib.auth import get_user_model;
User = get_user_model();
if not User.objects.filter(username='$Username').exists():
    User.objects.create_superuser('$Username', '$Email', '$Password');
    print('Суперпользователь создан');
else:
    print('Пользователь уже существует');
"@
    
    docker exec gis-admin python manage.py shell -c "$script"
    Write-Host "Операция создания суперпользователя завершена" -ForegroundColor Green
}

# Функция для миграции базы данных
function Migrate-Database {
    Write-Host "Выполнение миграции базы данных..."
    docker exec gis-admin python manage.py makemigrations
    docker exec gis-admin python manage.py migrate
    Write-Host "Миграция базы данных завершена успешно" -ForegroundColor Green
}

# Функция для сбора статических файлов
function Collect-Static {
    Write-Host "Сбор статических файлов..."
    docker exec gis-admin python manage.py collectstatic --no-input
    Write-Host "Сбор статических файлов завершен успешно" -ForegroundColor Green
}

# Основная логика скрипта
switch ($Command) {
    "init" {
        Initialize-DjangoProject
    }
    "update" {
        Write-Host "Обновление Django-приложения..."
        docker-compose build django
        docker-compose restart django
        Write-Host "Django-приложение обновлено" -ForegroundColor Green
    }
    "backup" {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupDir = "backups/django_$timestamp"
        
        Write-Host "Создание резервной копии Django-проекта в $backupDir..."
        New-Item -Path $backupDir -ItemType Directory -Force | Out-Null
        
        # Создание дампа базы данных
        docker exec postgis pg_dump -U postgres gis > "$backupDir/database.sql"
        
        # Копирование файлов проекта
        Copy-Item -Path "src/admin-panel" -Destination "$backupDir/admin-panel" -Recurse
        Copy-Item -Path "media" -Destination "$backupDir/media" -Recurse -ErrorAction SilentlyContinue
        Copy-Item -Path "static" -Destination "$backupDir/static" -Recurse -ErrorAction SilentlyContinue
        
        Write-Host "Резервная копия создана в директории $backupDir" -ForegroundColor Green
    }
    "migrate" {
        Migrate-Database
    }
    "create-superuser" {
        Create-Superuser -Username $Username -Email $Email -Password $Password
    }
    "collect-static" {
        Collect-Static
    }
    "restart" {
        Write-Host "Перезапуск Django-контейнера..."
        docker-compose restart django
        Write-Host "Django-контейнер перезапущен" -ForegroundColor Green
    }
}
```

### 2. `scripts/update-web-interface.ps1` - Управление веб-интерфейсом

```powershell
# Скрипт для управления веб-интерфейсом на основе Vue.js

param (
    [Parameter(Mandatory=$true)]
    [ValidateSet("init", "build", "dev", "lint", "update-libs", "install-dependencies")]
    [string]$Command,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force
)

# Функция для инициализации Vue.js проекта
function Initialize-VueProject {
    Write-Host "Инициализация Vue.js проекта..."
    
    # Проверка наличия директории
    if (-not (Test-Path "src/web-interface/webgis")) {
        New-Item -Path "src/web-interface/webgis" -ItemType Directory -Force | Out-Null
    }
    
    # Создание структуры проекта
    $directories = @(
        "src/web-interface/webgis/js",
        "src/web-interface/webgis/js/components",
        "src/web-interface/webgis/js/services",
        "src/web-interface/webgis/js/utils",
        "src/web-interface/webgis/css",
        "src/web-interface/webgis/assets",
        "src/web-interface/webgis/assets/icons"
    )
    
    foreach ($dir in $directories) {
        if (-not (Test-Path $dir)) {
            New-Item -Path $dir -ItemType Directory -Force | Out-Null
        }
    }
    
    # Создание базовых файлов проекта
    
    # Создание package.json
    @"
{
  "name": "corporate-gis-webgis",
  "version": "1.0.0",
  "description": "WebGIS интерфейс для Корпоративной ГИС-платформы",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview",
    "lint": "eslint . --ext .js,.vue"
  },
  "dependencies": {
    "vue": "^3.3.4",
    "ol": "^7.5.1",
    "axios": "^1.6.2",
    "pinia": "^2.1.6"
  },
  "devDependencies": {
    "@vitejs/plugin-vue": "^4.3.4",
    "autoprefixer": "^10.4.16",
    "eslint": "^8.49.0",
    "eslint-plugin-vue": "^9.17.0",
    "postcss": "^8.4.31",
    "tailwindcss": "^3.3.3",
    "vite": "^4.4.9"
  }
}
"@ | Set-Content -Path "src/web-interface/webgis/package.json" -Encoding UTF8
    
    # Создание базового index.html
    @"
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Корпоративная ГИС - WebGIS</title>
    <link rel="stylesheet" href="./css/main.css">
</head>
<body>
    <div id="app"></div>
    <script type="module" src="./js/app.js"></script>
</body>
</html>
"@ | Set-Content -Path "src/web-interface/webgis/index.html" -Encoding UTF8
    
    # Создание main.css
    @"
@import url('https://fonts.googleapis.com/css2?family=Roboto:wght@300;400;500;700&display=swap');

:root {
  --primary-color: #3498db;
  --secondary-color: #2ecc71;
  --background-color: #f8f9fa;
  --text-color: #2c3e50;
  --border-color: #dcdfe6;
}

body {
  font-family: 'Roboto', sans-serif;
  margin: 0;
  padding: 0;
  background-color: var(--background-color);
  color: var(--text-color);
}

#app {
  height: 100vh;
  display: flex;
  flex-direction: column;
}
"@ | Set-Content -Path "src/web-interface/webgis/css/main.css" -Encoding UTF8
    
    # Создание базового app.js
    @"
import { createApp } from 'vue';
import { createPinia } from 'pinia';
import Map from './components/Map.js';

const app = createApp({
    components: {
        Map
    },
    template: `
        <div class="webgis-container">
            <header class="webgis-header">
                <h1>Корпоративная ГИС</h1>
                <div class="controls">
                    <!-- Элементы управления -->
                </div>
            </header>
            <main class="webgis-content">
                <Map />
            </main>
        </div>
    `
});

// Подключение Pinia для управления состоянием
const pinia = createPinia();
app.use(pinia);

// Монтирование приложения
app.mount('#app');
"@ | Set-Content -Path "src/web-interface/webgis/js/app.js" -Encoding UTF8
    
    # Создание базового компонента Map.js
    @"
import { defineComponent, onMounted, ref } from 'vue';
import { Map, View } from 'ol';
import TileLayer from 'ol/layer/Tile';
import OSM from 'ol/source/OSM';
import { fromLonLat } from 'ol/proj';
import 'ol/ol.css';

export default defineComponent({
    name: 'MapComponent',
    template: `
        <div ref="mapContainer" class="map-container"></div>
    `,
    setup() {
        const mapContainer = ref(null);
        const map = ref(null);
        
        onMounted(() => {
            if (mapContainer.value) {
                map.value = new Map({
                    target: mapContainer.value,
                    layers: [
                        new TileLayer({
                            source: new OSM(),
                            visible: true
                        })
                    ],
                    view: new View({
                        center: fromLonLat([37.618423, 55.751244]), // Москва
                        zoom: 10
                    })
                });
            }
        });
        
        return {
            mapContainer,
            map
        };
    }
});
"@ | Set-Content -Path "src/web-interface/webgis/js/components/Map.js" -Encoding UTF8
    
    # Создание Vite конфига
    @"
import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';

export default defineConfig({
    plugins: [vue()],
    base: '/webgis/',
    build: {
        outDir: 'dist',
        assetsDir: 'assets'
    },
    server: {
        port: 3000,
        proxy: {
            '/api': {
                target: 'http://localhost/api',
                changeOrigin: true
            },
            '/geoserver': {
                target: 'http://localhost/geoserver',
                changeOrigin: true
            }
        }
    }
});
"@ | Set-Content -Path "src/web-interface/webgis/vite.config.js" -Encoding UTF8
    
    # Создание базового сервиса для работы с API
    @"
import axios from 'axios';

const apiClient = axios.create({
    baseURL: '/api',
    timeout: 10000,
    headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
    }
});

export default {
    // Получение списка слоев
    getLayers() {
        return apiClient.get('/layers/');
    },
    
    // Получение метаданных слоя
    getLayerMetadata(layerId) {
        return apiClient.get(`/layers/\${layerId}/metadata/`);
    },
    
    // Получение информации о точке на карте
    getFeatureInfo(layerName, x, y, srs) {
        return apiClient.get('/feature-info/', {
            params: { layer: layerName, x, y, srs }
        });
    },
    
    // Аутентификация пользователя
    login(credentials) {
        return apiClient.post('/auth/login/', credentials);
    },
    
    // Выход пользователя
    logout() {
        return apiClient.post('/auth/logout/');
    }
};
"@ | Set-Content -Path "src/web-interface/webgis/js/services/api.js" -Encoding UTF8
    
    Write-Host "Vue.js проект успешно инициализирован в директории src/web-interface/webgis" -ForegroundColor Green
}

# Функция для сборки проекта
function Build-Project {
    Write-Host "Сборка Vue.js проекта..."
    
    if (-not (Test-Path "src/web-interface/webgis/node_modules")) {
        Write-Host "Node modules не найдены. Установка зависимостей..." -ForegroundColor Yellow
        Set-Location -Path "src/web-interface/webgis"
        npm install
        Set-Location -Path "$PSScriptRoot/../../"
    }
    
    Set-Location -Path "src/web-interface/webgis"
    npm run build
    Set-Location -Path "$PSScriptRoot/../../"
    
    # Копирование собранных файлов в директорию NGINX
    if (Test-Path "src/web-interface/webgis/dist") {
        Copy-Item -Path "src/web-interface/webgis/dist/*" -Destination "src/web-interface/webgis/" -Recurse -Force
    }
    
    Write-Host "Сборка проекта завершена успешно" -ForegroundColor Green
}

# Функция для запуска локального сервера разработки
function Start-DevServer {
    Write-Host "Запуск сервера разработки..."
    
    if (-not (Test-Path "src/web-interface/webgis/node_modules")) {
        Write-Host "Node modules не найдены. Установка зависимостей..." -ForegroundColor Yellow
        Set-Location -Path "src/web-interface/webgis"
        npm install
        Set-Location -Path "$PSScriptRoot/../../"
    }
    
    Set-Location -Path "src/web-interface/webgis"
    npm run dev
    Set-Location -Path "$PSScriptRoot/../../"
}

# Функция для проверки кода
function Lint-Project {
    Write-Host "Проверка кода проекта..."
    
    if (-not (Test-Path "src/web-interface/webgis/node_modules")) {
        Write-Host "Node modules не найдены. Установка зависимостей..." -ForegroundColor Yellow
        Set-Location -Path "src/web-interface/webgis"
        npm install
        Set-Location -Path "$PSScriptRoot/../../"
    }
    
    Set-Location -Path "src/web-interface/webgis"
    npm run lint
    Set-Location -Path "$PSScriptRoot/../../"
    
    Write-Host "Проверка кода завершена" -ForegroundColor Green
}

# Функция для обновления библиотек
function Update-Libraries {
    Write-Host "Обновление библиотек проекта..."
    
    if (-not (Test-Path "src/web-interface/webgis/node_modules")) {
        Write-Host "Node modules не найдены. Установка зависимостей..." -ForegroundColor Yellow
        Set-Location -Path "src/web-interface/webgis"
        npm install
        Set-Location -Path "$PSScriptRoot/../../"
    } else {
        Set-Location -Path "src/web-interface/webgis"
        npm update
        Set-Location -Path "$PSScriptRoot/../../"
    }
    
    Write-Host "Библиотеки обновлены успешно" -ForegroundColor Green
}

# Функция для установки зависимостей
function Install-Dependencies {
    Write-Host "Установка зависимостей проекта..."
    
    Set-Location -Path "src/web-interface/webgis"
    npm install
    Set-Location -Path "$PSScriptRoot/../../"
    
    Write-Host "Зависимости установлены успешно" -ForegroundColor Green
}

# Основная логика скрипта
switch ($Command) {
    "init" {
        Initialize-VueProject
    }
    "build" {
        Build-Project
    }
    "dev" {
        Start-DevServer
    }
    "lint" {
        Lint-Project
    }
    "update-libs" {
        Update-Libraries
    }
    "install-dependencies" {
        Install-Dependencies
    }
}
```

### 3. `scripts/setup-nginx-proxy.ps1` - Настройка NGINX для проксирования Django

```powershell
# Скрипт для настройки NGINX для проксирования Django и статических файлов

param (
    [Parameter(Mandatory=$false)]
    [switch]$ForceRestart
)

# Путь к конфигурационному файлу
$nginxConfigPath = "config/nginx/conf.d/django-admin.conf"

# Создание конфигурационного файла
Write-Host "Создание конфигурации NGINX для Django-админки..."

@"
# Конфигурация для Django-админки
location /admin/ {
    proxy_pass http://django:8000/admin/;
    proxy_set_header Host `$host;
    proxy_set_header X-Real-IP `$remote_addr;
    proxy_set_header X-Forwarded-For `$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto `$scheme;
}

# Django API
location /api/ {
    proxy_pass http://django:8000/api/;
    proxy_set_header Host `$host;
    proxy_set_header X-Real-IP `$remote_addr;
    proxy_set_header X-Forwarded-For `$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto `$scheme;
}

# Статические файлы Django
location /static/ {
    alias /usr/share/nginx/static/;
    expires 30d;
    add_header Cache-Control "public, max-age=2592000";
}

# Медиа-файлы
location /media/ {
    alias /usr/share/nginx/media/;
    expires 30d;
    add_header Cache-Control "public, max-age=2592000";
}

# WebGIS приложение
location /webgis/ {
    alias /usr/share/nginx/html/webgis/;
    index index.html;
    try_files `$uri `$uri/ /webgis/index.html;
}
"@ | Set-Content -Path $nginxConfigPath -Encoding UTF8

Write-Host "Конфигурационный файл создан: $nginxConfigPath" -ForegroundColor Green

# Проверка и создание директорий для статических и медиа файлов
$directories = @("static", "media")

foreach ($dir in $directories) {
    if (-not (Test-Path $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
        Write-Host "Создана директория: $dir" -ForegroundColor Green
    }
}

# Перезапуск NGINX для применения изменений
if (docker ps -q -f name=nginx 2>$null) {
    if ($ForceRestart) {
        Write-Host "Перезапуск NGINX для применения изменений..."
        docker restart nginx
        Write-Host "NGINX перезапущен" -ForegroundColor Green
    } else {
        Write-Host "Для применения изменений необходимо перезапустить NGINX. Используйте -ForceRestart для автоматического перезапуска." -ForegroundColor Yellow
    }
} else {
    Write-Host "Контейнер NGINX не запущен. Изменения будут применены при следующем запуске." -ForegroundColor Yellow
}
```

### 4. `scripts/modernization-check.ps1` - Проверка готовности инфраструктуры

```powershell
# Скрипт для проверки готовности инфраструктуры к компромиссной модернизации

param (
    [Parameter(Mandatory=$false)]
    [switch]$Detailed,
    
    [Parameter(Mandatory=$false)]
    [switch]$Fix
)

# Функция для проверки Docker
function Test-Docker {
    Write-Host "Проверка Docker..."
    
    try {
        $dockerVersion = docker --version
        Write-Host "✅ Docker установлен: $dockerVersion" -ForegroundColor Green
        
        $composeVersion = docker-compose --version
        Write-Host "✅ Docker Compose установлен: $composeVersion" -ForegroundColor Green
        
        return $true
    } catch {
        Write-Host "❌ Ошибка Docker: $_" -ForegroundColor Red
        return $false
    }
}

# Функция для проверки структуры проекта
function Test-ProjectStructure {
    Write-Host "Проверка структуры проекта..."
    
    $requiredDirs = @(
        "src",
        "config",
        "data",
        "scripts",
        "docs"
    )
    
    $missingDirs = @()
    
    foreach ($dir in $requiredDirs) {
        if (-not (Test-Path $dir)) {
            $missingDirs += $dir
            Write-Host "❌ Отсутствует директория: $dir" -ForegroundColor Red
        } else {
            if ($Detailed) {
                Write-Host "✅ Директория существует: $dir" -ForegroundColor Green
            }
        }
    }
    
    if ($missingDirs.Count -gt 0) {
        if ($Fix) {
            Write-Host "Создание отсутствующих директорий..." -ForegroundColor Yellow
            foreach ($dir in $missingDirs) {
                New-Item -Path $dir -ItemType Directory -Force | Out-Null
                Write-Host "✅ Создана директория: $dir" -ForegroundColor Green
            }
        }
        return $false
    }
    
    return $true
}

# Функция для проверки docker-compose.yml
function Test-DockerCompose {
    Write-Host "Проверка docker-compose.yml..."
    
    if (-not (Test-Path "docker-compose.yml")) {
        Write-Host "❌ Файл docker-compose.yml отсутствует" -ForegroundColor Red
        return $false
    }
    
    try {
        $composeContent = Get-Content "docker-compose.yml" -Raw
        if ($composeContent -match "postgis" -and $composeContent -match "geoserver") {
            Write-Host "✅ docker-compose.yml содержит необходимые сервисы" -ForegroundColor Green
            return $true
        } else {
            Write-Host "❌ docker-compose.yml не содержит необходимые сервисы" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "❌ Ошибка при проверке docker-compose.yml: $_" -ForegroundColor Red
        return $false
    }
}

# Функция для проверки сетевых портов
function Test-NetworkPorts {
    Write-Host "Проверка доступности портов..."
    
    $ports = @(80, 8080, 8081, 5432, 8000) # Добавлен порт 8000 для Django
    $reservedPorts = @()
    
    foreach ($port in $ports) {
        try {
            $listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $port)
            $listener.Start()
            $listener.Stop()
            
            if ($Detailed) {
                Write-Host "✅ Порт $port свободен" -ForegroundColor Green
            }
        } catch {
            $reservedPorts += $port
            Write-Host "❌ Порт $port занят" -ForegroundColor Red
        }
    }
    
    if ($reservedPorts.Count -gt 0) {
        Write-Host "Следующие порты заняты и могут вызвать конфликты: $($reservedPorts -join ', ')" -ForegroundColor Yellow
        return $false
    }
    
    return $true
}

# Функция для проверки готовности к модернизации
function Test-ModernizationReadiness {
    Write-Host "Проверка готовности к компромиссной модернизации..."
    
    # Проверка наличия директорий для новых компонентов
    $modernizationDirs = @(
        "src/admin-panel",
        "src/web-interface/webgis",
        "static",
        "media",
        "config/django"
    )
    
    $missingModDirs = @()
    
    foreach ($dir in $modernizationDirs) {
        if (-not (Test-Path $dir)) {
            $missingModDirs += $dir
            Write-Host "❌ Отсутствует директория для модернизации: $dir" -ForegroundColor Red
        } else {
            if ($Detailed) {
                Write-Host "✅ Директория для модернизации существует: $dir" -ForegroundColor Green
            }
        }
    }
    
    if ($missingModDirs.Count -gt 0) {
        if ($Fix) {
            Write-Host "Создание отсутствующих директорий для модернизации..." -ForegroundColor Yellow
            foreach ($dir in $missingModDirs) {
                New-Item -Path $dir -ItemType Directory -Force | Out-Null
                Write-Host "✅ Создана директория: $dir" -ForegroundColor Green
            }
        }
        return $false
    }
    
    return $true
}

# Основной блок скрипта
$dockerOk = Test-Docker
$structureOk = Test-ProjectStructure
$composeOk = Test-DockerCompose
$portsOk = Test-NetworkPorts
$modernizationOk = Test-ModernizationReadiness

# Вывод итогового результата
Write-Host "`n--- Результаты проверки ---" -ForegroundColor Cyan
Write-Host "Docker: $(if ($dockerOk) { "✅ OK" } else { "❌ Проблема" })"
Write-Host "Структура проекта: $(if ($structureOk) { "✅ OK" } else { "❌ Проблема" })"
Write-Host "Docker Compose: $(if ($composeOk) { "✅ OK" } else { "❌ Проблема" })"
Write-Host "Сетевые порты: $(if ($portsOk) { "✅ OK" } else { "❌ Проблема" })"
Write-Host "Готовность к модернизации: $(if ($modernizationOk) { "✅ OK" } else { "❌ Проблема" })"

if ($dockerOk -and $structureOk -and $composeOk -and $portsOk -and $modernizationOk) {
    Write-Host "`n✅ Система готова к компромиссной модернизации!" -ForegroundColor Green
} else {
    Write-Host "`n❌ Система требует настройки перед модернизацией. Исправьте указанные проблемы." -ForegroundColor Red
    
    if (-not $Fix) {
        Write-Host "Для автоматического исправления проблем запустите скрипт с параметром -Fix" -ForegroundColor Yellow
    }
}
```

### 5. Обновление основного `manage-gis.ps1`

Основной скрипт управления `manage-gis.ps1` также будет обновлен для поддержки новых компонентов:

```powershell
# Добавление новых команд для управления Django и модернизированным веб-интерфейсом

# В блоке switch для параметра Command добавляются новые опции
switch ($Command) {
    # ... существующие команды ...
    
    "django" {
        & "$PSScriptRoot\scripts\update-django-admin.ps1" -Command $SubCommand -Username $Username -Email $Email -Password $Password -Force:$Force
    }
    
    "webgis" {
        & "$PSScriptRoot\scripts\update-web-interface.ps1" -Command $SubCommand -Force:$Force
    }
    
    "check-modernization" {
        & "$PSScriptRoot\scripts\modernization-check.ps1" -Detailed:$Detailed -Fix:$Fix
    }
    
    "setup-nginx-proxy" {
        & "$PSScriptRoot\scripts\setup-nginx-proxy.ps1" -ForceRestart:$ForceRestart
    }
    
    # ... другие команды ...
}
```

### Использование новых инструментов

После внедрения модернизации, управление системой будет осуществляться через обновленный основной скрипт:

```powershell
# Инициализация Django-приложения
./manage-gis.ps1 django init

# Создание суперпользователя Django
./manage-gis.ps1 django create-superuser -Username admin -Email admin@example.com

# Инициализация WebGIS на Vue.js
./manage-gis.ps1 webgis init

# Сборка WebGIS
./manage-gis.ps1 webgis build

# Настройка NGINX для проксирования Django и WebGIS
./manage-gis.ps1 setup-nginx-proxy -ForceRestart

# Проверка готовности к модернизации
./manage-gis.ps1 check-modernization -Detailed -Fix
```

Эти инструменты значительно упростят процесс модернизации и последующее управление расширенной ГИС-платформой. 

## Публикация растровых слоев: `scripts/setup-raster-layer.ps1`

Этот скрипт предназначен для автоматизации процесса публикации растровых слоев в GeoServer. Он создает рабочее пространство, хранилище данных и публикует слой с указанными параметрами.

### Использование

```powershell
./scripts/setup-raster-layer.ps1 -GeoServerUrl <url> -AdminUser <user> -AdminPassword <password> -WorkspaceName <workspace> -DatastoreName <datastore> -LayerName <layer> -RasterFilePath <path> [-CoverageSRS <srs>]
```

### Параметры

| Параметр | Описание | Обязательный | Пример значения |
|----------|----------|--------------|-----------------|
| `-GeoServerUrl` | URL REST API GeoServer, включая порт и путь | Да | `http://localhost:8081/geoserver/rest` |
| `-AdminUser` | Имя пользователя администратора GeoServer | Да | `admin` |
| `-AdminPassword` | Пароль администратора GeoServer | Да | `geoserver` |
| `-WorkspaceName` | Имя рабочего пространства для публикации | Да | `raster` |
| `-DatastoreName` | Имя хранилища данных для растрового слоя | Да | `ecw_store` |
| `-LayerName` | Имя публикуемого слоя | Да | `landsat` |
| `-RasterFilePath` | Полный путь к растровому файлу | Да | `D:\data\imagery\landsat.ecw` |
| `-CoverageSRS` | Система координат растрового слоя (EPSG код) | Нет | `EPSG:4326` |

### Поддерживаемые форматы растровых данных

Скрипт автоматически определяет тип хранилища данных на основе расширения файла:

| Расширение | Тип хранилища в GeoServer |
|------------|---------------------------|
| `.tif`, `.tiff` | GeoTIFF |
| `.ecw` | ECW |
| `.jp2` | JP2K (JPEG2000) |
| `.sid` | MrSID |
| другие | GeoTIFF (по умолчанию) |

### Что делает скрипт

1. Проверяет подключение к GeoServer
2. Проверяет наличие растрового файла
3. Создает рабочее пространство, если оно не существует
4. Создает хранилище данных для растрового файла
5. Публикует слой с указанным именем
6. Применяет стиль по умолчанию
7. Проверяет доступность слоя через WMS

### Примеры использования

Публикация ECW файла в GeoServer ECW:
```powershell
./scripts/setup-raster-layer.ps1 -GeoServerUrl "http://localhost:8081/geoserver/rest" -AdminUser "admin" -AdminPassword "geoserver" -WorkspaceName "raster" -DatastoreName "ecw_store" -LayerName "landsat" -RasterFilePath "D:\data\imagery\landsat.ecw" -CoverageSRS "EPSG:4326"
```

Публикация GeoTIFF файла:
```powershell
./scripts/setup-raster-layer.ps1 -GeoServerUrl "http://localhost:8081/geoserver/rest" -AdminUser "admin" -AdminPassword "geoserver" -WorkspaceName "raster" -DatastoreName "tiff_store" -LayerName "elevation" -RasterFilePath "D:\data\imagery\elevation.tif" -CoverageSRS "EPSG:3857"
```

### Функции скрипта

Скрипт содержит следующие основные функции:

- `Write-Log` - Функция для логирования сообщений с указанием уровня (INFO, WARNING, ERROR)
- `Test-GeoServerConnection` - Проверка подключения к GeoServer
- `Create-Workspace` - Создание рабочего пространства
- `Create-CoverageStore` - Создание хранилища данных для растрового файла
- `Publish-Coverage` - Публикация слоя
- `Set-LayerStyles` - Применение стиля к слою
- `Test-RasterLayer` - Проверка доступности слоя через WMS

### Интеграция с основным скриптом управления

Для удобства использования рекомендуется добавить вызов скрипта в основной скрипт управления `manage-gis.ps1`:

```powershell
# В функцию обработки команд manage-gis.ps1 добавить:
"setup-raster" {
    $geoserverUrl = "http://localhost:8081/geoserver/rest"
    $adminUser = "admin"
    $adminPassword = "geoserver"
    
    # Запрос параметров у пользователя
    $workspaceName = Read-Host "Введите имя рабочего пространства (по умолчанию: raster)"
    if ([string]::IsNullOrEmpty($workspaceName)) { $workspaceName = "raster" }
    
    $datastoreName = Read-Host "Введите имя хранилища данных"
    $layerName = Read-Host "Введите имя слоя"
    $rasterFilePath = Read-Host "Введите полный путь к растровому файлу"
    
    # Вызов скрипта
    & "$PSScriptRoot\scripts\setup-raster-layer.ps1" -GeoServerUrl $geoserverUrl -AdminUser $adminUser -AdminPassword $adminPassword -WorkspaceName $workspaceName -DatastoreName $datastoreName -LayerName $layerName -RasterFilePath $rasterFilePath
}
```

Эти инструменты значительно упростят процесс модернизации и последующее управление расширенной ГИС-платформой. 