#!/bin/bash
# Скрипт для проверки работы Django-админки с реестром слоев

set -e

# Проверяем доступность сервера Django
echo "Проверка доступности Django-админки..."

# Ждем, пока сервер станет доступен
MAX_TRIES=30
COUNTER=0
while ! curl -s "http://localhost:8000/admin/" > /dev/null; do
    if [ $COUNTER -eq $MAX_TRIES ]; then
        echo "Ошибка: Не удалось подключиться к Django-админке после $MAX_TRIES попыток."
        exit 1
    fi
    COUNTER=$((COUNTER+1))
    echo "Ожидание доступности Django-админки... ($COUNTER/$MAX_TRIES)"
    sleep 5
done

echo "Django-админка доступна!"

# Проверяем API для синхронизации реестра слоев
echo "Проверка API для синхронизации реестра слоев..."

RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8000/admin/data_manager/layer/")

if [ "$RESPONSE" == "200" ] || [ "$RESPONSE" == "302" ]; then
    echo "API для слоев доступен!"
else
    echo "Ошибка: API для слоев недоступен. Код ответа: $RESPONSE"
    exit 1
fi

# Проверяем доступность JSON-реестра слоев
echo "Проверка доступности JSON-реестра слоев..."

if [ -f "config/layer-registry.json" ]; then
    echo "JSON-реестр слоев найден!"
else
    echo "Предупреждение: Файл JSON-реестра слоев не найден."
fi

echo "Проверка успешно завершена!"
exit 0 