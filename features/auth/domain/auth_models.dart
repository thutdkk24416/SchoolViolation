enum AuthRole { student, teacher }

enum AppLocale { vi, en }

enum PasswordStrength { weak, fair, good, strong }

enum AuthErrorKind {
  configuration,
  network,
  invalidCredentials,
  validation,
  provider,
  unknown,
}

class AuthException implements Exception {
  const AuthException(this.kind, {this.message});

  final AuthErrorKind kind;
  final String? message;
}

class AuthSession {
  const AuthSession({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.role,
    this.accessToken,
    this.refreshToken,
  });

  final String userId;
  final String fullName;
  final String email;
  final AuthRole role;
  final String? accessToken;
  final String? refreshToken;
}

class LoginRequest {
  const LoginRequest({
    required this.email,
    required this.password,
    required this.role,
    this.rememberMe = false,
  });

  final String email;
  final String password;
  final AuthRole role;
  final bool rememberMe;
}

class RegisterRequest {
  const RegisterRequest({
    required this.fullName,
    required this.email,
    required this.password,
    required this.role,
    required this.acceptTerms,
  });

  final String fullName;
  final String email;
  final String password;
  final AuthRole role;
  final bool acceptTerms;
}

class RegistrationResult {
  const RegistrationResult({
    required this.userId,
    required this.requiresEmailVerification,
  });

  final String userId;
  final bool requiresEmailVerification;
}

class ResetPasswordRequest {
  const ResetPasswordRequest({required this.token, required this.newPassword});

  final String token;
  final String newPassword;
}
