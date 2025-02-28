"""
Представления для приложения data_manager.
"""

import logging
import os
from django.contrib.gis.geos import Polygon
from django.db.models import Q
from rest_framework import viewsets, status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, IsAdminUser, BasePermission
from rest_framework.parsers import MultiPartParser, FormParser
from .models import LayerMetadata, LayerCategory, AttributeMetadata
from .serializers import (
    LayerMetadataSerializer, 
    LayerCategorySerializer, 
    AttributeMetadataSerializer
)
from geoserver_connector.services import GeoServerConnector

logger = logging.getLogger(__name__)


class LayerPermission(BasePermission):
    """
    Разрешение на доступ к слоям в зависимости от прав пользователя.
    """
    def has_permission(self, request, view):
        # Администраторы имеют полный доступ
        if request.user.is_staff or request.user.is_geoserver_admin:
            return True
        
        # Для чтения - разрешаем, детальная проверка происходит в get_queryset
        if request.method in ['GET', 'HEAD', 'OPTIONS']:
            return True
        
        # Для всех остальных - только администраторы
        return False
    
    def has_object_permission(self, request, view, obj):
        # Администраторы имеют полный доступ
        if request.user.is_staff or request.user.is_geoserver_admin:
            return True
        
        # Для чтения - проверяем права на конкретный слой
        if request.method in ['GET', 'HEAD', 'OPTIONS']:
            # Проверка прав доступа к слою из модели UserLayerPermission
            layer_permissions = request.user.layer_permissions.filter(
                layer_name=obj.name,
                workspace=obj.workspace,
                can_read=True
            )
            return layer_permissions.exists()
        
        # Для изменения - проверяем права на запись
        elif request.method in ['PUT', 'PATCH']:
            layer_permissions = request.user.layer_permissions.filter(
                layer_name=obj.name,
                workspace=obj.workspace,
                can_write=True
            )
            return layer_permissions.exists()
        
        # Для удаления - проверяем права на удаление
        elif request.method == 'DELETE':
            layer_permissions = request.user.layer_permissions.filter(
                layer_name=obj.name,
                workspace=obj.workspace,
                can_delete=True
            )
            return layer_permissions.exists()
        
        return False


class LayerMetadataViewSet(viewsets.ModelViewSet):
    """
    ViewSet для модели метаданных слоев.
    """
    queryset = LayerMetadata.objects.all()
    serializer_class = LayerMetadataSerializer
    permission_classes = [IsAuthenticated, LayerPermission]
    filterset_fields = ['layer_type', 'workspace', 'is_published', 'is_restricted']
    search_fields = ['name', 'title', 'abstract', 'keywords']
    ordering_fields = ['name', 'title', 'date_created', 'last_updated']
    ordering = ['title']
    
    def get_queryset(self):
        """
        Получение списка слоев с учетом прав пользователя.
        """
        user = self.request.user
        queryset = super().get_queryset()
        
        # Администраторы видят все слои
        if user.is_staff or user.is_geoserver_admin:
            return queryset
        
        # Фильтрация по правам пользователя
        accessible_layers = []
        for perm in user.layer_permissions.filter(can_read=True):
            accessible_layers.append((perm.workspace, perm.layer_name))
        
        if accessible_layers:
            filters = Q()
            for workspace, layer_name in accessible_layers:
                filters |= Q(workspace=workspace, name=layer_name)
            return queryset.filter(filters)
        
        # Если у пользователя нет прав, возвращаем только публичные слои
        return queryset.filter(is_published=True, is_restricted=False)


class LayerCategoryViewSet(viewsets.ModelViewSet):
    """
    ViewSet для модели категорий слоев.
    """
    queryset = LayerCategory.objects.all()
    serializer_class = LayerCategorySerializer
    permission_classes = [IsAuthenticated]
    filterset_fields = ['parent']
    search_fields = ['name', 'description']
    ordering_fields = ['name', 'order']
    ordering = ['order', 'name']
    
    def get_permissions(self):
        """
        Переопределение разрешений в зависимости от действия.
        """
        if self.action in ['create', 'update', 'partial_update', 'destroy']:
            return [IsAuthenticated(), IsAdminUser()]
        return super().get_permissions()
    
    def get_queryset(self):
        """
        Получение списка категорий с фильтрацией.
        """
        queryset = super().get_queryset()
        
        # Фильтрация по родительской категории
        parent_id = self.request.query_params.get('parent')
        if parent_id:
            if parent_id == 'null':
                queryset = queryset.filter(parent__isnull=True)
            else:
                queryset = queryset.filter(parent_id=parent_id)
        
        # Фильтрация по корневым категориям
        root_only = self.request.query_params.get('root_only')
        if root_only and root_only.lower() == 'true':
            queryset = queryset.filter(parent__isnull=True)
        
        return queryset


class AttributeMetadataViewSet(viewsets.ModelViewSet):
    """
    ViewSet для модели метаданных атрибутов слоев.
    """
    queryset = AttributeMetadata.objects.all()
    serializer_class = AttributeMetadataSerializer
    permission_classes = [IsAuthenticated, IsAdminUser]
    filterset_fields = ['layer', 'is_visible']
    search_fields = ['name', 'display_name', 'description']
    ordering_fields = ['name', 'display_name', 'order']
    ordering = ['order', 'name']


class SyncLayersView(APIView):
    """
    Представление для синхронизации метаданных слоев с GeoServer.
    """
    permission_classes = [IsAuthenticated, IsAdminUser]
    
    def post(self, request):
        """
        Синхронизация метаданных слоев с GeoServer.
        """
        instance_type = request.data.get('instance_type', 'vector')
        workspace = request.data.get('workspace')
        
        geoserver = GeoServerConnector(instance_type=instance_type)
        try:
            # Получение списка слоев из GeoServer
            layers_response = geoserver.get_layers(workspace)
            
            if 'error' in layers_response:
                return Response(
                    {"error": f"Ошибка при получении слоев из GeoServer: {layers_response['error']}"},
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR
                )
            
            # Обработка ответа и создание/обновление метаданных
            layers = layers_response.get('layers', {}).get('layer', [])
            if not isinstance(layers, list):
                layers = [layers] if layers else []
            
            sync_results = {
                'created': [],
                'updated': [],
                'errors': []
            }
            
            for layer_info in layers:
                layer_name = layer_info.get('name')
                if not layer_name:
                    continue
                
                # Попытка получить детальную информацию о слое
                try:
                    # Извлечение имени рабочего пространства и имени слоя из полного имени
                    name_parts = layer_name.split(':')
                    if len(name_parts) > 1:
                        ws_name = name_parts[0]
                        name = name_parts[1]
                    else:
                        ws_name = workspace or 'default'
                        name = layer_name
                    
                    # Получение детальной информации о слое
                    layer_details = geoserver.get_layer_details(ws_name, name)
                    
                    if 'error' in layer_details:
                        sync_results['errors'].append({
                            'name': layer_name,
                            'error': layer_details['error']
                        })
                        continue
                    
                    # Определение типа слоя (векторный или растровый)
                    layer_type = 'vector'
                    if instance_type == 'ecw' or 'coverage' in layer_details:
                        layer_type = 'ecw' if instance_type == 'ecw' else 'raster'
                    
                    # Поиск существующего слоя в БД
                    layer, created = LayerMetadata.objects.get_or_create(
                        name=name,
                        workspace=ws_name,
                        defaults={
                            'title': layer_name,
                            'layer_type': layer_type,
                            'store': layer_details.get('defaultStore', '')
                        }
                    )
                    
                    # Обновление информации о слое
                    if not created:
                        layer.title = layer_name
                        layer.layer_type = layer_type
                        layer.store = layer_details.get('defaultStore', '')
                        layer.save()
                    
                    # Добавление в результаты
                    result_info = {
                        'name': layer_name,
                        'id': layer.id
                    }
                    if created:
                        sync_results['created'].append(result_info)
                    else:
                        sync_results['updated'].append(result_info)
                    
                except Exception as e:
                    sync_results['errors'].append({
                        'name': layer_name,
                        'error': str(e)
                    })
            
            return Response({
                'message': 'Синхронизация завершена',
                'results': sync_results
            })
            
        except Exception as e:
            logger.error(f"Ошибка при синхронизации слоев: {e}")
            return Response(
                {"error": f"Произошла ошибка при синхронизации: {str(e)}"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class LayersByBoundsView(APIView):
    """
    Представление для поиска слоев по географическим границам.
    """
    permission_classes = [IsAuthenticated]
    
    def post(self, request):
        """
        Поиск слоев, пересекающихся с заданными географическими границами.
        """
        bounds_data = request.data.get('bounds')
        if not bounds_data:
            return Response(
                {"error": "Необходимо указать географические границы"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            # Преобразование границ в полигон
            if isinstance(bounds_data, dict) and bounds_data.get('type') == 'Polygon':
                coords = bounds_data.get('coordinates')
                if not coords or not len(coords) > 0:
                    raise ValueError("Неверный формат координат")
                
                search_polygon = Polygon(coords[0])
            elif isinstance(bounds_data, list) and len(bounds_data) == 4:
                # Формат [minLng, minLat, maxLng, maxLat]
                min_lng, min_lat, max_lng, max_lat = bounds_data
                search_polygon = Polygon.from_bbox((min_lng, min_lat, max_lng, max_lat))
            else:
                return Response(
                    {"error": "Неверный формат географических границ"},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            # Фильтрация слоев, пересекающихся с границами
            queryset = LayerMetadata.objects.filter(
                bounding_box__intersects=search_polygon,
                is_published=True
            )
            
            # Применение дополнительных фильтров
            layer_type = request.data.get('layer_type')
            if layer_type:
                queryset = queryset.filter(layer_type=layer_type)
            
            workspace = request.data.get('workspace')
            if workspace:
                queryset = queryset.filter(workspace=workspace)
            
            category = request.data.get('category')
            if category:
                queryset = queryset.filter(categories__id=category)
            
            # Сериализация и возврат результатов
            serializer = LayerMetadataSerializer(queryset, many=True)
            return Response(serializer.data)
            
        except Exception as e:
            logger.error(f"Ошибка при поиске слоев по границам: {e}")
            return Response(
                {"error": f"Произошла ошибка при поиске слоев: {str(e)}"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class LayerUploadView(APIView):
    """
    View для загрузки геопространственных данных.
    
    Поддерживает загрузку файлов в форматах:
    - Shapefile (.shp, .dbf, .shx, .prj)
    - GeoJSON (.geojson)
    - KML/KMZ (.kml, .kmz)
    - GeoTIFF (.tif, .tiff)
    """
    parser_classes = (MultiPartParser, FormParser)
    permission_classes = [IsAuthenticated]
    
    def post(self, request, format=None):
        """
        Обработка загрузки файлов геоданных.
        
        Файлы сохраняются во временной директории, затем обрабатываются
        и регистрируются в соответствующем хранилище (PostGIS или файловая система).
        """
        file_obj = request.FILES.get('file')
        if not file_obj:
            return Response(
                {"error": "Файл не был предоставлен"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Получаем расширение файла
        file_extension = os.path.splitext(file_obj.name)[1].lower()
        
        # Создаем временную директорию для обработки файлов
        import tempfile
        temp_dir = tempfile.mkdtemp()
        
        try:
            # Сохраняем файл во временной директории
            temp_path = os.path.join(temp_dir, file_obj.name)
            with open(temp_path, 'wb') as temp_file:
                for chunk in file_obj.chunks():
                    temp_file.write(chunk)
            
            # Определяем тип данных и обрабатываем соответствующим образом
            if file_extension in ['.shp', '.geojson', '.kml', '.kmz']:
                # Векторные данные
                result = self._process_vector_data(temp_path, request.data)
            elif file_extension in ['.tif', '.tiff', '.ecw']:
                # Растровые данные
                result = self._process_raster_data(temp_path, request.data)
            else:
                return Response(
                    {"error": f"Неподдерживаемый формат файла: {file_extension}"},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            return Response(result, status=status.HTTP_201_CREATED)
        
        except Exception as e:
            return Response(
                {"error": str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
        finally:
            # Очищаем временные файлы
            import shutil
            shutil.rmtree(temp_dir)
    
    def _process_vector_data(self, file_path, form_data):
        """
        Обработка векторных данных.
        
        Args:
            file_path: Путь к загруженному файлу
            form_data: Дополнительные параметры запроса
            
        Returns:
            dict: Информация о созданном слое
        """
        # Получаем необходимые параметры
        layer_name = form_data.get('name', os.path.basename(file_path).split('.')[0])
        workspace = form_data.get('workspace', 'default')
        
        # TODO: Реализовать загрузку в PostGIS и публикацию в GeoServer
        # Это заглушка, которую нужно реализовать с использованием ogr2ogr или GeoDjango
        
        # Создаем запись метаданных слоя
        from .models import LayerMetadata
        metadata = LayerMetadata.objects.create(
            name=layer_name,
            title=form_data.get('title', layer_name),
            abstract=form_data.get('abstract', ''),
            keywords=form_data.get('keywords', ''),
            layer_type='vector',
            source=f"Uploaded by {self.request.user.username}"
        )
        
        return {
            "id": metadata.id,
            "name": metadata.name,
            "type": "vector",
            "status": "pending",
            "message": "Векторный слой создан. Публикация в GeoServer в процессе."
        }
    
    def _process_raster_data(self, file_path, form_data):
        """
        Обработка растровых данных.
        
        Args:
            file_path: Путь к загруженному файлу
            form_data: Дополнительные параметры запроса
            
        Returns:
            dict: Информация о созданном слое
        """
        # Получаем необходимые параметры
        layer_name = form_data.get('name', os.path.basename(file_path).split('.')[0])
        workspace = form_data.get('workspace', 'default')
        
        # TODO: Реализовать копирование в хранилище растров и публикацию в GeoServer
        # Это заглушка, которую нужно реализовать с использованием GDAL или GeoDjango
        
        # Создаем запись метаданных слоя
        from .models import LayerMetadata
        metadata = LayerMetadata.objects.create(
            name=layer_name,
            title=form_data.get('title', layer_name),
            abstract=form_data.get('abstract', ''),
            keywords=form_data.get('keywords', ''),
            layer_type='raster',
            source=f"Uploaded by {self.request.user.username}"
        )
        
        return {
            "id": metadata.id,
            "name": metadata.name,
            "type": "raster",
            "status": "pending",
            "message": "Растровый слой создан. Публикация в GeoServer в процессе."
        } 