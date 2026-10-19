import '../domain/auth_service.dart';
import 'development_mock_auth_service.dart';
import 'django_auth_service.dart';
import 'unavailable_auth_service.dart';

class AuthServiceFactory {
  const AuthServiceFactory({String? mode})
      : mode = mode ??
            const String.fromEnvironment(
              'AUTH_MODE',
              defaultValue: 'django',
            );

  final String mode;

  AuthService create() {
    switch (mode) {
      case 'mock':
        return const DevelopmentMockAuthService();
      case 'unavailable':
        return const UnavailableAuthService();
      case 'django':
      default:
        return DjangoAuthService();
    }
  }
}
