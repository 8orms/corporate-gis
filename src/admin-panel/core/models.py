"""
Core models for GIS admin application.
"""

from django.contrib.auth.models import AbstractUser
from django.db import models


class GISUser(AbstractUser):
    """
    Расширенная модель пользователя для ГИС-платформы.
    """
    is_geoserver_admin = models.BooleanField(
        default=False,
        verbose_name="Администратор GeoServer",
        help_text="Указывает, имеет ли пользователь права администратора GeoServer"
    )
    organization = models.CharField(
        max_length=100,
        blank=True,
        verbose_name="Организация",
        help_text="Организация, к которой принадлежит пользователь"
    )

    class Meta:
        verbose_name = "Пользователь ГИС"
        verbose_name_plural = "Пользователи ГИС"
        ordering = ['username']

    def __str__(self):
        return f"{self.username} ({self.organization})" if self.organization else self.username


class UserLayerPermission(models.Model):
    """
    Модель для хранения прав доступа пользователей к слоям.
    """
    user = models.ForeignKey(
        GISUser,
        on_delete=models.CASCADE,
        verbose_name="Пользователь",
        related_name="layer_permissions"
    )
    layer_name = models.CharField(
        max_length=255,
        verbose_name="Имя слоя"
    )
    workspace = models.CharField(
        max_length=100,
        verbose_name="Рабочее пространство"
    )
    can_read = models.BooleanField(
        default=True,
        verbose_name="Чтение"
    )
    can_write = models.BooleanField(
        default=False,
        verbose_name="Запись"
    )
    can_delete = models.BooleanField(
        default=False,
        verbose_name="Удаление"
    )

    class Meta:
        verbose_name = "Право доступа к слою"
        verbose_name_plural = "Права доступа к слоям"
        unique_together = ('user', 'layer_name', 'workspace')
        ordering = ['user', 'workspace', 'layer_name']

    def __str__(self):
        return f"{self.user.username} - {self.workspace}:{self.layer_name}" 