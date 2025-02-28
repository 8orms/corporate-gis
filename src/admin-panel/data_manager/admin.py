"""
Настройка админ-панели для моделей приложения data_manager.
"""

from django.contrib import admin
from django.contrib.gis.admin import OSMGeoAdmin
from .models import LayerMetadata, LayerCategory, AttributeMetadata, Category, Object, Layer, sync_from_json, sync_to_json, generate_js_config
from django.utils.html import format_html
from django.urls import path
from django.shortcuts import redirect
from django.contrib import messages
import logging
from django import forms

logger = logging.getLogger(__name__)


class AttributeMetadataInline(admin.TabularInline):
    """
    Встроенное отображение метаданных атрибутов слоев в админ-панели.
    """
    model = AttributeMetadata
    extra = 1
    
    fieldsets = (
        (None, {
            'fields': ('name', 'display_name', 'description', 'attribute_type', 'is_visible', 'order')
        }),
    )


@admin.register(LayerMetadata)
class LayerMetadataAdmin(OSMGeoAdmin):
    """
    Настройка отображения модели метаданных слоев в админ-панели.
    """
    list_display = ('name', 'title', 'workspace', 'layer_type', 'is_published', 'is_restricted')
    list_filter = ('layer_type', 'workspace', 'is_published', 'is_restricted')
    search_fields = ('name', 'title', 'abstract', 'keywords')
    readonly_fields = ('date_created', 'last_updated')
    filter_horizontal = ('categories',)
    
    fieldsets = (
        (None, {
            'fields': ('name', 'title', 'abstract', 'keywords', 'layer_type', 'source')
        }),
        ('Связь с GeoServer', {
            'fields': ('workspace', 'store', 'srs')
        }),
        ('Настройки', {
            'fields': ('is_published', 'is_restricted', 'default_style')
        }),
        ('Географические границы', {
            'fields': ('bounding_box',)
        }),
        ('Категории', {
            'fields': ('categories',)
        }),
        ('Информация', {
            'fields': ('date_created', 'last_updated'),
            'classes': ('collapse',)
        }),
    )
    
    inlines = [AttributeMetadataInline]


@admin.register(LayerCategory)
class LayerCategoryAdmin(admin.ModelAdmin):
    """
    Настройка отображения модели категорий слоев в админ-панели.
    """
    list_display = ('name', 'parent', 'order', 'get_layer_count')
    list_filter = ('parent',)
    search_fields = ('name', 'description')
    filter_horizontal = ('layers',)
    
    fieldsets = (
        (None, {
            'fields': ('name', 'description', 'parent', 'order')
        }),
        ('Слои', {
            'fields': ('layers',)
        }),
    )
    
    def get_layer_count(self, obj):
        """
        Получение количества слоев в категории.
        """
        return obj.layers.count()
    get_layer_count.short_description = 'Количество слоев'


@admin.register(AttributeMetadata)
class AttributeMetadataAdmin(admin.ModelAdmin):
    """
    Настройка отображения модели метаданных атрибутов слоев в админ-панели.
    """
    list_display = ('name', 'display_name', 'layer', 'attribute_type', 'is_visible', 'order')
    list_filter = ('layer', 'attribute_type', 'is_visible')
    search_fields = ('name', 'display_name', 'description', 'layer__name')
    
    fieldsets = (
        (None, {
            'fields': ('layer', 'name', 'display_name', 'description', 'attribute_type', 'is_visible', 'order')
        }),
    )


class CategoryAdmin(admin.ModelAdmin):
    list_display = ['id', 'name', 'icon', 'layer_count']
    search_fields = ['id', 'name']
    
    def layer_count(self, obj):
        return obj.layers.count()
    layer_count.short_description = 'Кол-во слоев'


class ObjectAdmin(admin.ModelAdmin):
    list_display = ['id', 'name', 'bbox_display', 'layer_count']
    search_fields = ['id', 'name']
    fieldsets = (
        (None, {
            'fields': ('id', 'name')
        }),
        ('Координаты границ', {
            'fields': (('bbox_min_x', 'bbox_min_y'), ('bbox_max_x', 'bbox_max_y'))
        })
    )
    
    def bbox_display(self, obj):
        return f"[{obj.bbox_min_x}, {obj.bbox_min_y}, {obj.bbox_max_x}, {obj.bbox_max_y}]"
    bbox_display.short_description = 'Границы (bbox)'
    
    def layer_count(self, obj):
        return obj.layers.count()
    layer_count.short_description = 'Кол-во слоев'


class LayerAdminForm(forms.ModelForm):
    """Форма с динамическими полями в зависимости от типа слоя"""
    class Meta:
        model = Layer
        fields = '__all__'
    
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        # Делаем поля для тегов более удобными
        if isinstance(self.fields.get('tags'), forms.JSONField):
            self.fields['tags'].help_text = 'Введите теги через запятую'
            
        # В зависимости от выбранного типа, показываем соответствующие поля
        if self.instance.pk and self.instance.type:
            self._toggle_fields_by_type(self.instance.type)
    
    def _toggle_fields_by_type(self, layer_type):
        """Скрывает/показывает поля в зависимости от типа слоя"""
        if layer_type == 'raster':
            self.fields['data_store'].widget = forms.HiddenInput()
            self.fields['table_name'].widget = forms.HiddenInput()
        elif layer_type == 'vector':
            self.fields['file_path'].widget = forms.HiddenInput()


class LayerAdmin(admin.ModelAdmin):
    form = LayerAdminForm
    list_display = ['id', 'title', 'type', 'object', 'category', 'workspace', 'layer_name', 'visible_icon']
    list_filter = ['type', 'object', 'category', 'visible']
    search_fields = ['id', 'title', 'workspace', 'layer_name']
    fieldsets = (
        (None, {
            'fields': ('id', 'type', 'title', 'object', 'category')
        }),
        ('GeoServer настройки', {
            'fields': ('workspace', 'layer_name', 'instance')
        }),
        ('Дополнительно', {
            'fields': ('year', 'visible', 'tags')
        }),
        ('Настройки растрового слоя', {
            'fields': ('file_path',),
            'classes': ('raster-fields',)
        }),
        ('Настройки векторного слоя', {
            'fields': ('data_store', 'table_name'),
            'classes': ('vector-fields',)
        })
    )
    
    class Media:
        js = ('admin/js/layer_admin.js',)  # JavaScript для динамического отображения полей
    
    def visible_icon(self, obj):
        if obj.visible:
            return format_html('<span style="color: green;">✓</span>')
        return format_html('<span style="color: red;">✗</span>')
    visible_icon.short_description = 'Видимость'
    
    def get_urls(self):
        urls = super().get_urls()
        custom_urls = [
            path('import-from-json/', self.admin_site.admin_view(self.import_from_json_view), 
                 name='data_manager_import_from_json'),
            path('export-to-json/', self.admin_site.admin_view(self.export_to_json_view), 
                 name='data_manager_export_to_json'),
            path('generate-js-config/', self.admin_site.admin_view(self.generate_js_config_view), 
                 name='data_manager_generate_js_config'),
        ]
        return custom_urls + urls
    
    def import_from_json_view(self, request):
        """Импорт данных из JSON-файла"""
        try:
            success = sync_from_json()
            if success:
                messages.success(request, 'Данные успешно импортированы из JSON-файла.')
            else:
                messages.error(request, 'Ошибка при импорте данных. Проверьте логи для получения подробностей.')
        except Exception as e:
            logger.exception("Неожиданная ошибка при импорте из JSON")
            messages.error(request, f'Ошибка при импорте данных: {e}')
        return redirect('..')
    
    def export_to_json_view(self, request):
        """Экспорт данных в JSON-файл"""
        try:
            success = sync_to_json()
            if success:
                messages.success(request, 'Данные успешно экспортированы в JSON-файл.')
            else:
                messages.error(request, 'Ошибка при экспорте данных. Проверьте логи для получения подробностей.')
        except Exception as e:
            logger.exception("Неожиданная ошибка при экспорте в JSON")
            messages.error(request, f'Ошибка при экспорте данных: {e}')
        return redirect('..')
    
    def generate_js_config_view(self, request):
        """Генерация JavaScript-конфигурации"""
        try:
            success = generate_js_config()
            if success:
                messages.success(request, 'JavaScript-конфигурация успешно сгенерирована.')
            else:
                messages.error(request, 'Ошибка при генерации JavaScript-конфигурации. Проверьте логи для получения подробностей.')
        except Exception as e:
            logger.exception("Неожиданная ошибка при генерации JS-конфигурации")
            messages.error(request, f'Ошибка при генерации JavaScript-конфигурации: {e}')
        return redirect('..')
    
    def changelist_view(self, request, extra_context=None):
        """Добавляем кнопки для импорта/экспорта на страницу списка слоев"""
        extra_context = extra_context or {}
        extra_context['show_import_export'] = True
        return super().changelist_view(request, extra_context=extra_context)


# Регистрация моделей в админке
admin.site.register(Category, CategoryAdmin)
admin.site.register(Object, ObjectAdmin)
admin.site.register(Layer, LayerAdmin) 