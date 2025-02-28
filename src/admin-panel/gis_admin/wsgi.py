"""
WSGI config for gis_admin project.
"""

import os

from django.core.wsgi import get_wsgi_application

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'gis_admin.settings')

application = get_wsgi_application() 