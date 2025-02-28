"""
Сериализаторы для моделей приложения data_manager.
"""

from rest_framework import serializers
from django.contrib.gis.geos import Polygon
from .models import LayerMetadata, LayerCategory, AttributeMetadata


class AttributeMetadataSerializer(serializers.ModelSerializer):
    """
    Сериализатор для модели метаданных атрибутов слоев.
    """
    class Meta:
        model = AttributeMetadata
        fields = [
            'id', 'name', 'display_name', 'description', 
            'attribute_type', 'is_visible', 'order', 'layer'
        ]


class LayerMetadataSerializer(serializers.ModelSerializer):
    """
    Сериализатор для модели метаданных слоев.
    """
    attributes = AttributeMetadataSerializer(many=True, read_only=True)
    bounding_box = serializers.SerializerMethodField()
    categories = serializers.PrimaryKeyRelatedField(
        many=True, 
        queryset=LayerCategory.objects.all(),
        required=False
    )
    category_names = serializers.SerializerMethodField(read_only=True)
    
    class Meta:
        model = LayerMetadata
        fields = [
            'id', 'name', 'title', 'abstract', 'keywords', 'layer_type', 
            'source', 'date_created', 'last_updated', 'bounding_box',
            'workspace', 'store', 'srs', 'is_published', 'is_restricted',
            'default_style', 'attributes', 'categories', 'category_names'
        ]
        read_only_fields = ['id', 'date_created', 'last_updated', 'attributes']
    
    def get_bounding_box(self, obj):
        """
        Получение географических границ слоя в формате GeoJSON.
        """
        if obj.bounding_box:
            return {
                'type': 'Polygon',
                'coordinates': [list(obj.bounding_box.coords[0])]
            }
        return None
    
    def get_category_names(self, obj):
        """
        Получение списка названий категорий слоя.
        """
        return [category.name for category in obj.categories.all()]
    
    def to_internal_value(self, data):
        """
        Преобразование данных для создания/обновления объекта.
        """
        # Обработка bounding_box в формате GeoJSON
        if 'bounding_box' in data and data['bounding_box']:
            bbox_data = data['bounding_box']
            if isinstance(bbox_data, dict) and bbox_data.get('type') == 'Polygon':
                coords = bbox_data.get('coordinates')
                if coords and len(coords) > 0:
                    try:
                        data['bounding_box'] = Polygon(coords[0])
                    except Exception as e:
                        raise serializers.ValidationError({
                            'bounding_box': f'Неверный формат географических границ: {e}'
                        })
        
        return super().to_internal_value(data)
    
    def create(self, validated_data):
        """
        Создание метаданных слоя.
        """
        categories_data = validated_data.pop('categories', [])
        layer = LayerMetadata.objects.create(**validated_data)
        
        # Добавление категорий
        layer.categories.set(categories_data)
        
        return layer
    
    def update(self, instance, validated_data):
        """
        Обновление метаданных слоя.
        """
        categories_data = validated_data.pop('categories', None)
        
        # Обновление полей объекта
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        
        # Обновление категорий
        if categories_data is not None:
            instance.categories.set(categories_data)
        
        instance.save()
        return instance


class LayerCategorySerializer(serializers.ModelSerializer):
    """
    Сериализатор для модели категорий слоев.
    """
    children = serializers.SerializerMethodField()
    parent_name = serializers.SerializerMethodField(read_only=True)
    layer_count = serializers.SerializerMethodField(read_only=True)
    
    class Meta:
        model = LayerCategory
        fields = [
            'id', 'name', 'description', 'parent', 'parent_name',
            'order', 'children', 'layer_count'
        ]
        read_only_fields = ['id', 'children', 'parent_name', 'layer_count']
    
    def get_children(self, obj):
        """
        Получение дочерних категорий.
        """
        children = LayerCategory.objects.filter(parent=obj)
        if children:
            return LayerCategorySerializer(children, many=True).data
        return []
    
    def get_parent_name(self, obj):
        """
        Получение имени родительской категории.
        """
        return obj.parent.name if obj.parent else None
    
    def get_layer_count(self, obj):
        """
        Получение количества слоев в категории.
        """
        return obj.layers.count()
    
    def validate_parent(self, value):
        """
        Проверка корректности родительской категории.
        """
        if value == self.instance:
            raise serializers.ValidationError("Категория не может быть родителем самой себя")
        return value
    
    def validate(self, data):
        """
        Проверка данных сериализатора.
        """
        # Проверка циклических ссылок
        parent = data.get('parent')
        if parent:
            current_parent = parent
            while current_parent:
                if current_parent == self.instance:
                    raise serializers.ValidationError({
                        'parent': 'Обнаружена циклическая ссылка в иерархии категорий'
                    })
                current_parent = current_parent.parent
        
        return data 