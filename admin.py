from django.contrib import admin
from .models import AIResult

@admin.register(AIResult)
class AIResultAdmin(admin.ModelAdmin):
    list_display = ('case', 'risk_score', 'created_at')
    list_filter = ('risk_score',)
