# Generated manually

from django.db import migrations, models
import django.db.models.deletion
from django.contrib.gis.db import models as gis_models


class Migration(migrations.Migration):

    initial = True

    dependencies = [
    ]

    operations = [
        migrations.CreateModel(
            name='Category',
            fields=[
                ('id', models.CharField(help_text='Уникальный ID категории (например, topo)', max_length=50, primary_key=True, serialize=False, verbose_name='Идентификатор')),
                ('name', models.CharField(max_length=100, verbose_name='Название')),
                ('icon', models.CharField(max_length=50, verbose_name='Иконка')),
            ],
            options={
                'verbose_name': 'Категория',
                'verbose_name_plural': 'Категории',
                'ordering': ['name'],
            },
        ),
        migrations.CreateModel(
            name='Object',
            fields=[
                ('id', models.CharField(help_text='Уникальный ID объекта (например, obj1)', max_length=50, primary_key=True, serialize=False, verbose_name='Идентификатор')),
                ('name', models.CharField(max_length=200, verbose_name='Название')),
                ('bbox_min_x', models.FloatField(verbose_name='Мин X')),
                ('bbox_min_y', models.FloatField(verbose_name='Мин Y')),
                ('bbox_max_x', models.FloatField(verbose_name='Макс X')),
                ('bbox_max_y', models.FloatField(verbose_name='Макс Y')),
            ],
            options={
                'verbose_name': 'Объект',
                'verbose_name_plural': 'Объекты',
                'ordering': ['name'],
            },
        ),
        migrations.CreateModel(
            name='LayerCategory',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('name', models.CharField(max_length=100, unique=True, verbose_name='Название')),
                ('description', models.TextField(blank=True, verbose_name='Описание')),
                ('order', models.PositiveIntegerField(default=0, verbose_name='Порядок отображения')),
                ('parent', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.CASCADE, related_name='children', to='data_manager.layercategory', verbose_name='Родительская категория')),
            ],
            options={
                'verbose_name': 'Категория слоев',
                'verbose_name_plural': 'Категории слоев',
                'ordering': ['order', 'name'],
            },
        ),
        migrations.CreateModel(
            name='LayerMetadata',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('name', models.CharField(help_text='Системное имя слоя в GeoServer', max_length=255, verbose_name='Имя слоя')),
                ('title', models.CharField(help_text='Отображаемое название слоя', max_length=255, verbose_name='Заголовок')),
                ('abstract', models.TextField(blank=True, help_text='Подробное описание слоя', verbose_name='Описание')),
                ('keywords', models.TextField(blank=True, help_text='Ключевые слова для поиска, разделенные запятыми', verbose_name='Ключевые слова')),
                ('layer_type', models.CharField(choices=[('vector', 'Векторный'), ('raster', 'Растровый'), ('ecw', 'ECW Растр')], max_length=50, verbose_name='Тип слоя')),
                ('source', models.CharField(blank=True, help_text='Источник данных', max_length=255, verbose_name='Источник')),
                ('date_created', models.DateTimeField(auto_now_add=True, verbose_name='Дата создания')),
                ('last_updated', models.DateTimeField(auto_now=True, verbose_name='Дата обновления')),
                ('bounding_box', gis_models.PolygonField(blank=True, help_text='Географические границы слоя', null=True, verbose_name='Граница')),
                ('workspace', models.CharField(help_text='Рабочее пространство GeoServer, в котором находится слой', max_length=100, verbose_name='Рабочее пространство')),
                ('store', models.CharField(help_text='Хранилище данных, в котором находится слой', max_length=100, verbose_name='Хранилище')),
                ('srs', models.CharField(default='EPSG:4326', help_text='Код системы координат (например, EPSG:4326)', max_length=50, verbose_name='Система координат')),
                ('is_published', models.BooleanField(default=True, help_text='Доступен ли слой для просмотра', verbose_name='Опубликован')),
                ('is_restricted', models.BooleanField(default=False, help_text='Требуется ли авторизация для просмотра', verbose_name='Ограниченный доступ')),
                ('default_style', models.CharField(blank=True, help_text='Имя стиля по умолчанию для слоя', max_length=100, verbose_name='Стиль по умолчанию')),
                ('categories', models.ManyToManyField(blank=True, related_name='layers', to='data_manager.layercategory', verbose_name='Категории')),
            ],
            options={
                'verbose_name': 'Метаданные слоя',
                'verbose_name_plural': 'Метаданные слоев',
                'ordering': ['title'],
                'unique_together': {('workspace', 'name')},
            },
        ),
        migrations.CreateModel(
            name='Layer',
            fields=[
                ('id', models.CharField(help_text='Уникальный ID слоя (например, obj1-topo-2023)', max_length=50, primary_key=True, serialize=False, verbose_name='Идентификатор')),
                ('type', models.CharField(choices=[('raster', 'Растровый'), ('vector', 'Векторный')], max_length=10, verbose_name='Тип слоя')),
                ('title', models.CharField(max_length=200, verbose_name='Название')),
                ('workspace', models.CharField(max_length=50, verbose_name='Workspace в GeoServer')),
                ('layer_name', models.CharField(max_length=100, verbose_name='Имя слоя в GeoServer')),
                ('instance', models.CharField(help_text="'vector' или 'ecw'", max_length=50, verbose_name='Инстанс GeoServer')),
                ('year', models.CharField(blank=True, max_length=10, null=True, verbose_name='Год данных')),
                ('visible', models.BooleanField(default=False, verbose_name='Видимость по умолчанию')),
                ('tags', models.JSONField(blank=True, default=list, verbose_name='Теги')),
                ('file_path', models.CharField(blank=True, help_text='Путь к файлу ECW в контейнере GeoServer', max_length=255, null=True, verbose_name='Путь к файлу (для растровых)')),
                ('data_store', models.CharField(blank=True, max_length=50, null=True, verbose_name='Data Store (для векторных)')),
                ('table_name', models.CharField(blank=True, max_length=100, null=True, verbose_name='Имя таблицы (для векторных)')),
                ('category', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='layers', to='data_manager.category', verbose_name='Категория')),
                ('object', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='layers', to='data_manager.object', verbose_name='Объект')),
            ],
            options={
                'verbose_name': 'Слой',
                'verbose_name_plural': 'Слои',
                'ordering': ['title'],
            },
        ),
        migrations.CreateModel(
            name='AttributeMetadata',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('name', models.CharField(max_length=100, verbose_name='Имя атрибута')),
                ('display_name', models.CharField(max_length=100, verbose_name='Отображаемое имя')),
                ('description', models.TextField(blank=True, verbose_name='Описание')),
                ('attribute_type', models.CharField(max_length=50, verbose_name='Тип данных')),
                ('is_visible', models.BooleanField(default=True, verbose_name='Видимый')),
                ('order', models.PositiveIntegerField(default=0, verbose_name='Порядок отображения')),
                ('layer', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='attributes', to='data_manager.layermetadata', verbose_name='Слой')),
            ],
            options={
                'verbose_name': 'Метаданные атрибута',
                'verbose_name_plural': 'Метаданные атрибутов',
                'ordering': ['order', 'name'],
                'unique_together': {('layer', 'name')},
            },
        ),
    ]
