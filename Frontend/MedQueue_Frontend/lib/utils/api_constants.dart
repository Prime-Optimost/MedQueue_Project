import 'package:flutter/foundation.dart';

/// API Configuration Constants
class ApiConstants {
  // Backend Base URL
  // For Web (Chrome/Edge): use localhost (the browser runs on this machine)
  // For Android Emulator: use 10.0.2.2 (special alias for host machine)
  // For iOS Simulator: use localhost
  // For Physical Device: use your computer's IP address (e.g., 192.168.x.x)
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000/api/v1';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.223.6.233:8000/api/v1';
    }
    return 'http://10.223.6.233:8000/api/v1';
  }

  static String get mediaBaseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000/';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.223.6.233:8000/';
    }
    return 'http://localhost:8000/';
  }

  // Authentication Endpoints
  static const String registerEndpoint = '/auth/register/';
  static const String loginEndpoint = '/auth/login/';
  static const String logoutEndpoint = '/auth/logout/';
  static const String refreshTokenEndpoint = '/auth/token/refresh/';
  static const String profileEndpoint = '/auth/profile/';

  // OTP Endpoints
  static const String otpSendEndpoint = '/auth/otp/send/';
  static const String otpVerifyEndpoint = '/auth/otp/verify/';

  // Password Reset Endpoints
  static const String passwordResetRequestEndpoint = '/auth/password/reset/request/';
  static const String passwordResetConfirmEndpoint = '/auth/password/reset/confirm/';

  static const String availabilityMyEndpoint = '/auth/availability/my/';
  static const String availabilityDatesEndpoint = '/auth/availability/dates/';

  // Timeouts
  static const Duration apiTimeout = Duration(seconds: 30);

  // Token Storage Keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userDataKey = 'user_data';

  // OTP Configuration
  static const int otpLength = 6;
  static const int otpExpiryMinutes = 5;

  // Account Lockout
  static const int maxLoginAttempts = 3;
  static const int lockoutDurationMinutes = 15;

  // Validation Rules
  static const int minPasswordLength = 8;
  static const int minUsernameLength = 3;
  static const int maxUsernameLength = 150;
  static const int minPhoneLength = 10;
  static const int maxPhoneLength = 20;

  // Error Messages
  static const String networkError = 'Network error. Please check your connection.';
  static const String timeoutError = 'Request timeout. Please try again.';
  static const String invalidCredentials = 'Invalid username or password.';
  static const String accountLocked = 'Account locked. Please try again later.';
  static const String sessionExpired = 'Session expired. Please log in again.';
  static const String unexpectedError = 'An unexpected error occurred. Please try again.';
}

/// User Roles
enum UserRole { patient, doctor, admin }

extension UserRoleExtension on UserRole {
  String get value {
    return toString().split('.').last;
  }

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => UserRole.patient,
    );
  }
}

/// OTP Purpose Types
enum OtpPurpose { phoneReg, passwordReset }

extension OtpPurposeExtension on OtpPurpose {
  String get value {
    switch (this) {
      case OtpPurpose.phoneReg:
        return 'phone_reg';
      case OtpPurpose.passwordReset:
        return 'password_reset';
    }
  }

  static OtpPurpose fromString(String value) {
    return OtpPurpose.values.firstWhere(
      (purpose) => purpose.value == value,
      orElse: () => OtpPurpose.phoneReg,
    );
  }
}
