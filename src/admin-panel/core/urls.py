"""
URL конфигурация для приложения core.
"""

from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import UserViewSet, LoginView, LogoutView, UserInfoView

# Создание маршрутизатора для ViewSets
router = DefaultRouter()
router.register(r'users', UserViewSet)

# URL-маршруты приложения
urlpatterns = [
    # Маршруты API для работы с пользователями
    path('', include(router.urls)),
    
    # Аутентификация
    path('login/', LoginView.as_view(), name='api-login'),
    path('logout/', LogoutView.as_view(), name='api-logout'),
    path('me/', UserInfoView.as_view(), name='api-user-info'),
] 