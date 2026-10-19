import 'auth_models.dart';

String? validateEmail(String value) {
  final email = value.trim();
  if (email.isEmpty) return 'required';
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
      ? null
      : 'invalidEmail';
}

String? validateRequired(String value) => value.trim().isEmpty ? 'required' : null;

String? validatePassword(String value) {
  if (value.isEmpty) return 'required';
  if (value.length < 8) return 'passwordTooShort';
  return null;
}

String? validatePasswordConfirmation(String value, String password) {
  if (value.isEmpty) return 'required';
  return value == password ? null : 'passwordMismatch';
}

PasswordStrength passwordStrength(String password) {
  if (password.isEmpty || password.length < 6) return PasswordStrength.weak;
  var score = password.length >= 10 ? 1 : 0;
  if (RegExp(r'[A-Z]').hasMatch(password)) score++;
  if (RegExp(r'[a-z]').hasMatch(password)) score++;
  if (RegExp(r'[0-9]').hasMatch(password)) score++;
  if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) score++;
  if (score >= 4) return PasswordStrength.strong;
  if (score >= 3) return PasswordStrength.good;
  return PasswordStrength.fair;
}
