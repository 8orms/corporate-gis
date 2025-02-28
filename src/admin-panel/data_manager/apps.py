from django.apps import AppConfig


class DataManagerConfig(AppConfig):
    name = 'data_manager'
    verbose_name = 'Управление данными'
    
    def ready(self):
        """
        Выполняет импорт сигналов и другие операции при загрузке приложения
        """
        import data_manager.signals  # noqa 