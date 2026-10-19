import 'dart:html' as html;
import 'dart:typed_data';

// ─── Download File ──────────────────────────────────────────────
void downloadFileWeb(String? blobUrl, String filename) {
  if (blobUrl == null) return;
  final anchor = html.AnchorElement(href: blobUrl)
    ..setAttribute('download', filename);
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
}

// ─── Camera Capture via HTML input[capture] ─────────────────────
void captureImageWeb(void Function(String name, int size, Uint8List? bytes) onFile) {
  final input = html.InputElement(type: 'file')
    ..accept = 'image/*'
    ..setAttribute('capture', 'environment');
  input.onChange.listen((_) {
    final files = input.files;
    if (files == null || files.isEmpty) return;
    final file = files.first;
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    reader.onLoadEnd.listen((_) {
      Uint8List? bytes;
      if (reader.result is Uint8List) {
        bytes = reader.result as Uint8List;
      } else if (reader.result is ByteBuffer) {
        bytes = (reader.result as ByteBuffer).asUint8List();
      }
      onFile(file.name, file.size, bytes);
    });
  });
  input.click();
}

// ─── Audio Recording via MediaRecorder ─────────────────────────
html.MediaRecorder? _recorder;
html.MediaStream? _stream;
final List<html.Blob> _chunks = [];

Future<bool> startAudioRecordingWeb(
    void Function(String name, String blobUrl) onDone) async {
  try {
    final stream = await html.window.navigator.mediaDevices!
        .getUserMedia({'audio': true});
    _stream = stream;
    _chunks.clear();

    final recorder = html.MediaRecorder(stream);
    _recorder = recorder;

    recorder.addEventListener('dataavailable', (html.Event event) {
      final dynamic blob = (event as dynamic).data;
      if (blob != null && (blob.size as int) > 0) {
        _chunks.add(blob as html.Blob);
      }
    });

    recorder.addEventListener('stop', (html.Event event) {
      if (_chunks.isEmpty) return;
      final finalBlob = html.Blob(_chunks.toList(), 'audio/webm');
      final url = html.Url.createObjectUrl(finalBlob);
      final name = 'ghi_am_${DateTime.now().millisecondsSinceEpoch}.webm';
      _stream?.getTracks().forEach((t) => t.stop());
      _chunks.clear();
      _recorder = null;
      _stream = null;
      onDone(name, url);
    });

    recorder.start(100);
    return true;
  } catch (_) {
    return false;
  }
}

void stopAudioRecordingWeb() {
  _recorder?.stop();
}

// ─── GPS Geolocation ───────────────────────────────────────────
void getCurrentLocationWeb(
    void Function(double lat, double lng) onSuccess,
    void Function(String err) onError) {
  try {
    html.window.navigator.geolocation.getCurrentPosition().then((pos) {
      final coords = pos.coords;
      if (coords != null && coords.latitude != null && coords.longitude != null) {
        onSuccess(coords.latitude!.toDouble(), coords.longitude!.toDouble());
      } else {
        onError('Không thể lấy tọa độ vị trí.');
      }
    }).catchError((e) {
      onError('Chưa cấp quyền truy cập vị trí GPS.');
    });
  } catch (e) {
    onError('Hệ thống không hỗ trợ GPS.');
  }
}
