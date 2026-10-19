import '../domain/auth_models.dart';

class AuthStrings {
  const AuthStrings(this.locale);
  final AppLocale locale;

  String get language => locale == AppLocale.vi ? 'Tiếng Việt' : 'English';
  String get otherLanguage => locale == AppLocale.vi ? 'English' : 'Tiếng Việt';
  String get appName => locale == AppLocale.vi
      ? 'Hệ thống phát hiện vi phạm học đường'
      : 'School Violation Detector';
  String get portalLabel =>
      locale == AppLocale.vi ? 'Cổng thông tin' : 'Portal';
  String get studentPortal =>
      locale == AppLocale.vi ? 'Cổng sinh viên' : 'Student portal';
  String get teacherPortal =>
      locale == AppLocale.vi ? 'Cổng giảng viên' : 'Teacher portal';
  String get welcome =>
      locale == AppLocale.vi ? 'Chào mừng trở lại' : 'Welcome back';
  String get subtitle => locale == AppLocale.vi
      ? 'Đăng nhập để bảo vệ cộng đồng học đường.'
      : 'Sign in to protect your school community.';
  String get login => locale == AppLocale.vi ? 'Đăng nhập' : 'Login';
  String get register => locale == AppLocale.vi ? 'Đăng ký' : 'Register';
  String get email =>
      locale == AppLocale.vi ? 'Email trường học' : 'School email';
  String get password => locale == AppLocale.vi ? 'Mật khẩu' : 'Password';
  String get confirmPassword =>
      locale == AppLocale.vi ? 'Xác nhận mật khẩu' : 'Confirm password';
  String get fullName => locale == AppLocale.vi ? 'Họ và tên' : 'Full name';
  String get forgot =>
      locale == AppLocale.vi ? 'Quên mật khẩu?' : 'Forgot password?';
  String get remember =>
      locale == AppLocale.vi ? 'Ghi nhớ đăng nhập' : 'Remember me';
  String get continueWith =>
      locale == AppLocale.vi ? 'hoặc tiếp tục với' : 'or continue with';
  String get google =>
      locale == AppLocale.vi ? 'Tiếp tục với Google' : 'Continue with Google';
  String get apple =>
      locale == AppLocale.vi ? 'Tiếp tục với Apple' : 'Continue with Apple';
  String get required => locale == AppLocale.vi
      ? 'Trường này là bắt buộc'
      : 'This field is required';
  String get invalidEmail =>
      locale == AppLocale.vi ? 'Email không hợp lệ' : 'Enter a valid email';
  String get shortPassword => locale == AppLocale.vi
      ? 'Mật khẩu phải có ít nhất 8 ký tự'
      : 'Password must be at least 8 characters';
  String get mismatch => locale == AppLocale.vi
      ? 'Mật khẩu xác nhận không khớp'
      : 'Passwords do not match';
  String get configuration => locale == AppLocale.vi
      ? 'Xác thực chưa được cấu hình. Vui lòng thử lại sau.'
      : 'Authentication is not configured yet. Please try again later.';
  String get invalidCredentials => locale == AppLocale.vi
      ? 'Email hoặc mật khẩu không đúng.'
      : 'Incorrect email or password.';
  String get providerError => locale == AppLocale.vi
      ? 'Nhà cung cấp đăng nhập chưa được cấu hình.'
      : 'This sign-in provider is not configured.';
  String get genericError => locale == AppLocale.vi
      ? 'Đã có lỗi xảy ra. Vui lòng thử lại.'
      : 'Something went wrong. Please try again.';
  String get resetTitle =>
      locale == AppLocale.vi ? 'Đặt lại mật khẩu' : 'Reset password';
  String get resetDescription => locale == AppLocale.vi
      ? 'Nhập email để nhận hướng dẫn đặt lại mật khẩu.'
      : 'Enter your email to receive reset instructions.';
  String get sendInstructions =>
      locale == AppLocale.vi ? 'Gửi hướng dẫn' : 'Send instructions';
  String get resetSent => locale == AppLocale.vi
      ? 'Nếu email hợp lệ, hướng dẫn đặt lại đã được gửi.'
      : 'If the email is valid, reset instructions have been sent.';
  String get backToLogin =>
      locale == AppLocale.vi ? 'Quay lại đăng nhập' : 'Back to login';
  String get haveResetToken =>
      locale == AppLocale.vi ? 'Tôi đã có mã đặt lại' : 'I have a reset token';
  String get registrationSuccess => locale == AppLocale.vi
      ? 'Đăng ký thành công!'
      : 'Registration successful!';
  String get passwordChanged => locale == AppLocale.vi
      ? 'Đổi mật khẩu thành công.'
      : 'Password changed successfully.';
  String get agree => locale == AppLocale.vi
      ? 'Tôi đồng ý với điều khoản và quyền riêng tư.'
      : 'I agree to the terms and privacy policy.';
  String get needAccount =>
      locale == AppLocale.vi ? 'Chưa có tài khoản?' : "Don't have an account?";
  String get haveAccount =>
      locale == AppLocale.vi ? 'Đã có tài khoản?' : 'Already have an account?';
  String get resetToken =>
      locale == AppLocale.vi ? 'Mã đặt lại' : 'Reset token';
  String get hidePassword =>
      locale == AppLocale.vi ? 'Ẩn mật khẩu' : 'Hide password';
  String get showPassword =>
      locale == AppLocale.vi ? 'Hiện mật khẩu' : 'Show password';
  String get universityName => locale == AppLocale.vi
      ? 'Trường Đại học Kinh tế - Luật'
      : 'University of Economics and Law';
  String get universityTagline => locale == AppLocale.vi
      ? 'Cộng đồng học đường an toàn và đáng tin cậy.'
      : 'A safer, trusted academic community.';
  String roleName(AuthRole role) => switch (role) {
    AuthRole.student => locale == AppLocale.vi ? 'Sinh viên' : 'Student',
    AuthRole.teacher => locale == AppLocale.vi ? 'Giảng viên' : 'Teacher',
  };
  String switchRole(AuthRole role) => role == AuthRole.student
      ? (locale == AppLocale.vi
            ? 'Chuyển sang Giảng viên'
            : 'Switch to Teacher')
      : (locale == AppLocale.vi
            ? 'Chuyển sang Sinh viên'
            : 'Switch to Student');
  String strength(PasswordStrength strength) => switch (strength) {
    PasswordStrength.weak => locale == AppLocale.vi ? 'Yếu' : 'Weak',
    PasswordStrength.fair => locale == AppLocale.vi ? 'Khá' : 'Fair',
    PasswordStrength.good => locale == AppLocale.vi ? 'Tốt' : 'Good',
    PasswordStrength.strong => locale == AppLocale.vi ? 'Mạnh' : 'Strong',
  };
}
