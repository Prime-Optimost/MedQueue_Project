# MedQueue Frontend - Authentication Implementation Guide

**Last Updated:** May 13, 2026  
**Backend API Base URL:** `http://localhost:8000/api/v1/`  
**Focus:** Authentication Service Implementation

---

## Table of Contents

1. [Authentication Overview](#authentication-overview)
2. [JWT Token Management](#jwt-token-management)
3. [API Response Format](#api-response-format)
4. [Error Handling](#error-handling)
5. [Authentication Endpoints](#authentication-endpoints)
6. [Implementation Flow](#implementation-flow)
7. [Code Examples](#code-examples)
8. [Security Considerations](#security-considerations)

---

## Authentication Overview

MedQueue uses **JWT (JSON Web Token) authentication** via `djangorestframework-simplejwt`. The authentication system supports three user roles:

- **Patient** - Regular healthcare users
- **Doctor** - Healthcare professionals
- **Admin** - System administrators

### Key Features

- OTP-based phone verification for registration
- Account lockout after 3 failed login attempts (15-minute lockout)
- JWT token pair system (access + refresh tokens)
- Phone/email-based password reset
- Role-based response data (patient/doctor specific profiles)

---

## JWT Token Management

### Token Pair System

The backend returns a **token pair** on successful login or registration:

```json
{
  "access": "eyJ0eXAiOiJKV1QiLCJhbGc...",  // Short-lived, ~5 minutes
  "refresh": "eyJ0eXAiOiJKV1QiLCJhbGc..."   // Long-lived, used to get new access tokens
}
```

### Token Payload

Both tokens contain:

```
{
  "user_id": 1,
  "role": "patient",           // Used for client-side routing
  "full_name": "John Doe",     // Used for UI display
  "exp": 1715601234,           // Expiration timestamp
  "iat": 1715601000,           // Issued at timestamp
  "jti": "..."                 // JWT ID (used for token blacklisting on logout)
}
```

### Token Storage (Flutter)

Store tokens securely using Flutter's **flutter_secure_storage**:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenManager {
  static const _storage = FlutterSecureStorage();

  static Future<void> saveTokens(String access, String refresh) async {
    await _storage.write(key: 'access_token', value: access);
    await _storage.write(key: 'refresh_token', value: refresh);
  }

  static Future<String?> getAccessToken() async {
    return await _storage.read(key: 'access_token');
  }

  static Future<String?> getRefreshToken() async {
    return await _storage.read(key: 'refresh_token');
  }

  static Future<void> clearTokens() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }
}
```

### Token Lifecycle

1. **On Login/Registration:**
   - Backend returns `access` + `refresh` tokens
   - Frontend stores both securely
   - Use `access` token for all API requests

2. **On Access Token Expiry (~5 minutes):**
   - Intercept 401 Unauthorized responses
   - Use `refresh` token to request a new access token
   - Retry original request with new token

3. **On Logout:**
   - Send `refresh` token to `/auth/logout/`
   - Backend blacklists the token
   - Frontend clears stored tokens
   - Redirect to login screen

---

## API Response Format

All endpoints return a **standardized envelope** format:

```json
{
  "status": "success" | "error",
  "message": "Human-readable message",
  "data": { /* response data or null */ },
  "errors": { /* field-level errors or null */ }
}
```

### Success Response Example

```json
{
  "status": "success",
  "message": "Login successful.",
  "data": {
    "tokens": {
      "access": "eyJ0eXAiOiJKV1QiLCJhbGc...",
      "refresh": "eyJ0eXAiOiJKV1QiLCJhbGc..."
    },
    "user": {
      "id": 1,
      "username": "john_doe",
      "email": "john@example.com",
      "role": "patient",
      "first_name": "John",
      "last_name": "Doe",
      "full_name": "John Doe",
      "phone_number": "+233201234567",
      "date_of_birth": "1990-05-15",
      "gender": "male",
      "address": "123 Main St, Accra",
      "profile_picture_url": "",
      "is_phone_verified": true,
      "is_email_verified": false,
      "whatsapp_number": "",
      "whatsapp_linked": false,
      "notif_push": true,
      "notif_sms": true,
      "notif_whatsapp": false,
      "patient_profile": {
        "blood_group": "O+",
        "allergies": "Penicillin",
        "emergency_contact_name": "Jane Doe",
        "emergency_contact_phone": "+233209876543",
        "medical_history": ""
      },
      "doctor_profile": null,
      "created_at": "2026-05-01T10:30:00Z"
    }
  },
  "errors": null
}
```

### Error Response Example

```json
{
  "status": "error",
  "message": "Login failed.",
  "data": null,
  "errors": {
    "password": "Incorrect password. 2 attempt(s) remaining before lockout."
  }
}
```

---

## Error Handling

### HTTP Status Codes

| Status | Meaning | Action |
| --- | --- | --- |
| 200 | Success | Proceed normally |
| 201 | Created (Registration) | Proceed to OTP verification |
| 400 | Bad Request | Display field errors to user |
| 401 | Unauthorized | Refresh token or redirect to login |
| 403 | Forbidden | Show permission error |
| 404 | Not Found | Handle gracefully |
| 429 | Too Many Requests | Implement rate limit backoff |
| 500 | Server Error | Show generic error, retry later |

### Common Error Scenarios

#### Invalid Credentials

```json
{
  "status": "error",
  "message": "Login failed.",
  "errors": {
    "password": "Incorrect password. 2 attempt(s) remaining before lockout."
  }
}
```

**Frontend Action:** Display password error and show remaining attempts.

#### Account Locked

```json
{
  "status": "error",
  "message": "Login failed.",
  "errors": {
    "non_field_errors": "Account locked after too many failed attempts. Try again after 14:30."
  }
}
```

**Frontend Action:** Parse unlock time from message and display countdown or disable login.

#### Validation Error (Registration)

```json
{
  "status": "error",
  "message": "Registration failed. Please fix the errors below.",
  "errors": {
    "email": ["An account with this email already exists."],
    "password_confirm": ["Passwords do not match."]
  }
}
```

**Frontend Action:** Display field-specific errors near form fields.

#### Invalid/Expired OTP

```json
{
  "status": "error",
  "message": "OTP verification failed.",
  "errors": {
    "code": "OTP has expired. Please request a new one."
  }
}
```

**Frontend Action:** Show error and provide "Resend OTP" button.

---

## Authentication Endpoints

### 1. POST /auth/register/

**Purpose:** Create a new user account

**Request:**

```json
{
  "username": "john_doe",
  "email": "john@example.com",
  "phone_number": "+233201234567",
  "password": "SecurePassword123!",
  "password_confirm": "SecurePassword123!",
  "first_name": "John",
  "last_name": "Doe",
  "role": "patient",
  "gender": "male",
  "date_of_birth": "1990-05-15",
  "address": "123 Main St, Accra",
  "blood_group": "O+",
  "emergency_contact_name": "Jane Doe",
  "emergency_contact_phone": "+233209876543"
}
```

**Required Fields:**

- `username` - Max 150 chars, unique, alphanumeric + underscore
- `email` - Valid email, unique
- `phone_number` - Max 20 chars, unique, E.164 format recommended: +233...
- `password` - Min 8 chars, not all numeric, not common
- `password_confirm` - Must match password
- `first_name` - Max 150 chars
- `last_name` - Max 150 chars
- `role` - `patient` | `doctor` | `admin`

**Optional Fields:**

- `gender` - `male` | `female` | `other` | `unspecified` (default)
- `date_of_birth` - ISO 8601 format
- `address` - Text
- `blood_group` - Patient only
- `emergency_contact_name` - Patient only
- `emergency_contact_phone` - Patient only
- `specialization` - Doctor only
- `medical_license_number` - Doctor only
- `hospital_name` - Doctor only
- `consultation_fee` - Doctor only

**Response:** `201 Created`

**Next Step:** Call `/auth/otp/verify/` to verify phone number.

---

### 2. POST /auth/otp/send/

**Purpose:** Send or resend a 4-digit OTP

**Request:**

```json
{
  "phone_number": "+233201234567",
  "purpose": "phone_reg"
}
```

**Fields:**

- `phone_number` (required) - Phone number associated with account
- `purpose` (optional):
  - `phone_reg` - Phone registration verification
  - `password_reset` - Password reset OTP
  - Default: `phone_reg`

**Response:** `200 OK`

```json
{
  "status": "success",
  "message": "OTP sent to +233201234567. Valid for 5 minutes.",
  "data": null,
  "errors": null
}
```

---

### 3. POST /auth/otp/verify/

**Purpose:** Verify OTP and complete associated action

**Request:**

```json
{
  "phone_number": "+233201234567",
  "code": "1234",
  "purpose": "phone_reg"
}
```

**Fields:**

- `phone_number` (required) - Phone that received OTP
- `code` (required) - 4-digit OTP code
- `purpose` (optional) - Must match OTP purpose. Default: `phone_reg`

**Response:** `200 OK`

Returns user object + tokens on successful registration OTP verification.

---

### 4. POST /auth/login/

**Purpose:** Authenticate user and get JWT tokens

**Request:**

```json
{
  "login": "john_doe",
  "password": "SecurePassword123!"
}
```

**Fields:**

- `login` (required) - Username, email, or phone number
- `password` (required) - Account password

**Response:** `200 OK`

Returns user object + tokens.

**Account Lockout:** After 3 failed attempts, account is locked for 15 minutes.

---

### 5. POST /auth/logout/

**Purpose:** Blacklist refresh token and log out user

**Authentication:** Required (Bearer token)

**Request:**

```json
{
  "refresh": "eyJ0eXAiOiJKV1QiLCJhbGc..."
}
```

**Response:** `200 OK`

After logout:
- Refresh token cannot be reused
- Access token remains valid until expiry (~5 minutes)
- User must log in again

---

### 6. POST /auth/token/refresh/

**Purpose:** Get a new access token using refresh token

**Request:**

```json
{
  "refresh": "eyJ0eXAiOiJKV1QiLCJhbGc..."
}
```

**Response:** `200 OK`

```json
{
  "status": "success",
  "message": "Token refreshed.",
  "data": {
    "access": "eyJ0eXAiOiJKV1QiLCJhbGc...",
    "refresh": "eyJ0eXAiOiJKV1QiLCJhbGc..."
  },
  "errors": null
}
```

---

### 7. POST /auth/password/reset/request/

**Purpose:** Initiate password reset

**Request:**

```json
{
  "phone_number": "+233201234567"
}
```

OR

```json
{
  "email": "john@example.com"
}
```

**Response:** `200 OK` (always vague for security)

```json
{
  "status": "success",
  "message": "If an account exists with the provided details, a reset code has been sent.",
  "data": null,
  "errors": null
}
```

**Next Step:** User receives OTP, then calls `/auth/password/reset/confirm/`.

---

### 8. POST /auth/password/reset/confirm/

**Purpose:** Complete password reset with OTP and new password

**Request:**

```json
{
  "phone_number": "+233201234567",
  "code": "1234",
  "new_password": "NewSecurePassword123!",
  "confirm_password": "NewSecurePassword123!"
}
```

**Response:** `200 OK`

Returns new JWT token pair.

---

### 9. GET /auth/profile/

**Purpose:** Get current authenticated user's profile

**Authentication:** Required (Bearer token)

**Response:** `200 OK`

Returns user object with role-specific profile data.

---

## Implementation Flow

### Registration Flow

```
1. User enters: username, email, phone, password, role, optional fields
   ↓
2. Validate inputs on frontend
   ↓
3. POST /auth/register/
   ├─ Success → Show "Verify Phone" screen
   ├─ Error → Display field errors
   └─ Validation Error → Show specific errors
   ↓
4. Display OTP input form
   ↓
5. User enters 4-digit OTP
   ↓
6. POST /auth/otp/verify/ with phone_number, code, purpose="phone_reg"
   ├─ Success → Save tokens → Navigate to dashboard
   ├─ Invalid OTP → Show error
   ├─ Expired OTP → Show "Resend OTP" button
   └─ Error → Show error message
   ↓
7. User is logged in and can access app
```

### Login Flow

```
1. User enters: login (username/email/phone) + password
   ↓
2. POST /auth/login/
   ├─ Success (200) → Save tokens → Navigate to dashboard
   ├─ Invalid Credentials (401) → Show error
   │  └─ If attempt < 3 → Show remaining attempts
   │  └─ If attempt >= 3 → Show lockout time
   ├─ Validation Error (400) → Show field errors
   └─ Server Error (500) → Show "Try again later"
   ↓
3. User is logged in and can access app
```

### Token Refresh Flow

```
1. Frontend makes API request with access token
   ↓
2. Backend responds with 401 Unauthorized
   ↓
3. Frontend detects 401:
   ├─ Check if refresh token exists
   ├─ POST /auth/token/refresh/ with refresh token
   │  ├─ Success → Get new access token
   │  ├─ Invalid/Expired refresh → User logged out
   │  └─ Error → Show error, redirect to login
   ├─ Retry original request with new access token
   └─ On success → Continue normally
   ↓
4. If refresh fails → Redirect to login screen
```

### Logout Flow

```
1. User taps logout
   ↓
2. POST /auth/logout/ with refresh token
   ├─ Success → Clear tokens locally
   ├─ Fail → Clear tokens anyway (for user experience)
   └─ (Refresh token is now blacklisted server-side)
   ↓
3. Redirect to login screen
```

### Password Reset Flow

```
1. User taps "Forgot Password"
   ↓
2. User enters: phone_number OR email
   ↓
3. POST /auth/password/reset/request/
   ├─ Response always same (security)
   └─ Show "Check for OTP"
   ↓
4. User receives OTP (if account exists)
   ↓
5. Show OTP + New Password Form
   ↓
6. POST /auth/password/reset/confirm/
   ├─ Success → Show "Password updated, login again"
   ├─ Invalid OTP → Show error
   ├─ Expired OTP → Show "Resend OTP" button
   └─ Weak Password → Show password requirements
   ↓
7. Redirect to login screen
```

---

## Code Examples

### Flutter HTTP Client with Token Handling

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  static const String baseUrl = 'http://localhost:8000/api/v1';
  static const storage = FlutterSecureStorage();

  // Make authenticated request with automatic token refresh
  static Future<http.Response> getWithAuth(String endpoint) async {
    var accessToken = await storage.read(key: 'access_token');

    if (accessToken == null) {
      throw Exception('Not authenticated');
    }

    var response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );

    // If token expired, refresh and retry
    if (response.statusCode == 401) {
      var refreshToken = await storage.read(key: 'refresh_token');
      if (refreshToken != null) {
        await _refreshToken(refreshToken);
        accessToken = await storage.read(key: 'access_token');
        
        response = await http.get(
          Uri.parse('$baseUrl$endpoint'),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        );
      }
    }

    return response;
  }

  // POST request with authentication
  static Future<http.Response> postWithAuth(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    var accessToken = await storage.read(key: 'access_token');

    if (accessToken == null) {
      throw Exception('Not authenticated');
    }

    var response = await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    return response;
  }

  // Refresh access token
  static Future<void> _refreshToken(String refreshToken) async {
    var response = await http.post(
      Uri.parse('$baseUrl/auth/token/refresh/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh': refreshToken}),
    );

    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      await storage.write(
        key: 'access_token',
        value: data['data']['access'],
      );
      await storage.write(
        key: 'refresh_token',
        value: data['data']['refresh'],
      );
    } else {
      // Refresh failed, clear tokens and redirect to login
      await storage.delete(key: 'access_token');
      await storage.delete(key: 'refresh_token');
      throw Exception('Session expired. Please log in again.');
    }
  }
}
```

### Registration Implementation

```dart
class RegistrationService {
  static Future<bool> registerUser({
    required String username,
    required String email,
    required String phoneNumber,
    required String password,
    required String passwordConfirm,
    required String firstName,
    required String lastName,
    required String role, // 'patient' or 'doctor'
    String gender = 'unspecified',
    String? dateOfBirth,
    String? address,
  }) async {
    try {
      var response = await http.post(
        Uri.parse('${ApiClient.baseUrl}/auth/register/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'phone_number': phoneNumber,
          'password': password,
          'password_confirm': passwordConfirm,
          'first_name': firstName,
          'last_name': lastName,
          'role': role,
          'gender': gender,
          'date_of_birth': dateOfBirth,
          'address': address,
        }),
      );

      if (response.statusCode == 201) {
        // Success - show OTP verification screen
        return true;
      } else {
        var errorData = jsonDecode(response.body);
        // Handle errors from errorData['errors']
        throw Exception(errorData['message']);
      }
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }
}
```

### OTP Verification Implementation

```dart
class OTPService {
  static Future<bool> verifyOTP({
    required String phoneNumber,
    required String code,
    required String purpose, // 'phone_reg' or 'password_reset'
  }) async {
    try {
      var response = await http.post(
        Uri.parse('${ApiClient.baseUrl}/auth/otp/verify/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone_number': phoneNumber,
          'code': code,
          'purpose': purpose,
        }),
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        var tokens = data['data']['tokens'];
        var user = data['data']['user'];

        // Save tokens
        await ApiClient.storage.write(
          key: 'access_token',
          value: tokens['access'],
        );
        await ApiClient.storage.write(
          key: 'refresh_token',
          value: tokens['refresh'],
        );

        // Save user data (optional, for quick access)
        await ApiClient.storage.write(
          key: 'user_data',
          value: jsonEncode(user),
        );

        return true;
      } else {
        var errorData = jsonDecode(response.body);
        throw Exception(errorData['errors']['code'] ?? errorData['message']);
      }
    } catch (e) {
      throw Exception('OTP verification failed: $e');
    }
  }

  static Future<void> resendOTP({
    required String phoneNumber,
    required String purpose, // 'phone_reg' or 'password_reset'
  }) async {
    try {
      var response = await http.post(
        Uri.parse('${ApiClient.baseUrl}/auth/otp/send/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone_number': phoneNumber,
          'purpose': purpose,
        }),
      );

      if (response.statusCode != 200) {
        var errorData = jsonDecode(response.body);
        throw Exception(errorData['message']);
      }
    } catch (e) {
      throw Exception('Failed to resend OTP: $e');
    }
  }
}
```

### Login Implementation

```dart
class LoginService {
  static Future<Map<String, dynamic>> loginUser({
    required String login, // username, email, or phone
    required String password,
  }) async {
    try {
      var response = await http.post(
        Uri.parse('${ApiClient.baseUrl}/auth/login/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'login': login,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        var tokens = data['data']['tokens'];
        var user = data['data']['user'];

        // Save tokens
        await ApiClient.storage.write(
          key: 'access_token',
          value: tokens['access'],
        );
        await ApiClient.storage.write(
          key: 'refresh_token',
          value: tokens['refresh'],
        );

        // Save user data
        await ApiClient.storage.write(
          key: 'user_data',
          value: jsonEncode(user),
        );

        return {
          'success': true,
          'user': user,
          'role': user['role'],
        };
      } else if (response.statusCode == 401) {
        var errorData = jsonDecode(response.body);
        var errors = errorData['errors'];

        // Check if account is locked
        if (errors.containsKey('non_field_errors')) {
          throw Exception(errors['non_field_errors']);
        }

        // Show remaining attempts
        if (errors.containsKey('password')) {
          throw Exception(errors['password']);
        }

        throw Exception('Invalid credentials');
      } else {
        var errorData = jsonDecode(response.body);
        throw Exception(errorData['message']);
      }
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }
}
```

### Logout Implementation

```dart
class LogoutService {
  static Future<void> logout() async {
    try {
      var refreshToken = await ApiClient.storage.read(key: 'refresh_token');

      if (refreshToken != null) {
        var response = await http.post(
          Uri.parse('${ApiClient.baseUrl}/auth/logout/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refresh': refreshToken}),
        );

        // Whether it succeeds or fails, clear tokens locally
        if (response.statusCode == 200 || response.statusCode == 401) {
          await _clearAllData();
        }
      } else {
        // No refresh token, just clear local data
        await _clearAllData();
      }
    } catch (e) {
      // On error, clear local data anyway for better UX
      await _clearAllData();
    }
  }

  static Future<void> _clearAllData() async {
    await ApiClient.storage.delete(key: 'access_token');
    await ApiClient.storage.delete(key: 'refresh_token');
    await ApiClient.storage.delete(key: 'user_data');
  }
}
```

---

## Security Considerations

### 1. Token Storage

- ✅ Use **flutter_secure_storage** for tokens (encrypted storage)
- ❌ Do NOT store tokens in SharedPreferences or plain text
- ❌ Do NOT log tokens or print to console

### 2. HTTPS Only

- ✅ Use HTTPS in production (http://localhost:8000 only for development)
- ✅ Enable certificate pinning for extra security
- ❌ Do NOT send tokens over plain HTTP

### 3. Token Transmission

- ✅ Always include token in `Authorization: Bearer <token>` header
- ✅ Use POST for sensitive requests (password, OTP)
- ❌ Do NOT pass tokens in query parameters
- ❌ Do NOT pass tokens in request body

### 4. Password Handling

- ✅ Validate password strength on frontend (min 8 chars, not all numeric)
- ✅ Use `input_type: password` in forms
- ✅ Clear password from memory after sending
- ❌ Do NOT store passwords locally
- ❌ Do NOT log password values

### 5. OTP Handling

- ✅ Auto-clear OTP after submission
- ✅ Show expiry timer (5 minutes)
- ✅ Provide "Resend OTP" button
- ❌ Do NOT send OTP in unencrypted emails/logs
- ❌ Do NOT allow unlimited OTP verification attempts

### 6. Session Management

- ✅ Clear tokens on logout
- ✅ Clear tokens on app uninstall
- ✅ Handle token refresh automatically
- ✅ Show "Session expired" on refresh failure
- ❌ Do NOT persist tokens to disk permanently
- ❌ Do NOT allow old tokens after logout

### 7. Error Handling

- ✅ Show generic error messages to users
- ✅ Log detailed errors server-side
- ✅ Handle account lockout gracefully
- ❌ Do NOT expose internal error details to user
- ❌ Do NOT reveal if email/phone exists (user enumeration)

### 8. Rate Limiting

The backend enforces rate limiting:
- Registration: Limited to prevent spam
- OTP: Limited to prevent brute force
- Login: Locked after 3 failed attempts for 15 minutes

Frontend should:
- ✅ Disable buttons during requests
- ✅ Show cooldown timers
- ✅ Show account lockout warnings

---

## Testing the API Locally

### 1. Start Backend Server

```bash
cd medqueue_backend
python manage.py runserver
```

### 2. Test Registration (Postman/curl)

```bash
curl -X POST http://localhost:8000/api/v1/auth/register/ \
  -H "Content-Type: application/json" \
  -d '{
    "username": "john_doe",
    "email": "john@example.com",
    "phone_number": "+233201234567",
    "password": "SecurePassword123!",
    "password_confirm": "SecurePassword123!",
    "first_name": "John",
    "last_name": "Doe",
    "role": "patient"
  }'
```

### 3. Verify OTP (Check console/logs for OTP code)

```bash
curl -X POST http://localhost:8000/api/v1/auth/otp/verify/ \
  -H "Content-Type: application/json" \
  -d '{
    "phone_number": "+233201234567",
    "code": "123456",
    "purpose": "phone_reg"
  }'
```

### 4. Login

```bash
curl -X POST http://localhost:8000/api/v1/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{
    "login": "john_doe",
    "password": "SecurePassword123!"
  }'
```

### 5. Get Profile (with token)

```bash
curl -X GET http://localhost:8000/api/v1/auth/profile/ \
  -H "Authorization: Bearer <access_token>"
```

---

## Next Steps

1. **Implement authentication service** in your Flutter app using the code examples
2. **Test locally** with Postman/curl using the examples above
3. **Handle errors gracefully** - display user-friendly messages
4. **Store tokens securely** - use flutter_secure_storage
5. **Implement token refresh** - intercept 401 responses
6. **Test all flows** - registration, OTP, login, logout, password reset
7. **Monitor backend logs** - check for any issues or rate limiting

---

## Support & Debugging

If you encounter issues:

1. **Check backend logs** - `python manage.py runserver` output
2. **Use Postman** - Test endpoints independently
3. **Enable Flutter debug logging** - Print responses
4. **Verify phone format** - Use E.164 format: +233...
5. **Check token expiry** - Tokens expire after ~5 minutes
6. **Verify network connectivity** - Base URL is correct

---

**Last Updated:** May 13, 2026  
**Backend Version:** Django REST Framework with djangorestframework-simplejwt  
**Frontend Target:** Flutter (Dart)
