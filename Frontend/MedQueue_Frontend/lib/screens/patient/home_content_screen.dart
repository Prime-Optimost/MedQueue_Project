import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../services/auth_service.dart';
import '../../services/appointment_service.dart';
import '../../services/queue_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/appointment_card.dart';
import '../../widgets/notification_bell.dart';

class HomeContentScreen extends StatelessWidget {
  final VoidCallback? onViewAll;

  const HomeContentScreen({super.key, this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        automaticallyImplyLeading: false,
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
        
        title: const Text(
          'MedQueue GH',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: NotificationBell(),
          ),
        ],
      ),
      body: Consumer2<AuthService, AppointmentService>(
        builder: (context, authService, appointmentService, _) {
          final user = authService.currentUser;
          final upcomingAppointments =
              appointmentService.upcomingAppointments.take(3).toList();

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Hero Welcome Banner ──────────────────────────
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        AppColors.primaryBlue,
                        AppColors.primaryGreen,
                      ],
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
                          // Online badge
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
                          const SizedBox(height: 12),
                          Text(
                            'Hello, ${user?.fullName.split(' ').first ?? "there"} 👋',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'How are you feeling today?',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Stat chips
                          Consumer<QueueService>(
                            builder: (context, queueService, _) {
                              String nextApptText = 'No appt';
                              if (upcomingAppointments.isNotEmpty) {
                                final nextAppt =
                                    upcomingAppointments.first;
                                final apptDate = DateTime.parse(
                                  nextAppt.appointmentDate,
                                );
                                final today = DateTime.now();
                                final tomorrow = DateTime(
                                  today.year,
                                  today.month,
                                  today.day + 1,
                                );
                                if (apptDate.year == today.year &&
                                    apptDate.month == today.month &&
                                    apptDate.day == today.day) {
                                  nextApptText = 'Today';
                                } else if (apptDate.year ==
                                        tomorrow.year &&
                                    apptDate.month == tomorrow.month &&
                                    apptDate.day == tomorrow.day) {
                                  nextApptText = 'Tomorrow';
                                } else {
                                  nextApptText =
                                      DateFormat('MMM d').format(apptDate);
                                }
                              }

                              final queueNumber = queueService
                                      .currentQueueEntry?.queueNumber ??
                                  0;
                              final queueText = queueNumber > 0
                                  ? '#$queueNumber'
                                  : 'Not in queue';

                              return Row(
                                children: [
                                  _StatChip(
                                    icon: Icons.calendar_today_rounded,
                                    label: 'Next Appt',
                                    value: nextApptText,
                                  ),
                                  const SizedBox(width: 10),
                                  _StatChip(
                                    icon: Icons.queue_rounded,
                                    label: 'Queue',
                                    value: queueText,
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── Quick Actions ────────────────────────────────
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.25,
                    children: [
                      _ModernQuickAction(
                        icon: Icons.calendar_month_rounded,
                        label: 'Book\nAppointment',
                        color: AppColors.primaryBlue,
                        bgColor: const Color(0xFFEBF4FF),
                        onTap: () => Navigator.of(context)
                            .pushNamed('/patient/doctors'),
                      ),
                      _ModernQuickAction(
                        icon: Icons.queue_rounded,
                        label: 'Queue\nStatus',
                        color: AppColors.primaryGreen,
                        bgColor: const Color(0xFFE8F8F2),
                        onTap: () => Navigator.of(context)
                            .pushNamed('/queue-tracker'),
                      ),
                      _ModernQuickAction(
                        icon: Icons.smart_toy_rounded,
                        label: 'AI Health\nAssistant',
                        color: AppColors.warningOrange,
                        bgColor: const Color(0xFFFFF5E6),
                        onTap: () => Navigator.of(context)
                            .pushNamed('/patient-chatbot'),
                      ),
                      _ModernQuickAction(
                        icon: Icons.emergency_rounded,
                        label: 'Emergency\nSOS',
                        color: AppColors.emergencyRed,
                        bgColor: const Color(0xFFFFECEB),
                        onTap: () => Navigator.of(context)
                            .pushNamed('/emergency-sos'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── Upcoming Appointments ────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Upcoming Appointments',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                          letterSpacing: -0.3,
                        ),
                      ),
                      GestureDetector(
                        onTap: onViewAll,
                        child: const Text(
                          'See all',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Empty state
                if (upcomingAppointments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 32,
                        horizontal: 24,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.borderColor.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.calendar_today_rounded,
                              color: AppColors.primaryBlue,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No upcoming appointments',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Book one to get started',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textGray,
                            ),
                          ),
                          const SizedBox(height: 20),
                          GestureDetector(
                            onTap: () => Navigator.of(context)
                                .pushNamed('/patient/doctors'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    AppColors.primaryBlue,
                                    AppColors.primaryGreen,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryBlue
                                        .withValues(alpha: 0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Text(
                                'Book Now',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  // Appointments list
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: upcomingAppointments.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) => AppointmentCard(
                        appointment: upcomingAppointments[index],
                        onTap: () => Navigator.of(context).pushNamed(
                          '/patient/appointment-detail',
                          arguments: upcomingAppointments[index].id,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 28),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ModernQuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  // Each card gets a unique subtitle hint
  String get _subtitle {
    if (label.contains('Book')) return 'Find a doctor';
    if (label.contains('Queue')) return 'Live updates';
    if (label.contains('AI') || label.contains('Assistant')) {
      return 'Ask anything';
    }
    if (label.contains('Emergency')) return 'Tap to call';
    return '';
  }

  const _ModernQuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isEmergency = label.contains('Emergency');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: isEmergency
                ? [AppColors.emergencyRed, AppColors.emergencyLight]
                : [color.withValues(alpha: 0.92), color.withValues(alpha: 0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: isEmergency ? 0.45 : 0.3),
              blurRadius: 16,
              spreadRadius: -3,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // ── Large decorative circle top-right ──────────
            Positioned(
              right: -14,
              top: -14,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
            ),
            // ── Small decorative circle bottom-left ────────
            Positioned(
              left: -8,
              bottom: -12,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),

            // ── Content ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Icon container
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),

                  // Label + subtitle
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.2,
                          height: 1.2,
                        ),
                      ),
                      if (_subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          _subtitle,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // ── Arrow chip top-right ───────────────────────
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
