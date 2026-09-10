import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medqueue_frontend/widgets/appointment_card.dart';

import '../../models/appointment_model.dart';
import '../../services/queue_api_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/custom_components.dart';

class DoctorAppointmentsScreen extends StatefulWidget {
  const DoctorAppointmentsScreen({super.key});

  @override
  State<DoctorAppointmentsScreen> createState() =>
      _DoctorAppointmentsScreenState();
}

class _DoctorAppointmentsScreenState extends State<DoctorAppointmentsScreen> {
  late QueueApiService _queueApiService;
  List<Appointment> _appointments = [];
  List<Appointment> _filteredAppointments = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedFilter = 'all'; // all, confirmed, pending, completed

  @override
  void initState() {
    super.initState();
    _queueApiService = QueueApiService();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _queueApiService.getDoctorWeeklySchedule();
      if (mounted) {
        if (response.isSuccess) {
          //fetch full appointment details for each appointment
          final fullAppointments = <Appointment>[];
          for (final appointment in response.data?.appointments ?? []) {
            final fullAppointment = await _queueApiService.getAppointmentDetail(appointment.id);
            if (fullAppointment.isSuccess) {
              fullAppointments.add(fullAppointment.data!);
            }
          }
          setState(() {
            _appointments = fullAppointments;
            _applyFilter();
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = response.message;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load appointments: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilter() {
    switch (_selectedFilter) {
      case 'confirmed':
        _filteredAppointments = _appointments
            .where((a) => a.status == 'confirmed')
            .toList();
        break;
      case 'pending':
        _filteredAppointments = _appointments
            .where((a) => a.status == 'pending')
            .toList();
        break;
      case 'completed':
        _filteredAppointments = _appointments
            .where((a) => a.status == 'completed')
            .toList();
        break;
      default:
        _filteredAppointments = _appointments;
    }

    // Sort by date
    _filteredAppointments.sort((a, b) {
      try {
        final dateA = DateTime.parse(a.appointmentDate);
        final dateB = DateTime.parse(b.appointmentDate);
        return dateA.compareTo(dateB);
      } catch (e) {
        return 0;
      }
    });
  }

  void _setFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
      _applyFilter();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Weekly Appointments'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading && _appointments.isEmpty
          ? const CustomLoadingIndicator(message: 'Loading appointments...')
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Error Message
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.emergencyRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.emergencyRed.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppColors.emergencyRed,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Filter Chips
                  _buildFilterChips(),
                  const SizedBox(height: 20),

                  // Appointments Summary
                  _buildSummarySection(),
                  const SizedBox(height: 20),

                  // Appointments List
                  if (_filteredAppointments.isEmpty)
                    _buildEmptyState()
                  else
                    _buildAppointmentsList(),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip(
            label: 'All',
            value: 'all',
            count: _appointments.length,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Confirmed',
            value: 'confirmed',
            count: _appointments.where((a) => a.status == 'confirmed').length,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Pending',
            value: 'pending',
            count: _appointments.where((a) => a.status == 'pending').length,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Completed',
            value: 'completed',
            count: _appointments.where((a) => a.status == 'completed').length,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String value,
    required int count,
  }) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(
        '$label ($count)',
        style: TextStyle(
          color: isSelected ? Colors.white : AppColors.textGray,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      onSelected: (_) => _setFilter(value),
      selected: isSelected,
      backgroundColor: AppColors.backgroundLight,
      selectedColor: AppColors.primaryBlue,
      side: BorderSide(
        color: isSelected
            ? AppColors.primaryBlue
            : AppColors.textLight.withValues(alpha: 0.3),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _buildSummarySection() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSummaryStat(
              label: 'Total',
              value: '${_appointments.length}',
              icon: Icons.calendar_today,
            ),
            _buildSummaryStat(
              label: 'This Week',
              value: '${_filteredAppointments.length}',
              icon: Icons.event,
            ),
            _buildSummaryStat(
              label: 'Confirmed',
              value: '${_appointments.where((a) => a.status == 'confirmed').length}',
              icon: Icons.check_circle,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStat({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.primaryBlue, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textGray,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.textLight, width: 1),
        ),
        child: Column(
          children: [
            Icon(
              Icons.event_busy,
              size: 48,
              color: AppColors.textLight,
            ),
            const SizedBox(height: 16),
            const Text(
              'No appointments found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No $_selectedFilter appointments available for this week',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textGray,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentsList() {
    // Group appointments by date
    final groupedAppointments = <String, List<Appointment>>{};
    for (var appointment in _filteredAppointments) {
      final dateKey = appointment.appointmentDate;
      if (!groupedAppointments.containsKey(dateKey)) {
        groupedAppointments[dateKey] = [];
      }
      groupedAppointments[dateKey]!.add(appointment);
    }

    return Column(
      children: groupedAppointments.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _formatDateHeader(entry.key),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryBlue,
                ),
              ),
            ),

            // Appointments for this date
            ...entry.value.map((appointment) {
              return _buildAppointmentCard(appointment);
            }),

            const SizedBox(height: 20),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildAppointmentCard(Appointment appointment) {

    return AppointmentCard(appointment: appointment, showPatientName: true);
  }

  String _formatDateHeader(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('EEEE, MMMM d, y').format(date);
    } catch (e) {
      return dateStr;
    }
  }

 
}
