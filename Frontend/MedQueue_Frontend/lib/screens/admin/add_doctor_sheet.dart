import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/admin_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_textfield.dart';

/// Modal bottom sheet form that lets an admin create a new doctor account.
void showAddDoctorSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.backgroundLight,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const AddDoctorSheet(),
  );
}

class AddDoctorSheet extends StatefulWidget {
  const AddDoctorSheet({super.key});

  @override
  State<AddDoctorSheet> createState() => _AddDoctorSheetState();
}

class _AddDoctorSheetState extends State<AddDoctorSheet> {
  final _formKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _specializationController = TextEditingController();
  final _hospitalController = TextEditingController();
  final _feeController = TextEditingController();

  bool _submitting = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _passwordController.dispose();
    _specializationController.dispose();
    _hospitalController.dispose();
    _feeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      // Give immediate feedback so the user knows the tap registered even if a
      // field (possibly scrolled out of view) is invalid.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please check the highlighted fields and try again.'),
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    final adminService = context.read<AdminService>();
    final success = await adminService.createUser(
      username: _usernameController.text,
      email: _emailController.text,
      phoneNumber: _phoneController.text,
      password: _passwordController.text,
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
      role: 'doctor',
      specialization: _specializationController.text,
      hospitalName: _hospitalController.text,
      consultationFee: _feeController.text,
    );

    if (!mounted) return;

    setState(() => _submitting = false);

    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doctor account created successfully.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(adminService.errorMessage ?? 'Failed to create doctor account.')),
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
              'Add Doctor',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Create a doctor account on the platform. The doctor can log in with these credentials.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textGray,
              ),
            ),
            const SizedBox(height: 20),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  CustomTextField(
                    label: 'Username',
                    hint: 'e.g. drkwame',
                    controller: _usernameController,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Username is required'
                        : null,
                  ),
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
                    hint: 'e.g. kwame@hospital.com',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  CustomTextField(
                    label: 'Phone Number',
                    hint: 'e.g. +233201234567',
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                  ),
                  CustomTextField(
                    label: 'Password',
                    hint: 'Min 8 characters',
                    controller: _passwordController,
                    isPassword: true,
                    validator: (v) => (v == null || v.length < 8)
                        ? 'Password must be at least 8 characters'
                        : null,
                  ),
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
                  const SizedBox(height: 8),
                  CustomButton(
                    label: 'Create Doctor',
                    isLoading: _submitting,
                    icon: Icons.add,
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
