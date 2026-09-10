import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/appointment_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/bottom_navbar.dart';
import 'appointment_history_screen.dart';
import 'chatbot_screen.dart';
import 'home_content_screen.dart';
import 'patient_profile_screen.dart';

class PatientHomeScreen extends StatefulWidget {
  final int selectedIndex;

  const PatientHomeScreen({
    super.key,
    this.selectedIndex = 0,
  });

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  int _selectedIndex = 0; 

  @override
  void initState() {
    super.initState();
      _selectedIndex = widget.selectedIndex; // Set initial index from widget parameter
      // Fetch appointments on screen load
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final appointmentService = context.read<AppointmentService>();
        appointmentService.fetchAppointments();
      });
    // Fetch appointments on screen load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appointmentService = context.read<AppointmentService>();
      appointmentService.fetchAppointments();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: _getBody(),
      bottomNavigationBar: ModernBottomNavBar(
        selectedIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }

  Widget _getBody() {
    switch (_selectedIndex) {
      case 0:
        return HomeContentScreen(
          onViewAll: () {
            setState(() {
              _selectedIndex = 1;
            });
          },
        );
      case 1:
        return const AppointmentHistoryScreen();
      case 2:
        return const ChatbotScreen();
      case 3:
        return const PatientProfileScreen();
      default:
        return HomeContentScreen(
          onViewAll: () {
            setState(() {
              _selectedIndex = 1;
            });
          },
        );
    }
  }
}