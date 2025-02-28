"""
Сериализаторы для моделей приложения core.
"""

from rest_framework import serializers
from .models import GISUser, UserLayerPermission


class UserLayerPermissionSerializer(serializers.ModelSerializer):
    """
    Сериализатор для модели прав доступа пользователя к слоям.
    """
    class Meta:
        model = UserLayerPermission
        fields = ['id', 'layer_name', 'workspace', 'can_read', 'can_write', 'can_delete']


class UserSerializer(serializers.ModelSerializer):
    """
    Сериализатор для модели пользователя.
    """
    layer_permissions = UserLayerPermissionSerializer(many=True, read_only=True)
    password = serializers.CharField(write_only=True, required=False)
    
    class Meta:
        model = GISUser
        fields = ['id', 'username', 'email', 'first_name', 'last_name', 'organization', 
                  'is_geoserver_admin', 'is_staff', 'is_active', 'date_joined', 
                  'password', 'layer_permissions']
        read_only_fields = ['id', 'date_joined', 'layer_permissions']
    
    def create(self, validated_data):
        """
        Создание пользователя с хешированием пароля.
        """
        password = validated_data.pop('password', None)
        user = GISUser(**validated_data)
        if password:
            user.set_password(password)
        user.save()
        return user
    
    def update(self, instance, validated_data):
        """
        Обновление пользователя с хешированием пароля, если он указан.
        """
        password = validated_data.pop('password', None)
        
        # Обновление полей пользователя
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        
        # Если указан пароль, обновляем его
        if password:
            instance.set_password(password)
        
        instance.save()
        return instance


class LoginSerializer(serializers.Serializer):
    """
    Сериализатор для аутентификации пользователя.
    """
    username = serializers.CharField(max_length=150)
    password = serializers.CharField(max_length=128, write_only=True)


class UserInfoSerializer(serializers.ModelSerializer):
    """
    Сериализатор для получения информации о текущем пользователе.
    """
    full_name = serializers.SerializerMethodField()
    
    class Meta:
        model = GISUser
        fields = ['id', 'username', 'email', 'full_name', 'organization', 
                  'is_geoserver_admin', 'is_staff', 'is_active']
    
    def get_full_name(self, obj):
        """
        Получение полного имени пользователя.
        """
        return f"{obj.first_name} {obj.last_name}".strip() or obj.username 