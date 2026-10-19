import '../domain/auth_models.dart';
import '../domain/auth_service.dart';

class UnavailableAuthService implements AuthService {
  const UnavailableAuthService();

  Never _unavailable() => throw const AuthException(AuthErrorKind.configuration);

  @override
  Future<AuthSession> login(LoginRequest request) async => _unavailable();

  @override
  Future<RegistrationResult> register(RegisterRequest request) async =>
      _unavailable();

  @override
  Future<void> requestPasswordReset({
    required String email,
    required AppLocale locale,
  }) async =>
      _unavailable();

  @override
  Future<void> resetPassword(ResetPasswordRequest request) async =>
      _unavailable();

  @override
  Future<AuthSession> signInWithGoogle(AuthRole role) async => _unavailable();

  @override
  Future<AuthSession> signInWithApple(AuthRole role) async => _unavailable();
}
