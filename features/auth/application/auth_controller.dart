import '../domain/auth_models.dart';
import '../domain/auth_service.dart';

class AuthActionResult {
  const AuthActionResult._({this.session, this.error});
  const AuthActionResult.success(AuthSession? session) : this._(session: session);
  const AuthActionResult.failure(AuthException error) : this._(error: error);

  final AuthSession? session;
  final AuthException? error;
  bool get isSuccess => error == null;
}

class AuthController {
  const AuthController(this._service);

  final AuthService _service;

  Future<AuthActionResult> login(LoginRequest request) => _runSession(
        () => _service.login(request),
      );
  Future<AuthActionResult> google(AuthRole role) =>
      _runSession(() => _service.signInWithGoogle(role));
  Future<AuthActionResult> apple(AuthRole role) =>
      _runSession(() => _service.signInWithApple(role));

  Future<AuthActionResult> register(RegisterRequest request) => _run(
        () => _service.register(request),
      );
  Future<AuthActionResult> forgotPassword(String email, AppLocale locale) =>
      _run(() => _service.requestPasswordReset(email: email, locale: locale));
  Future<AuthActionResult> resetPassword(ResetPasswordRequest request) =>
      _run(() => _service.resetPassword(request));

  Future<AuthActionResult> _runSession(Future<AuthSession> Function() action) async {
    try {
      return AuthActionResult.success(await action());
    } on AuthException catch (error) {
      return AuthActionResult.failure(error);
    } catch (_) {
      return const AuthActionResult.failure(AuthException(AuthErrorKind.unknown));
    }
  }

  Future<AuthActionResult> _run<T>(Future<T> Function() action) async {
    try {
      await action();
      return const AuthActionResult.success(null);
    } on AuthException catch (error) {
      return AuthActionResult.failure(error);
    } catch (_) {
      return const AuthActionResult.failure(AuthException(AuthErrorKind.unknown));
    }
  }
}
