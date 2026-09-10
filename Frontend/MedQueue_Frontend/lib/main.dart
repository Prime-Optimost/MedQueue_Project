import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'services/auth_service.dart';
import 'services/admin_service.dart';
import 'services/appointment_service.dart';
import 'services/doctor_service.dart';
import 'services/queue_service.dart';
import 'services/emergency_service.dart';
import 'services/chatbot_service.dart';
import 'services/notification_service.dart';
import 'services/availability_service.dart';
import 'utils/app_colors.dart';
import 'routes/app_routes.dart';
import 'screens/auth/startup_wrapper.dart';

void main() async {
  await dotenv.load();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => AdminService()),
        ChangeNotifierProvider(create: (_) => AppointmentService()),
        ChangeNotifierProvider(create: (_) => DoctorService()),
        ChangeNotifierProvider(create: (_) => QueueService()),
        ChangeNotifierProvider(create: (_) => EmergencyService()),
        ChangeNotifierProvider(create: (_) => ChatbotService()),
        ChangeNotifierProvider(create: (_) => NotificationService()),
        ChangeNotifierProvider(create: (_) => AvailabilityService()),
      ],
      child: MaterialApp(
        title: 'MedQueue GH',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const StartupWrapper(),
        routes: AppRoutes.getRoutes(),
      ),
    );
  }
}
