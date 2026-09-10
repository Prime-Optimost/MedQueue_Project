import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_management_model.dart';
import '../../services/admin_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_textfield.dart';

/// Modal bottom sheet that lets an admin edit an existing user's profile.
void showEditUserSheet(BuildContext context, AdminUserEntry user) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.backgroundLight,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => EditUserSheet(user: user),
  );
}

class EditUserSheet extends StatefulWidget {
  final AdminUserEntry user;

  const EditUserSheet({super.key, required this.user});

  @override
  State<EditUserSheet> createState() => _EditUserSheetState();
}

class _EditUserSheetState extends State<EditUserSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _specializationController;
  late final TextEditingController _hospitalController;
  late final TextEditingController _feeController;

  late bool _isAcceptingPatients;
  bool _submitting = false;

  bool get _isDoctor => widget.user.role == 'doctor';

  String _formatFee(double? fee) {
    if (fee == null || fee <= 0) return '';
    return fee == fee.roundToDouble() ? fee.round().toString() : fee.toString();
  }

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.user.firstName);
    _lastNameController = TextEditingController(text: widget.user.lastName);
    _emailController = TextEditingController(text: widget.user.email);
    _phoneController = TextEditingController(text: widget.user.phoneNumber);
    _specializationController = TextEditingController(
      text: widget.user.doctorProfile?.specialization ?? '',
    );
    _hospitalController = TextEditingController(
      text: widget.user.doctorProfile?.hospitalName ?? '',
    );
    _feeController = TextEditingController(
      text: _formatFee(widget.user.doctorProfile?.consultationFee),
    );
    _isAcceptingPatients = widget.user.doctorProfile?.isAcceptingPatients ?? true;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _specializationController.dispose();
    _hospitalController.dispose();
    _feeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    final adminService = context.read<AdminService>();
    final success = await adminService.updateUser(
      widget.user.id,
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
      email: _emailController.text,
      phoneNumber: _phoneController.text,
      specialization: _isDoctor ? _specializationController.text : null,
      hospitalName: _isDoctor ? _hospitalController.text : null,
      consultationFee: _isDoctor ? _feeController.text : null,
      isAcceptingPatients: _isDoctor ? _isAcceptingPatients : null,
    );

    if (!mounted) return;

    setState(() => _submitting = false);

    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User updated successfully.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(adminService.errorMessage ?? 'Failed to update user.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textLight,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Edit User',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Editing @${widget.user.username}',
              style: const TextStyle(fontSize: 13, color: AppColors.textGray),
            ),
            const SizedBox(height: 20),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  CustomTextField(
                    label: 'First Name',
                    hint: 'e.g. Kwame',
                    controller: _firstNameController,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'First name is required'
                        : null,
                  ),
                  CustomTextField(
                    label: 'Last Name',
                    hint: 'e.g. Mensah',
                    controller: _lastNameController,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Last name is required'
                        : null,
                  ),
                  CustomTextField(
                    label: 'Email',
                    hint: 'e.g. user@hospital.com',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Email is required'
                        : null,
                  ),
                  CustomTextField(
                    label: 'Phone Number',
                    hint: 'e.g. +233201234567',
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Phone number is required'
                        : null,
                  ),
                  if (_isDoctor) ...[
                    CustomTextField(
                      label: 'Specialization',
                      hint: 'e.g. Cardiology',
                      controller: _specializationController,
                    ),
                    CustomTextField(
                      label: 'Hospital',
                      hint: 'e.g. UENR Hospital',
                      controller: _hospitalController,
                    ),
                    CustomTextField(
                      label: 'Consultation Fee (GHS)',
                      hint: 'e.g. 150',
                      controller: _feeController,
                      keyboardType: TextInputType.number,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Accepting new patients',
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      value: _isAcceptingPatients,
                      activeTrackColor: AppColors.primaryBlue,
                      onChanged: (v) => setState(() => _isAcceptingPatients = v),
                    ),
                  ],
                  const SizedBox(height: 8),
                  CustomButton(
                    label: 'Save Changes',
                    isLoading: _submitting,
                    icon: Icons.save,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
