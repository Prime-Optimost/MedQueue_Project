import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../utils/app_colors.dart';
import '../doctor/edit_doctor_profile_screen.dart';
import 'doctor_availability_screen.dart';
import '../../widgets/custom_components.dart';

class DoctorProfileScreen extends StatefulWidget {
  const DoctorProfileScreen({super.key});

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  void _openAvailabilityScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DoctorAvailabilityScreen(),
      ),
    );
  }

  void _openEditProfileScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DoctorEditProfileScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Consumer<AuthService>(
        builder: (context, authService, _) {
          final doctor = authService.currentUser;
        debugPrint("profile url: ${doctor?.profilePictureUrl}");
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                // ── Hero Header ──────────────────────────────────
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primaryBlue, AppColors.primaryGreen],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(36),
                      bottomRight: Radius.circular(36),
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Decorative circles
                      Positioned(
                        right: -30,
                        top: 10,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.07),
                          ),
                        ),
                      ),
                      Positioned(
                        left: -20,
                        bottom: -20,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                      ),

                      Positioned(
                        top: 20,
                        right: 20,
                        child: _HeroActionPill(
                          icon: Icons.calendar_month_rounded,
                          label: 'My Availability',
                          onTap: _openAvailabilityScreen,
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
                        child: Column(
                          children: [
                            Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                doctor?.profilePictureUrl != null &&
                                        doctor?.profilePictureUrl?.isNotEmpty ==
                                            true
                                    ? Container(
                                        width: 96,
                                        height: 96,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.5),
                                            width: 3,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.15),
                                              blurRadius: 20,
                                              offset: const Offset(0, 8),
                                            ),
                                          ],
                                        ),
                                        child: ClipOval(
                                          child: Image.network(
                                            doctor!.profilePictureUrl!,
                                            fit: BoxFit.cover,
                                            width: 96,
                                            height: 96,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return const Icon(
                                                Icons.local_hospital_rounded,
                                                size: 52,
                                                color: Colors.white,
                                              );
                                            },
                                          ),
                                        ),
                                      )
                                    : Container(
                                        width: 96,
                                        height: 96,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white.withValues(alpha: 0.2),
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.5),
                                            width: 3,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.15),
                                              blurRadius: 20,
                                              offset: const Offset(0, 8),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.local_hospital_rounded,
                                          size: 52,
                                          color: Colors.white,
                                        ),
                                      ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: _AvatarEditButton(
                                    onTap: _openEditProfileScreen,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            Text(
                              'Dr. ${doctor?.fullName ?? 'Doctor'}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.4,
                              ),
                              textAlign: TextAlign.center,
                            ),

                            const SizedBox(height: 6),

                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                doctor?.email ?? '',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Stats Row
                            Row(
                              children: [
                                Expanded(
                                  child: _ProfileStat(
                                    label: 'Specialty',
                                    value:
                                        doctor?.doctorProfile?.specialization ??
                                        'N/A',
                                    icon: Icons.medical_services_rounded,
                                  ),
                                ),

                                Container(
                                  width: 1,
                                  height: 36,
                                  color: Colors.white.withValues(alpha: 0.3),
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                ),

                                Expanded(
                                  child: _ProfileStat(
                                    label: 'Hospital',
                                    value:
                                        doctor?.doctorProfile?.hospitalName ??
                                        'N/A',
                                    icon: Icons.local_hospital_rounded,
                                  ),
                                ),

                                Container(
                                  width: 1,
                                  height: 36,
                                  color: Colors.white.withValues(alpha: 0.3),
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                ),

                                const Expanded(
                                  child: _ProfileStat(
                                    label: 'Status',
                                    value: 'Active',
                                    icon: Icons.verified_rounded,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Personal Information ────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _SectionCard(
                    title: 'Personal Information',
                    icon: Icons.person_outline_rounded,
                    children: [
                      _ModernInfoTile(
                        icon: Icons.phone_rounded,
                        label: 'Phone',
                        value: doctor?.phoneNumber ?? 'N/A',
                        iconColor: AppColors.primaryBlue,
                      ),
                      _ModernInfoTile(
                        icon: Icons.email_rounded,
                        label: 'Email',
                        value: doctor?.email ?? 'N/A',
                        iconColor: AppColors.primaryGreen,
                        showDivider: false,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── Professional Information ────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _SectionCard(
                    title: 'Professional Information',
                    icon: Icons.medical_services_rounded,
                    children: [
                      _ModernInfoTile(
                        icon: Icons.medical_services_rounded,
                        label: 'Specialization',
                        value: doctor?.doctorProfile?.specialization ?? 'N/A',
                        iconColor: AppColors.primaryBlue,
                      ),
                      _ModernInfoTile(
                        icon: Icons.badge_rounded,
                        label: 'Medical License',
                        value: doctor?.doctorProfile?.medicalLicense ?? 'N/A',
                        iconColor: AppColors.warningOrange,
                      ),
                      _ModernInfoTile(
                        icon: Icons.local_hospital_rounded,
                        label: 'Hospital',
                        value: doctor?.doctorProfile?.hospitalName ?? 'N/A',
                        iconColor: AppColors.primaryGreen,
                        showDivider: false,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                if (doctor?.doctorProfile?.bio != null && doctor!.doctorProfile!.bio!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _SectionCard(
                      title: 'About',
                      icon: Icons.article_rounded,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Text(
                            doctor.doctorProfile!.bio!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color.fromARGB(255, 75, 86, 96),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 12),

                // ── Consultation Information ────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _SectionCard(
                    title: 'Consultation Details',
                    icon: Icons.payments_rounded,
                    children: [
                      _ModernInfoTile(
                        icon: Icons.money,
                        label: 'Consultation Fee',
                        value:
                            'GHS${doctor?.doctorProfile?.consultationFee ?? 'N/A'}',
                        iconColor: AppColors.emergencyRed,
                        valueWidget:
                            doctor?.doctorProfile?.consultationFee != null
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryGreen.withValues(alpha: 
                                    0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.primaryGreen.withValues(alpha: 
                                      0.3,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  'GHS${doctor!.doctorProfile!.consultationFee}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                              )
                            : null,
                        showDivider: false,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Action Buttons ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      // Logout
                      GestureDetector(
                        onTap: () => _showLogoutDialog(context, authService),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: AppColors.emergencyRed.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.emergencyRed.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.logout_rounded,
                                color: AppColors.emergencyRed,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Logout',
                                style: TextStyle(
                                  color: AppColors.emergencyRed,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthService authService) {
    final navigator = Navigator.of(context, rootNavigator: true);

    showDialog(
      context: context,
      builder: (context) => ConfirmDialog(
        title: 'Logout',
        message: 'Are you sure you want to logout?',
        confirmButtonText: 'Logout',
        cancelButtonText: 'Cancel',
        confirmButtonColor: AppColors.emergencyRed,
        onConfirm: () async {
          Navigator.of(context, rootNavigator: true).pop();

          // First logout to clear auth state
          await authService.logout();

          navigator.pushNamedAndRemoveUntil('/login', (route) => false);
        },
      ),
    );
  }
}

class _AvatarEditButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AvatarEditButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppColors.textGray.withValues(alpha: 0.6),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.edit_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }
}

class _HeroActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HeroActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ProfileStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          maxLines: 1,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            overflow: TextOverflow.ellipsis,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withValues(alpha: 0.05),
            blurRadius: 12,
            spreadRadius: -2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Icon(icon, size: 16, color: AppColors.textGray),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textGray,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          ...children,
        ],
      ),
    );
  }
}

class _ModernInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  final bool showDivider;
  final Widget? valueWidget;

  const _ModernInfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
    this.showDivider = true,
    this.valueWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textGray,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
              ?valueWidget,
            ],
          ),
        ),
        if (showDivider)
          const Padding(
            padding: EdgeInsets.only(left: 66),
            child: Divider(height: 1, color: Color(0xFFF0F0F0)),
          ),
      ],
    );
  }
}
