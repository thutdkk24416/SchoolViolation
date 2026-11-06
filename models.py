from django.db import models
from cases.models import Case
from users.models import User

class AIResult(models.Model):
    case = models.OneToOneField(Case, on_delete=models.CASCADE, related_name='ai_result')
    risk_score = models.FloatField()
    recommendation = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"AI Result for Case #{self.case.id}"
