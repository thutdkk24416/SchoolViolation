import 'dart:html' as html;
import 'dart:typed_data';

import 'dashboard_platform.dart';

class WebDashboardPlatform extends DashboardPlatform {
  const WebDashboardPlatform();

  @override
  void downloadFile(String? blobUrl, String filename) {
    if (blobUrl == null) return;
    final anchor = html.AnchorElement(href: blobUrl)
      ..setAttribute('download', filename);
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
  }

  @override
  void captureImage(
    void Function(String name, int size, Uint8List? bytes) onFile,
  ) {
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

  @override
  void getCurrentLocation(
    void Function(double lat, double lng) onSuccess,
    void Function(String error) onError,
  ) {
    try {
      html.window.navigator.geolocation
          .getCurrentPosition()
          .then((pos) {
            final coords = pos.coords;
            if (coords != null &&
                coords.latitude != null &&
                coords.longitude != null) {
              onSuccess(
                coords.latitude!.toDouble(),
                coords.longitude!.toDouble(),
              );
            } else {
              onError('Không thể lấy tọa độ vị trí.');
            }
          })
          .catchError((e) {
            onError('Chưa cấp quyền truy cập vị trí GPS.');
          });
    } catch (e) {
      onError('Hệ thống không hỗ trợ GPS.');
    }
  }
}

DashboardPlatform createDashboardPlatform() => const WebDashboardPlatform();
