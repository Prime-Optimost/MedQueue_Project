from django.apps import AppConfig


class BaseConfig(AppConfig):
    name = 'base'
    
    def ready(self):
        from .signals import register_signals
        register_signals()


class EmergencyConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name               = "emergency"
    verbose_name       = "Emergency SOS"