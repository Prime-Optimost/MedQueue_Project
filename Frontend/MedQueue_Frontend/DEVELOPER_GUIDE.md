# Flutter Authentication Implementation - Developer Quick Reference

## Quick Start

### **Basic Login**
```dart
import 'package:provider/provider.dart';
import 'services/auth_service.dart';

// In your widget
Consumer<AuthService>(
  builder: (context, authService, _) {
    return ElevatedButton(
      onPressed: () async {
        final success = await authService.login(
          'username_or_email_or_phone',
          'password',
        );
        if (success) {
          // Navigate based on role
          if (authService.isPatient) {
            Navigator.pushNamed(context, '/patient-home');
          }
        } else {
          // Show error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(authService.errorMessage!)),
          );
        }
      },
      child: const Text('Login'),
    );
  },
)
```

### **Check Authentication Status**
```dart
final authService = Provider.of<AuthService>(context);

if (authService.isAuthenticated) {
  // User is logged in
  print('User: ${authService.currentUser?.fullName}');
  print('Role: ${authService.userRole}');
} else {
  // User not logged in
}
```

### **Make Authenticated API Calls**
```dart
import 'services/api_client.dart';

// Example: Get user profile
final response = await ApiClient.getWithAuth<UserProfile>(
  '/auth/profile/',
  parser: (json) => UserProfile.fromJson(json),
);

if (response.isSuccess) {
  print('User profile: ${response.data}');
} else {
  print('Error: ${response.message}');
  if (response.fieldErrors != null) {
    print('Field errors: ${response.fieldErrors}');
  }
}
```

### **Handle Errors Properly**
```dart
// Backend field-level errors
if (authService.fieldErrors != null) {
  // Display field-specific errors
  authService.fieldErrors!.forEach((field, errors) {
    print('$field: $errors');
  });
}

// Clear errors
authService.clearError();
```

---

## Common Patterns

### **Pattern: Authentication Guard**
```dart
class AuthGuard extends StatelessWidget {
  final Widget child;
  final String? requiredRole;

  const AuthGuard({
    required this.child,
    this.requiredRole,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        if (!authService.isAuthenticated) {
          return const LoginScreen();
        }
        
        if (requiredRole != null && authService.userRole != requiredRole) {
          return const Center(child: Text('Access Denied'));
        }
        
        return child;
      },
    );
  }
}

// Usage
AuthGuard(
  requiredRole: 'patient',
  child: PatientScreen(),
)
```

### **Pattern: Loading State**
```dart
Consumer<AuthService>(
  builder: (context, authService, _) {
    if (authService.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return MyContent();
  },
)
```

### **Pattern: Error Display**
```dart
if (authService.errorMessage != null) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(authService.errorMessage!),
      backgroundColor: Colors.red,
    ),
  );
}
```

---

## API Constants Reference

```dart
// Import constants
import 'utils/api_constants.dart';

// Access endpoints
ApiConstants.loginEndpoint          // '/auth/login/'
ApiConstants.registerEndpoint       // '/auth/register/'
ApiConstants.otpVerifyEndpoint      // '/auth/otp/verify/'
ApiConstants.logoutEndpoint         // '/auth/logout/'

// Access configuration
ApiConstants.baseUrl                // 'http://localhost:8000/api/v1'
ApiConstants.apiTimeout             // Duration(seconds: 30)
ApiConstants.minPasswordLength      // 8
ApiConstants.otpLength              // 6

// Use enums
UserRole.patient.value              // 'patient'
UserRole.doctor.value               // 'doctor'
OtpPurpose.phoneReg.value           // 'phone_reg'
OtpPurpose.passwordReset.value      // 'password_reset'
```

---

## Token Management

```dart
import 'utils/token_manager.dart';

// Get tokens
final accessToken = await TokenManager.getAccessToken();
final refreshToken = await TokenManager.getRefreshToken();

// Check authentication
final isAuth = await TokenManager.isAuthenticated();
final isExpired = await TokenManager.isAccessTokenExpired();

// Get user info from token
final claims = await TokenManager.getAccessTokenClaims();
print('User ID: ${claims?.userId}');
print('Role: ${claims?.role}');
print('Expires: ${DateTime.fromMillisecondsSinceEpoch(claims!.exp * 1000)}');

// Get cached user data
final user = await TokenManager.getCachedUserData();
final role = await TokenManager.getUserRole();

// Clear on logout
await TokenManager.clearAll();
```

---

## AuthService Methods Reference

### **Authentication**
```dart
// Login with any of: username, email, phone
await authService.login(login, password);

// Register new account
await authService.register(
  username: 'john_doe',
  email: 'john@example.com',
  phoneNumber: '+233201234567',
  password: 'SecurePass123!',
  passwordConfirm: 'SecurePass123!',
  firstName: 'John',
  lastName: 'Doe',
  role: 'patient',  // or 'doctor'
  gender: 'male',   // optional
  dateOfBirth: '1990-05-15',  // optional
  address: '123 Main St',      // optional
  // Patient-specific
  bloodGroup: 'O+',            // optional
  emergencyContactName: 'Jane Doe',  // optional
  emergencyContactPhone: '+233209876543',  // optional
);

// Logout
await authService.logout();
```

### **OTP Flow**
```dart
// Send OTP
await authService.sendOTP(
  phoneNumber,
  OtpPurpose.phoneReg.value,  // or 'password_reset'
);

// Verify OTP
await authService.verifyOTP(
  phoneNumber: phoneNumber,
  code: '1234',
  purpose: OtpPurpose.phoneReg.value,
);
```

### **Password Reset**
```dart
// Request reset
await authService.requestPasswordReset(phoneOrEmail);

// Confirm reset
await authService.confirmPasswordReset(
  phoneNumber: phoneNumber,
  code: otpCode,
  newPassword: newPassword,
  newPasswordConfirm: newPassword,
);
```

### **State Access**
```dart
authService.currentUser           // UserProfile?
authService.isLoading             // bool
authService.errorMessage          // String?
authService.fieldErrors           // Map<String, dynamic>?
authService.isAuthenticated       // bool
authService.userRole              // String?
authService.isPatient             // bool
authService.isDoctor              // bool
authService.isAdmin               // bool
```

---

## Model Reference

### **UserProfile**
```dart
class UserProfile {
  int id;
  String username;
  String email;
  String role;                      // 'patient', 'doctor', 'admin'
  String firstName;
  String lastName;
  String fullName;
  String phoneNumber;
  String? dateOfBirth;
  String? gender;
  String? address;
  String? profilePictureUrl;
  bool isPhoneVerified;
  bool isEmailVerified;
  String? whatsappNumber;
  bool whatsappLinked;
  bool notifPush;
  bool notifSms;
  bool notifWhatsapp;
  PatientProfile? patientProfile;
  DoctorProfile? doctorProfile;
  DateTime createdAt;
}

// Usage
final user = authService.currentUser;
print('User: ${user?.fullName}');
print('Role: ${user?.role}');
if (user?.role == 'patient') {
  print('Blood: ${user?.patientProfile?.bloodGroup}');
}
```

### **TokenClaims** (from JWT)
```dart
class TokenClaims {
  int userId;
  String role;
  String fullName;
  int exp;                         // expiration timestamp
  int iat;                         // issued at timestamp
  String jti;                      // JWT ID
  
  bool get isExpired { ... }       // Check if expired
}

// Usage
final claims = await TokenManager.getAccessTokenClaims();
if (claims != null && !claims.isExpired) {
  print('Token valid until: ${DateTime.fromMillisecondsSinceEpoch(claims.exp * 1000)}');
}
```

---

## Error Handling Examples

### **Handle Field Errors**
```dart
if (authService.fieldErrors != null) {
  final emailError = authService.fieldErrors!['email'];
  if (emailError != null) {
    // Show error for email field
    print('Email: ${emailError.first}');
  }
}
```

### **Handle Account Lockout**
```dart
if (authService.errorMessage?.contains('locked') ?? false) {
  // Show lockout message with unlock time
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(authService.errorMessage!),
      duration: const Duration(seconds: 5),
    ),
  );
}
```

### **Handle Network Errors**
```dart
final response = await ApiClient.getWithAuth(
  endpoint,
  parser: parser,
);

if (!response.isSuccess) {
  if (response.errors?['network'] != null) {
    // Network error
    print('Network error - check connection');
  } else if (response.errors?['timeout'] != null) {
    // Timeout error
    print('Request timeout - please retry');
  } else {
    // Other error
    print('Error: ${response.message}');
  }
}
```

---

## Troubleshooting Checklist

### **User can't login**
- [ ] Verify backend is running at configured URL
- [ ] Check credentials are correct
- [ ] Look for field errors in response
- [ ] Check if account is locked (3 attempts)

### **OTP not being sent**
- [ ] Verify OTP service is configured on backend
- [ ] Check phone number format (E.164 recommended)
- [ ] Verify phone number is valid
- [ ] Check backend logs for OTP service errors

### **Tokens not persisting**
- [ ] Verify Flutter Secure Storage is working
- [ ] Check for app crashes during token save
- [ ] Verify token format is correct
- [ ] Check device secure storage permissions

### **Token refresh failing**
- [ ] Verify refresh token is being stored
- [ ] Check backend token refresh endpoint works
- [ ] Verify token expiry times in backend
- [ ] Check if refresh token is blacklisted

### **App crashes on auth**
- [ ] Run `flutter clean && flutter pub get`
- [ ] Check Flutter version compatibility
- [ ] Review error logs in VS Code console
- [ ] Verify all imports are correct

---

## Best Practices

### ✅ DO
```dart
// Store sensitive data in TokenManager
await TokenManager.saveTokens(access, refresh);

// Use Consumer for reactive updates
Consumer<AuthService>(
  builder: (context, authService, _) { ... }
)

// Clear errors after displaying
authService.clearError();

// Check role-based access
if (authService.isPatient) { ... }
```

### ❌ DON'T
```dart
// Don't store tokens in SharedPreferences
SharedPreferences.getInstance().setString('token', token);

// Don't ignore errors
if (success) { } // No else handling

// Don't make API calls without checking auth
ApiClient.postWithAuth(...) // Will fail if not authenticated

// Don't show raw error messages
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text(response.errors.toString()))
);
```

---

## Integration with Existing Services

### **Combining with AppointmentService**
```dart
Future<void> bookAppointment(Appointment appointment) async {
  // Verify user is authenticated
  final authService = Provider.of<AuthService>(context, listen: false);
  if (!authService.isAuthenticated) {
    Navigator.pushNamed(context, AppRoutes.login);
    return;
  }

  // Make authenticated appointment request
  final appointmentService = Provider.of<AppointmentService>(context, listen: false);
  await appointmentService.bookAppointment(appointment);
}
```

---

**For full documentation, see [REFACTORING_SUMMARY.md](REFACTORING_SUMMARY.md)**
