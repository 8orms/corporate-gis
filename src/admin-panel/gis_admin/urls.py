"""
URL configuration for gis_admin project.
"""

from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from rest_framework import permissions
from drf_yasg.views import get_schema_view
from drf_yasg import openapi

# Создание схемы API для Swagger/OpenAPI документации
schema_view = get_schema_view(
    openapi.Info(
        title="GIS Admin API",
        default_version='v1',
        description="API для управления ГИС-платформой",
        terms_of_service="https://www.example.com/terms/",
        contact=openapi.Contact(email="admin@example.com"),
        license=openapi.License(name="BSD License"),
    ),
    public=True,
    permission_classes=[permissions.IsAuthenticated],
)

urlpatterns = [
    # Административный интерфейс Django
    path('admin/', admin.site.urls),
    
    # API endpoints
    path('api/v1/', include([
        path('layers/', include('data_manager.urls')),
        path('geoserver/', include('geoserver_connector.urls')),
        path('auth/', include('core.urls')),
    ])),
    
    # API документация
    path('api/docs/', schema_view.with_ui('swagger', cache_timeout=0), name='schema-swagger-ui'),
    path('api/redoc/', schema_view.with_ui('redoc', cache_timeout=0), name='schema-redoc'),
    
    # Аутентификация через Django AllAuth
    path('accounts/', include('allauth.urls')),
]

# Обслуживание статических и медиа файлов в среде разработки
if settings.DEBUG:
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT) 