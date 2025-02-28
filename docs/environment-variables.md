# Управление переменными окружения

В проекте Corporate GIS используется система переменных окружения для конфигурации различных компонентов платформы. Это позволяет гибко настраивать систему для разных окружений (разработка, тестирование, продакшен) без изменения кода.

## Структура файлов переменных окружения

В проекте используются следующие файлы переменных окружения:

- `.env.example` - шаблон с примерами всех доступных переменных окружения и их описанием
- `.env.dev` - конфигурация для окружения разработки
- `.env.prod` - конфигурация для продакшен-окружения
- `.env` - активный файл конфигурации, который используется системой

При инициализации проекта с помощью команды `./manage-gis.ps1 init [dev|prod]` создаются все необходимые файлы, и соответствующий файл (`.env.dev` или `.env.prod`) копируется в `.env`.

## Основные группы переменных окружения

### PostgreSQL/PostGIS

```
POSTGRES_DB=gis
POSTGRES_USER=postgres
POSTGRES_PASSWORD=secure_password_here
POSTGRES_HOST=postgis
POSTGRES_PORT=5432
PGDATA=/var/lib/postgresql/data/pgdata
```

### GeoServer

```
GEOSERVER_ADMIN_USER=admin
GEOSERVER_ADMIN_PASSWORD=secure_password_here
GEOSERVER_DATA_DIR=/opt/geoserver/data_dir
GEOSERVER_PORT=8080
GEOSERVER_INITIAL_MEMORY=512M
GEOSERVER_MAXIMUM_MEMORY=1G
GEOSERVER_PROXY_BASE_URL=http://localhost:8080/geoserver
```

### Django Admin

```
DJANGO_SUPERUSER_USERNAME=admin
DJANGO_SUPERUSER_PASSWORD=secure_password_here
DJANGO_SUPERUSER_EMAIL=admin@example.com
DJANGO_PORT=8000
```

### Пути к данным

```
VECTOR_DATA_PATH=./data/geoserver/vector
RASTER_DATA_PATH=./data/raster-storage
PROJECTIONS_PATH=./config/geoserver/projections
```

### Nginx

```
NGINX_PORT=80
NGINX_HTTPS_PORT=443
```

### SSL (только для продакшена)

```
SSL_CERT_PATH=/etc/ssl/certs/gis.example.com.pem
SSL_KEY_PATH=/etc/ssl/private/gis.example.com.key
```

### Другие настройки

```
TZ=Europe/Moscow
ENVIRONMENT=dev  # или prod
LOG_LEVEL=DEBUG  # или INFO, WARNING, ERROR
BACKUP_PATH=/var/backups/gis  # путь для резервных копий
```

## Переключение между окружениями

Для переключения между окружениями разработки и продакшена используйте следующие команды:

```powershell
# Переключение на окружение разработки
Copy-Item -Path .env.dev -Destination .env -Force

# Переключение на продакшен-окружение
Copy-Item -Path .env.prod -Destination .env -Force
```

После переключения окружения рекомендуется перезапустить контейнеры:

```powershell
./manage-gis.ps1 restart
```

## Безопасность

**ВАЖНО**: Файлы `.env`, `.env.dev` и `.env.prod` содержат чувствительную информацию (пароли, ключи и т.д.) и не должны добавляться в систему контроля версий. Они уже добавлены в `.gitignore`.

Для продакшен-окружения обязательно замените все стандартные пароли на надежные значения перед развертыванием.

## Добавление новых переменных окружения

При добавлении новых переменных окружения следуйте этим рекомендациям:

1. Добавьте переменную в `.env.example` с комментарием, объясняющим ее назначение
2. Добавьте переменную в `.env.dev` и `.env.prod` с соответствующими значениями
3. Обновите эту документацию, добавив новую переменную в соответствующую секцию
4. Если переменная критична для работы системы, обновите скрипты инициализации

## Использование переменных окружения в скриптах

В PowerShell скриптах проекта можно получить доступ к переменным окружения с помощью функции `Get-EnvVariables`:

```powershell
# Функция для загрузки переменных окружения из .env файла
function Get-EnvVariables {
    param (
        [string]$EnvFile = ".env"
    )
    
    $envVars = @{}
    
    if (Test-Path $EnvFile) {
        Get-Content $EnvFile | ForEach-Object {
            if ($_ -match "^\s*([^#][^=]+)=(.*)$") {
                $key = $matches[1].Trim()
                $value = $matches[2].Trim()
                $envVars[$key] = $value
            }
        }
    }
    
    return $envVars
}

# Использование
$envVars = Get-EnvVariables
$postgresDb = $envVars["POSTGRES_DB"]
``` 