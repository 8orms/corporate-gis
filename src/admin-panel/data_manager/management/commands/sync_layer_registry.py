from django.core.management.base import BaseCommand
from data_manager.models import sync_from_json, sync_to_json, generate_js_config
import logging

logger = logging.getLogger(__name__)

class Command(BaseCommand):
    help = 'Синхронизирует данные между JSON-реестром и моделями Django'

    def add_arguments(self, parser):
        parser.add_argument(
            '--direction',
            choices=['import', 'export', 'both'],
            default='both',
            help='Направление синхронизации: import (из JSON в Django), export (из Django в JSON), both (в обе стороны)'
        )
        parser.add_argument(
            '--generate-js',
            action='store_true',
            help='Генерировать JavaScript-конфигурацию после синхронизации'
        )

    def handle(self, *args, **options):
        direction = options['direction']
        generate_js = options['generate_js']
        
        if direction in ['import', 'both']:
            self.stdout.write('Импорт данных из JSON...')
            success = sync_from_json()
            if success:
                self.stdout.write(self.style.SUCCESS('Импорт данных из JSON успешно завершен.'))
            else:
                self.stdout.write(self.style.ERROR('Ошибка при импорте данных из JSON.'))
        
        if direction in ['export', 'both']:
            self.stdout.write('Экспорт данных в JSON...')
            success = sync_to_json()
            if success:
                self.stdout.write(self.style.SUCCESS('Экспорт данных в JSON успешно завершен.'))
            else:
                self.stdout.write(self.style.ERROR('Ошибка при экспорте данных в JSON.'))
        
        if generate_js:
            self.stdout.write('Генерация JavaScript-конфигурации...')
            success = generate_js_config()
            if success:
                self.stdout.write(self.style.SUCCESS('JavaScript-конфигурация успешно сгенерирована.'))
            else:
                self.stdout.write(self.style.ERROR('Ошибка при генерации JavaScript-конфигурации.')) 