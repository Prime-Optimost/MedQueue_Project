import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medqueue_frontend/models/appointment_model.dart';

import '../../services/queue_api_service.dart';
import '../../services/whatsapp_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/custom_components.dart';
import '../../widgets/notification_bell.dart';

class DoctorPatientContactsScreen extends StatefulWidget {
  const DoctorPatientContactsScreen({super.key});

  @override
  State<DoctorPatientContactsScreen> createState() =>
      _DoctorPatientContactsScreenState();
}

class _DoctorPatientContactsScreenState
    extends State<DoctorPatientContactsScreen> {
  late QueueApiService _queueApiService;
  List<Appointment> _appointments = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedFilter = 'upcoming';

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
          final fullAppointments = <Appointment>[];
          for (final appointment in response.data?.appointments ?? []) {
            final fullAppointment =
                await _queueApiService.getAppointmentDetail(appointment.id);
            if (fullAppointment.isSuccess) {
              fullAppointments.add(fullAppointment.data!);
            }
          }
          setState(() {
            _appointments = fullAppointments;
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
          _errorMessage = 'Failed to load patients: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  List<Appointment> get _filteredAppointments {
    switch (_selectedFilter) {
      case 'upcoming':
        return _appointments
            .where((a) => a.isUpcoming && a.status != 'cancelled')
            .toList();
      case 'today':
        return _appointments.where((a) => a.isToday).toList();
      case 'all':
        return _appointments;
      default:
        return _appointments
            .where((a) => a.isUpcoming && a.status != 'cancelled')
            .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Patient Contacts'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: NotificationBell(),
          ),
        ],
      ),
      body: _isLoading && _appointments.isEmpty
          ? const CustomLoadingIndicator(message: 'Loading patients...')
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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

                  _buildFilterChips(),
                  const SizedBox(height: 20),

                  _buildSummaryCard(),
                  const SizedBox(height: 20),

                  if (_filteredAppointments.isEmpty)
                    _buildEmptyState()
                  else
                    _buildPatientList(),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterChips() {
    final upcomingCount = _appointments
        .where((a) => a.isUpcoming && a.status != 'cancelled')
        .length;
    final todayCount = _appointments.where((a) => a.isToday).length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip(
            label: 'Upcoming',
            value: 'upcoming',
            count: upcomingCount,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Today',
            value: 'today',
            count: todayCount,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'All',
            value: 'all',
            count: _appointments.length,
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
      onSelected: (_) {
        setState(() {
          _selectedFilter = value;
        });
      },
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

  Widget _buildSummaryCard() {
    final whatsappCount = _filteredAppointments
        .where((a) => a.patientDetail.hasWhatsApp)
        .length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF25D366), Color(0xFF128C7E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF25D366).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.chat_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'WhatsApp Contacts',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$whatsappCount of ${_filteredAppointments.length} patients available',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.people_outline_rounded,
            size: 56,
            color: AppColors.textLight,
          ),
          const SizedBox(height: 16),
          const Text(
            'No patients found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFilter == 'today'
                ? 'No patients scheduled for today'
                : 'No $_selectedFilter appointments available',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textGray,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPatientList() {
    final grouped = <String, List<Appointment>>{};
    for (var appt in _filteredAppointments) {
      final key = appt.appointmentDate;
      grouped.putIfAbsent(key, () => []).add(appt);
    }

    // Sort date keys
    final sortedKeys = grouped.keys.toList()..sort();

    return Column(
      children: sortedKeys.map((dateKey) {
        final appts = grouped[dateKey]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                _formatDateHeader(dateKey),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryBlue,
                ),
              ),
            ),
            ...appts.map((appt) => _buildPatientCard(appt)),
            const SizedBox(height: 16),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildPatientCard(Appointment appointment) {
    final patient = appointment.patientDetail;
    final hasWhatsApp = patient.hasWhatsApp;
    final statusColor = _getStatusColor(appointment.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFFE8F0FE),
                  backgroundImage: patient.profilePictureUrl?.isNotEmpty == true
                      ? NetworkImage(patient.profilePictureUrl!)
                      : null,
                  child: patient.profilePictureUrl?.isNotEmpty != true
                      ? Text(
                          _initials(patient.fullName),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryBlue,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.fullName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        patient.phone.isNotEmpty ? patient.phone : 'No phone',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textGray,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _formatStatus(appointment.status),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.event_rounded,
                    size: 14, color: AppColors.textGray),
                const SizedBox(width: 6),
                Text(
                  _formatAppointmentTime(appointment),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textGray,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (appointment.reason.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.notes_rounded,
                      size: 14, color: AppColors.textGray),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      appointment.reason,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textGray,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: hasWhatsApp
                  ? GestureDetector(
                      onTap: () => WhatsAppService.openWhatsApp(
                        patient.whatsappNumber,
                        message:
                            'Hello ${patient.fullName.split(' ').first}, this is Dr. ${appointment.doctorDetail.fullName} from MedQueue. Regarding your appointment on ${_formatAppointmentTime(appointment)}.',
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          color: const Color(0xFF25D366),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF25D366).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Contact on WhatsApp',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundGray,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.phone_disabled_rounded,
                            size: 18,
                            color: AppColors.textGray,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'WhatsApp not linked',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textGray,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String _formatDateHeader(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('EEEE, MMMM d, y').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _formatAppointmentTime(Appointment appointment) {
    try {
      final date = DateTime.parse(appointment.appointmentDate);
      final dayStr = DateFormat('EEE, MMM d').format(date);
      String timeStr = appointment.appointmentTime;
      try {
        final parsed = DateFormat('HH:mm').parse(timeStr);
        timeStr = DateFormat('h:mm a').format(parsed);
      } catch (_) {}
      return '$dayStr at $timeStr';
    } catch (_) {
      return '${appointment.appointmentDate} at ${appointment.appointmentTime}';
    }
  }

  String _formatStatus(String status) {
    switch (status) {
      case 'confirmed':
        return 'Confirmed';
      case 'pending':
        return 'Pending';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'no_show':
        return 'No Show';
      default:
        return status[0].toUpperCase() + status.substring(1);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'confirmed':
        return AppColors.primaryBlue;
      case 'pending':
        return AppColors.warningOrange;
      case 'completed':
        return AppColors.successGreen;
      case 'cancelled':
        return AppColors.emergencyRed;
      case 'no_show':
        return AppColors.emergencyLight;
      default:
        return AppColors.textGray;
    }
  }
}
