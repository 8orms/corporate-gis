FROM python:3.10-slim

WORKDIR /app

# Установка зависимостей для GeoDjango и необходимых инструментов сборки
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        gdal-bin \
        libgdal-dev \
        python3-gdal \
        binutils \
        libproj-dev \
        netcat-openbsd \
        gcc \
        g++ \
        build-essential \
        python3-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Создание и активация виртуального окружения
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Обновление pip до последней версии
RUN pip install --upgrade pip

# Копирование и установка зависимостей
COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

# Копирование проекта
COPY . /app/

# Скрипт для проверки доступности базы данных перед запуском приложения
COPY ./entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

EXPOSE 8000

# Запуск приложения через entrypoint скрипт
ENTRYPOINT ["/app/entrypoint.sh"] 