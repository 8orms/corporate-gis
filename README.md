# Корпоративная ГИС-платформа
Система на базе GeoServer для обработки и визуализации геопространственных данных.  
**Целевая аудитория**: 15-50 пользователей в сфере инженерных изысканий (геология, геодезия, 
экология).

**Репозиторий**: [github.com/8orms/corporate-gis](https://github.com/8orms/corporate-gis)
---

## 🛠️ Системные требования
- **ОС**: Windows 10+/Linux  
- **Docker Desktop** (версия 4.15+)  
- **Процессор**: 4+ ядра для оптимальной производительности  
- **RAM**: Минимум 8 GB  
- **Диск**: 20+ GB свободного места  
- **Виртуализация**: Включена поддержка VT-x/AMD-V в BIOS  
- **Свободные порты**: 80, 8080, 8081, 5432

---

## 🏗️ Архитектура

### Основные компоненты
| Сервис               | Версия     | Порт  | URL                                  | Описание                                           |
|----------------------|-----------:|------:|--------------------------------------|---------------------------------------------------|
| PostGIS             | 15-3.3     | 5432  | `postgis:5432`                       | База данных для геопространственных данных        |
| GeoServer Vector    | 2.26.1     | 8080  | `http://localhost/geoserver/vector/web`   | Сервер для публикации векторных геоданных        |
| GeoServer ECW       | master     | 8081  | `http://localhost/geoserver/ecw/web`   | Сервер для публикации растровых данных (ECW)     |
| NGINX               | 1.26.3     | 80    | `http://localhost`                   | Веб-сервер и обратный прокси                       |

### Учётные данные
- **GeoServer**: `admin` / `geoserver`  
- **PostGIS**: `postgres` / `postgres`  

### Поддерживаемые форматы данных
- **Векторные**: Shapefiles, KMZ/KML, CSV, GeoJSON (с возможностью преобразования в единую БД PostGIS)
- **Растровые**: ECW (основной формат), GeoTIFF, тайлы SasPlanet
- **Лидар**: LAS/LAZ файлы

### Подробная структура
Подробное описание структуры проекта доступно в файле [project-structure.md](./docs/project-structure.md).

---

## 🚀 Запуск системы

### Быстрый старт
```powershell
# Клонирование репозитория
git clone https://github.com/8orms/corporate-gis.git
cd corporate-gis

# Инициализация проекта и создание структуры директорий
# Для разработки:
./manage-gis.ps1 init dev
# Для продакшена:
# ./manage-gis.ps1 init prod

# Запуск всех сервисов
./manage-gis.ps1 start
```

### Управление окружениями

Система поддерживает два типа окружения: разработка (`dev`) и продакшен (`prod`). Каждое окружение имеет свой набор конфигурационных файлов:

- `.env.dev` - конфигурация для разработки с упрощенными настройками
- `.env.prod` - конфигурация для продакшена с усиленной безопасностью

При инициализации проекта создается активный файл `.env` на основе выбранного окружения. Для переключения между окружениями используйте:

```powershell
# Переключение на окружение разработки
Copy-Item -Path .env.dev -Destination .env -Force
./manage-gis.ps1 restart

# Переключение на продакшен-окружение
Copy-Item -Path .env.prod -Destination .env -Force
./manage-gis.ps1 restart
```

Подробная информация о переменных окружения доступна в [документации по переменным окружения](./docs/environment-variables.md).

### Основные команды управления
```powershell
# Проверка состояния системы
./manage-gis.ps1 status

# Просмотр логов
./manage-gis.ps1 logs

# Остановка сервисов
./manage-gis.ps1 stop

# Создание резервной копии конфигурации
./manage-gis.ps1 backup

# Полная пересборка системы
./manage-gis.ps1 rebuild
```

Полное описание доступных инструментов управления находится в [документации PowerShell инструментов](./docs/powershell-tools.md).

### Управление ECW файлами и пользовательскими проекциями

```powershell
# Отображение списка файлов
./manage-gis.ps1 manage-ecw list

# Импорт ECW файла
./manage-gis.ps1 manage-ecw import -FilePath D:/temp/map.ecw

# Регистрация проекции
./manage-gis.ps1 manage-ecw register -FilePath D:/temp/custom.prj
```

### Публикация растровых слоев

```powershell
# Публикация растрового слоя ECW в GeoServer
./scripts/setup-raster-layer.ps1 -GeoServerUrl "http://localhost/geoserver/ecw" `
  -AdminUser "admin" -AdminPassword "geoserver" `
  -WorkspaceName "raster" -DatastoreName "ecw_store" `
  -LayerName "map_layer" -RasterFilePath "/opt/geoserver/data_dir/raster-data/ecw/map.ecw"
```

### Оптимизация производительности для больших растров
1. GeoWebCache (GWC) автоматически включен в GeoServer и настроен для кэширования
2. NGINX настроен для оптимального проксирования GeoServer и кэширования статического контента
3. Рекомендуемые настройки для ECW файлов:
   ```
   Формат кэширования: GeoTIFF/PNG
   Глубина масштабирования: до 20 уровней
   Упреждающее кэширование: Включено для наиболее используемых участков
   ```

### Проверка состояния системы
```powershell
# Запуск скрипта проверки состояния
./manage-gis.ps1 status

# Подробная проверка с автоматическим исправлением проблем
./scripts/check-health.ps1 -FixProblems
```

---

## 🔍 Управление данными

### Доступ к GeoServer
Система содержит две специализированные инстанции GeoServer:

- **GeoServer Vector** - Оптимизирован для работы с векторными данными (Shapefiles, PostGIS, GeoJSON)
  - Доступ: http://localhost/geoserver/vector/web/
  - Используется для: публикации векторных слоев, работы с PostGIS

- **GeoServer ECW** - Специализирован для работы с растровыми данными
  - Доступ: http://localhost/geoserver/ecw/web/
  - Используется для: публикации и отображения ECW файлов, тяжелых растров

Страница выбора между инстанциями доступна по адресу: http://localhost/geoserver/

### Маршрутизация запросов GeoServer

Система использует NGINX для маршрутизации запросов к соответствующей инстанции GeoServer на основе URL-пути:

#### URL-структура для сервисов OGC

##### Vector GeoServer
- **WMS**: `http://hostname/geoserver/vector/wms`
- **WFS**: `http://hostname/geoserver/vector/wfs`
- **WCS**: `http://hostname/geoserver/vector/wcs`

##### ECW GeoServer
- **WMS**: `http://hostname/geoserver/ecw/wms`
- **WCS**: `http://hostname/geoserver/ecw/wcs`

Для идентификации инстанции GeoServer, обработавшей запрос, используется заголовок `X-GeoServer-Instance`. Возможные значения:
- `vector` - запрос обработан Vector GeoServer
- `ecw` - запрос обработан ECW GeoServer

Подробная документация по маршрутизации запросов доступна в [документации по маршрутизации GeoServer](./docs/geoserver-routing.md).

### Веб-интерфейс ГИС-платформы

Веб-интерфейс доступен по адресу: http://localhost/

Основные возможности:
- Отображение векторных и растровых слоев
- Переключение между базовыми картами
- Поддержка темной темы
- Автоматическое определение экстента растровых слоев
- Адаптивный дизайн для мобильных устройств

Подробная документация по веб-интерфейсу: [web-interface.md](./docs/web-interface.md)

### Импорт данных из Shapefile в PostGIS
```powershell
# Импорт shapefile в PostGIS
docker run --rm --network corporate-gis_gis_network -v D:/git/corporate-gis/data/vector-storage/shapefiles:/data osgeo/gdal:alpine-normal-latest \
  ogr2ogr -f "PostgreSQL" PG:"host=postgis user=postgres dbname=gis password=postgres" \
  "/data/your_shapefile.shp" -nln schema_name.table_name -nlt PROMOTE_TO_MULTI
```

### Регистрация ECW данных
1. В интерфейсе GeoServer перейдите в "Хранилища данных" → "Добавить новое хранилище"
2. Выберите "ECW" из списка растровых форматов
3. Укажите путь к файлу: `/opt/geoserver/data_dir/raster-data/ecw/your_file.ecw`
4. Укажите пользовательскую проекцию при необходимости

### Управление проекциями
1. Для добавления пользовательской СК, создайте файл `.prj` в директории `config/geoserver/projections/`
2. Перезапустите GeoServer для применения изменений:
   ```powershell
   ./manage-gis.ps1 restart
   ```

---

## 🔧 PowerShell инструменты

Система управления проектом реализована в виде набора PowerShell скриптов:

1. **manage-gis.ps1** - Главный скрипт управления проектом
   - Поддерживает команды: init, start, stop, restart, status, logs, backup, manage-ecw
   - Предоставляет единую точку входа для всех операций

2. **scripts/initialize-project.ps1** - Скрипт инициализации проекта
   - Создает структуру директорий
   - Настраивает Docker Compose
   - Создает конфигурации NGINX
   - Создает базовый веб-интерфейс

3. **scripts/create-directories.ps1** - Скрипт для создания структуры директорий
   - Создает все необходимые директории для проекта
   - Устанавливает правильные разрешения
   - Проверяет наличие конфликтов с существующими файлами

4. **scripts/manage-ecw.ps1** - Скрипт управления ECW файлами
   - Поддерживает операции: list, import, register, move
   - Упрощает работу с растровыми данными

5. **scripts/setup-raster-layer.ps1** - Скрипт для публикации растровых слоев
   - Автоматизирует процесс публикации растровых данных в GeoServer
   - Поддерживает форматы ECW, GeoTIFF и другие
   - Создает рабочие пространства и хранилища данных при необходимости

6. **scripts/check-health.ps1** - Скрипт проверки здоровья системы
   - Отображает статус всех компонентов
   - Проверяет доступность сервисов
   - Может автоматически исправлять проблемы

7. **scripts/collect-container-logs.ps1** - Скрипт для сбора и анализа логов контейнеров
   - Собирает логи из всех контейнеров
   - Фильтрует по уровню сообщений (ERROR, WARN, INFO)
   - Удаляет дубликаты сообщений для повышения читаемости

8. **scripts/check-geoserver-routing.ps1** - Скрипт для проверки маршрутизации запросов к GeoServer
   - Проверяет конфигурацию NGINX и GeoServer
   - Тестирует URL маршрутизацию и заголовки запросов
   - Может автоматически исправлять обнаруженные проблемы с конфигурацией
   - Проверяет наличие заголовков X-GeoServer-Instance для идентификации инстанций

9. **scripts/test-wms-services.ps1** - Скрипт для тестирования WMS-сервисов
   - Проверяет доступность WMS-сервисов обеих инстанций GeoServer
   - Получает список слоев из каждой инстанции
   - Создает тестовые запросы GetMap для проверки работоспособности
   - Генерирует HTML-отчет с примерами карт

10. **scripts/initialize-git-repo.ps1** - Скрипт для инициализации Git репозитория
    - Проверяет установку Git
    - Создает .gitignore для GIS-проектов
    - Выполняет начальный коммит
    - Настраивает удаленный репозиторий (опционально)
    - Отправляет коммит в удаленный репозиторий (опционально)

11. **scripts/monitor-geoserver-health.ps1** - Скрипт мониторинга здоровья GeoServer
    - Выполняет комплексную проверку инстанций GeoServer
    - Поддерживает непрерывный мониторинг с заданным интервалом

### Новые инструменты для проверки маршрутизации

```powershell
# Проверка маршрутизации запросов к GeoServer
./scripts/check-geoserver-routing.ps1

# Проверка с выводом подробной информации
./scripts/check-geoserver-routing.ps1 -Verbose

# Проверка с автоматическим исправлением проблем
./scripts/check-geoserver-routing.ps1 -Fix

# Тестирование WMS-сервисов с генерацией HTML-отчета
./scripts/test-wms-services.ps1 -GenerateHtml -OpenResults
```

---

## 🔍 Устранение неполадок

### Распространенные проблемы

1. **502 Bad Gateway** - проверьте, запущены ли контейнеры GeoServer:
   ```powershell
   docker ps | Select-String "geoserver"
   ```

2. **404 Not Found** - проверьте правильность URL и конфигурацию NGINX:
   ```powershell
   docker logs dev-nginx-1
   ```

3. **Перенаправление на неправильную инстанцию** - запустите скрипт проверки маршрутизации:
   ```powershell
   ./scripts/check-geoserver-routing.ps1 -Verbose
   ```

4. **Проблемы с доступом к WMS-сервисам** - проверьте работоспособность WMS:
   ```powershell
   ./scripts/test-wms-services.ps1
   ```

### Проверка логов

```powershell
# Проверка логов NGINX
docker logs dev-nginx-1

# Проверка логов Vector GeoServer
docker logs geoserver-vector

# Проверка логов ECW GeoServer
docker logs geoserver-ecw
```

---

## 📚 Документация

Подробная документация доступна в каталоге `docs`:

- [Настройка маршрутизации GeoServer](docs/geoserver-routing.md)
- [Руководство администратора](docs/admin-guide.md)
- [Руководство пользователя](docs/user-guide.md)
- [Переменные окружения](docs/environment-variables.md)
- [PowerShell инструменты](docs/powershell-tools.md)
- [Веб-интерфейс](docs/web-interface.md)
- [Структура проекта](docs/project-structure.md)

---

## 📝 Лицензия

© 2025 Corporate GIS Team. Все права защищены.
