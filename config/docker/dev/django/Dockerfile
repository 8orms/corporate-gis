FROM python:3.10-slim

# Установка дополнительных зависимостей
RUN apt-get update && apt-get install -y \
    netcat-traditional \
    gcc \
    gdal-bin \
    libgdal-dev \
    g++ \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Установка переменных окружения
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DEBIAN_FRONTEND=noninteractive \
    DB_HOST=postgis \
    DB_PORT=5432

# Создание рабочей директории
WORKDIR /app

# Копирование и установка зависимостей Python
COPY src/admin-panel/requirements.txt .
RUN pip install --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Копирование кода приложения
COPY src/admin-panel/ .

# Копирование entrypoint-скрипта
COPY src/admin-panel/entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Запуск приложения через entrypoint-скрипт
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["gunicorn", "gis_admin.wsgi:application", "--bind", "0.0.0.0:8000"] 