"""
URL конфигурация для приложения geoserver_connector.
"""

from django.urls import path
from .views import (
    WorkspacesListView, 
    WorkspaceDetailView, 
    DataStoresListView,
    DataStoreDetailView,
    LayersListView,
    LayerDetailView
)

# URL-маршруты приложения
urlpatterns = [
    # Маршруты для рабочих пространств GeoServer
    path('workspaces/', WorkspacesListView.as_view(), name='workspaces-list'),
    path('workspaces/<str:name>/', WorkspaceDetailView.as_view(), name='workspace-detail'),
    
    # Маршруты для хранилищ данных
    path('workspaces/<str:workspace>/datastores/', DataStoresListView.as_view(), name='datastores-list'),
    path('workspaces/<str:workspace>/datastores/<str:name>/', DataStoreDetailView.as_view(), name='datastore-detail'),
    
    # Маршруты для слоев
    path('layers/', LayersListView.as_view(), name='layers-list'),
    path('workspaces/<str:workspace>/layers/', LayersListView.as_view(), name='workspace-layers-list'),
    path('workspaces/<str:workspace>/layers/<str:name>/', LayerDetailView.as_view(), name='layer-detail'),
] 