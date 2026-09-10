import 'package:flutter/material.dart';
import 'package:medqueue_frontend/services/appointment_service.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../utils/app_colors.dart';
import 'package:medqueue_frontend/screens/patient/edit_patient_profile_screen.dart';
import '../../widgets/custom_components.dart';

class PatientProfileScreen extends StatefulWidget {
  const PatientProfileScreen({super.key});

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Consumer<AuthService>(
        builder: (context, authService, appointmentService) {
          final user = authService.currentUser;
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
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
                        child: Column(
                          children: [
                       // Avatar
                       user?.profilePictureUrl != null && user?.profilePictureUrl?.isNotEmpty == true
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
                                   user!.profilePictureUrl!,
                                   fit: BoxFit.cover,
                                   width: 96,
                                   height: 96,
                                   errorBuilder: (context, error, stackTrace) {
                                     return const Icon(
                                       Icons.person_rounded,
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
                                 Icons.person_rounded,
                                 size: 52,
                                 color: Colors.white,
                               ),
                             ),
                            const SizedBox(height: 16),
                            Text(
                              user?.fullName ?? 'Patient',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.4,
                              ),
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
                                user?.email ?? '',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Stats row
                            //consume by appointment count
                            Consumer<AppointmentService>(
                              builder: (context, appointmentService, child) {
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _ProfileStat(
                                      label: 'Appointments',
                                      value:
                                          '${appointmentService.appointmentCount}',
                                      icon: Icons.calendar_month_rounded,
                                    ),
                                    Container(
                                      width: 1,
                                      height: 36,
                                      color: Colors.white.withValues(alpha: 0.3),
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                      ),
                                    ),
                                    _ProfileStat(
                                      label: 'Blood Type',
                                      value:
                                          user?.patientProfile?.bloodGroup ??
                                          '—',
                                      icon: Icons.bloodtype_rounded,
                                    ),
                                    Container(
                                      width: 1,
                                      height: 36,
                                      color: Colors.white.withValues(alpha: 0.3),
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                      ),
                                    ),
                                    _ProfileStat(
                                      label: 'Status',
                                      value: 'Active',
                                      icon: Icons.verified_rounded,
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Personal Info Card ───────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _SectionCard(
                    title: 'Personal Information',
                    icon: Icons.person_outline_rounded,
                    children: [
                      _ModernInfoTile(
                        icon: Icons.phone_rounded,
                        label: 'Phone',
                        value: user?.phoneNumber ?? 'N/A',
                        iconColor: AppColors.primaryBlue,
                      ),
                      _ModernInfoTile(
                        icon: Icons.cake_rounded,
                        label: 'Date of Birth',
                        value: user?.dateOfBirth ?? 'N/A',
                        iconColor: AppColors.primaryGreen,
                        showDivider: false,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── Medical Info Card ────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _SectionCard(
                    title: 'Medical Information',
                    icon: Icons.medical_information_rounded,
                    children: [
                      _ModernInfoTile(
                        icon: Icons.bloodtype_rounded,
                        label: 'Blood Type',
                        value: user?.patientProfile?.bloodGroup ?? 'N/A',
                        iconColor: AppColors.emergencyRed,
                        valueWidget: user?.patientProfile?.bloodGroup != null
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.emergencyRed.withValues(alpha: 
                                    0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.emergencyRed.withValues(alpha: 
                                      0.3,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  user!.patientProfile!.bloodGroup!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.emergencyRed,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      _ModernInfoTile(
                        icon: Icons.contact_emergency_rounded,
                        label: 'Emergency Contact',
                        value:
                            '${user?.patientProfile?.emergencyContactName ?? 'N/A'}\n${user?.patientProfile?.emergencyContactPhone ?? ''}',
                        iconColor: AppColors.warningOrange,
                        showDivider: false,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Action Buttons ───────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      // Edit Profile
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const PatientEditProfileScreen(),
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.primaryBlue,
                                AppColors.primaryGreen,
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryBlue.withValues(alpha: 0.35),
                                blurRadius: 16,
                                spreadRadius: -2,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.edit_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Edit Profile',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
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

          // Then clear all navigation routes to ensure LoginScreen shows
          navigator.pushNamedAndRemoveUntil('/login', (route) => false);
        },
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
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
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
