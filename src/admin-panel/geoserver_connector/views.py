"""
Представления для приложения geoserver_connector.
"""

import logging
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from .services import GeoServerConnector

logger = logging.getLogger(__name__)


class GeoServerBaseView(APIView):
    """
    Базовое представление для взаимодействия с GeoServer.
    """
    permission_classes = [IsAuthenticated]
    
    def get_geoserver_instance(self, request):
        """
        Получение экземпляра GeoServerConnector.
        """
        instance_type = request.query_params.get('instance', 'vector')
        return GeoServerConnector(instance_type=instance_type)


class WorkspacesListView(GeoServerBaseView):
    """
    Представление для работы со списком рабочих пространств GeoServer.
    """
    def get(self, request):
        """
        Получение списка рабочих пространств.
        """
        geoserver = self.get_geoserver_instance(request)
        try:
            result = geoserver.get_workspaces()
            return Response(result)
        except Exception as e:
            logger.error(f"Ошибка при получении списка рабочих пространств: {e}")
            return Response(
                {"error": f"Не удалось получить список рабочих пространств: {str(e)}"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
    
    def post(self, request):
        """
        Создание нового рабочего пространства.
        """
        name = request.data.get('name')
        if not name:
            return Response(
                {"error": "Необходимо указать имя рабочего пространства"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        geoserver = self.get_geoserver_instance(request)
        try:
            success = geoserver.create_workspace(name)
            if success:
                return Response(
                    {"message": f"Рабочее пространство {name} успешно создано"},
                    status=status.HTTP_201_CREATED
                )
            else:
                return Response(
                    {"error": "Не удалось создать рабочее пространство"},
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR
                )
        except Exception as e:
            logger.error(f"Ошибка при создании рабочего пространства: {e}")
            return Response(
                {"error": f"Не удалось создать рабочее пространство: {str(e)}"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class WorkspaceDetailView(GeoServerBaseView):
    """
    Представление для работы с конкретным рабочим пространством GeoServer.
    """
    def get(self, request, name):
        """
        Получение информации о рабочем пространстве.
        """
        geoserver = self.get_geoserver_instance(request)
        try:
            # Здесь можно реализовать получение детальной информации о рабочем пространстве,
            # но в API GeoServer такого метода нет, поэтому возвращаем только имя
            return Response({"name": name})
        except Exception as e:
            logger.error(f"Ошибка при получении информации о рабочем пространстве: {e}")
            return Response(
                {"error": f"Не удалось получить информацию о рабочем пространстве: {str(e)}"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class DataStoresListView(GeoServerBaseView):
    """
    Представление для работы со списком хранилищ данных в рабочем пространстве.
    """
    def get(self, request, workspace):
        """
        Получение списка хранилищ данных.
        """
        # Здесь можно реализовать получение списка хранилищ данных,
        # но пока метод не добавлен в GeoServerConnector
        return Response({"message": "Метод получения списка хранилищ данных в разработке"})
    
    def post(self, request, workspace):
        """
        Создание нового хранилища данных.
        """
        store_name = request.data.get('name')
        store_type = request.data.get('type', 'postgis')
        connection_params = request.data.get('connection_parameters', {})
        
        if not store_name:
            return Response(
                {"error": "Необходимо указать имя хранилища данных"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        geoserver = self.get_geoserver_instance(request)
        try:
            success = geoserver.create_datastore(
                workspace, store_name, store_type, connection_params
            )
            if success:
                return Response(
                    {"message": f"Хранилище данных {store_name} успешно создано"},
                    status=status.HTTP_201_CREATED
                )
            else:
                return Response(
                    {"error": "Не удалось создать хранилище данных"},
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR
                )
        except Exception as e:
            logger.error(f"Ошибка при создании хранилища данных: {e}")
            return Response(
                {"error": f"Не удалось создать хранилище данных: {str(e)}"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class DataStoreDetailView(GeoServerBaseView):
    """
    Представление для работы с конкретным хранилищем данных.
    """
    def get(self, request, workspace, name):
        """
        Получение информации о хранилище данных.
        """
        # Здесь можно реализовать получение детальной информации о хранилище данных,
        # но пока метод не добавлен в GeoServerConnector
        return Response({
            "workspace": workspace,
            "name": name,
            "message": "Метод получения информации о хранилище данных в разработке"
        })


class LayersListView(GeoServerBaseView):
    """
    Представление для работы со списком слоев.
    """
    def get(self, request, workspace=None):
        """
        Получение списка слоев.
        """
        geoserver = self.get_geoserver_instance(request)
        try:
            result = geoserver.get_layers(workspace)
            return Response(result)
        except Exception as e:
            logger.error(f"Ошибка при получении списка слоев: {e}")
            return Response(
                {"error": f"Не удалось получить список слоев: {str(e)}"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
    
    def post(self, request, workspace=None):
        """
        Создание нового слоя.
        """
        if not workspace:
            return Response(
                {"error": "Необходимо указать рабочее пространство"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        store = request.data.get('store')
        layer_name = request.data.get('name')
        feature_type = request.data.get('feature_type', {})
        
        if not store or not layer_name:
            return Response(
                {"error": "Необходимо указать хранилище данных и имя слоя"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        geoserver = self.get_geoserver_instance(request)
        try:
            success = geoserver.publish_layer(
                workspace, store, layer_name, feature_type
            )
            if success:
                return Response(
                    {"message": f"Слой {layer_name} успешно создан"},
                    status=status.HTTP_201_CREATED
                )
            else:
                return Response(
                    {"error": "Не удалось создать слой"},
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR
                )
        except Exception as e:
            logger.error(f"Ошибка при создании слоя: {e}")
            return Response(
                {"error": f"Не удалось создать слой: {str(e)}"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class LayerDetailView(GeoServerBaseView):
    """
    Представление для работы с конкретным слоем.
    """
    def get(self, request, workspace, name):
        """
        Получение информации о слое.
        """
        geoserver = self.get_geoserver_instance(request)
        try:
            result = geoserver.get_layer_details(workspace, name)
            return Response(result)
        except Exception as e:
            logger.error(f"Ошибка при получении информации о слое: {e}")
            return Response(
                {"error": f"Не удалось получить информацию о слое: {str(e)}"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            ) 