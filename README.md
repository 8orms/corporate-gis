# Корпоративная ГИС-платформа
Система на базе GeoServer для обработки и визуализации геопространственных данных.  
**Целевая аудитория**: 15-50 пользователей в сфере инженерных изысканий (геология, геодезия, 
экология).
---

## 🛠️ Системные требования
- **ОС**: Windows 10+/Linux  
- **Docker Desktop** (версия 4.15+)  
- **Процессор**: 4+ ядра для оптимальной производительности  
- **RAM**: Минимум 8 GB  
- **Диск**: 20+ GB свободного места  
- **Виртуализация**: Включена поддержка VT-x/AMD-V в BIOS  
- **Свободные порты**: 80, 8080, 5432

---

## 🏗️ Архитектура

### Основные компоненты
| Сервис               | Версия     | Порт  | URL                                  | Описание                                           |
|----------------------|-----------:|------:|--------------------------------------|---------------------------------------------------|
| PostGIS             | 15-3.3     | 5432  | `postgis:5432`                       | База данных для геопространственных данных        |
| GeoServer           | 2.26.1     | 8080  | `http://localhost:8080/geoserver`   | Сервер для публикации геоданных                   |
| NGINX               | stable     | 80    | `http://localhost`                   | Веб-сервер и обратный прокси                       |

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
git clone https://github.com/username/corporate-gis.git
cd corporate-gis

# Инициализация проекта и создание структуры директорий
./manage-gis.ps1 init dev

# Запуск всех сервисов
./manage-gis.ps1 start
```

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

## 📝 Справочная информация

### Полезные ссылки
- [Документация GeoServer](https://docs.geoserver.org/latest/en/user/)
- [Документация PostGIS](https://postgis.net/documentation/)
- [Руководство по OpenLayers](https://openlayers.org/en/latest/doc/)

### Дополнительная документация
- Подробное описание структуры проекта: [project-structure.md](./docs/project-structure.md)
- Журнал разработки и дорожная карта: [storybook.md](./docs/storybook.md)
- Инструменты PowerShell для управления: [powershell-tools.md](./docs/powershell-tools.md)

---

&copy; 2024 Корпоративная ГИС | Версия 1.0
