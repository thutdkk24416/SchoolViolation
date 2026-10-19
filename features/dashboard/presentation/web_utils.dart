// Legacy browser audio recording helpers; dashboard UI currently does not use them.
// New dashboard platform operations live under features/dashboard/platform.
export 'web_utils_stub.dart' if (dart.library.html) 'web_utils_web.dart';
