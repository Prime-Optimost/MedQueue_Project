import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_management_model.dart';
import '../../services/admin_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/custom_components.dart';
import '../../widgets/custom_textfield.dart';
import 'add_doctor_sheet.dart';
import 'edit_user_sheet.dart';

/// Full admin user-management screen: search, filter, view, edit and
/// activate/deactivate users.
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _searchController = TextEditingController();
  String _roleFilter = '';
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AdminService>().fetchUsers();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({String? role, String? search}) async {
    final service = context.read<AdminService>();
    await service.fetchUsers(
      role: role ?? _roleFilter,
      search: search ?? _search,
    );
  }

  void _onRoleChanged(String role) {
    setState(() => _roleFilter = role);
    _load(role: role);
  }

  void _onSearchChanged(String value) {
    _search = value;
    _load(search: value);
  }

  Future<void> _confirmToggle(AdminUserEntry user) async {
    final activating = !user.isActive;
    await showDialog<void>(
      context: context,
      builder: (ctx) => ConfirmDialog(
        title: activating ? 'Reactivate User' : 'Deactivate User',
        message: activating
            ? 'Allow ${user.displayName} to log in again?'
            : 'Block ${user.displayName} from logging in? They can be '
                  'reactivated later if needed.',
        confirmButtonText: activating ? 'Reactivate' : 'Deactivate',
        cancelButtonText: 'Cancel',
        onConfirm: () {
          Navigator.pop(ctx);
          _doToggle(user, activating);
        },
      ),
    );
  }

  Future<void> _doToggle(AdminUserEntry user, bool activating) async {
    final service = context.read<AdminService>();
    final ok = await service.setUserActive(user.id, isActive: activating);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (activating
                  ? '${user.displayName} reactivated.'
                  : '${user.displayName} deactivated.')
              : (service.errorMessage ?? 'Action failed.'),
        ),
      ),
    );
  }

  void _openEdit(AdminUserEntry user) {
    showEditUserSheet(context, user);
  }

  Future<void> _confirmDelete(AdminUserEntry user) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => ConfirmDialog(
        title: 'Delete User',
        message: 'Permanently delete ${user.displayName}? '
            'This action cannot be undone and will remove their account data.',
        confirmButtonText: 'Delete',
        confirmButtonColor: AppColors.errorRed,
        cancelButtonText: 'Cancel',
        onConfirm: () {
          Navigator.pop(ctx);
          _doDelete(user);
        },
      ),
    );
  }

  Future<void> _doDelete(AdminUserEntry user) async {
    final service = context.read<AdminService>();
    final ok = await service.deleteUser(user.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? '${user.displayName} deleted.'
              : (service.errorMessage ?? 'Delete failed.'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('User Management'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Add Doctor',
            icon: const Icon(Icons.person_add),
            onPressed: () => showAddDoctorSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchTextField(
              controller: _searchController,
              hint: 'Search name, username, email or phone...',
              onChanged: _onSearchChanged,
              onClear: () => _onSearchChanged(''),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _RoleChip(label: 'All', selected: _roleFilter == '', onTap: () => _onRoleChanged('')),
                const SizedBox(width: 8),
                _RoleChip(
                  label: 'Patients',
                  selected: _roleFilter == 'patient',
                  onTap: () => _onRoleChanged('patient'),
                ),
                const SizedBox(width: 8),
                _RoleChip(
                  label: 'Doctors',
                  selected: _roleFilter == 'doctor',
                  onTap: () => _onRoleChanged('doctor'),
                ),
                const SizedBox(width: 8),
                _RoleChip(
                  label: 'Admins',
                  selected: _roleFilter == 'admin',
                  onTap: () => _onRoleChanged('admin'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Consumer<AdminService>(
      builder: (context, service, _) {
        if (service.usersLoading) {
          return const CustomLoadingIndicator(message: 'Loading users...');
        }
        if (service.usersError != null && service.users.isEmpty) {
          return AppErrorWidget(
            message: service.usersError!,
            onRetry: () => _load(),
          );
        }
        if (service.users.isEmpty) {
          return const EmptyState(
            icon: Icons.people_outline,
            title: 'No users found',
            message: 'Try adjusting your search or role filter.',
          );
        }
        return RefreshIndicator(
          onRefresh: () => _load(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: service.users.length,
            itemBuilder: (context, index) {
              return _UserTile(
                user: service.users[index],
                onEdit: () => _openEdit(service.users[index]),
                onToggleActive: () => _confirmToggle(service.users[index]),
                onDelete: () => _confirmDelete(service.users[index]),
              );
            },
          ),
        );
      },
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RoleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primaryBlue,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textDark,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}

class _UserTile extends StatelessWidget {
  final AdminUserEntry user;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  const _UserTile({
    required this.user,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  IconData get _roleIcon {
    switch (user.role) {
      case 'doctor':
        return Icons.medical_services;
      case 'admin':
        return Icons.admin_panel_settings;
      default:
        return Icons.person;
    }
  }

  Color get _roleColor {
    switch (user.role) {
      case 'doctor':
        return AppColors.primaryBlue;
      case 'admin':
        return AppColors.successGreen;
      default:
        return AppColors.warningOrange;
    }
  }

  String get _roleLabel {
    switch (user.role) {
      case 'doctor':
        return 'Doctor';
      case 'admin':
        return 'Admin';
      default:
        return 'Patient';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDoctor = user.role == 'doctor';
    final subtitle = isDoctor
        ? (user.doctorProfile?.specialization.isNotEmpty ?? false
            ? user.doctorProfile!.specialization
            : 'Doctor')
        : '@${user.username}';

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: user.isActive ? Colors.white : AppColors.backgroundLight,
          border: Border.all(
            color: user.isActive ? Colors.transparent : AppColors.textLight,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: _roleColor.withValues(alpha: 0.15),
              child: Icon(_roleIcon, color: _roleColor, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.displayName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      if (!user.isActive) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.errorRed.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Inactive',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.errorRed,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 13, color: AppColors.textGray),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _RoleBadge(label: _roleLabel, color: _roleColor),
                      if (user.isPhoneVerified)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Row(
                            children: [
                              Icon(Icons.verified, size: 12, color: AppColors.successGreen),
                              SizedBox(width: 2),
                              Text(
                                'Verified',
                                style: TextStyle(fontSize: 11, color: AppColors.successGreen),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit_outlined, color: AppColors.primaryBlue),
                  onPressed: onEdit,
                ),
                IconButton(
                  tooltip: user.isActive ? 'Deactivate' : 'Reactivate',
                  icon: Icon(
                    user.isActive ? Icons.block : Icons.check_circle_outline,
                    color: user.isActive ? AppColors.errorRed : AppColors.successGreen,
                  ),
                  onPressed: onToggleActive,
                ),
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline, color: AppColors.errorRed),
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _RoleBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
