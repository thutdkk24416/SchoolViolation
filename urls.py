from django.urls import path
from .views import create_case_api, list_cases_api

urlpatterns = [
    path('create/', create_case_api, name='create_case_api'),
    path('list/', list_cases_api, name='list_cases_api'),
]
