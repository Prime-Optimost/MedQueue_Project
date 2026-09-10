import 'package:flutter/material.dart';
import 'package:medqueue_frontend/screens/patient/appointment_detail_screen.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/auth/onboarding_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/role_selection_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/patient/patient_home_screen.dart';
import '../screens/patient/book_appointment_screen.dart';
import '../screens/patient/queue_tracker_screen.dart';
import '../screens/patient/chatbot_screen.dart';
import '../screens/patient/emergency_sos_screen.dart';
import '../screens/patient/notifications_screen.dart';
import '../screens/patient/doctors_browse_screen.dart';
import '../screens/patient/doctor_detail_screen.dart';
import '../screens/patient/appointment_booking_confirm_screen.dart';
import '../screens/patient/appointment_history_screen.dart';
import '../screens/doctor/doctor_home_screen.dart';
import '../screens/doctor/doctor_availability_screen.dart';
import '../screens/admin/admin_home_screen.dart';

class AppRoutes {
  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String roleSelection = '/role-selection';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  
  // Patient Routes
  static const String patientHome = '/patient-home';
  static const String bookAppointment = '/book-appointment';
  static const String queueTracker = '/queue-tracker';
  static const String patientChatbot = '/patient-chatbot';
  static const String emergencySos = '/emergency-sos';
  static const String patientNotifications = '/patient-notifications';
  
  // Appointment Routes (Patient - Phase 1)
  static const String doctorsBrowse = '/patient/doctors';
  static const String doctorDetail = '/patient/doctor-detail';
  static const String appointmentBookingConfirm = '/patient/appointment-booking-confirm';
  static const String appointmentsHistory = '/patient/appointments-history';
  static const String appointmentDetail = '/patient/appointment-detail';
  
  // Doctor Routes
  static const String doctorHome = '/doctor-home';
  static const String doctorQueueDashboard = '/doctor/queue-dashboard';
  static const String doctorAvailability = '/doctor/availability';
  
  // Admin Routes
  static const String adminHome = '/admin-home';

  static Map<String, WidgetBuilder> getRoutes() {
    return {
      splash: (context) => const SplashScreen(),
      onboarding: (context) => const OnboardingScreen(),
      roleSelection: (context) => const RoleSelectionScreen(),
      login: (context) => const LoginScreen(),
      register: (context) {
        final arguments = ModalRoute.of(context)?.settings.arguments;
        String? role;
        if (arguments is String) {
          role = arguments;
        } else if (arguments is Map<String, dynamic>) {
          role = arguments['role'] as String?;
        }
        return RegisterScreen(role: role);
      },
      forgotPassword: (context) => const ForgotPasswordScreen(),
      patientHome: (context) => const PatientHomeScreen(),
      bookAppointment: (context) => const BookAppointmentScreen(),
      queueTracker: (context) {
        final arguments = ModalRoute.of(context)?.settings.arguments;
        DateTime? initialDate;

        if (arguments is DateTime) {
          initialDate = arguments;
        } else if (arguments is Map<String, dynamic>) {
          final value = arguments['date'];
          if (value is DateTime) {
            initialDate = value;
          }
        }

        return QueueTrackerScreen(initialDate: initialDate);
      },
      patientChatbot: (context) => const ChatbotScreen(),
      emergencySos: (context) => const EmergencySosScreen(),
      patientNotifications: (context) => const NotificationsScreen(),
      
      // Appointment routes (Patient - Phase 1)
      doctorsBrowse: (context) => const DoctorsBrowseScreen(),
      doctorDetail: (context) => const DoctorDetailScreen(),
      appointmentBookingConfirm: (context) => const AppointmentBookingConfirmScreen(),
      appointmentsHistory: (context) => const AppointmentHistoryScreen(),
      appointmentDetail: (context) => const AppointmentDetailScreen(),
      
      // Doctor routes
      doctorHome: (context) => const DoctorHomeScreen(),
      // Note: doctorQueueDashboard now maps to DoctorHomeScreen with Queue tab selected
      // The queue management is now integrated into the main DoctorHomeScreen
      doctorQueueDashboard: (context) => const DoctorHomeScreen(),
      doctorAvailability: (context) => const DoctorAvailabilityScreen(),
      
      // Admin routes
      adminHome: (context) => const AdminHomeScreen(),
    };
  }
}
