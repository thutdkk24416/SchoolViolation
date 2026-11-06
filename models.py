from django.db import models
from users.models import User

class Case(models.Model):
    reporter = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='reported_cases', db_column='reporter_id')
    report_type = models.CharField(max_length=50, blank=True, null=True)
    incident_type = models.CharField(max_length=50, blank=True, null=True)
    priority = models.CharField(max_length=20, blank=True, null=True)
    location = models.CharField(max_length=255, blank=True, null=True)
    description = models.TextField()
    solution = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    status = models.CharField(max_length=50, default='New')
    latitude = models.FloatField(null=True, blank=True)
    longitude = models.FloatField(null=True, blank=True)
    anonymous = models.BooleanField(default=False)
    user_code = models.CharField(max_length=50, null=True, blank=True)
    class Meta:
        verbose_name_plural = "​​Cases"
    def __str__(self): return f"Case #{self.id}"

class Evidence(models.Model):
    case = models.ForeignKey(Case, on_delete=models.CASCADE, related_name='evidences')
    uploader = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, db_column='user_id')
    file_type = models.CharField(max_length=50, blank=True, null=True)
    file_name = models.CharField(max_length=255, blank=True, null=True)
    file_url = models.FileField(upload_to='evidences/')
    description = models.TextField(blank=True, null=True)
    uploaded_at = models.DateTimeField(auto_now_add=True)
    class Meta:
        verbose_name_plural = "Evidences"
    def __str__(self): return self.file_name or f"Evidence {self.id}"

class CaseHistory(models.Model):
    case = models.ForeignKey(Case, on_delete=models.CASCADE, related_name='history')
    actor = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True)
    action = models.CharField(max_length=100)
    description = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    class Meta:
        verbose_name_plural = "​Case History"
    def __str__(self): return f"Case #{self.case.id}"

class Assignment(models.Model):
    case = models.ForeignKey(Case, on_delete=models.CASCADE, related_name='assignments')
    assignee = models.ForeignKey(User, on_delete=models.CASCADE, related_name='tasks')
    assigned_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='assigned_tasks')
    status = models.CharField(max_length=50, default='Pending')
    assigned_at = models.DateTimeField(auto_now_add=True)
    class Meta:
        verbose_name_plural = "Assignments"
    def __str__(self): return f"Assignment of Case #{self.case.id} to {self.assignee.username}"
