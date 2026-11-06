import json
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from users.models import User
from .models import Case, Evidence

@csrf_exempt
def create_case_api(request):
    if request.method != 'POST':
        return JsonResponse({'error': 'Method not allowed'}, status=405)

    try:
        if request.content_type and 'multipart/form-data' in request.content_type:
            description = request.POST.get('description', '').strip()
            location = request.POST.get('location', '').strip()
            report_type = request.POST.get('report_type', 'Report').strip()
            incident_type = request.POST.get('incident_type', 'General').strip()
            priority = request.POST.get('priority', 'Normal').strip()
            user_id = request.POST.get('user_id', None)
        else:
            try:
                data = json.loads(request.body)
            except Exception:
                data = request.POST
            description = data.get('description', '').strip()
            location = data.get('location', '').strip()
            report_type = data.get('report_type', 'Report').strip()
            incident_type = data.get('incident_type', 'General').strip()
            priority = data.get('priority', 'Normal').strip()
            user_id = data.get('user_id', None)

        if not description:
            return JsonResponse({'error': 'Vui lòng nhập nội dung báo cáo'}, status=400)

        reporter = None
        if user_id:
            try:
                reporter = User.objects.filter(id=user_id).first()
            except Exception:
                pass

        case = Case.objects.create(
            reporter=reporter,
            report_type=report_type,
            incident_type=incident_type,
            priority=priority,
            location=location,
            description=description,
            status='New'
        )

        uploaded_files = request.FILES.getlist('files')
        if not uploaded_files:
            for key in request.FILES:
                uploaded_files.extend(request.FILES.getlist(key))

        evidence_list = []
        for file_obj in uploaded_files:
            filename = file_obj.name
            ext = filename.split('.')[-1].lower() if '.' in filename else ''
            if ext in ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp']:
                file_type = 'image'
            elif ext in ['mp3', 'wav', 'm4a', 'aac', 'ogg']:
                file_type = 'audio'
            elif ext in ['mp4', 'avi', 'mov', 'mkv']:
                file_type = 'video'
            else:
                file_type = 'document'

            evidence = Evidence.objects.create(
                case=case,
                uploader=reporter,
                file_name=filename,
                file_type=file_type,
                file_url=file_obj
            )

            file_url_str = evidence.file_url.url if evidence.file_url else ''
            if request and file_url_str:
                file_url_str = request.build_absolute_uri(file_url_str)

            evidence_list.append({
                'id': evidence.id,
                'file_name': evidence.file_name,
                'file_type': evidence.file_type,
                'file_url': file_url_str
            })

        return JsonResponse({
            'status': 'success',
            'message': 'Báo cáo đã được gửi và lưu vào Database thành công!',
            'case': {
                'id': case.id,
                'report_type': case.report_type,
                'incident_type': case.incident_type,
                'priority': case.priority,
                'location': case.location,
                'description': case.description,
                'status': case.status,
                'created_at': case.created_at.isoformat(),
                'evidences': evidence_list
            }
        }, status=201)

    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)


@csrf_exempt
def list_cases_api(request):
    if request.method != 'GET':
        return JsonResponse({'error': 'Method not allowed'}, status=405)

    try:
        user_id = request.GET.get('user_id', None)
        cases_qs = Case.objects.all().order_by('-created_at')

        if user_id:
            try:
                cases_qs = cases_qs.filter(reporter_id=user_id)
            except Exception:
                pass

        case_list = []
        for case in cases_qs:
            evidences = []
            for ev in case.evidences.all():
                f_url = ev.file_url.url if ev.file_url else ''
                if f_url and request:
                    f_url = request.build_absolute_uri(f_url)

                evidences.append({
                    'id': ev.id,
                    'file_name': ev.file_name,
                    'file_type': ev.file_type,
                    'file_url': f_url
                })

            case_list.append({
                'id': case.id,
                'report_type': case.report_type or 'Report',
                'incident_type': case.incident_type or 'General',
                'priority': case.priority or 'Normal',
                'location': case.location or '',
                'description': case.description,
                'status': case.status,
                'created_at': case.created_at.isoformat(),
                'evidences': evidences
            })

        return JsonResponse({
            'status': 'success',
            'cases': case_list
        })

    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)
