import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../auth/domain/auth_models.dart';
import '../data/case_service.dart';
import 'location_picker_dialog.dart';
import 'web_utils.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  int? _hoveredIndex;

  final CaseService _caseService = CaseService();
  final List<UploadedFile> _uploadedFiles = [];
  List<CaseModel> _historyCases = [];
  bool _isLoadingHistory = false;
  bool _isSubmitting = false;
  bool _initializedArgs = false;

  final TextEditingController _reportController = TextEditingController(
    text: '',
  );
  final TextEditingController _locationController = TextEditingController(
    text: 'Phòng 302, Tòa A',
  );

  // User Profile State
  String _userFullName = 'Nguyễn Đình Huy';
  String _userEmail = 'huy.nd@uel.edu.vn';
  String _userIdCode = 'K214141573';
  String _userDepartment = 'Khoa Kinh tế';
  String _userRole = 'Sinh viên UEL';

  bool _isVietnamese = true;
  final bool _hasNotification = true;
  bool _isLoggedIn = true;

  // Audio Recording State
  bool _isRecordingAudio = false;

  // Speech-to-Text State
  late stt.SpeechToText _speechToText;
  bool _speechEnabled = false;
  bool _isListening = false;
  String _sttBaseText = '';
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // GlobalKeys for header popup positioning
  final GlobalKey _langKey = GlobalKey();
  final GlobalKey _notifKey = GlobalKey();

  final List<_SidebarItem> _items = const [
    _SidebarItem(title: 'Báo cáo', icon: Icons.report_problem_outlined, subtitle: 'Gửi thông tin mới'),
    _SidebarItem(title: 'SOS Khẩn cấp', icon: Icons.sos_outlined, subtitle: 'Cấp cứu / Khẩn cấp'),
    _SidebarItem(title: 'Xem báo cáo cũ', icon: Icons.history_edu_outlined, subtitle: 'Lịch sử đã gửi'),
  ];

  @override
  void initState() {
    super.initState();
    _speechToText = stt.SpeechToText();
    _initSpeech();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.14).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _fetchHistory();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedArgs) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is AuthSession) {
        setState(() {
          if (args.fullName.isNotEmpty) {
            _userFullName = args.fullName;
          } else if (args.email.isNotEmpty) {
            _userFullName = args.email.split('@').first;
          }
          if (args.email.isNotEmpty) _userEmail = args.email;
          _userIdCode = args.userId.isNotEmpty ? args.userId : _userIdCode;
          _userRole = args.role == AuthRole.teacher ? 'Giảng viên UEL' : 'Sinh viên UEL';
        });
      }
      _initializedArgs = true;
    }
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      final cases = await _caseService.fetchCases();
      if (mounted) {
        setState(() {
          _historyCases = cases;
          _isLoadingHistory = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingHistory = false);
      }
    }
  }

  Future<void> _initSpeech() async {
    try {
      _speechEnabled = await _speechToText.initialize(
        onError: (error) {
          if (mounted) {
            setState(() { _isListening = false; });
            _pulseController.stop();
          }
        },
        onStatus: (status) {
          if ((status == 'done' || status == 'notListening') && mounted && _isListening) {
            setState(() { _isListening = false; });
            _pulseController.stop();
          }
        },
      );
      setState(() {});
    } catch (_) {
      _speechEnabled = false;
    }
  }

  @override
  void dispose() {
    _reportController.dispose();
    _locationController.dispose();
    _pulseController.dispose();
    if (_isListening) _speechToText.stop();
    if (_isRecordingAudio) stopAudioRecordingWeb();
    super.dispose();
  }

  // Audio Recording Toggle (Top Option Card -> Saves .webm audio file into _uploadedFiles)
  Future<void> _toggleAudioRecording() async {
    if (_isRecordingAudio) {
      stopAudioRecordingWeb();
      setState(() => _isRecordingAudio = false);
    } else {
      final success = await startAudioRecordingWeb((name, blobUrl) {
        if (mounted) {
          setState(() {
            _isRecordingAudio = false;
            _uploadedFiles.add(UploadedFile(
              name: name,
              size: 'Audio webm',
              isAudio: true,
              blobUrl: blobUrl,
            ));
          });
          _showSuccessSnack('Đã ghi âm và lưu file: $name');
        }
      });
      if (success) {
        setState(() => _isRecordingAudio = true);
        _showInfoSnack('Đang ghi âm giọng nói... Bấm lại nút để dừng và lưu file.');
      } else {
        _showErrorSnack('Không thể truy cập Microphone. Vui lòng cấp quyền trong trình duyệt.');
      }
    }
  }

  // Speech-to-Text: Converts Voice directly real-time inside TextField
  Future<void> _toggleSTT() async {
    if (!_speechEnabled) {
      _showErrorSnack('Trình duyệt không hỗ trợ Nhận dạng giọng nói (STT). Hãy dùng Google Chrome hoặc Microsoft Edge.');
      return;
    }
    if (_isListening) {
      await _speechToText.stop();
      setState(() { _isListening = false; });
      _pulseController.stop();
    } else {
      _sttBaseText = _reportController.text;
      setState(() { _isListening = true; });
      _pulseController.repeat(reverse: true);
      await _speechToText.listen(
        listenOptions: stt.SpeechListenOptions(
          localeId: _isVietnamese ? 'vi-VN' : 'en-US',
          partialResults: true,
          listenFor: const Duration(minutes: 5),
          pauseFor: const Duration(seconds: 5),
        ),
        onResult: (result) {
          if (!mounted) return;
          final recognized = result.recognizedWords.trim();
          if (recognized.isNotEmpty) {
            final prefix = _sttBaseText;
            final needSpace = prefix.isNotEmpty && !prefix.endsWith(' ');
            final fullText = prefix + (needSpace ? ' ' : '') + recognized;
            _reportController.text = fullText;
            _reportController.selection = TextSelection.fromPosition(
              TextPosition(offset: fullText.length),
            );
          }
          if (result.finalResult) {
            _sttBaseText = _reportController.text;
          }
        },
      );
    }
  }

  // Open Interactive Map Picker
  Future<void> _openMapPicker() async {
    final result = await showDialog<PickedLocation>(
      context: context,
      builder: (ctx) => const LocationPickerDialog(),
    );

    if (result != null) {
      setState(() {
        _locationController.text = result.display;
      });
      _showSuccessSnack('Đã chọn vị trí: ${result.display}');
    }
  }

  // Camera Capture
  void _captureImage() {
    captureImageWeb((name, size, bytes) {
      if (mounted) {
        setState(() => _uploadedFiles.add(UploadedFile(name: name, size: _formatBytes(size), bytes: bytes)));
        _showSuccessSnack('Đã thêm ảnh chụp: $name');
      }
    });
  }

  // File Upload
  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true, type: FileType.any, withData: true);
    if (result == null || result.files.isEmpty) return;
    setState(() {
      _uploadedFiles.addAll(
        result.files.where((f) => f.name.isNotEmpty)
            .map((f) => UploadedFile(
              name: f.name,
              size: _formatBytes(f.size),
              bytes: f.bytes,
              path: f.path,
            )),
      );
    });
  }

  // Download (Web)
  void _downloadFile(UploadedFile file) {
    if (file.blobUrl != null) {
      downloadFileWeb(file.blobUrl, file.name);
    } else {
      _showInfoSnack('"${file.name}" (${file.size}) - File đã được lưu trên máy chủ.');
    }
  }

  void _removeFile(UploadedFile file) {
    setState(() => _uploadedFiles.remove(file));
    _showInfoSnack('Đã xóa "${file.name}".');
  }

  // Language dropdown
  void _showLanguageMenu(BuildContext ctx) {
    final rb = _langKey.currentContext!.findRenderObject() as RenderBox;
    final overlay = Navigator.of(ctx).overlay!.context.findRenderObject() as RenderBox;
    final pos = RelativeRect.fromRect(
      Rect.fromPoints(
        rb.localToGlobal(Offset.zero, ancestor: overlay),
        rb.localToGlobal(rb.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
    showMenu<String>(
      context: ctx, position: pos,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 8,
      items: [
        _langMenuItem('vi', 'Tiếng Việt', _isVietnamese),
        _langMenuItem('en', 'English', !_isVietnamese),
      ],
    ).then((val) { if (val != null) setState(() => _isVietnamese = val == 'vi'); });
  }

  PopupMenuItem<String> _langMenuItem(String val, String label, bool selected) {
    return PopupMenuItem<String>(
      value: val,
      child: Row(children: [
        Text(val == 'vi' ? 'VI' : 'EN',
            style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 13,
                color: selected ? const Color(0xFF0B6EDB) : const Color(0xFF8AA5C7))),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            color: selected ? const Color(0xFF0B6EDB) : const Color(0xFF0A2F5D))),
        if (selected) ...[const Spacer(), const Icon(Icons.check_rounded, size: 16, color: Color(0xFF0B6EDB))],
      ]),
    );
  }

  // Notification popup
  void _showNotificationPopup(BuildContext ctx) {
    final notifs = [
      _NotifItem(icon: Icons.check_circle_rounded, color: const Color(0xFF1AA06A), title: 'Báo cáo #1023 đã được phê duyệt', time: '10 phút trước'),
      _NotifItem(icon: Icons.info_rounded, color: const Color(0xFF0B6EDB), title: 'Hệ thống bảo trì lúc 02:00 AM', time: '1 giờ trước'),
      _NotifItem(icon: Icons.warning_amber_rounded, color: const Color(0xFFF77B32), title: 'Sự cố khu A cần xử lý ngay', time: 'Hôm qua'),
    ];

    if (_notifKey.currentContext != null) {
      final rb = _notifKey.currentContext!.findRenderObject() as RenderBox;
      final overlay = Navigator.of(ctx).overlay!.context.findRenderObject() as RenderBox;
      final pos = RelativeRect.fromRect(
        Rect.fromPoints(
          rb.localToGlobal(Offset.zero, ancestor: overlay),
          rb.localToGlobal(rb.size.bottomRight(Offset.zero), ancestor: overlay),
        ),
        Offset.zero & overlay.size,
      );
      showMenu<void>(
        context: ctx, position: pos,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        constraints: const BoxConstraints(minWidth: 320, maxWidth: 360),
        elevation: 10,
        items: [
          const PopupMenuItem<void>(enabled: false, height: 40,
              child: Text('Thông báo', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0A2F5D)))),
          const PopupMenuDivider(height: 1),
          ...notifs.map((n) => PopupMenuItem<void>(
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Container(width: 38, height: 38,
                    decoration: BoxDecoration(color: n.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                    child: Icon(n.icon, color: n.color, size: 19)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(n.title, style: const TextStyle(fontSize: 13, color: Color(0xFF0A2F5D), fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(n.time, style: const TextStyle(fontSize: 11, color: Color(0xFF8AA5C7))),
                ])),
              ]),
            ),
          )),
        ],
      );
    } else {
      showDialog(
        context: ctx,
        builder: (dCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Thông báo', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0A2F5D))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: notifs.map((n) => ListTile(
              dense: true,
              leading: Icon(n.icon, color: n.color),
              title: Text(n.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Text(n.time, style: const TextStyle(fontSize: 11)),
            )).toList(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Đóng')),
          ],
        ),
      );
    }
  }

  // Account Popup / Profile Dialog
  void _showAccountPopup(BuildContext ctx) {
    if (_isLoggedIn) {
      _showAccountProfileDialog(ctx);
    } else {
      Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
    }
  }

  void _showAccountProfileDialog(BuildContext ctx) {
    final nameCtrl = TextEditingController(text: _userFullName);
    final emailCtrl = TextEditingController(text: _userEmail);
    final idCtrl = TextEditingController(text: _userIdCode);
    final deptCtrl = TextEditingController(text: _userDepartment);

    showDialog(
      context: ctx,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            child: Container(
              width: 520,
              padding: const EdgeInsets.all(22),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: const Color(0xFF0B6EDB).withValues(alpha: 0.12),
                          child: const Icon(Icons.manage_accounts_rounded, color: Color(0xFF0B6EDB), size: 30),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Tài khoản & Hồ sơ cá nhân', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0A2F5D))),
                              Text('Điều chỉnh thông tin Profile hoặc chuyển tài khoản', style: TextStyle(fontSize: 12, color: const Color(0xFF8AA5C7))),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF8AA5C7)),
                          onPressed: () => Navigator.pop(dCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Divider(height: 1),
                    const SizedBox(height: 18),

                    // Quick Account Selector
                    const Text('Chọn / Chuyển tài khoản nhanh', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0A2F5D))),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _accountChoiceChip(
                          title: 'Nguyễn Đình Huy',
                          subtitle: 'Sinh viên',
                          selected: nameCtrl.text == 'Nguyễn Đình Huy',
                          onTap: () {
                            setDialogState(() {
                              nameCtrl.text = 'Nguyễn Đình Huy';
                              emailCtrl.text = 'huy.nd@uel.edu.vn';
                              idCtrl.text = 'K214141573';
                              deptCtrl.text = 'Khoa Kinh tế';
                              _userRole = 'Sinh viên UEL';
                            });
                          },
                        ),
                        _accountChoiceChip(
                          title: 'ThS. Lê Hoàng Nam',
                          subtitle: 'Giảng viên',
                          selected: nameCtrl.text == 'ThS. Lê Hoàng Nam',
                          onTap: () {
                            setDialogState(() {
                              nameCtrl.text = 'ThS. Lê Hoàng Nam';
                              emailCtrl.text = 'nam.lh@uel.edu.vn';
                              idCtrl.text = 'GV00284';
                              deptCtrl.text = 'Khoa Luật';
                              _userRole = 'Giảng viên UEL';
                            });
                          },
                        ),
                        _accountChoiceChip(
                          title: 'Đội Hỗ trợ & An ninh',
                          subtitle: 'Cán bộ',
                          selected: nameCtrl.text == 'Đội Hỗ trợ & An ninh',
                          onTap: () {
                            setDialogState(() {
                              nameCtrl.text = 'Đội Hỗ trợ & An ninh';
                              emailCtrl.text = 'hotro@uel.edu.vn';
                              idCtrl.text = 'CB00102';
                              deptCtrl.text = 'Phòng An ninh - Quản lý';
                              _userRole = 'Cán bộ Support';
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Profile Edit Form
                    const Text('Chỉnh sửa thông tin Hồ sơ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0A2F5D))),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Họ và tên',
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailCtrl,
                      decoration: InputDecoration(labelText: 'Email', prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: idCtrl,
                            decoration: InputDecoration(labelText: 'MSSV / Mã cán bộ', prefixIcon: const Icon(Icons.badge_outlined),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: deptCtrl,
                            decoration: InputDecoration(labelText: 'Khoa / Đơn vị', prefixIcon: const Icon(Icons.school_outlined),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Action Buttons: Logout & Save
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(dCtx);
                              _logoutAndReturnToAuth();
                            },
                            icon: const Icon(Icons.logout_rounded, size: 18),
                            label: const Text('Đăng xuất'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFCF3C3C),
                              side: const BorderSide(color: Color(0xFFCF3C3C)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _userFullName = nameCtrl.text.trim();
                                _userEmail = emailCtrl.text.trim();
                                _userIdCode = idCtrl.text.trim();
                                _userDepartment = deptCtrl.text.trim();
                              });
                              Navigator.pop(dCtx);
                              _showSuccessSnack('Đã cập nhật thông tin Hồ sơ thành công!');
                            },
                            icon: const Icon(Icons.save_rounded, size: 18),
                            label: const Text('Lưu thay đổi'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0B6EDB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _logoutAndReturnToAuth() {
    setState(() => _isLoggedIn = false);
    _showInfoSnack('Đã đăng xuất tài khoản.');
    Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
  }

  Widget _accountChoiceChip({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0B6EDB).withValues(alpha: 0.12) : const Color(0xFFF4F8FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? const Color(0xFF0B6EDB) : const Color(0xFFE3ECFF), width: selected ? 1.5 : 1.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? Icons.check_circle_rounded : Icons.account_circle_outlined,
                size: 16, color: selected ? const Color(0xFF0B6EDB) : const Color(0xFF8AA5C7)),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? const Color(0xFF0B6EDB) : const Color(0xFF0A2F5D))),
                Text(subtitle, style: const TextStyle(fontSize: 10, color: Color(0xFF8AA5C7))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Submit Report
  Future<void> _submitReport() async {
    final desc = _reportController.text.trim();
    if (desc.isEmpty) {
      _showErrorSnack('Vui lòng nhập nội dung báo cáo trước khi gửi.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final location = _locationController.text.trim();

      final processedFiles = <UploadedFile>[];
      for (final f in _uploadedFiles) {
        Uint8List? bytes = f.bytes;
        if (bytes == null && f.blobUrl != null) {
          try {
            final res = await http.get(Uri.parse(f.blobUrl!));
            if (res.statusCode == 200) {
              bytes = res.bodyBytes;
            }
          } catch (_) {}
        }
        if (bytes == null || bytes.isEmpty) {
          bytes = Uint8List.fromList('File content: ${f.name}'.codeUnits);
        }
        processedFiles.add(UploadedFile(
          name: f.name,
          size: f.size,
          bytes: bytes,
          path: f.path,
          isAudio: f.isAudio,
          blobUrl: f.blobUrl,
        ));
      }

      final createdCase = await _caseService.submitReport(
        description: desc,
        location: location,
        reportType: 'Report',
        priority: 'Normal',
        userId: _userIdCode,
        files: processedFiles,
      );

      setState(() {
        _isSubmitting = false;
        _reportController.clear();
        _uploadedFiles.clear();
      });

      _fetchHistory();

      if (!mounted) return;
      showDialog(context: context, builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Color(0xFF1AA06A), size: 26),
          SizedBox(width: 10),
          Text('Gửi báo cáo thành công!', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0A2F5D))),
        ]),
        content: Text('Báo cáo #${createdCase.id} đã được lưu vào Database PostgreSQL với ${createdCase.evidences.length} tệp đính kèm.'),
        actions: [ElevatedButton(
          onPressed: () => Navigator.pop(ctx),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B6EDB), foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: const Text('OK'))],
      ));
    } catch (e) {
      setState(() => _isSubmitting = false);
      _showErrorSnack('Lỗi khi gửi báo cáo: $e');
    }
  }

  Future<void> _submitSos() async {
    setState(() => _isSubmitting = true);
    try {
      final desc = _reportController.text.trim().isNotEmpty
          ? _reportController.text.trim()
          : 'Yêu cầu cấp cứu / KHẨN CẤP (SOS)';
      final location = _locationController.text.trim();

      final createdCase = await _caseService.submitReport(
        description: desc,
        location: location,
        reportType: 'SOS',
        priority: 'High',
        userId: _userIdCode,
      );

      setState(() {
        _isSubmitting = false;
      });

      _fetchHistory();

      if (!mounted) return;
      showDialog(context: context, builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFCF3C3C), size: 26),
          SizedBox(width: 10),
          Text('SOS đã được gửi!', style: TextStyle(color: Color(0xFFCF3C3C), fontWeight: FontWeight.w800)),
        ]),
        content: Text('Yêu cầu khẩn cấp #${createdCase.id} đã được gửi và lưu vào Database PostgreSQL.'),
        actions: [ElevatedButton(
          onPressed: () => Navigator.pop(ctx),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCF3C3C), foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: const Text('OK'))],
      ));
    } catch (e) {
      setState(() => _isSubmitting = false);
      _showErrorSnack('Lỗi khi gửi SOS: $e');
    }
  }

  // Helpers
  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 KB';
    const u = ['B', 'KB', 'MB', 'GB'];
    var s = bytes.toDouble(); var i = 0;
    while (s >= 1024 && i < u.length - 1) { s /= 1024; i++; }
    return '${s.toStringAsFixed(s >= 10 || i == 0 ? 0 : 1)} ${u[i]}';
  }

  void _showErrorSnack(String m) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFFCF3C3C)));
  void _showSuccessSnack(String m) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF1AA06A)));
  void _showInfoSnack(String m) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;

        if (isMobile) {
          return Scaffold(
            backgroundColor: const Color(0xFFEAF3FF),
            appBar: AppBar(
              backgroundColor: const Color(0xFF0D4D8A),
              foregroundColor: Colors.white,
              elevation: 2,
              title: Row(
                children: [
                  const Icon(Icons.school_rounded, color: Colors.white, size: 24),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'UEL Support Center',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 20),
                  tooltip: 'Thông báo',
                  onPressed: () => _showNotificationPopup(context),
                ),
                GestureDetector(
                  onTap: () => _showAccountPopup(context),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.white,
                      child: Text(
                        _userFullName.isNotEmpty ? _userFullName[0] : 'H',
                        style: const TextStyle(color: Color(0xFF0B3B7A), fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: _buildMainPanel(),
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _selectedIndex.clamp(0, 2),
              onDestinationSelected: (index) {
                setState(() => _selectedIndex = index);
                if (index == 2) _fetchHistory();
              },
              backgroundColor: Colors.white,
              indicatorColor: const Color(0xFF0B6EDB).withValues(alpha: 0.15),
              elevation: 8,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.report_problem_outlined),
                  selectedIcon: Icon(Icons.report_problem_rounded, color: Color(0xFF0B6EDB)),
                  label: 'Báo cáo',
                ),
                NavigationDestination(
                  icon: Icon(Icons.sos_outlined),
                  selectedIcon: Icon(Icons.sos_rounded, color: Color(0xFFCF3C3C)),
                  label: 'SOS Khẩn cấp',
                ),
                NavigationDestination(
                  icon: Icon(Icons.history_edu_outlined),
                  selectedIcon: Icon(Icons.history_edu_rounded, color: Color(0xFF0B6EDB)),
                  label: 'Lịch sử',
                ),
              ],
            ),
          );
        }

        // Web / Desktop Layout (>= 768px)
        return Scaffold(
          backgroundColor: const Color(0xFFEAF3FF),
          body: Column(
            children: [
              _buildHeader(theme),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSidebar(),
                    Expanded(
                      flex: 8,
                      child: LayoutBuilder(
                        builder: (ctx, c) => SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: c.maxHeight),
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: _buildMainPanel(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _buildFooter(theme),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.only(left: 18, right: 20, top: 11, bottom: 11),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D4D8A), Color(0xFF0B3B7A)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.school_rounded, color: Color(0xFF0B3B7A), size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text('Trường Đại học Kinh tế - Luật',
              style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 10),
          Flexible(child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _HeaderAction(label: 'Tải app Mobile', icon: Icons.smartphone_rounded, onTap: () {}),
              const SizedBox(width: 8),
              _HeaderAction(key: _langKey, label: _isVietnamese ? 'Tiếng Việt' : 'English',
                  icon: Icons.language_rounded, onTap: () => _showLanguageMenu(context)),
              const SizedBox(width: 8),
              _HeaderAction(key: _notifKey, label: 'Thông báo', icon: _hasNotification
                  ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                  badge: _hasNotification ? '3' : null, onTap: () => _showNotificationPopup(context)),
              const SizedBox(width: 8),
              _HeaderAction(label: 'Hướng dẫn', icon: Icons.help_outline_rounded, onTap: () {}),
              const SizedBox(width: 8),
              _HeaderAction(label: _isLoggedIn ? _userFullName : 'Đăng nhập',
                  icon: _isLoggedIn ? Icons.account_circle_rounded : Icons.login_rounded,
                  onTap: () => _showAccountPopup(context), highlight: _isLoggedIn),
            ]),
          )),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 360,
      decoration: const BoxDecoration(gradient: LinearGradient(
          colors: [Color(0xFF0D4D8A), Color(0xFF103F75)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Column(children: [
          const CircleAvatar(radius: 36, backgroundColor: Colors.white,
              child: Icon(Icons.person_rounded, size: 42, color: Color(0xFF0B3B7A))),
          const SizedBox(height: 10),
          Text(_userFullName,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text('$_userRole • $_userDepartment',
              style: const TextStyle(color: Colors.white70, fontSize: 12), textAlign: TextAlign.center),
          const SizedBox(height: 18),
          Expanded(child: ListView.builder(
            padding: EdgeInsets.zero, itemCount: _items.length,
            itemBuilder: (ctx, index) {
              final item = _items[index];
              final selected = _selectedIndex == index;
              final hovered = _hoveredIndex == index;
              return MouseRegion(
                onEnter: (_) => setState(() => _hoveredIndex = index),
                onExit: (_) => setState(() => _hoveredIndex = null),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200), curve: Curves.easeInOut,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: EdgeInsets.symmetric(horizontal: selected ? 16.0 : 14.0, vertical: selected ? 16.0 : 12.0),
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : hovered ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: selected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))] : null,
                  ),
                  child: Material(color: Colors.transparent,
                    child: InkWell(borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        setState(() => _selectedIndex = index);
                        if (index == 2) _fetchHistory();
                      },
                      child: Row(children: [
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(item.title, style: TextStyle(
                              color: selected ? const Color(0xFF0B3B7A) : Colors.white,
                              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                              fontSize: selected ? 20 : 17)),
                          const SizedBox(height: 3),
                          Text(item.subtitle, style: TextStyle(
                              color: selected ? const Color(0xFF4A7CC5) : Colors.white70, fontSize: 12)),
                        ])),
                        if (selected) const Icon(Icons.chevron_right_rounded, color: Color(0xFF0B3B7A), size: 24),
                      ]),
                    ),
                  ),
                ),
              );
            },
          )),
        ]),
      ),
    );
  }

  Widget _buildMainPanel() {
    final titles = ['Báo cáo', 'SOS Khẩn cấp', 'Xem báo cáo cũ'];
    final body = switch (_selectedIndex) { 1 => _buildSosPanel(), 2 => _buildHistoryPanel(), _ => _buildReportPanel() };
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 18, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: const BoxDecoration(color: Color(0xFF0D4D8A), borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
          child: Text(titles[_selectedIndex.clamp(0, 2)], textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
        ),
        body,
      ]),
    );
  }

  Widget _buildReportPanel() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, c) {
            final isSmall = c.maxWidth < 450;
            if (isSmall) {
              return Column(
                children: [
                  _AudioRecordCard(isRecording: _isRecordingAudio, onTap: _toggleAudioRecording),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _ReportOptionCard(title: 'Tải file lên', icon: Icons.upload_file_rounded, color: const Color(0xFF0B6EDB), onTap: _pickFiles)),
                      const SizedBox(width: 10),
                      Expanded(child: _ReportOptionCard(title: 'Chụp hình', icon: Icons.camera_alt_rounded, color: const Color(0xFF1AA06A), onTap: _captureImage)),
                    ],
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: _AudioRecordCard(isRecording: _isRecordingAudio, onTap: _toggleAudioRecording)),
                const SizedBox(width: 12),
                Expanded(child: _ReportOptionCard(title: 'Tải file lên', icon: Icons.upload_file_rounded, color: const Color(0xFF0B6EDB), onTap: _pickFiles)),
                const SizedBox(width: 12),
                Expanded(child: _ReportOptionCard(title: 'Chụp hình', icon: Icons.camera_alt_rounded, color: const Color(0xFF1AA06A), onTap: _captureImage)),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFF4F8FF), borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFDBE7FF))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Vị trí / Địa điểm', style: TextStyle(color: Color(0xFF0A2F5D), fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(
              controller: _locationController,
              style: const TextStyle(color: Color(0xFF0A2F5D), fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                prefixIcon: IconButton(
                  tooltip: 'Mở bản đồ chọn vị trí (Map Picker)',
                  icon: const Icon(Icons.location_on_rounded, color: Color(0xFF0B6EDB)),
                  onPressed: _openMapPicker,
                ),
                suffixIcon: IconButton(
                  tooltip: 'Mở bản đồ',
                  icon: const Icon(Icons.map_rounded, color: Color(0xFF0B6EDB), size: 20),
                  onPressed: _openMapPicker,
                ),
                hintText: 'Nhập hoặc bấm biểu tượng vị trí để chọn trên bản đồ...',
                hintStyle: const TextStyle(color: Color(0xFF8AA5C7), fontSize: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE3ECFF))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE3ECFF))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              ),
            ),
            const SizedBox(height: 14),
            Row(children: [
              const Text('Nội dung báo cáo', style: TextStyle(color: Color(0xFF0A2F5D), fontSize: 16, fontWeight: FontWeight.w700)),
              if (_isListening) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFFFF3B30).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.fiber_manual_record, color: Color(0xFFFF3B30), size: 8),
                    SizedBox(width: 4),
                    Text('Đang nghe...', style: TextStyle(color: Color(0xFFFF3B30), fontSize: 11, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ],
            ]),
            const SizedBox(height: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _isListening ? const Color(0xFFFF3B30).withValues(alpha: 0.5) : const Color(0xFFE3ECFF),
                    width: _isListening ? 1.5 : 1.0),
                boxShadow: _isListening ? [BoxShadow(color: const Color(0xFFFF3B30).withValues(alpha: 0.08), blurRadius: 8)] : null,
              ),
              child: TextField(
                controller: _reportController, maxLines: 8, minLines: 5,
                style: const TextStyle(color: Color(0xFF53709F), fontSize: 14, height: 1.5),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                  hintText: 'Mô tả sự việc, thời gian, địa điểm... Hoặc bấm icon [Micro] ở góc dưới để nói nhập văn bản',
                  hintStyle: const TextStyle(color: Color(0xFF8AA5C7), fontSize: 14, height: 1.5),
                  suffixIcon: Align(
                    alignment: Alignment.bottomCenter, widthFactor: 1.0, heightFactor: 1.0,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 6, right: 4),
                      child: ScaleTransition(
                        scale: _isListening ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
                        child: Tooltip(
                          message: _isListening ? 'Dừng nhận dạng giọng nói' : 'Nhận dạng giọng nói (STT)',
                          child: Material(
                            color: _isListening ? const Color(0xFFFF3B30).withValues(alpha: 0.1) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: _toggleSTT,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                  _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                                  color: _isListening ? const Color(0xFFFF3B30) : const Color(0xFFAEC6E8),
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              const Text('Các file đã tải lên', style: TextStyle(color: Color(0xFF0A2F5D), fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFF0B6EDB).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Text('${_uploadedFiles.length}',
                    style: const TextStyle(color: Color(0xFF0B6EDB), fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 8),
            ..._uploadedFiles.map((file) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE3ECFF))),
              child: Row(children: [
                Container(width: 32, height: 32,
                    decoration: BoxDecoration(
                        color: (file.isAudio ? const Color(0xFF17A1B8) : const Color(0xFF0B6EDB)).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Icon(file.isAudio ? Icons.audio_file_rounded : Icons.insert_drive_file_rounded,
                        color: file.isAudio ? const Color(0xFF17A1B8) : const Color(0xFF0B6EDB), size: 16)),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(file.name, style: const TextStyle(color: Color(0xFF0A2F5D), fontWeight: FontWeight.w600, fontSize: 12), overflow: TextOverflow.ellipsis),
                  Text(file.size, style: const TextStyle(color: Color(0xFF6C8BB8), fontSize: 10)),
                ])),
                IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(), tooltip: 'Tải xuống', icon: const Icon(Icons.download_rounded, color: Color(0xFF0B6EDB), size: 18), onPressed: () => _downloadFile(file)),
                const SizedBox(width: 8),
                IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(), tooltip: 'Xóa', icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFCF3C3C), size: 18), onPressed: () => _removeFile(file)),
              ]),
            )),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitReport,
                icon: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(_isSubmitting ? 'Đang gửi...' : 'Gửi báo cáo & Lưu DB'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0B6EDB), foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              )),
          ]),
        ),
      ]),
    );
  }

  Widget _buildSosPanel() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFFFF3F3), borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFFFCDD2), width: 1.5)),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFCF3C3C), size: 20),
              SizedBox(width: 6),
              Text('Mức độ cấp cứu', style: TextStyle(color: Color(0xFFCF3C3C), fontSize: 16, fontWeight: FontWeight.w700)),
            ]),
            SizedBox(height: 8),
            Text('Khẩn cấp: Liên hệ hỗ trợ ngay hoặc báo với quản lý khu vực để xử lý nhanh nhất.',
                style: TextStyle(color: Color(0xFF53709F), fontSize: 13, height: 1.4)),
          ]),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _ReportOptionCard(title: 'Gọi hỗ trợ', icon: Icons.call_rounded, color: const Color(0xFF0B6EDB), onTap: _isSubmitting ? null : _submitSos)),
          const SizedBox(width: 12),
          Expanded(child: _ReportOptionCard(title: 'Vị trí hiện tại', icon: Icons.location_on_rounded, color: const Color(0xFF17A1B8), onTap: _openMapPicker)),
        ]),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _submitSos,
            icon: const Icon(Icons.warning_amber_rounded, size: 20),
            label: Text(_isSubmitting ? 'Đang gửi SOS...' : 'Gửi SOS vào Database', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCF3C3C), foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          )),
      ]),
    );
  }

  Widget _buildHistoryPanel() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFF4F8FF), borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFDBE7FF))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Expanded(
              child: Text('Lịch sử báo cáo trong Database',
                  style: TextStyle(color: Color(0xFF0A2F5D), fontSize: 16, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0B6EDB), size: 20),
              tooltip: 'Làm mới',
              onPressed: _fetchHistory,
            ),
          ]),
          const SizedBox(height: 10),
          if (_isLoadingHistory)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
          else if (_historyCases.isEmpty)
            const Padding(padding: EdgeInsets.all(16), child: Text('Chưa có báo cáo nào trong Database.', style: TextStyle(color: Color(0xFF53709F))))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _historyCases.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (ctx, index) {
                final item = _historyCases[index];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE3ECFF)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: item.reportType == 'SOS' 
                                        ? const Color(0xFFCF3C3C).withValues(alpha: 0.1) 
                                        : const Color(0xFF0B6EDB).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '#${item.id} - ${item.reportType}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      color: item.reportType == 'SOS' ? const Color(0xFFCF3C3C) : const Color(0xFF0B6EDB),
                                    ),
                                  ),
                                ),
                                if (item.location.isNotEmpty)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.location_on_rounded, size: 13, color: Color(0xFF8AA5C7)),
                                      const SizedBox(width: 2),
                                      Flexible(
                                        child: Text(
                                          item.location,
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF53709F)),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1AA06A).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.status,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Color(0xFF1AA06A)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(item.description, style: const TextStyle(fontSize: 13, color: Color(0xFF0A2F5D), height: 1.4)),
                      if (item.evidences.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: item.evidences.map((e) => Chip(
                            padding: const EdgeInsets.all(2),
                            avatar: Icon(
                              e.fileType == 'image' ? Icons.image_rounded : e.fileType == 'audio' ? Icons.audiotrack_rounded : Icons.insert_drive_file_rounded,
                              size: 14,
                            ),
                            label: Text(e.fileName, style: const TextStyle(fontSize: 10)),
                            backgroundColor: const Color(0xFFF4F8FF),
                          )).toList(),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
        ]),
      ),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(color: Color(0xFF0B3B7A)),
      child: Wrap(spacing: 12, runSpacing: 8, alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [
        ConstrainedBox(constraints: const BoxConstraints(maxWidth: 700),
            child: const Text('Hotline: 1900 1234  -  Email: support@uel.edu.vn  -  Địa chỉ: 669 Quốc lộ 1A, TP. Thủ Đức, TP. Hồ Chí Minh',
                style: TextStyle(color: Colors.white70, fontSize: 12), softWrap: true, overflow: TextOverflow.ellipsis, maxLines: 2)),
        Text('2026 UEL Support Center', style: theme.textTheme.labelMedium?.copyWith(color: Colors.white70)),
      ]),
    );
  }
}

// ─── DATA CLASSES ──────────────────────────────────────────────────────────────

class _SidebarItem {
  const _SidebarItem({required this.title, required this.icon, required this.subtitle});
  final String title;
  final IconData icon;
  final String subtitle;
}

class _NotifItem {
  const _NotifItem({required this.icon, required this.color, required this.title, required this.time});
  final IconData icon;
  final Color color;
  final String title;
  final String time;
}

// ─── WIDGETS ───────────────────────────────────────────────────────────────────

class _HeaderAction extends StatefulWidget {
  const _HeaderAction({super.key, required this.label, required this.icon, required this.onTap, this.badge, this.highlight = false});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final String? badge;
  final bool highlight;

  @override
  State<_HeaderAction> createState() => _HeaderActionState();
}

class _HeaderActionState extends State<_HeaderAction> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: widget.highlight
                ? Colors.white.withValues(alpha: _hovered ? 0.28 : 0.18)
                : Colors.white.withValues(alpha: _hovered ? 0.15 : 0.08),
            borderRadius: BorderRadius.circular(12),
            border: widget.highlight ? Border.all(color: Colors.white.withValues(alpha: 0.4)) : null,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Stack(clipBehavior: Clip.none, children: [
              Icon(widget.icon, color: Colors.white, size: 17),
              if (widget.badge != null)
                Positioned(top: -6, right: -8, child: Container(
                  width: 15, height: 15,
                  decoration: const BoxDecoration(color: Color(0xFFFF3B30), shape: BoxShape.circle),
                  child: Center(child: Text(widget.badge!, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700))),
                )),
            ]),
            const SizedBox(width: 7),
            Text(widget.label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

class _AudioRecordCard extends StatelessWidget {
  const _AudioRecordCard({required this.isRecording, required this.onTap});
  final bool isRecording;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ReportOptionCard(
      title: isRecording ? 'Đang ghi âm... (Bấm dừng)' : 'Ghi âm thành file',
      icon: isRecording ? Icons.stop_circle_rounded : Icons.mic_rounded,
      color: isRecording ? const Color(0xFFCF3C3C) : const Color(0xFF17A1B8),
      onTap: onTap,
    );
  }
}

class _ReportOptionCard extends StatelessWidget {
  const _ReportOptionCard({required this.title, required this.icon, required this.color, this.onTap});
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 84,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 5),
              Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
