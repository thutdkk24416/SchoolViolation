import 'dart:typed_data';

import 'dashboard_platform_stub.dart'
    if (dart.library.html) 'dashboard_platform_web.dart'
    as implementation;

/// Platform operations used by the dashboard UI.
abstract class DashboardPlatform {
  const DashboardPlatform();

  void captureImage(
    void Function(String name, int size, Uint8List? bytes) onFile,
  );

  void downloadFile(String? blobUrl, String filename);

  void getCurrentLocation(
    void Function(double lat, double lng) onSuccess,
    void Function(String error) onError,
  );
}

DashboardPlatform createDashboardPlatform() =>
    implementation.createDashboardPlatform();
