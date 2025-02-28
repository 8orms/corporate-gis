#!/bin/bash

# Установка параметров для обработки ошибок
set -e

# Функция для ожидания доступности базы данных
function wait_for_postgres() {
    echo "Ожидание PostgreSQL..."
    while ! nc -z $DB_HOST $DB_PORT; do
        sleep 0.5
    done
    echo "PostgreSQL доступен!"
}

# Ожидаем доступности базы данных
wait_for_postgres

# Применяем миграции
echo "Применение миграций..."
python manage.py migrate

# Создаем суперпользователя, если он не существует
echo "Проверка наличия суперпользователя..."
python manage.py shell -c "
from django.contrib.auth import get_user_model;
User = get_user_model();
if not User.objects.filter(username='$DJANGO_SUPERUSER_USERNAME').exists():
    User.objects.create_superuser('$DJANGO_SUPERUSER_USERNAME', '$DJANGO_SUPERUSER_EMAIL', '$DJANGO_SUPERUSER_PASSWORD');
    print('Суперпользователь создан');
else:
    print('Суперпользователь уже существует');
"

# Собираем статические файлы
echo "Сбор статических файлов..."
python manage.py collectstatic --noinput

# Синхронизируем реестр слоев из JSON
echo "Синхронизация реестра слоев..."
python manage.py sync_layer_registry --direction import --generate-js

# Запускаем сервер Django
echo "Запуск сервера Django..."
exec "$@" 