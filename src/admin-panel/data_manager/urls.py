"""
URL конфигурация для приложения data_manager.
"""

from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    LayerMetadataViewSet,
    LayerCategoryViewSet, 
    AttributeMetadataViewSet,
    SyncLayersView,
    LayerUploadView,
    LayersByBoundsView
)

# Создание маршрутизатора для ViewSets
router = DefaultRouter()
router.register(r'layers', LayerMetadataViewSet)
router.register(r'categories', LayerCategoryViewSet)
router.register(r'attributes', AttributeMetadataViewSet)

# URL-маршруты приложения
urlpatterns = [
    # Маршруты API для работы с метаданными слоев
    path('', include(router.urls)),
    
    # Маршруты для синхронизации с GeoServer
    path('sync-geoserver/', SyncLayersView.as_view(), name='sync-geoserver'),
    
    # Поиск слоев по географическим границам
    path('search/bounds/', LayersByBoundsView.as_view(), name='layers-by-bounds'),
    
    # URL для загрузки нового слоя
    path('upload/', LayerUploadView.as_view(), name='layer-upload'),
] 