// lib/features/report/data/case_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

String _getDefaultCaseBaseUrl() {
  if (kIsWeb) return 'http://localhost:8000/api/cases';
  if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:8000/api/cases';
  return 'http://localhost:8000/api/cases';
}

class CaseModel {
  final int id;
  final String reportType;
  final String incidentType;
  final String priority;
  final String location;
  final String description;
  final String status;
  final String createdAt;
  final List<EvidenceModel> evidences;

  CaseModel({
    required this.id, required this.reportType, required this.incidentType,
    required this.priority, required this.location, required this.description,
    required this.status, required this.createdAt, required this.evidences,
  });

  factory CaseModel.fromJson(Map<String, dynamic> json) {
    int _toInt(dynamic v) => v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;
    return CaseModel(
      id: _toInt(json['id']),
      reportType: json['report_type'] as String? ?? 'Report',
      incidentType: json['incident_type'] as String? ?? 'General',
      priority: json['priority'] as String? ?? 'Normal',
      location: json['location'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? 'New',
      createdAt: json['created_at']?.toString() ?? '',
      evidences: (json['evidences'] as List<dynamic>?)
          ?.map((e) => EvidenceModel.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
}

class EvidenceModel {
  final int id;
  final String fileName;
  final String fileType;
  final String fileUrl;

  EvidenceModel({required this.id, required this.fileName, required this.fileType, required this.fileUrl});

  factory EvidenceModel.fromJson(Map<String, dynamic> json) {
    int _toInt(dynamic v) => v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;
    return EvidenceModel(
      id: _toInt(json['id']),
      fileName: json['file_name'] as String? ?? '',
      fileType: json['file_type'] as String? ?? '',
      fileUrl: json['file_url'] as String? ?? '',
    );
  }
}

class CaseService {
  final String baseUrl;
  CaseService({String? baseUrl}) : baseUrl = baseUrl ?? _getDefaultCaseBaseUrl();

  Future<CaseModel> submitReport({
    required String description,
    required String location,
    required String reportType,
    required String priority,
    required String incidentType,
    required bool anonymous,
    String? userId,
    double? latitude,   // ✅ Đã thêm
    double? longitude,  // ✅ Đã thêm
    List<UploadedFile> files = const [],
  }) async {
    final url = '$baseUrl/create/';
    try {
      final uri = Uri.parse(url);
      final request = http.MultipartRequest('POST', uri);

      request.fields['description'] = description;
      request.fields['location'] = location;
      request.fields['report_type'] = reportType;
      request.fields['priority'] = priority;
      request.fields['incident_type'] = incidentType;
      request.fields['anonymous'] = anonymous.toString();

      // ✅ Đẩy tọa độ vào request
      if (latitude != null) request.fields['latitude'] = latitude.toString();
      if (longitude != null) request.fields['longitude'] = longitude.toString();

      if (userId != null && userId.isNotEmpty && !anonymous) {
        request.fields['user_code'] = userId;
      }

      for (final file in files) {
        if (file.bytes != null) {
          request.files.add(http.MultipartFile.fromBytes('files', file.bytes!, filename: file.name));
        }
      }

      final streamedResponse = await request.send().timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final caseJson = (data['case'] as Map<String, dynamic>?) ?? data;
        return CaseModel.fromJson(caseJson);
      } else {
        debugPrint('SERVER ERROR BODY: ${response.body}');
        throw Exception('Lỗi HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('SUBMIT CATCH ERROR: $e');
      throw Exception('Không thể gửi báo cáo ($e)');
    }
  }

  Future<List<CaseModel>> fetchCases({String? userId}) async {
    String query = '';
    if (userId != null && userId.isNotEmpty) {
      query = '?user_code=$userId';
    }

    final url = '$baseUrl/list/$query';

    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = data['cases'] as List<dynamic>? ?? data as List<dynamic>? ?? [];
        return list.map((e) => CaseModel.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Fetch history error: $e');
    }
    return [];
  }
}

class UploadedFile {
  final String name;
  final String size;
  final Uint8List? bytes;
  final String? path;
  final bool isAudio;
  final String? blobUrl;

  UploadedFile({
    required this.name, required this.size, this.bytes, this.path,
    this.isAudio = false, this.blobUrl,
  });
}
