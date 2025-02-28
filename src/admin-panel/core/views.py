"""
Представления для приложения core.
"""

import logging
from django.contrib.auth import authenticate, login, logout
from rest_framework import viewsets, status, permissions
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, IsAdminUser
from .models import GISUser, UserLayerPermission
from .serializers import (
    UserSerializer, 
    LoginSerializer, 
    UserInfoSerializer, 
    UserLayerPermissionSerializer
)

logger = logging.getLogger(__name__)


class IsAdminOrSelf(permissions.BasePermission):
    """
    Разрешение, позволяющее пользователю редактировать только свой профиль,
    а администраторам - любой профиль.
    """
    def has_object_permission(self, request, view, obj):
        return obj == request.user or request.user.is_staff


class UserViewSet(viewsets.ModelViewSet):
    """
    Представление для работы с пользователями.
    """
    queryset = GISUser.objects.all()
    serializer_class = UserSerializer
    permission_classes = [IsAuthenticated, IsAdminOrSelf]
    
    def get_permissions(self):
        """
        Переопределение разрешений в зависимости от действия.
        """
        if self.action in ['create', 'destroy', 'list']:
            return [IsAdminUser()]
        return super().get_permissions()


class LoginView(APIView):
    """
    Представление для аутентификации пользователя.
    """
    permission_classes = []
    
    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        if serializer.is_valid():
            username = serializer.validated_data.get('username')
            password = serializer.validated_data.get('password')
            
            user = authenticate(username=username, password=password)
            if user:
                login(request, user)
                return Response({
                    'message': 'Вход выполнен успешно',
                    'user': UserInfoSerializer(user).data
                })
            return Response({
                'error': 'Неправильное имя пользователя или пароль'
            }, status=status.HTTP_401_UNAUTHORIZED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class LogoutView(APIView):
    """
    Представление для выхода пользователя из системы.
    """
    permission_classes = [IsAuthenticated]
    
    def post(self, request):
        logout(request)
        return Response({
            'message': 'Выход выполнен успешно'
        })


class UserInfoView(APIView):
    """
    Представление для получения информации о текущем пользователе.
    """
    permission_classes = [IsAuthenticated]
    
    def get(self, request):
        serializer = UserInfoSerializer(request.user)
        return Response(serializer.data) 