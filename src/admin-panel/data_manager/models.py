"""
Модели для управления метаданными слоев.
"""

from django.db import models
from django.contrib.gis.db import models as gis_models
from django.utils.translation import gettext_lazy as _
from django.dispatch import receiver
from django.db.models.signals import post_save, post_delete
import subprocess
import json
import os
import logging

logger = logging.getLogger(__name__)


class LayerMetadata(models.Model):
    """
    Модель для хранения метаданных о слоях GeoServer.
    """
    LAYER_TYPES = (
        ('vector', _('Векторный')),
        ('raster', _('Растровый')),
        ('ecw', _('ECW Растр')),
    )
    
    name = models.CharField(
        max_length=255,
        verbose_name=_("Имя слоя"),
        help_text=_("Системное имя слоя в GeoServer")
    )
    title = models.CharField(
        max_length=255,
        verbose_name=_("Заголовок"),
        help_text=_("Отображаемое название слоя")
    )
    abstract = models.TextField(
        blank=True,
        verbose_name=_("Описание"),
        help_text=_("Подробное описание слоя")
    )
    keywords = models.TextField(
        blank=True,
        verbose_name=_("Ключевые слова"),
        help_text=_("Ключевые слова для поиска, разделенные запятыми")
    )
    layer_type = models.CharField(
        max_length=50,
        choices=LAYER_TYPES,
        verbose_name=_("Тип слоя")
    )
    source = models.CharField(
        max_length=255,
        blank=True,
        verbose_name=_("Источник"),
        help_text=_("Источник данных")
    )
    date_created = models.DateTimeField(
        auto_now_add=True,
        verbose_name=_("Дата создания")
    )
    last_updated = models.DateTimeField(
        auto_now=True,
        verbose_name=_("Дата обновления")
    )
    bounding_box = gis_models.PolygonField(
        null=True,
        blank=True,
        verbose_name=_("Граница"),
        help_text=_("Географические границы слоя")
    )
    
    # Связь с GeoServer
    workspace = models.CharField(
        max_length=100,
        verbose_name=_("Рабочее пространство"),
        help_text=_("Рабочее пространство GeoServer, в котором находится слой")
    )
    store = models.CharField(
        max_length=100,
        verbose_name=_("Хранилище"),
        help_text=_("Хранилище данных, в котором находится слой")
    )
    srs = models.CharField(
        max_length=50,
        default="EPSG:4326",
        verbose_name=_("Система координат"),
        help_text=_("Код системы координат (например, EPSG:4326)")
    )
    
    # Дополнительные настройки
    is_published = models.BooleanField(
        default=True,
        verbose_name=_("Опубликован"),
        help_text=_("Доступен ли слой для просмотра")
    )
    is_restricted = models.BooleanField(
        default=False,
        verbose_name=_("Ограниченный доступ"),
        help_text=_("Требуется ли авторизация для просмотра")
    )
    default_style = models.CharField(
        max_length=100,
        blank=True,
        verbose_name=_("Стиль по умолчанию"),
        help_text=_("Имя стиля по умолчанию для слоя")
    )
    
    class Meta:
        verbose_name = _("Метаданные слоя")
        verbose_name_plural = _("Метаданные слоев")
        unique_together = ('workspace', 'name')
        ordering = ['title']
    
    def __str__(self):
        return f"{self.title} ({self.workspace}:{self.name})"


class LayerCategory(models.Model):
    """
    Модель для категоризации слоев.
    """
    name = models.CharField(
        max_length=100,
        verbose_name=_("Название"),
        unique=True
    )
    description = models.TextField(
        blank=True,
        verbose_name=_("Описание")
    )
    parent = models.ForeignKey(
        'self',
        null=True,
        blank=True,
        on_delete=models.CASCADE,
        related_name='children',
        verbose_name=_("Родительская категория")
    )
    layers = models.ManyToManyField(
        LayerMetadata,
        related_name='categories',
        blank=True,
        verbose_name=_("Слои")
    )
    order = models.PositiveIntegerField(
        default=0,
        verbose_name=_("Порядок отображения")
    )
    
    class Meta:
        verbose_name = _("Категория слоев")
        verbose_name_plural = _("Категории слоев")
        ordering = ['order', 'name']
    
    def __str__(self):
        return self.name
        
        
class AttributeMetadata(models.Model):
    """
    Метаданные для атрибутов векторных слоев.
    """
    layer = models.ForeignKey(
        LayerMetadata,
        on_delete=models.CASCADE,
        related_name='attributes',
        verbose_name=_("Слой")
    )
    name = models.CharField(
        max_length=100,
        verbose_name=_("Имя атрибута")
    )
    display_name = models.CharField(
        max_length=100,
        verbose_name=_("Отображаемое имя")
    )
    description = models.TextField(
        blank=True,
        verbose_name=_("Описание")
    )
    attribute_type = models.CharField(
        max_length=50,
        verbose_name=_("Тип данных")
    )
    is_visible = models.BooleanField(
        default=True,
        verbose_name=_("Видимый")
    )
    order = models.PositiveIntegerField(
        default=0,
        verbose_name=_("Порядок отображения")
    )
    
    class Meta:
        verbose_name = _("Метаданные атрибута")
        verbose_name_plural = _("Метаданные атрибутов")
        unique_together = ('layer', 'name')
        ordering = ['order', 'name']
    
    def __str__(self):
        return f"{self.display_name} ({self.layer.name}.{self.name})"


class Category(models.Model):
    """Категория слоя (топография, геология и т.д.)"""
    id = models.CharField("Идентификатор", primary_key=True, max_length=50, 
                          help_text="Уникальный ID категории (например, topo)")
    name = models.CharField("Название", max_length=100)
    icon = models.CharField("Иконка", max_length=50)
    
    class Meta:
        verbose_name = "Категория"
        verbose_name_plural = "Категории"
        ordering = ['name']
    
    def __str__(self):
        return self.name


class Object(models.Model):
    """Объект проекта (стройка, месторождение и т.д.)"""
    id = models.CharField("Идентификатор", primary_key=True, max_length=50,
                          help_text="Уникальный ID объекта (например, obj1)")
    name = models.CharField("Название", max_length=200)
    bbox_min_x = models.FloatField("Мин X")
    bbox_min_y = models.FloatField("Мин Y")
    bbox_max_x = models.FloatField("Макс X")
    bbox_max_y = models.FloatField("Макс Y")
    
    class Meta:
        verbose_name = "Объект"
        verbose_name_plural = "Объекты"
        ordering = ['name']
    
    def __str__(self):
        return self.name
    
    @property
    def bbox(self):
        """Возвращает bbox в формате [minX, minY, maxX, maxY]"""
        return [self.bbox_min_x, self.bbox_min_y, self.bbox_max_x, self.bbox_max_y]


class Layer(models.Model):
    """Слой геоданных (растровый или векторный)"""
    TYPE_CHOICES = [
        ('raster', 'Растровый'),
        ('vector', 'Векторный'),
    ]
    
    id = models.CharField("Идентификатор", primary_key=True, max_length=50,
                         help_text="Уникальный ID слоя (например, obj1-topo-2023)")
    type = models.CharField("Тип слоя", max_length=10, choices=TYPE_CHOICES)
    title = models.CharField("Название", max_length=200)
    workspace = models.CharField("Workspace в GeoServer", max_length=50)
    layer_name = models.CharField("Имя слоя в GeoServer", max_length=100)
    instance = models.CharField("Инстанс GeoServer", max_length=50, 
                               help_text="'vector' или 'ecw'")
    object = models.ForeignKey(Object, verbose_name="Объект", on_delete=models.CASCADE, 
                              related_name='layers')
    category = models.ForeignKey(Category, verbose_name="Категория", on_delete=models.CASCADE,
                                related_name='layers')
    year = models.CharField("Год данных", max_length=10, blank=True, null=True)
    visible = models.BooleanField("Видимость по умолчанию", default=False)
    tags = models.JSONField("Теги", default=list, blank=True)
    
    # Дополнительные поля в зависимости от типа слоя
    file_path = models.CharField("Путь к файлу (для растровых)", max_length=255, blank=True, null=True,
                                help_text="Путь к файлу ECW в контейнере GeoServer")
    data_store = models.CharField("Data Store (для векторных)", max_length=50, blank=True, null=True)
    table_name = models.CharField("Имя таблицы (для векторных)", max_length=100, blank=True, null=True)
    
    class Meta:
        verbose_name = "Слой"
        verbose_name_plural = "Слои"
        ordering = ['title']
    
    def __str__(self):
        return f"{self.title} ({self.type})"
    
    def clean(self):
        """Дополнительная валидация модели"""
        from django.core.exceptions import ValidationError
        
        # Проверка полей в зависимости от типа слоя
        if self.type == 'raster' and not self.file_path:
            raise ValidationError({'file_path': 'Для растрового слоя необходимо указать путь к файлу'})
        elif self.type == 'vector' and (not self.data_store or not self.table_name):
            if not self.data_store:
                raise ValidationError({'data_store': 'Для векторного слоя необходимо указать Data Store'})
            if not self.table_name:
                raise ValidationError({'table_name': 'Для векторного слоя необходимо указать имя таблицы'})


# Функции для синхронизации между Django и JSON

def sync_to_json():
    """Синхронизация данных из моделей Django в JSON-файл"""
    registry_path = os.path.join('config', 'layer-registry.json')
    
    try:
        # Подготавливаем структуру данных
        registry = {
            'layers': [],
            'objects': [],
            'categories': []
        }
        
        # Добавляем категории
        for category in Category.objects.all():
            registry['categories'].append({
                'id': category.id,
                'name': category.name,
                'icon': category.icon
            })
        
        # Добавляем объекты
        for obj in Object.objects.all():
            registry['objects'].append({
                'id': obj.id,
                'name': obj.name,
                'bbox': obj.bbox
            })
        
        # Добавляем слои
        for layer in Layer.objects.all():
            layer_data = {
                'id': layer.id,
                'type': layer.type,
                'title': layer.title,
                'workspace': layer.workspace,
                'layerName': layer.layer_name,
                'instance': layer.instance,
                'objectId': layer.object.id,
                'category': layer.category.id,
                'year': layer.year,
                'visible': layer.visible,
                'tags': layer.tags
            }
            
            # Добавляем специфичные поля в зависимости от типа слоя
            if layer.type == 'raster':
                layer_data['filePath'] = layer.file_path
            elif layer.type == 'vector':
                layer_data['dataStore'] = layer.data_store
                layer_data['tableName'] = layer.table_name
            
            registry['layers'].append(layer_data)
        
        # Создаем директорию, если не существует
        os.makedirs(os.path.dirname(registry_path), exist_ok=True)
        
        # Сохраняем в JSON-файл
        with open(registry_path, 'w', encoding='utf-8') as f:
            json.dump(registry, f, ensure_ascii=False, indent=2)
            
        logger.info(f"Данные успешно экспортированы в {registry_path}")
        
        return True
    except Exception as e:
        logger.error(f"Ошибка при экспорте данных в JSON: {str(e)}")
        return False


def sync_from_json():
    """Импорт данных из JSON-файла в модели Django"""
    from django.db import transaction
    
    registry_path = os.path.join('config', 'layer-registry.json')
    
    if not os.path.exists(registry_path):
        logger.warning(f"Файл {registry_path} не найден")
        return False
    
    try:
        with open(registry_path, 'r', encoding='utf-8') as f:
            registry = json.load(f)
        
        with transaction.atomic():
            # Импортируем категории
            for cat_data in registry.get('categories', []):
                Category.objects.update_or_create(
                    id=cat_data['id'],
                    defaults={
                        'name': cat_data['name'],
                        'icon': cat_data['icon']
                    }
                )
            
            # Импортируем объекты
            for obj_data in registry.get('objects', []):
                bbox = obj_data['bbox']
                Object.objects.update_or_create(
                    id=obj_data['id'],
                    defaults={
                        'name': obj_data['name'],
                        'bbox_min_x': bbox[0],
                        'bbox_min_y': bbox[1],
                        'bbox_max_x': bbox[2],
                        'bbox_max_y': bbox[3]
                    }
                )
            
            # Импортируем слои
            for layer_data in registry.get('layers', []):
                defaults = {
                    'type': layer_data['type'],
                    'title': layer_data['title'],
                    'workspace': layer_data['workspace'],
                    'layer_name': layer_data['layerName'],
                    'instance': layer_data['instance'],
                    'year': layer_data.get('year', ''),
                    'visible': layer_data.get('visible', False),
                    'tags': layer_data.get('tags', []),
                }
                
                # Связанные модели
                try:
                    defaults['object'] = Object.objects.get(id=layer_data['objectId'])
                    defaults['category'] = Category.objects.get(id=layer_data['category'])
                except (Object.DoesNotExist, Category.DoesNotExist) as e:
                    logger.warning(f"Ошибка при импорте слоя {layer_data['id']}: {str(e)}")
                    continue  # Пропускаем, если объект или категория не существуют
                
                # Специфичные поля
                if layer_data['type'] == 'raster':
                    defaults['file_path'] = layer_data.get('filePath', '')
                elif layer_data['type'] == 'vector':
                    defaults['data_store'] = layer_data.get('dataStore', '')
                    defaults['table_name'] = layer_data.get('tableName', '')
                
                Layer.objects.update_or_create(
                    id=layer_data['id'],
                    defaults=defaults
                )
            
            logger.info(f"Данные успешно импортированы из {registry_path}")
            return True
            
    except Exception as e:
        logger.error(f"Ошибка при импорте данных из JSON: {str(e)}")
        return False


def generate_js_config():
    """Запуск скрипта для генерации JavaScript-конфигурации"""
    try:
        # Для Windows
        result = subprocess.run(['powershell', '-File', os.path.join('scripts', 'generate-layer-config.ps1')], 
                       check=True, capture_output=True, text=True)
        logger.info(f"JavaScript-конфигурация успешно сгенерирована. Вывод: {result.stdout}")
        return True
    except subprocess.CalledProcessError as e:
        logger.error(f"Ошибка при генерации JavaScript-конфигурации: {e}\nStdout: {e.stdout}\nStderr: {e.stderr}")
        return False
    except FileNotFoundError:
        logger.error("Скрипт PowerShell не найден")
        return False
    except Exception as e:
        logger.error(f"Неизвестная ошибка при генерации JavaScript-конфигурации: {str(e)}")
        return False


# Сигналы для автоматической синхронизации

@receiver([post_save, post_delete], sender=Category)
@receiver([post_save, post_delete], sender=Object)
@receiver([post_save, post_delete], sender=Layer)
def update_json_registry(sender, **kwargs):
    """Обновляет JSON-реестр при изменении моделей"""
    sync_to_json()
    generate_js_config() 