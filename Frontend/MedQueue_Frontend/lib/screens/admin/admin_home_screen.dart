import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import '../../services/emergency_service.dart';
import '../../models/emergency_model.dart';
import '../../utils/app_colors.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_components.dart';
import '../../widgets/notification_bell.dart';
import 'add_doctor_sheet.dart';
import 'live_queue_screen.dart';
import 'reports_screen.dart';
import 'user_management_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Pre-fetch system overview on load so the dashboard shows real numbers.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AdminService>().fetchDashboardStats();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        centerTitle: true,
        elevation: 0,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: NotificationBell(),
          ),
        ],
      ),
      body: _getBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.emergency),
            label: 'Emergency',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Users'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _getBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildHome();
      case 1:
        return _buildEmergencies();
      case 2:
        return _buildUsers();
      case 3:
        return _buildProfile();
      default:
        return _buildHome();
    }
  }

  Widget _buildHome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryBlue,
                    AppColors.primaryBlue.withValues(alpha: 0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, Administrator',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'System Health Check',
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'System Overview',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
          Consumer<AdminService>(
            builder: (context, adminService, _) {
              final stats = adminService.dashboardStats;

              if (stats == null) {
                return const CustomLoadingIndicator(
                  message: 'Loading system overview...',
                );
              }

              return Column(
                children: [
                  Row(
                    children: [
                      _AdminStatCard(
                        label: 'Total Users',
                        value: '${stats.totalUsers}',
                        color: AppColors.primaryBlue,
                        icon: Icons.people,
                      ),
                      const SizedBox(width: 12),
                      _AdminStatCard(
                        label: 'Doctors',
                        value: '${stats.doctors}',
                        color: AppColors.primaryGreen,
                        icon: Icons.local_hospital,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _AdminStatCard(
                        label: 'Appointments',
                        value: '${stats.totalAppointments}',
                        color: AppColors.warningOrange,
                        icon: Icons.calendar_today,
                      ),
                      const SizedBox(width: 12),
                      _AdminStatCard(
                        label: 'Emergencies',
                        value: '${stats.totalEmergencies}',
                        color: AppColors.emergencyRed,
                        icon: Icons.emergency,
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
          CustomButton(
            label: 'Generate Reports',
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ReportsScreen()));
            },
          ),
          const SizedBox(height: 12),
          OutlineCustomButton(
            label: 'View Live Queue',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LiveQueueScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencies() {
    return Consumer<EmergencyService>(
      builder: (context, emergencyService, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              !emergencyService.isLoading &&
              emergencyService.emergencies.isEmpty) {
            emergencyService.getEmergencies();
          }
        });

        if (emergencyService.isLoading &&
            emergencyService.emergencies.isEmpty) {
          return const CustomLoadingIndicator(
            message: 'Loading emergencies...',
          );
        }

        final emergencies = emergencyService.emergencies;
        if (emergencies.isEmpty) {
          return EmptyState(
            icon: Icons.check_circle,
            title: 'No Emergencies',
            message: 'No SOS records found',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: emergencies.length,
          itemBuilder: (context, index) {
            final emergency = emergencies[index];
            final isActive =
                emergency.status == EmergencyStatus.pending ||
                emergency.status == EmergencyStatus.dispatched;
            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
                                emergency.patientName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                emergency.description.isEmpty
                                    ? _emergencyTypeLabel(
                                        emergency.emergencyType,
                                      )
                                    : emergency.description,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textGray,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.emergencyRed.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _statusLabel(emergency.status),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.emergencyRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (isActive) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (emergency.status == EmergencyStatus.pending) ...[
                            Expanded(
                              child: CustomButton(
                                label: 'Dispatch',
                                onPressed: () async {
                                  await emergencyService.updateEmergencyStatus(
                                    emergency.id,
                                    EmergencyStatus.dispatched,
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Emergency dispatched'),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                          ] else if (emergency.status ==
                              EmergencyStatus.dispatched) ...[
                            Expanded(
                              child: CustomButton(
                                label: 'Mark Resolved',
                                onPressed: () async {
                                  await emergencyService.updateEmergencyStatus(
                                    emergency.id,
                                    EmergencyStatus.resolved,
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Emergency resolved'),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: OutlineCustomButton(
                              label: 'False Alarm',
                              textColor: AppColors.emergencyRed,
                              borderColor: AppColors.emergencyRed,
                              onPressed: () async {
                                await emergencyService.updateEmergencyStatus(
                                  emergency.id,
                                  EmergencyStatus.falseAlarm,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Marked as false alarm'),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _statusLabel(EmergencyStatus status) {
    switch (status) {
      case EmergencyStatus.pending:
        return 'Pending';
      case EmergencyStatus.dispatched:
        return 'Dispatched';
      case EmergencyStatus.resolved:
        return 'Resolved';
      case EmergencyStatus.cancelled:
        return 'Cancelled';
      case EmergencyStatus.falseAlarm:
        return 'False Alarm';
    }
  }

  String _emergencyTypeLabel(String type) {
    switch (type) {
      case 'ambulance':
        return 'Ambulance Request';
      case 'cardiac':
        return 'Cardiac / Chest Pain';
      case 'accident':
        return 'Accident / Trauma';
      case 'maternity':
        return 'Maternity Emergency';
      case 'other':
        return 'Other Emergency';
      case 'medical':
      default:
        return 'Medical Emergency';
    }
  }

  Widget _buildUsers() {
    return Consumer<AdminService>(
      builder: (context, adminService, _) {
        final stats = adminService.dashboardStats;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              const Icon(Icons.people, size: 80, color: AppColors.textLight),
              const SizedBox(height: 16),
              const Text(
                'User Management',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 24),
              if (stats == null)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: CustomLoadingIndicator(
                    message: 'Loading system overview...',
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primaryBlue.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      _UserCountRow(
                        label: 'Total Users',
                        value: stats.totalUsers,
                      ),
                      const Divider(height: 20),
                      _UserCountRow(label: 'Doctors', value: stats.doctors),
                      const SizedBox(height: 8),
                      _UserCountRow(label: 'Patients', value: stats.patients),
                      const SizedBox(height: 8),
                      _UserCountRow(label: 'Admins', value: stats.admins),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              CustomButton(
                label: 'Add Doctor',
                icon: Icons.person_add,
                onPressed: () => showAddDoctorSheet(context),
              ),
              const SizedBox(height: 12),
              OutlineCustomButton(
                label: 'Manage All Users',
                icon: Icons.group,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const UserManagementScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfile() {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        final admin = authService.currentUser;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.admin_panel_settings,
                  size: 60,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                admin?.fullName ?? 'Administrator',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Admin Panel',
                style: const TextStyle(fontSize: 14, color: AppColors.textGray),
              ),
              const SizedBox(height: 32),
              OutlineCustomButton(
                label: 'Logout',
                textColor: AppColors.emergencyRed,
                borderColor: AppColors.emergencyRed,
                onPressed: () async {
                  await authService.logout();
                  if (context.mounted) {
                    // Take the same reliable path as the doctor app: clear all
                    // routes and land on the login screen explicitly.
                    Navigator.of(
                      context,
                      rootNavigator: true,
                    ).pushNamedAndRemoveUntil('/login', (route) => false);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AdminStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _AdminStatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.textGray),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _UserCountRow extends StatelessWidget {
  final String label;
  final int value;

  const _UserCountRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 15, color: AppColors.textDark),
          ),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryBlue,
            ),
          ),
        ],
      ),
    );
  }
}
