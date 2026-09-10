import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../models/appointment_model.dart';
import '../services/whatsapp_service.dart';

class DoctorCard extends StatelessWidget {
  final String doctorId;
  final String name;
  final String specialization;
  final double rating;
  final int experience;
  final bool isAvailable;
  final String nextAvailable;
  final VoidCallback onTap;
  final String? whatsappNumber;
  final bool whatsappLinked;
  final VoidCallback? onWhatsAppTap;

  const DoctorCard({
    super.key,
    required this.doctorId,
    required this.name,
    required this.specialization,
    required this.rating,
    required this.experience,
    required this.isAvailable,
    required this.nextAvailable,
    required this.onTap,
    this.whatsappNumber,
    this.whatsappLinked = false,
    this.onWhatsAppTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.2),
                    child: Icon(
                      Icons.person,
                      size: 40,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          specialization,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textGray,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.star, size: 16, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              '$rating',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '$experience years',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textGray,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isAvailable ? AppColors.successGreen.withValues(alpha: 0.1) : AppColors.errorRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isAvailable ? 'Available' : 'Unavailable',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isAvailable ? AppColors.successGreen : AppColors.errorRed,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.backgroundGray,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Next: $nextAvailable',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textGray,
                  ),
                ),
              ),

              if (whatsappLinked && (whatsappNumber ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onWhatsAppTap ?? () => WhatsAppService.openWhatsApp(
                      whatsappNumber,
                      message: 'Hello Dr. $name, I found your profile on MedQueue.',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF128C7E),
                      side: const BorderSide(color: Color(0xFF128C7E)),
                    ),
                    icon: const Icon(Icons.chat_rounded, size: 18),
                    label: const Text('WhatsApp'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class RoughAppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final VoidCallback? onReschedule;
  final VoidCallback? onCancel;
  final VoidCallback onTap;
  final bool showPatientName;

  const RoughAppointmentCard({
    super.key,
    required this.appointment,
    this.onReschedule,
    this.onCancel,
    required this.onTap,
    this.showPatientName = false,
  });

  String get _status => appointment.status;

  Color _getStatusColor() {
    switch (_status.toLowerCase()) {
      case 'scheduled':
      case 'confirmed':
      case 'pending':
        return AppColors.infoBlue;
      case 'completed':
        return AppColors.successGreen;
      case 'cancelled':
        return AppColors.errorRed;
      case 'in progress':
      case 'in_progress':
        return AppColors.warningOrange;
      default:
        return AppColors.textGray;
    }
  }

  @override
  Widget build(BuildContext context) {
    final doctorName = appointment.doctorDetail.fullName;
    final specialization = appointment.doctorDetail.specialization;
    final date = appointment.appointmentDate;
    final time = appointment.appointmentTime;
    final reason = appointment.reason;
    final status = appointment.status;

    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doctorName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          specialization,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor().withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.backgroundGray,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16, color: AppColors.primaryBlue),
                        const SizedBox(width: 8),
                        Text(
                          date,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 16, color: AppColors.primaryBlue),
                        const SizedBox(width: 8),
                        Text(
                          time,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.note, size: 16, color: AppColors.primaryBlue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            reason,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textGray,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (status.toLowerCase() == 'scheduled' || status.toLowerCase() == 'pending')
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      if (onReschedule != null)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: onReschedule,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              side: const BorderSide(color: AppColors.primaryBlue),
                            ),
                            child: const Text(
                              'Reschedule',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      if (onReschedule != null && onCancel != null) const SizedBox(width: 8),
                      if (onCancel != null)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: onCancel,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              side: const BorderSide(color: AppColors.errorRed),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(fontSize: 12, color: AppColors.errorRed),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                if ((appointment.patientDetail.hasWhatsApp && showPatientName) ||
                    (appointment.doctorDetail.hasWhatsApp && !showPatientName))
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => WhatsAppService.openWhatsApp(
                          showPatientName
                              ? appointment.patientDetail.whatsappNumber
                              : appointment.doctorDetail.whatsappNumber,
                          message: showPatientName
                              ? 'Hello, I am reaching out about my appointment.'
                              : 'Hello, I am reaching out about this appointment.',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF128C7E),
                          side: const BorderSide(color: Color(0xFF128C7E)),
                        ),
                        icon: const Icon(Icons.chat_rounded, size: 18),
                        label: Text(showPatientName ? 'Patient WhatsApp' : 'Doctor WhatsApp'),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class QueueCard extends StatelessWidget {
  final int queueNumber;
  final String patientName;
  final String doctorName;
  final int estimatedWait;
  final String status;

  const QueueCard({
    super.key,
    required this.queueNumber,
    required this.patientName,
    required this.doctorName,
    required this.estimatedWait,
    required this.status,
  });

  Color _getStatusColor() {
    switch (status.toLowerCase()) {
      case 'waiting':
        return AppColors.warningOrange;
      case 'inprogress':
        return AppColors.infoBlue;
      case 'completed':
        return AppColors.successGreen;
      default:
        return AppColors.textGray;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Queue Number Badge
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.primaryBlue,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '#$queueNumber',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Patient and Doctor Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patientName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Dr: $doctorName',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textGray,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 14,
                        color: AppColors.textGray,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$estimatedWait min wait',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textGray,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor().withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _getStatusColor(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NotificationCard extends StatelessWidget {
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final VoidCallback onTap;
  final VoidCallback? onDismiss;

  const NotificationCard({
    super.key,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.onTap,
    this.onDismiss,
  });

  Color _getTypeColor() {
    switch (type.toLowerCase()) {
      case 'appointment':
        return AppColors.infoBlue;
      case 'queue':
        return AppColors.primaryGreen;
      case 'emergency':
        return AppColors.emergencyRed;
      case 'reminder':
        return AppColors.warningOrange;
      default:
        return AppColors.textGray;
    }
  }

  IconData _getTypeIcon() {
    switch (type.toLowerCase()) {
      case 'appointment':
        return Icons.calendar_today;
      case 'queue':
        return Icons.line_weight;
      case 'emergency':
        return Icons.emergency;
      case 'reminder':
        return Icons.notifications;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(title),
      onDismissed: (_) => onDismiss?.call(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isRead ? AppColors.backgroundGray : _getTypeColor().withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _getTypeColor().withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getTypeColor().withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getTypeIcon(),
                  color: _getTypeColor(),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textGray,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (!isRead)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _getTypeColor(),
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
