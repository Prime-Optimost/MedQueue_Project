import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medqueue_frontend/models/api_response_model.dart';
import 'package:medqueue_frontend/models/appointment_model.dart';
import 'package:medqueue_frontend/models/queue_model.dart';
import 'package:medqueue_frontend/widgets/appointment_card.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/queue_api_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/custom_components.dart';
import '../../widgets/bottom_navbar.dart';
import '../../widgets/notification_bell.dart';
import 'doctor_queue_management_screen.dart';
import 'doctor_profile_screen.dart';
import 'doctor_appointments_screen.dart';
import 'doctor_patient_contacts_screen.dart';

class DoctorHomeScreen extends StatefulWidget {
  const DoctorHomeScreen({super.key});

  @override
  State<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends State<DoctorHomeScreen> {
  int _selectedIndex = 0;
  late QueueApiService _queueApiService;

  @override
  void initState() {
    super.initState();
    _queueApiService = QueueApiService();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
       
        body: _getBody(),
        bottomNavigationBar: ModernBottomNavBar(
          selectedIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          items: const [
            NavItem(icon: Icons.home_rounded, label: 'Home'),
            NavItem(icon: Icons.queue_rounded, label: 'Queue'),
            NavItem(icon: Icons.chat_rounded, label: 'Patients'),
            NavItem(icon: Icons.person_rounded, label: 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _getBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildHome();
      case 1:
        return const DoctorQueueManagementScreen();
      case 2:
        return const DoctorPatientContactsScreen();
      case 3:
        return const DoctorProfileScreen();
      default:
        return _buildHome();
    }
  }

  Widget _buildHome() {
  return Consumer<AuthService>(
    builder: (context, authService, _) {
      final doctor = authService.currentUser;

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
              'MedQueue GH',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3),
            ),
           
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: NotificationBell(),
          ),
        ],
      ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Banner
              _buildWelcomeBanner(doctor),
              const SizedBox(height: 24),

              // Queue Status Card
              _buildQueueStatusCard(),
              const SizedBox(height: 24),

              // Upcoming Appointments Section
              const Text(
                'This Week\'s Upcoming Appointments',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),

              _buildUpcomingAppointments(),
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const DoctorAppointmentsScreen(),
                      ),
                    );
                  },
                  child: const Text('View All Appointments'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

  Widget _buildWelcomeBanner(dynamic doctor) {
    return FutureBuilder<ApiResponse<DoctorWeeklyScheduleResponse>>(
      future: _queueApiService.getDoctorWeeklySchedule(),
      builder: (context, snapshot) {
        // Count today's appointments
        int todayAppointmentCount = 0;
        if (snapshot.hasData && snapshot.data?.isSuccess == true) {
          final appointments = snapshot.data?.data?.appointments ?? [];
          final today = DateTime.now();
          todayAppointmentCount = appointments.where((appt) {
            try {
              final apptDate = DateTime.parse(appt.appointmentDate);
              return apptDate.day == today.day &&
                  apptDate.month == today.month &&
                  apptDate.year == today.year;
            } catch (e) {
              return false;
            }
          }).length;
        }

        return FutureBuilder<ApiResponse<QueueSession>>(
          future: _queueApiService.getDoctorQueue(),
          builder: (context, queueSnapshot) {
            // Count people in queue
            int queueCount = 0;
            if (queueSnapshot.hasData && queueSnapshot.data?.isSuccess == true) {
              final session = queueSnapshot.data?.data;
              queueCount = session?.waitingCount ?? 0;
            }

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryBlue, AppColors.primaryGreen],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.35),
                    blurRadius: 24,
                    spreadRadius: -4,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Decorative circles
                  Positioned(
                    right: -20,
                    top: -20,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 20,
                    bottom: -30,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.circle,
                                  color: Color(0xFF90EE90),
                                  size: 8,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Online',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Welcome back, Dr. ${doctor?.fullName?.split(' ').last ?? "Doctor"}',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${doctor?.doctorProfile?.specialization ?? "Specialist"} • ${DateFormat('EEEE').format(DateTime.now())}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Stats row with dynamic values
                      Row(
                        children: [
                          _StatChip(
                            icon: Icons.people_rounded,
                            label: 'Appointments',
                            value: '$todayAppointmentCount',
                          ),
                          const SizedBox(width: 10),
                          _StatChip(
                            icon: Icons.queue_rounded,
                            label: 'In Queue',
                            value: '$queueCount',
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQueueStatusCard() {
  return FutureBuilder<ApiResponse<QueueSession>>(
    future: _queueApiService.getDoctorQueue(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const CustomLoadingIndicator(message: 'Loading queue status...');
      }

      QueueSession? session;
      if (snapshot.hasData && snapshot.data?.isSuccess == true) {
        session = snapshot.data?.data;
      }

      // ── Empty / No Queue State ─────────────────────────────
      if (session == null) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border:
                Border.all(color: AppColors.borderColor.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowColor.withValues(alpha: 0.05),
                blurRadius: 16,
                spreadRadius: -2,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundGray,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.queue_rounded,
                    color: AppColors.textGray,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'No Queue Today',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Your queue hasn\'t started yet',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textGray,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _selectedIndex = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.primaryBlue,
                          AppColors.primaryGreen
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryBlue.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Text(
                      'Open',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      // ── Status config ──────────────────────────────────────
      final bool isActive = !session.isPaused &&
          session.status != QueueSessionStatus.closed;
      final bool isPaused = session.isPaused;
      final bool isClosed = session.status == QueueSessionStatus.closed;

      final Color statusColor = isPaused
          ? AppColors.warningOrange
          : isClosed
              ? AppColors.textGray
              : AppColors.successGreen;

      final String statusLabel =
          isPaused ? 'Paused' : isClosed ? 'Closed' : 'Active';

      final IconData statusIcon = isPaused
          ? Icons.pause_circle_rounded
          : isClosed
              ? Icons.lock_rounded
              : Icons.play_circle_rounded;

      final int total = session.waitingCount + session.servedCount;
      final double progress =
          total > 0 ? session.servedCount / total : 0.0;

      // ── Active Queue Card ──────────────────────────────────
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: isActive
                ? [AppColors.primaryBlue, AppColors.primaryGreen]
                : isPaused
                    ? [
                        AppColors.warningOrange,
                        AppColors.warningOrange.withValues(alpha: 0.75)
                      ]
                    : [AppColors.textGray, AppColors.textLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: statusColor.withValues(alpha: 0.35),
              blurRadius: 24,
              spreadRadius: -4,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative circles
            Positioned(
              right: -24,
              top: -24,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
            Positioned(
              left: -16,
              bottom: -20,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Queue Status',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                          letterSpacing: 0.3,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Pulsing dot for active
                            if (isActive)
                              Container(
                                width: 7,
                                height: 7,
                                margin: const EdgeInsets.only(right: 5),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF90EE90),
                                  shape: BoxShape.circle,
                                ),
                              )
                            else
                              Icon(statusIcon,
                                  color: Colors.white, size: 12),
                            if (!isActive) const SizedBox(width: 4),
                            Text(
                              statusLabel,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── Now Serving ──────────────────────────
                  if (session.currentPosition > 0) ...[
                    Text(
                      '#${session.currentPosition}',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.0,
                        letterSpacing: -2,
                      ),
                    ),
                    const Text(
                      'Now Serving',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Progress bar ─────────────────────────
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${session.servedCount} of $total patients seen',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${(progress * 100).toInt()}%',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── Stat pills ───────────────────────────
                  Row(
                    children: [
                      _QueueStatPill(
                        icon: Icons.people_rounded,
                        label: 'Total',
                        value: '$total',
                      ),
                      const SizedBox(width: 8),
                      _QueueStatPill(
                        icon: Icons.hourglass_top_rounded,
                        label: 'Waiting',
                        value: '${session.waitingCount}',
                      ),
                      const SizedBox(width: 8),
                      _QueueStatPill(
                        icon: Icons.task_alt_rounded,
                        label: 'Done',
                        value: '${session.servedCount}',
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── Action buttons ───────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _selectedIndex = 1),
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(vertical: 13),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.queue_rounded,
                                    size: 16, color: statusColor),
                                const SizedBox(width: 6),
                                Text(
                                  'Manage Queue',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: statusColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (isPaused) ...[
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _selectedIndex = 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 13, horizontal: 18),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color:
                                      Colors.white.withValues(alpha: 0.4)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.play_arrow_rounded,
                                    size: 16, color: Colors.white),
                                SizedBox(width: 6),
                                Text(
                                  'Resume',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

  Widget _buildUpcomingAppointments() {
    return FutureBuilder<ApiResponse<DoctorWeeklyScheduleResponse>>(
      future: _queueApiService.getDoctorWeeklySchedule(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: CustomLoadingIndicator(message: 'Loading appointments...'),
          );
        }

        List<Appointment> appointments = [];
        if (snapshot.hasData && snapshot.data?.isSuccess == true) {
          appointments = snapshot.data?.data?.appointments ?? [];
        }

        if (appointments.isEmpty) {
          return Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.textLight, width: 1),
              ),
              child: const Center(
                child: Text(
                  'No upcoming appointments',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textGray,
                  ),
                ),
              ),
            ),
          );
        }

        // Fetch full details for appointments in parallel
        final appointmentIds = appointments.take(3).map((a) => a.id).toList();
        return FutureBuilder<List<Appointment?>>(
          future: Future.wait(
            appointmentIds.map((id) => _fetchAppointmentDetailQuietly(id)).toList(),
          ),
          builder: (context, detailSnapshot) {
            List<Appointment> detailedAppointments = [];
            
            if (detailSnapshot.hasData) {
              detailedAppointments = detailSnapshot.data!
                  .whereType<Appointment>()
                  .toList();
            }

            // If no detailed data yet, show lightweight appointments while loading
            if (detailedAppointments.isEmpty && detailSnapshot.connectionState == ConnectionState.waiting) {
              detailedAppointments = appointments.take(3).toList();
            }

            if (detailedAppointments.isEmpty) {
              return const SizedBox.shrink();
            }

            return Column(
              children: detailedAppointments.map((appointment) {
                return _buildAppointmentCard(appointment);
              }).toList(),
            );
          },
        );
      },
    );
  }

  /// Fetch full appointment details without showing loading state
  /// Used internally to fetch appointment details in parallel
  Future<Appointment?> _fetchAppointmentDetailQuietly(int appointmentId) async {
    try {
      final response = await _queueApiService.getAppointmentDetail(appointmentId);
      if (response.isSuccess && response.data != null) {
        return response.data;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching appointment detail for ID $appointmentId: $e');
      return null;
    }
  }

  Widget _buildAppointmentCard(Appointment appointment) {
    return AppointmentCard(appointment: appointment, showPatientName: true);
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueStatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _QueueStatPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white70),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white60,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}