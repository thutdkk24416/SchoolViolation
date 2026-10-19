import 'auth_models.dart';

abstract interface class AuthService {
  Future<AuthSession> login(LoginRequest request);
  Future<RegistrationResult> register(RegisterRequest request);
  Future<void> requestPasswordReset({
    required String email,
    required AppLocale locale,
  });
  Future<void> resetPassword(ResetPasswordRequest request);
  Future<AuthSession> signInWithGoogle(AuthRole role);
  Future<AuthSession> signInWithApple(AuthRole role);
}
