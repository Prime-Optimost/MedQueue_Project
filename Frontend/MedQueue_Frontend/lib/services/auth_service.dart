import 'package:flutter/foundation.dart';
import '../models/api_response_model.dart';
import '../utils/api_constants.dart';
import '../utils/token_manager.dart';
import 'api_client.dart';

class AuthService extends ChangeNotifier {
  UserProfile? _currentUser;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _errorMessage;
  Map<String, dynamic>? _fieldErrors;

  UserProfile? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get fieldErrors => _fieldErrors;
  bool get isAuthenticated => _currentUser != null;


  /// Initialize auth state on app startup (called only once)
  Future<void> initialize() async {
    if (_isInitialized) return; // Prevent re-initialization

    // Yield to the event loop so notifyListeners() below doesn't run during
    // the build/mount phase (which would throw "setState during build").
    await null;

    _isLoading = true;
    notifyListeners();

    try {
      // Check if user was previously logged in
      if (await TokenManager.isAuthenticated()) {
        _currentUser = await TokenManager.getCachedUserData();
      }
    } catch (e) {
      _errorMessage = 'Failed to initialize: $e';
    }

    _isInitialized = true;
    _isLoading = false;
    notifyListeners();
  }

  /// Login with username/email/phone and password
  Future<bool> login(String login, String password) async {
    _isLoading = true;
    _errorMessage = null;
    _fieldErrors = null;
    notifyListeners();

    try {
      final response = await ApiClient.post<LoginResponse>(
        ApiConstants.loginEndpoint,
        body: {
          'login': login.trim(),
          'password': password,
        },
        parser: (json) => LoginResponse.fromJson(json),
      );

      if (response.isSuccess && response.data != null) {
        // Save tokens
        await TokenManager.saveTokens(
          response.data!.tokens.access,
          response.data!.tokens.refresh,
        );
        
        // Save user data
        await TokenManager.saveUserData(response.data!.user);
        _currentUser = response.data!.user;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response.message;
        _fieldErrors = response.errors;
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Login failed: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Register a new user account
  Future<bool> register({
    required String username,
    required String email,
    required String phoneNumber,
    String? whatsappNumber,
    required String password,
    required String passwordConfirm,
    required String firstName,
    required String lastName,
    required String role,
    String gender = 'unspecified',
    String? dateOfBirth,
    String? address,
    String? bloodGroup,
    String? emergencyContactName,
    String? emergencyContactPhone,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _fieldErrors = null;
    notifyListeners();

    try {
      final body = {
        'username': username.trim(),
        'email': email.trim(),
        'phone_number': phoneNumber.trim(),
        'whatsapp_number': whatsappNumber?.trim() ?? '',
        'password': password,
        'password_confirm': passwordConfirm,
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'role': role,
        'gender': gender,
      };

      if (dateOfBirth != null) body['date_of_birth'] = dateOfBirth;
      if (address != null) body['address'] = address.trim();

      // Add patient-specific fields
      if (role == 'patient') {
        if (bloodGroup != null) body['blood_group'] = bloodGroup;
        if (emergencyContactName != null) {
          body['emergency_contact_name'] = emergencyContactName.trim();
        }
        if (emergencyContactPhone != null) {
          body['emergency_contact_phone'] = emergencyContactPhone.trim();
        }
      }

      final response = await ApiClient.post<Map<String, dynamic>>(
        ApiConstants.registerEndpoint,
        body: body,
        parser: (json) => json,
      );

      if (response.isSuccess) {
        _isLoading = false;
        notifyListeners();
        return true; // Success - proceed to OTP verification
      } else {
        _errorMessage = _firstFieldError(response.errors) ?? response.message;
        _fieldErrors = response.errors;
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Registration failed: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Return the first field-specific error message, if any.
  String? _firstFieldError(Map<String, dynamic>? errors) {
    if (errors == null || errors.isEmpty) return null;
    for (final value in errors.values) {
      if (value is List && value.isNotEmpty) return value.first.toString();
      if (value is String) return value;
    }
    return null;
  }

  /// Verify OTP during registration or password reset
  Future<bool> verifyOTP({
    required String phoneNumber,
    required String code,
    required String purpose,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _fieldErrors = null;
    notifyListeners();

    try {
      final response = await ApiClient.post<Map<String, dynamic>>(
        ApiConstants.otpVerifyEndpoint,
        body: {
          'phone_number': phoneNumber.trim(),
          'code': code.trim(),
          'purpose': purpose,
        },
        parser: (json) => json,
      );

      if (response.isSuccess && response.data != null) {
        final data = response.data!;
        
        // Check if we got tokens back (registration verification)
        if (data.containsKey('tokens') && data.containsKey('user')) {
          final tokens = data['tokens'] as Map<String, dynamic>;
          final user = data['user'] as Map<String, dynamic>;

          await TokenManager.saveTokens(
            tokens['access'],
            tokens['refresh'],
          );

          _currentUser = UserProfile.fromJson(user);
          await TokenManager.saveUserData(_currentUser!);
        }

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response.message;
        _fieldErrors = response.errors;
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'OTP verification failed: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Send OTP to phone number
  Future<bool> sendOTP(String phoneNumber, String purpose) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiClient.post<Map<String, dynamic>>(
        ApiConstants.otpSendEndpoint,
        body: {
          'phone_number': phoneNumber.trim(),
          'purpose': purpose,
        },
        parser: (json) => json,
      );

      if (response.isSuccess) {
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response.message;
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Failed to send OTP: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Request password reset
  Future<bool> requestPasswordReset(String phoneOrEmail) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final body = phoneOrEmail.contains('@')
          ? {'email': phoneOrEmail.trim()}
          : {'phone_number': phoneOrEmail.trim()};

      final response = await ApiClient.post<Map<String, dynamic>>(
        ApiConstants.passwordResetRequestEndpoint,
        body: body,
        parser: (json) => json,
      );

      if (response.isSuccess) {
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response.message;
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Password reset request failed: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Confirm password reset with OTP
  Future<bool> confirmPasswordReset({
    required String phoneNumber,
    required String code,
    required String newPassword,
    required String newPasswordConfirm,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _fieldErrors = null;
    notifyListeners();

    try {
      final response = await ApiClient.post<Map<String, dynamic>>(
        ApiConstants.passwordResetConfirmEndpoint,
        body: {
          'phone_number': phoneNumber.trim(),
          'code': code.trim(),
          'new_password': newPassword,
          'confirm_password': newPasswordConfirm,
        },
        parser: (json) => json,
      );

      if (response.isSuccess) {
        // Don't auto-login, let user go back to login screen
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response.message;
        _fieldErrors = response.errors;
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Password reset failed: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      final refreshToken = await TokenManager.getRefreshToken();

      if (refreshToken != null) {
        // Attempt to logout on backend
        await ApiClient.postWithAuth<Map<String, dynamic>>(
          ApiConstants.logoutEndpoint,
          body: {'refresh': refreshToken},
          parser: (json) => json,
        );
      }
    } catch (e) {
      // Continue logout even if backend call fails
    }

    // Clear tokens locally. Never let a storage failure block the logout —
    // otherwise the user can get stuck unable to sign out.
    try {
      await TokenManager.clearAll();
    } catch (e) {
      // Storage may be flaky (e.g. secure storage platform errors); ignore
      // and still reset the in-memory auth state below.
    }

    _currentUser = null;
    _errorMessage = null;
    _fieldErrors = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Update the authenticated user's profile
  Future<bool> updateProfile(Map<String, dynamic> body) async {
    _isLoading = true;
    _errorMessage = null;
    _fieldErrors = null;
    notifyListeners();

    try {
      final response = await ApiClient.patchWithAuth<UserProfile>(
        ApiConstants.profileEndpoint,
        body: body,
        parser: (json) => UserProfile.fromJson(json),
      );

      if (response.isSuccess && response.data != null) {
        _currentUser = response.data;
        await TokenManager.saveUserData(_currentUser!);
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _errorMessage = response.message;
      _fieldErrors = response.errors;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Profile update failed: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Update profile with picture upload (multipart/form-data)
  Future<bool> updateProfileWithPicture({
    required Map<String, String> fields,
    required Uint8List pictureBytes,
    required String pictureFilename,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _fieldErrors = null;
    notifyListeners();

    try {
      final response = await ApiClient.patchWithFileAuth<UserProfile>(
        ApiConstants.profileEndpoint,
        fields: fields,
        fileFieldName: 'profile_picture',
        fileBytes: pictureBytes,
        fileFilename: pictureFilename,
        parser: (json) => UserProfile.fromJson(json),
      );

      if (response.isSuccess && response.data != null) {
        _currentUser = response.data;
        await TokenManager.saveUserData(_currentUser!);
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _errorMessage = response.message;
      _fieldErrors = response.errors;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Profile update with picture failed: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Register with optional profile picture
  Future<bool> registerWithPicture({
    required String username,
    required String email,
    required String phoneNumber,
    String? whatsappNumber,
    required String password,
    required String passwordConfirm,
    required String firstName,
    required String lastName,
    required String role,
    String gender = 'unspecified',
    String? dateOfBirth,
    String? address,
    String? bloodGroup,
    String? emergencyContactName,
    String? emergencyContactPhone,
    Uint8List? profilePictureBytes,
    String? profilePictureFilename,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _fieldErrors = null;
    notifyListeners();

    try {
      final fields = <String, String>{
        'username': username.trim(),
        'email': email.trim(),
        'phone_number': phoneNumber.trim(),
        'whatsapp_number': whatsappNumber?.trim() ?? '',
        'password': password,
        'password_confirm': passwordConfirm,
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'role': role,
        'gender': gender,
      };

      if (dateOfBirth != null) fields['date_of_birth'] = dateOfBirth;
      if (address != null) fields['address'] = address.trim();

      if (role == 'patient') {
        if (bloodGroup != null) fields['blood_group'] = bloodGroup;
        if (emergencyContactName != null) {
          fields['emergency_contact_name'] = emergencyContactName.trim();
        }
        if (emergencyContactPhone != null) {
          fields['emergency_contact_phone'] = emergencyContactPhone.trim();
        }
      }

      // If profile picture is provided, use multipart upload
      if (profilePictureBytes != null && profilePictureFilename != null) {
        final response = await ApiClient.postWithFile<Map<String, dynamic>>(
          ApiConstants.registerEndpoint,
          fields: fields,
          fileFieldName: 'profile_picture',
          fileBytes: profilePictureBytes,
          fileFilename: profilePictureFilename,
          parser: (json) => json,
        );

        if (response.isSuccess) {
          _isLoading = false;
          notifyListeners();
          return true;
        } else {
          _errorMessage = response.message;
          _fieldErrors = response.errors;
          _isLoading = false;
          notifyListeners();
          return false;
        }
      } else {
        // Fallback to JSON registration without file
        final body = fields.cast<String, dynamic>();
        final response = await ApiClient.post<Map<String, dynamic>>(
          ApiConstants.registerEndpoint,
          body: body,
          parser: (json) => json,
        );

        if (response.isSuccess) {
          _isLoading = false;
          notifyListeners();
          return true;
        } else {
          _errorMessage = response.message;
          _fieldErrors = response.errors;
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }
    } catch (e) {
      _errorMessage = 'System error, wait and log in after some minutes}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Clear error messages
  void clearError() {
    _errorMessage = null;
    _fieldErrors = null;
    notifyListeners();
  }

  /// Get user role
  String? get userRole => _currentUser?.role;

  /// Check if user is patient
  bool get isPatient => userRole == 'patient';

  /// Check if user is doctor
  bool get isDoctor => userRole == 'doctor';

  /// Check if user is admin
  bool get isAdmin => userRole == 'admin';
}

