import '../domain/auth_models.dart';
import '../domain/auth_service.dart';

/// Preview-only adapter. Select it exclusively through `AUTH_MODE=mock`.
class DevelopmentMockAuthService implements AuthService {
  const DevelopmentMockAuthService();

  bool _validPreview(LoginRequest request) =>
      request.password == 'Preview@123' &&
      ((request.role == AuthRole.student &&
              request.email == 'student@uel.edu.vn') ||
          (request.role == AuthRole.teacher &&
              request.email == 'teacher@uel.edu.vn'));

  @override
  Future<AuthSession> login(LoginRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!_validPreview(request)) {
      throw const AuthException(AuthErrorKind.invalidCredentials);
    }
    final isStudent = request.role == AuthRole.student;
    return AuthSession(
      userId: isStudent ? 'preview-student-001' : 'preview-teacher-001',
      fullName: isStudent ? 'Nguyen Minh Student' : 'Tran Anh Teacher',
      email: request.email,
      role: request.role,
    );
  }

  @override
  Future<RegistrationResult> register(RegisterRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    return const RegistrationResult(
      userId: 'preview-registration',
      requiresEmailVerification: false,
    );
  }

  @override
  Future<void> requestPasswordReset({
    required String email,
    required AppLocale locale,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }

  @override
  Future<void> resetPassword(ResetPasswordRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }

  @override
  Future<AuthSession> signInWithGoogle(AuthRole role) async =>
      _providerSession(role, 'Google');

  @override
  Future<AuthSession> signInWithApple(AuthRole role) async =>
      _providerSession(role, 'Apple');

  Future<AuthSession> _providerSession(AuthRole role, String provider) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    return AuthSession(
      userId: 'preview-${provider.toLowerCase()}-${role.name}',
      fullName: '$provider Preview ${role.name}',
      email: '${role.name}@$provider.preview'.toLowerCase(),
      role: role,
    );
  }
}
