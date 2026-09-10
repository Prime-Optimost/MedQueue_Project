import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import 'splash_screen.dart';
import 'login_screen.dart';
import '../patient/patient_home_screen.dart';
import '../doctor/doctor_home_screen.dart';
import '../admin/admin_home_screen.dart';

/// StartupWrapper - Auth Guard that handles navigation based on auth state
/// Shows SplashScreen during initial auth check, then navigates to appropriate screen
class StartupWrapper extends StatefulWidget {
  const StartupWrapper({super.key});

  @override
  State<StartupWrapper> createState() => _StartupWrapperState();
}

class _StartupWrapperState extends State<StartupWrapper> {
  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  void _initializeAuth() async {
    // Get the auth service and initialize it (check for cached user)
    final authService = context.read<AuthService>();
    await authService.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        final notificationService = context.read<NotificationService>();

        if (!authService.isInitialized) {
          return SplashScreen();
        }

        // User is authenticated - show appropriate home screen based on role
        // and start loading/polling in-app notifications.
        if (authService.isAuthenticated) {
          notificationService.setAuthenticated(true);
          notificationService.startPolling();

          if (authService.isDoctor) {
            return DoctorHomeScreen();
          } else if (authService.isAdmin) {
            return AdminHomeScreen();
          } else {
            // Default to patient
            return PatientHomeScreen();
          }
        }

        // User is not authenticated - clear notification state
        notificationService.clearState();

        // User is not authenticated - show login screen
        return LoginScreen();
      },
    );
  }
}
