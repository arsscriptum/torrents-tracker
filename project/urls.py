# myproject/urls.py (Project-level)
from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),  # URL for the admin interface
    path('tracker/', include('tracker.urls')),  # Delegate 'tracker/' to tracker app's urls.py
]
