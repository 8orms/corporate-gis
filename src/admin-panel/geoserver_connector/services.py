"""
Сервисы для взаимодействия с GeoServer через REST API.
"""

import requests
import json
import base64
import logging
from django.conf import settings

logger = logging.getLogger(__name__)


class GeoServerConnector:
    """
    Класс для взаимодействия с GeoServer REST API.
    """
    
    def __init__(self, instance_type='vector'):
        """
        Инициализация коннектора с выбором инстанции GeoServer.
        
        Args:
            instance_type (str): Тип инстанции GeoServer ('vector' или 'ecw')
        """
        self.instance_type = instance_type
        if instance_type == 'vector':
            self.base_url = settings.GEOSERVER_VECTOR_URL
        else:
            self.base_url = settings.GEOSERVER_ECW_URL
            
        self.auth = (settings.GEOSERVER_ADMIN_USER, settings.GEOSERVER_ADMIN_PASSWORD)
        self.auth_header = self._get_auth_header()
        
    def _get_auth_header(self):
        """
        Формирует заголовок авторизации для REST API.
        
        Returns:
            dict: Заголовок с авторизацией Basic.
        """
        auth_string = f"{settings.GEOSERVER_ADMIN_USER}:{settings.GEOSERVER_ADMIN_PASSWORD}"
        encoded = base64.b64encode(auth_string.encode()).decode()
        return {"Authorization": f"Basic {encoded}"}
    
    def get_workspaces(self):
        """
        Получает список рабочих пространств GeoServer.
        
        Returns:
            dict: Данные о рабочих пространствах.
        """
        try:
            response = requests.get(
                f"{self.base_url}/rest/workspaces", 
                headers={"Accept": "application/json", **self.auth_header}
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            logger.error(f"Ошибка при получении рабочих пространств: {e}")
            return {"error": str(e)}
    
    def create_workspace(self, name):
        """
        Создает новое рабочее пространство в GeoServer.
        
        Args:
            name (str): Имя нового рабочего пространства.
            
        Returns:
            bool: True если успешно, иначе False.
        """
        try:
            data = json.dumps({"workspace": {"name": name}})
            response = requests.post(
                f"{self.base_url}/rest/workspaces", 
                headers={
                    "Content-Type": "application/json",
                    **self.auth_header
                },
                data=data
            )
            response.raise_for_status()
            return True
        except requests.exceptions.RequestException as e:
            logger.error(f"Ошибка при создании рабочего пространства: {e}")
            return False
    
    def get_layers(self, workspace=None):
        """
        Получает список слоев из GeoServer.
        
        Args:
            workspace (str, optional): Имя рабочего пространства для фильтрации.
            
        Returns:
            dict: Данные о слоях.
        """
        try:
            url = f"{self.base_url}/rest/layers"
            if workspace:
                url = f"{self.base_url}/rest/workspaces/{workspace}/layers"
                
            response = requests.get(
                url, 
                headers={"Accept": "application/json", **self.auth_header}
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            logger.error(f"Ошибка при получении слоев: {e}")
            return {"error": str(e)}
    
    def get_layer_details(self, workspace, layer_name):
        """
        Получает детальную информацию о слое.
        
        Args:
            workspace (str): Имя рабочего пространства.
            layer_name (str): Имя слоя.
            
        Returns:
            dict: Детальная информация о слое.
        """
        try:
            url = f"{self.base_url}/rest/workspaces/{workspace}/layers/{layer_name}"
            response = requests.get(
                url, 
                headers={"Accept": "application/json", **self.auth_header}
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            logger.error(f"Ошибка при получении детальной информации о слое: {e}")
            return {"error": str(e)}
    
    def create_datastore(self, workspace, store_name, store_type, connection_params):
        """
        Создает новое хранилище данных в GeoServer.
        
        Args:
            workspace (str): Имя рабочего пространства.
            store_name (str): Имя хранилища данных.
            store_type (str): Тип хранилища (postgis, directory, etc.).
            connection_params (dict): Параметры подключения.
            
        Returns:
            bool: True если успешно, иначе False.
        """
        try:
            # Реализация зависит от типа хранилища
            if store_type == 'postgis':
                data = {
                    "dataStore": {
                        "name": store_name,
                        "connectionParameters": connection_params
                    }
                }
                
                response = requests.post(
                    f"{self.base_url}/rest/workspaces/{workspace}/datastores",
                    headers={
                        "Content-Type": "application/json",
                        **self.auth_header
                    },
                    data=json.dumps(data)
                )
                response.raise_for_status()
                return True
            else:
                logger.error(f"Неподдерживаемый тип хранилища: {store_type}")
                return False
        except requests.exceptions.RequestException as e:
            logger.error(f"Ошибка при создании хранилища данных: {e}")
            return False
    
    def publish_layer(self, workspace, store, layer_name, feature_type):
        """
        Публикует новый слой в GeoServer.
        
        Args:
            workspace (str): Имя рабочего пространства.
            store (str): Имя хранилища данных.
            layer_name (str): Имя слоя.
            feature_type (dict): Конфигурация типа объектов.
            
        Returns:
            bool: True если успешно, иначе False.
        """
        try:
            data = {
                "featureType": feature_type
            }
            
            response = requests.post(
                f"{self.base_url}/rest/workspaces/{workspace}/datastores/{store}/featuretypes",
                headers={
                    "Content-Type": "application/json",
                    **self.auth_header
                },
                data=json.dumps(data)
            )
            response.raise_for_status()
            return True
        except requests.exceptions.RequestException as e:
            logger.error(f"Ошибка при публикации слоя: {e}")
            return False 