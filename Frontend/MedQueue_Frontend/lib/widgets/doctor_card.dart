import 'package:flutter/material.dart';
import '../models/doctor_model.dart';
import '../utils/app_colors.dart';
import '../services/whatsapp_service.dart';

class DoctorCard extends StatelessWidget {
  final Doctor doctor;
  final VoidCallback? onTap;
  final Widget? action;
  final bool showAvailability;

  const DoctorCard({
    super.key,
    required this.doctor,
    this.onTap,
    this.action,
    this.showAvailability = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryBlue.withValues(alpha: 0.08),
              blurRadius: 20,
              spreadRadius: -2,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: AppColors.shadowColor.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  //check if profile picture url is not empty an null, if available display the image
                  if (doctor.profilePictureUrl.trim().isNotEmpty)
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        image: DecorationImage(
                          image: NetworkImage(doctor.profilePictureUrl),
                          fit: BoxFit.cover,
                        ),
                       /*  boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryBlue.withValues(alpha: 0.3),
                            blurRadius: 12,
                            spreadRadius: -2,
                            offset: const Offset(0, 4),
                          ),
                        ], */
                      ),
                    )
                  else
                  
                  // ── Avatar ───────────────────────────────
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.primaryBlue,
                          AppColors.primaryGreen,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryBlue.withValues(alpha: 0.3),
                          blurRadius: 12,
                          spreadRadius: -2,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        doctor.initials,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 14),

                  // ── Name & Specialization ─────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dr. ${doctor.fullName}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            doctor.specialization,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryBlue,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (doctor.hospitalName.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_rounded,
                                size: 12,
                                color: AppColors.textGray,
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  doctor.hospitalName,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textGray,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // ── Action / Arrow ────────────────────────
                  if (action != null)
                    action!
                  else
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFF2F4F6)),
              const SizedBox(height: 12),

              // ── Stats Row ─────────────────────────────────
              Row(
                children: [
                  if (doctor.consultationFee > 0) ...[
                    _StatBadge(
                      icon: Icons.payments_rounded,
                      label: 'GHS ${doctor.consultationFee.toStringAsFixed(0)}',
                      iconColor: AppColors.primaryGreen,
                      bgColor: AppColors.primaryGreen.withValues(alpha: 0.08),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (doctor.yearsOfExperience > 0) ...[
                    _StatBadge(
                      icon: Icons.workspace_premium_rounded,
                      label: '${doctor.yearsOfExperience} yrs exp.',
                      iconColor: AppColors.warningOrange,
                      bgColor: AppColors.warningOrange.withValues(alpha: 0.08),
                    ),
                    const SizedBox(width: 8),
                  ],
                  /* if (showAvailability) ...[
                    const Spacer(),
                    _AvailabilityDot(isAvailable: doctor.isAvailable),
                  ], */
                ],
              ),

              if (doctor.hasWhatsApp) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: 100,
                  child: OutlinedButton.icon(
                    onPressed: () => WhatsAppService.openWhatsApp(
                      doctor.whatsappNumber,
                      message: 'Hello Dr. ${doctor.fullName}, I found your profile on MedQueue.',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF128C7E),
                      side: const BorderSide(color: Color(0xFF128C7E)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.chat_rounded, size: 18),
                    label: const Text(
                      'Chat',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
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

// ── Supporting Widgets ─────────────────────────────────────────

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color bgColor;

  const _StatBadge({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: iconColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }
}