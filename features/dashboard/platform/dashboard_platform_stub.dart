import 'dart:typed_data';

import 'dashboard_platform.dart';

/// Native implementation pending: do not silently report success.
class UnsupportedDashboardPlatform extends DashboardPlatform {
  const UnsupportedDashboardPlatform();

  @override
  void captureImage(
    void Function(String name, int size, Uint8List? bytes) onFile,
  ) {
    // No native camera adapter is installed yet.
  }

  @override
  void downloadFile(String? blobUrl, String filename) {
    // Blob URLs are browser-only; native downloads need a separate adapter.
  }

  @override
  void getCurrentLocation(
    void Function(double lat, double lng) onSuccess,
    void Function(String error) onError,
  ) {
    onError('Vui lòng nhập vị trí thủ công.');
  }
}

DashboardPlatform createDashboardPlatform() =>
    const UnsupportedDashboardPlatform();
