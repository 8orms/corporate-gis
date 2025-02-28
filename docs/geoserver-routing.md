# GeoServer Routing в Corporate GIS Platform

## Обзор архитектуры

Corporate GIS Platform использует две отдельные инстанции GeoServer для оптимальной работы с разными типами геоданных:

1. **Vector GeoServer** - оптимизирован для работы с векторными данными (шейп-файлы, PostGIS и т.д.)
2. **ECW GeoServer** - оптимизирован для работы с растровыми данными в формате ECW

Обе инстанции GeoServer доступны через единый NGINX прокси, который маршрутизирует запросы к соответствующей инстанции на основе URL-пути.

```
                   ┌─────────────────┐
                   │                 │
                   │  NGINX Proxy    │
                   │  (порт 80)      │
                   │                 │
                   └────────┬────────┘
                            │
              ┌─────────────┴─────────────┐
              │                           │
    ┌─────────▼──────────┐     ┌──────────▼─────────┐
    │                    │     │                     │
    │  Vector GeoServer  │     │   ECW GeoServer    │
    │  (порт 8080)       │     │   (порт 8081)      │
    │                    │     │                     │
    └────────────────────┘     └─────────────────────┘
```

## URL-структура

Для доступа к различным инстанциям GeoServer используются следующие URL-шаблоны:

### Веб-интерфейс

- **Страница выбора GeoServer**: `http://hostname/geoserver/`
- **Vector GeoServer**: `http://hostname/geoserver/vector/web/`
- **ECW GeoServer**: `http://hostname/geoserver/ecw/web/`

### Сервисы OGC

#### Vector GeoServer

- **WMS**: `http://hostname/geoserver/vector/wms`
- **WFS**: `http://hostname/geoserver/vector/wfs`
- **WCS**: `http://hostname/geoserver/vector/wcs`

#### ECW GeoServer

- **WMS**: `http://hostname/geoserver/ecw/wms`
- **WCS**: `http://hostname/geoserver/ecw/wcs`

## Конфигурация NGINX

Маршрутизация запросов осуществляется с помощью NGINX, который настроен на перенаправление запросов к соответствующей инстанции GeoServer на основе URL-пути.

Основные компоненты конфигурации NGINX:

1. **Upstream-серверы** - определяют адреса инстанций GeoServer
2. **Location-блоки** - определяют правила маршрутизации запросов
3. **Заголовки X-GeoServer-Instance** - добавляются для идентификации инстанции
4. **Кэширование** - настроено для WMS-запросов для повышения производительности

### Пример конфигурации

```nginx
# Определение upstream-серверов
upstream geoserver_vector {
    server geoserver-vector:8080;
}

upstream geoserver_ecw {
    server geoserver-ecw:8080;
}

# Настройка логов для отслеживания маршрутизации запросов
log_format geoserver_routing '$remote_addr - $remote_user [$time_local] '
                           '"$request" $status $body_bytes_sent '
                           '"$http_referer" "$http_user_agent" '
                           'routing=$upstream_addr';

server {
    listen 80;
    server_name localhost;

    # Включение логирования маршрутизации для отладки
    access_log /var/log/nginx/access.log geoserver_routing;
    error_log /var/log/nginx/error.log warn;

    # Страница выбора GeoServer
    location = /geoserver/ {
        root /usr/share/nginx/html;
        try_files /geoserver-index.html =404;
    }

    # Обработка WMS запросов для Vector GeoServer
    location ~ ^/geoserver/vector/wms {
        proxy_pass http://geoserver_vector/geoserver/wms;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Добавляем заголовок для идентификации инстанции
        add_header X-GeoServer-Instance "vector" always;
        
        # Настройки кэширования для WMS
        proxy_cache geoserver_cache;
        proxy_cache_valid 200 302 1h;
        proxy_cache_valid 404 1m;
        proxy_buffer_size 128k;
        proxy_buffers 4 256k;
        proxy_busy_buffers_size 256k;
    }

    # Обработка WFS запросов для Vector GeoServer
    location ~ ^/geoserver/vector/wfs {
        proxy_pass http://geoserver_vector/geoserver/wfs;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Добавляем заголовок для идентификации инстанции
        add_header X-GeoServer-Instance "vector" always;
    }

    # Обработка WMS запросов для ECW GeoServer
    location ~ ^/geoserver/ecw/wms {
        proxy_pass http://geoserver_ecw/geoserver/wms;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Добавляем заголовок для идентификации инстанции
        add_header X-GeoServer-Instance "ecw" always;
        
        # Настройки кэширования для WMS
        proxy_cache geoserver_cache;
        proxy_cache_valid 200 302 1h;
        proxy_cache_valid 404 1m;
        proxy_buffer_size 128k;
        proxy_buffers 4 256k;
        proxy_busy_buffers_size 256k;
    }

    # Обработка WCS запросов для ECW GeoServer
    location ~ ^/geoserver/ecw/wcs {
        proxy_pass http://geoserver_ecw/geoserver/wcs;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Добавляем заголовок для идентификации инстанции
        add_header X-GeoServer-Instance "ecw" always;
    }

    # Общий блок для Vector GeoServer
    location /geoserver/vector/ {
        proxy_pass http://geoserver_vector/geoserver/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 90;
        
        # Добавляем заголовок для идентификации инстанции
        add_header X-GeoServer-Instance "vector" always;
    }

    # Общий блок для ECW GeoServer
    location /geoserver/ecw/ {
        proxy_pass http://geoserver_ecw/geoserver/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 90;
        
        # Добавляем заголовок для идентификации инстанции
        add_header X-GeoServer-Instance "ecw" always;
    }
}
```

## Мониторинг и проверка маршрутизации

Для проверки корректности маршрутизации запросов к GeoServer используется скрипт `check-geoserver-routing.ps1`, который выполняет следующие проверки:

1. Доступность NGINX
2. Доступность страницы выбора GeoServer
3. Доступность веб-интерфейса Vector GeoServer
4. Доступность веб-интерфейса ECW GeoServer
5. Доступность WMS-сервиса Vector GeoServer
6. Доступность WMS-сервиса ECW GeoServer
7. Проверка заголовков X-GeoServer-Instance

### Использование скрипта

```powershell
# Базовая проверка
.\scripts\check-geoserver-routing.ps1

# Проверка с выводом подробной информации
.\scripts\check-geoserver-routing.ps1 -Verbose

# Проверка с автоматическим исправлением проблем
.\scripts\check-geoserver-routing.ps1 -Fix

# Проверка с указанием базового URL
.\scripts\check-geoserver-routing.ps1 -BaseUrl "http://gis.company.local"
```

### Автоматическое исправление проблем

Скрипт `check-geoserver-routing.ps1` с параметром `-Fix` может автоматически исправлять следующие проблемы:

1. Добавление заголовков X-GeoServer-Instance для идентификации инстанций
2. Добавление блоков для WFS и WCS запросов
3. Настройка логирования маршрутизации

## Рекомендации по использованию

### Для разработчиков

1. **Используйте правильные URL-шаблоны** - всегда указывайте полный путь, включая `/geoserver/vector/` или `/geoserver/ecw/`
2. **Проверяйте заголовки X-GeoServer-Instance** - для подтверждения, что запрос обработан нужной инстанцией
3. **Используйте скрипт мониторинга** - регулярно проверяйте корректность маршрутизации

### Для администраторов

1. **Мониторинг логов NGINX** - регулярно проверяйте логи на наличие ошибок маршрутизации
2. **Резервное копирование конфигурации** - перед внесением изменений в конфигурацию NGINX
3. **Тестирование после изменений** - используйте скрипт мониторинга после внесения изменений

## Устранение неполадок

### Распространенные проблемы

1. **502 Bad Gateway** - проверьте, запущены ли контейнеры GeoServer
2. **404 Not Found** - проверьте правильность URL и конфигурацию location-блоков
3. **Перенаправление на неправильную инстанцию** - проверьте конфигурацию location-блоков и порядок их определения

### Проверка логов

```powershell
# Проверка логов NGINX
docker logs dev-nginx-1

# Проверка логов Vector GeoServer
docker logs geoserver-vector

# Проверка логов ECW GeoServer
docker logs geoserver-ecw
```

## Дополнительная информация

- [Документация NGINX](https://nginx.org/en/docs/)
- [Документация GeoServer](https://docs.geoserver.org/)
- [Руководство по настройке GeoServer в Docker](https://github.com/georchestra/docker) 