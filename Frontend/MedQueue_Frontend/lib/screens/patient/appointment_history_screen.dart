import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/appointment_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/custom_components.dart';
import '../../widgets/appointment_card.dart';

class AppointmentHistoryScreen extends StatefulWidget {
  const AppointmentHistoryScreen({super.key});

  @override
  State<AppointmentHistoryScreen> createState() =>
      _AppointmentHistoryScreenState();
}

class _AppointmentHistoryScreenState extends State<AppointmentHistoryScreen> {
  String _selectedStatus = 'all';

  @override
  void initState() {
    super.initState();
    // Fetch appointments on screen load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAppointments();
    });
  }

  void _fetchAppointments({String? status}) {
    final appointmentService = context.read<AppointmentService>();
    appointmentService.fetchAppointments(
      status: status,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              'My Appointments',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3),
            ),
           
          ],
        ),
       
      ),
      body: Consumer<AppointmentService>(
        builder: (context, appointmentService, _) {
          if (appointmentService.isLoading &&
              appointmentService.appointments.isEmpty) {
            return const CustomLoadingIndicator(
              message: 'Loading appointments...',
            );
          }

          if (appointmentService.errorMessage != null &&
              appointmentService.appointments.isEmpty) {
            return _buildErrorWidget(context, appointmentService);
          }

          // Filter appointments by selected status
          final filteredAppointments = _selectedStatus == 'all'
              ? appointmentService.appointments
              : appointmentService.getAppointmentsByStatus(_selectedStatus);

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status filter tabs
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildStatusChip('all', 'All'),
                        _buildStatusChip('pending', 'Pending'),
                        _buildStatusChip('confirmed', 'Confirmed'),
                        _buildStatusChip('completed', 'Completed'),
                        _buildStatusChip('cancelled', 'Cancelled'),
                        _buildStatusChip('no_show', 'No Show'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Appointments list
                if (filteredAppointments.isEmpty)
                  _buildEmptyState()
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredAppointments.length,
                    itemBuilder: (context, index) {
                      final appointment = filteredAppointments[index];
                      return AppointmentCard(
                        appointment: appointment,
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/patient/appointment-detail',
                            arguments: appointment.id,
                          );
                        },
                      );
                    },
                  ),
                if (appointmentService.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: CustomLoadingIndicator(
                      message: 'Refreshing...',
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusChip(String value, String label) {
    final isSelected = _selectedStatus == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedStatus = selected ? value : 'all';
          });
          _fetchAppointments(
            status: _selectedStatus == 'all' ? null : _selectedStatus,
          );
        },
        backgroundColor: isSelected ? AppColors.primaryBlue : null,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.calendar_month,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            const Text(
              'No Appointments',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedStatus == 'all'
                  ? "You don't have any appointments yet.\nBook one to get started!"
                  : "No appointments with $_selectedStatus status",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/patient/doctors');
              },
              icon: const Icon(Icons.add),
              label: const Text('Book Appointment'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(
    BuildContext context,
    AppointmentService appointmentService,
  ) {
    return AppErrorWidget(
      title: 'Failed to Load Appointments',
      message: appointmentService.errorMessage ?? 'An error occurred',
      onRetry: () => _fetchAppointments(),
    );
  }
}
