import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/doctor_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/custom_components.dart';
import '../../widgets/doctor_card.dart';

class BookAppointmentScreen extends StatefulWidget {
  const BookAppointmentScreen({super.key});

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DoctorService>().fetchDoctors();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryBlue, AppColors.primaryGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Column(
          children: [
            const Text(
              'Book Appointment',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3),
            ),
           
          ],
        ),
       
      ),
      body: Consumer<DoctorService>(
        builder: (context, doctorService, _) {
          if (doctorService.isLoading && doctorService.doctors.isEmpty) {
            return const CustomLoadingIndicator(message: 'Loading doctors...');
          }

          if (doctorService.errorMessage != null && doctorService.doctors.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 80, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${doctorService.errorMessage}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => doctorService.fetchDoctors(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (doctorService.doctors.isEmpty) {
            return const EmptyState(
              icon: Icons.local_hospital,
              title: 'No Doctors Available',
              message: 'Please try again later',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: doctorService.doctors.length,
            itemBuilder: (context, index) {
              final doctor = doctorService.doctors[index];
              return DoctorCard(
                doctor: doctor,
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/patient/doctor-detail',
                    arguments: doctor.id,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
