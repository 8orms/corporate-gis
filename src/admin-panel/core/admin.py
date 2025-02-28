"""
Настройка админ-панели для моделей приложения core.
"""

from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import GISUser, UserLayerPermission


class UserLayerPermissionInline(admin.TabularInline):
    """
    Встроенное отображение прав доступа пользователя к слоям в админ-панели.
    """
    model = UserLayerPermission
    extra = 1
    
    fieldsets = (
        (None, {
            'fields': ('layer_name', 'workspace', 'can_read', 'can_write', 'can_delete')
        }),
    )


@admin.register(GISUser)
class GISUserAdmin(UserAdmin):
    """
    Настройка отображения модели пользователя в админ-панели.
    """
    fieldsets = UserAdmin.fieldsets + (
        ('ГИС-информация', {'fields': ('is_geoserver_admin', 'organization')}),
    )
    list_display = ('username', 'email', 'organization', 'is_geoserver_admin', 'is_staff')
    list_filter = UserAdmin.list_filter + ('is_geoserver_admin', 'organization')
    search_fields = UserAdmin.search_fields + ('organization',)
    inlines = [UserLayerPermissionInline]


@admin.register(UserLayerPermission)
class UserLayerPermissionAdmin(admin.ModelAdmin):
    """
    Настройка отображения модели прав доступа пользователя к слоям в админ-панели.
    """
    list_display = ('user', 'layer_name', 'workspace', 'can_read', 'can_write', 'can_delete')
    list_filter = ('user', 'workspace', 'can_read', 'can_write', 'can_delete')
    search_fields = ('user__username', 'layer_name', 'workspace')
    raw_id_fields = ('user',) 