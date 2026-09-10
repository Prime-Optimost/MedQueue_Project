import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/appointment_model.dart';
import '../utils/app_colors.dart';
import '../services/whatsapp_service.dart';

class AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final VoidCallback? onTap;
  final List<Widget>? actions;
  final bool showPatientName;

  const AppointmentCard({
    super.key,
    required this.appointment,
    this.onTap,
    this.actions,
    this.showPatientName = false,
  });

  // ── Status config ─────────────────────────────────────────────
  _StatusStyle get _statusStyle {
    switch (appointment.status) {
      case 'pending':
        return _StatusStyle(
          color: AppColors.warningOrange,
          bg: const Color(0xFFFFF5E6),
          icon: Icons.hourglass_top_rounded,
          label: 'Pending',
        );
      case 'confirmed':
        return _StatusStyle(
          color: AppColors.primaryBlue,
          bg: const Color(0xFFEBF4FF),
          icon: Icons.check_circle_rounded,
          label: 'Confirmed',
        );
      case 'completed':
        return _StatusStyle(
          color: AppColors.successGreen,
          bg: const Color(0xFFE8F8F2),
          icon: Icons.task_alt_rounded,
          label: 'Completed',
        );
      case 'cancelled':
        return _StatusStyle(
          color: AppColors.emergencyRed,
          bg: const Color(0xFFFFECEB),
          icon: Icons.cancel_rounded,
          label: 'Cancelled',
        );
      case 'no_show':
        return _StatusStyle(
          color: AppColors.emergencyLight,
          bg: const Color(0xFFFFECEB),
          icon: Icons.person_off_rounded,
          label: 'No Show',
        );
      case 'rescheduled':
        return _StatusStyle(
          color: const Color(0xFF8B5CF6),
          bg: const Color(0xFFF3EEFF),
          icon: Icons.update_rounded,
          label: 'Rescheduled',
        );
      default:
        return _StatusStyle(
          color: AppColors.textGray,
          bg: AppColors.backgroundGray,
          icon: Icons.info_outline_rounded,
          label: 'Unknown',
        );
    }
  }

  // ── Helpers ───────────────────────────────────────────────────
  String _initials() {
    final name = showPatientName
        ? appointment.patientDetail.fullName
        : appointment.doctorDetail.fullName;
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  /// Returns human-friendly date like:
  /// "Today at 9:00 AM", "Tomorrow at 2:30 PM", "Mon, Jun 3 at 10:00 AM"
  String _friendlyDateTime() {
    try {
      final date = DateTime.parse(appointment.appointmentDate);
      final time = appointment.appointmentTime; // e.g. "09:00"
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      final apptDay = DateTime(date.year, date.month, date.day);

      // Format time nicely
      String timeLabel = time;
      try {
        final parsed = DateFormat('HH:mm').parse(time);
        timeLabel = DateFormat('h:mm a').format(parsed);
      } catch (_) {}

      if (apptDay == today) {
        return 'Today  ·  $timeLabel';
      } else if (apptDay == tomorrow) {
        return 'Tomorrow  ·  $timeLabel';
      } else {
        final dayStr = DateFormat('EEE, MMM d').format(date);
        return '$dayStr  ·  $timeLabel';
      }
    } catch (_) {
      return '${appointment.appointmentDate}  ·  ${appointment.appointmentTime}';
    }
  }

  String? _contactNumber() => showPatientName
      ? appointment.patientDetail.whatsappNumber
      : appointment.doctorDetail.whatsappNumber;

  bool _contactHasWhatsApp() => showPatientName
      ? appointment.patientDetail.hasWhatsApp
      : appointment.doctorDetail.hasWhatsApp;

  @override
  Widget build(BuildContext context) {
    final status = _statusStyle;
    final name = showPatientName
        ? appointment.patientDetail.fullName
        : 'Dr. ${appointment.doctorDetail.fullName}';
    final subtitle = showPatientName
        ? appointment.patientDetail.phone
        : appointment.doctorDetail.specialization;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryBlue.withValues(alpha: 0.07),
              blurRadius: 16,
              spreadRadius: -2,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Gradient header ──────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    status.color.withValues(alpha: 0.08),
                    status.color.withValues(alpha: 0.03),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryBlue.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      backgroundImage: (showPatientName
                              ? appointment.patientDetail.profilePictureUrl
                              : appointment.doctorDetail.profilePictureUrl)
                          ?.isNotEmpty == true
                          ? NetworkImage(showPatientName
                              ? appointment.patientDetail.profilePictureUrl!
                              : appointment.doctorDetail.profilePictureUrl!)
                          : null,
                      backgroundColor: const Color(0xFFE8F0FE),
                      child: (showPatientName
                              ? appointment.patientDetail.profilePictureUrl
                              : appointment.doctorDetail.profilePictureUrl)
                          ?.isNotEmpty != true
                          ? Text(
                              _initials(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Name + subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textGray,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Status pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: status.bg,
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: status.color.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(status.icon, size: 12, color: status.color),
                        const SizedBox(width: 4),
                        Text(
                          status.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: status.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Divider ──────────────────────────────────────
            const Divider(height: 1, color: Color(0xFFF2F4F6)),

            // ── Body ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date & time — big and readable
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.event_rounded,
                          size: 18,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _friendlyDateTime(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),

                  // Reason
                  if (appointment.reason.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.textGray.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.notes_rounded,
                            size: 18,
                            color: AppColors.textGray,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              appointment.reason,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textGray,
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // ── WhatsApp button ─────────────────────────
                  if (_contactHasWhatsApp()) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => WhatsAppService.openWhatsApp(
                        _contactNumber(),
                        message: showPatientName
                            ? 'Hello, regarding your appointment.'
                            : 'Hello Dr., regarding my appointment.',
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF25D366).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF25D366).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.chat_rounded,
                              size: 16,
                              color: Color(0xFF25D366),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              showPatientName
                                  ? 'Message Patient on WhatsApp'
                                  : 'Message Doctor on WhatsApp',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF25D366),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // ── Extra actions ───────────────────────────
                  if (actions != null && actions!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: Color(0xFFF2F4F6)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: actions!
                          .map((a) => Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: a,
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Supporting types ───────────────────────────────────────────

class _StatusStyle {
  final Color color;
  final Color bg;
  final IconData icon;
  final String label;

  const _StatusStyle({
    required this.color,
    required this.bg,
    required this.icon,
    required this.label,
  });
}