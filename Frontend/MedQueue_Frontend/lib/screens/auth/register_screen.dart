import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../../services/auth_service.dart';
import '../../utils/api_constants.dart';
import '../../utils/app_colors.dart';
import '../../routes/app_routes.dart';

class RegisterScreen extends StatefulWidget {
  final String? role;
  const RegisterScreen({super.key, this.role});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _selectedRole;

  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  final _addressController = TextEditingController();
  final _bloodGroupController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;
  String _selectedGender = 'unspecified';
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  final ImagePicker _imagePicker = ImagePicker();

  bool _hasSpecialCharacter(String value) {
    final specialCharRegex = RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-\\/\[\]`~+=;]');
    return specialCharRegex.hasMatch(value);
  }

  @override
  void initState() {
    super.initState();
    _selectedRole = 'patient';
  }

  Future<void> _pickProfileImage() async {
    final pickedFile = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _selectedImage = pickedFile;
        _selectedImageBytes = bytes;
      });
    }
  }

  void _removeProfileImage() {
    setState(() {
      _selectedImage = null;
      _selectedImageBytes = null;
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _dateOfBirthController.dispose();
    _addressController.dispose();
    _bloodGroupController.dispose();
    _emergencyContactController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  void _handleRegister(AuthService authService) async {
    if (!_formKey.currentState!.validate()) return;
    final success = await authService.registerWithPicture(
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      whatsappNumber: _whatsappController.text.isEmpty
          ? null
          : _whatsappController.text.trim(),
      password: _passwordController.text,
      passwordConfirm: _passwordConfirmController.text,
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      role: _selectedRole,
      gender: _selectedGender,
      dateOfBirth: _dateOfBirthController.text.isEmpty
          ? null
          : _dateOfBirthController.text,
      address: _addressController.text.isEmpty
          ? null
          : _addressController.text.trim(),
      bloodGroup: _bloodGroupController.text.isEmpty
          ? null
          : _bloodGroupController.text,
      emergencyContactName: _emergencyContactController.text.isEmpty
          ? null
          : _emergencyContactController.text.trim(),
      emergencyContactPhone: _emergencyPhoneController.text.isEmpty
          ? null
          : _emergencyPhoneController.text.trim(),
      profilePictureBytes: _selectedImageBytes,
      profilePictureFilename: _selectedImage?.name,
    );
    if (!mounted) return;
    if (success) {
      _showOTPDialog(authService);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sign up failed, ensure correct inputs'),
        backgroundColor: AppColors.errorRed,
      ),
    );
  }

  void _showOTPDialog(AuthService authService) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _OTPDialog(
        email: _emailController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        onSuccess: () {
          Navigator.pop(context);
          Navigator.pushReplacementNamed(context, AppRoutes.patientHome);
        },
      ),
    );
  }

  // ── FIELD BUILDER ─────────────────────────────────────────────
  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    bool readOnly = false,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboard,
    int maxLines = 1,
    String? hint,
    String? errorText,
    String? Function(String?)? validator,
    VoidCallback? onTap,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      readOnly: readOnly,
      obscureText: obscure,
      keyboardType: keyboard,
      maxLines: maxLines,
      onTap: onTap,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
        prefixIcon: Icon(icon, size: 20, color: AppColors.textGray),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        labelStyle:
            const TextStyle(color: AppColors.textGray, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: AppColors.borderColor.withValues(alpha: 0.6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: AppColors.primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.errorRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: AppColors.errorRed, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 15, color: AppColors.primaryBlue),
          ),
          const SizedBox(width: 9),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              color: AppColors.borderColor.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
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
        title: const Column(
          children: [
            Text(
              'Create Account',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3),
            ),
            Text(
              'Join MedQueue GH',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Consumer<AuthService>(
          builder: (context, authService, _) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // ── Hero header strip ──────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryBlue,
                          AppColors.primaryGreen
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(32),
                        bottomRight: Radius.circular(32),
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          right: -20,
                          top: -10,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.07),
                            ),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.health_and_safety_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Patient Registration',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Fill in your details to get started with MedQueue',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ── Form body ──────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── Error banner ─────────────────
                          if (authService.errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.errorRed.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: AppColors.errorRed
                                        .withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded,
                                      color: AppColors.errorRed, size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      authService.errorMessage!,
                                      style: const TextStyle(
                                          color: AppColors.errorRed,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // ── Account Info ─────────────────
                          _sectionHeader(
                              'Account Information', Icons.manage_accounts_rounded),
                          _field(
                            controller: _usernameController,
                            label: 'Username',
                            icon: Icons.alternate_email_rounded,
                            enabled: !authService.isLoading,
                            errorText: authService.fieldErrors?['username'] != null
                                ? (authService.fieldErrors!['username'] as List).first
                                : null,
                            validator: (v) {
                              final value = v?.trim() ?? '';
                              if (value.isEmpty) return 'Username is required';
                              if (value.length < 3) return 'At least 3 characters';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          _field(
                            controller: _emailController,
                            label: 'Email Address',
                            icon: Icons.mail_outline_rounded,
                            keyboard: TextInputType.emailAddress,
                            enabled: !authService.isLoading,
                            errorText: authService.fieldErrors?['email'] != null
                                ? (authService.fieldErrors!['email'] as List).first
                                : null,
                            validator: (v) {
                              final value = v?.trim() ?? '';
                              if (value.isEmpty) return 'Email is required';
                              if (!value.contains('@')) return 'Enter a valid email';
                              return null;
                            },
                          ),

                          const SizedBox(height: 20),

                          // ── Personal Info ─────────────────
                          _sectionHeader(
                              'Personal Details', Icons.person_rounded),
                          Row(
                            children: [
                              Expanded(
                                child: _field(
                                  controller: _firstNameController,
                                  label: 'First Name',
                                  icon: Icons.badge_rounded,
                                  enabled: !authService.isLoading,
                                  validator: (v) {
                                    final value = v?.trim() ?? '';
                                    return value.isEmpty ? 'First name is required' : null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _field(
                                  controller: _lastNameController,
                                  label: 'Last Name',
                                  icon: Icons.badge_rounded,
                                  enabled: !authService.isLoading,
                                  validator: (v) {
                                    final value = v?.trim() ?? '';
                                    return value.isEmpty ? 'Last name is required' : null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Gender dropdown
                          DropdownButtonFormField<String>(
                            initialValue: _selectedGender,
                            decoration: InputDecoration(
                              labelText: 'Gender',
                              prefixIcon: const Icon(Icons.wc_rounded,
                                  size: 20, color: AppColors.textGray),
                              filled: true,
                              fillColor: Colors.white,
                              labelStyle: const TextStyle(
                                  color: AppColors.textGray, fontSize: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                    color: AppColors.borderColor
                                        .withValues(alpha: 0.6)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                    color: AppColors.primaryBlue,
                                    width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 16),
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: 'unspecified',
                                  child: Text('Not specified')),
                              DropdownMenuItem(
                                  value: 'male', child: Text('Male')),
                              DropdownMenuItem(
                                  value: 'female', child: Text('Female')),
                              DropdownMenuItem(
                                  value: 'other', child: Text('Other')),
                            ],
                            onChanged: (v) => setState(
                                () => _selectedGender = v ?? 'unspecified'),
                          ),
                          const SizedBox(height: 12),
                          _field(
                            controller: _dateOfBirthController,
                            label: 'Date of Birth (optional)',
                            icon: Icons.cake_rounded,
                            readOnly: true,
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: DateTime(2000),
                                firstDate: DateTime(1950),
                                lastDate: DateTime.now(),
                                builder: (ctx, child) => Theme(
                                  data: Theme.of(ctx).copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: AppColors.primaryBlue,
                                    ),
                                  ),
                                  child: child!,
                                ),
                              );
                              if (date != null) {
                                _dateOfBirthController.text =
                                    date.toString().split(' ')[0];
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          _field(
                            controller: _addressController,
                            label: 'Address (optional)',
                            icon: Icons.location_on_rounded,
                            maxLines: 2,
                            enabled: !authService.isLoading,
                          ),

                          const SizedBox(height: 16),

                          // ── Profile Picture ───────────────
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: AppColors.primaryBlue
                                      .withValues(alpha: 0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                        Icons.photo_camera_rounded,
                                        color: AppColors.primaryBlue,
                                        size: 20),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Profile Picture (optional)',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primaryBlue),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (_selectedImage != null) ...[
                                  Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      image: DecorationImage(
                                        image: MemoryImage(_selectedImageBytes!),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: authService.isLoading
                                            ? null
                                            : _pickProfileImage,
                                        icon: const Icon(Icons
                                            .image_rounded),
                                        label: const Text(
                                            'Change'),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        onPressed: authService.isLoading
                                            ? null
                                            : _removeProfileImage,
                                        icon: const Icon(Icons
                                            .delete_rounded),
                                        label: const Text(
                                            'Remove'),
                                        style:
                                            ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppColors.errorRed,
                                        ),
                                      ),
                                    ],
                                  ),
                                ] else
                                  ElevatedButton.icon(
                                    onPressed: authService.isLoading
                                        ? null
                                        : _pickProfileImage,
                                    icon: const Icon(Icons
                                        .image_rounded),
                                    label: const Text(
                                        'Pick Picture'),
                                  ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ── Contact ───────────────────────
                          _sectionHeader(
                              'Contact Details', Icons.contact_phone_rounded),
                          _field(
                            controller: _phoneController,
                            label: 'Phone Number',
                            hint: '020*******',
                            icon: Icons.phone_rounded,
                            keyboard: TextInputType.phone,
                            enabled: !authService.isLoading,
                            errorText: authService.fieldErrors?['phone_number'] != null
                                ? (authService.fieldErrors!['phone_number'] as List).first
                                : null,
                            validator: (v) {
                              final value = v?.trim() ?? '';
                              if (value.isEmpty) return 'Phone number is required';
                              if (value.length < 10) return 'Enter a valid phone number';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          _field(
                            controller: _whatsappController,
                            label: 'WhatsApp Number (optional)',
                            icon: Icons.chat_rounded,
                            keyboard: TextInputType.phone,
                            enabled: !authService.isLoading,
                          ),

                          const SizedBox(height: 20),

                          // ── Medical Info ──────────────────
                          _sectionHeader(
                              'Medical Information', Icons.medical_information_rounded),

                          // Blood Group
                          DropdownButtonFormField<String>(
                            initialValue: _bloodGroupController.text.isEmpty
                                ? null
                                : _bloodGroupController.text,
                            decoration: InputDecoration(
                              labelText: 'Blood Group (optional)',
                              prefixIcon: const Icon(Icons.bloodtype_rounded,
                                  size: 20, color: AppColors.textGray),
                              filled: true,
                              fillColor: Colors.white,
                              labelStyle: const TextStyle(
                                  color: AppColors.textGray, fontSize: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                    color: AppColors.borderColor
                                        .withValues(alpha: 0.6)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                    color: AppColors.primaryBlue,
                                    width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 16),
                            ),
                            items: ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-']
                                .map((g) => DropdownMenuItem(
                                    value: g, child: Text(g)))
                                .toList(),
                            onChanged: (v) =>
                                _bloodGroupController.text = v ?? '',
                          ),
                          const SizedBox(height: 12),
                          _field(
                            controller: _emergencyContactController,
                            label: 'Emergency Contact Name (optional)',
                            icon: Icons.contact_emergency_rounded,
                            enabled: !authService.isLoading,
                          ),
                          const SizedBox(height: 12),
                          _field(
                            controller: _emergencyPhoneController,
                            label: 'Emergency Contact Phone (optional)',
                            icon: Icons.phone_in_talk_rounded,
                            keyboard: TextInputType.phone,
                            enabled: !authService.isLoading,
                          ),

                          const SizedBox(height: 20),

                          // ── Security ──────────────────────
                          _sectionHeader(
                              'Security', Icons.lock_rounded),
                          _field(
                            controller: _passwordController,
                            label: 'Password',
                            icon: Icons.lock_outline_rounded,
                            obscure: _obscurePassword,
                            enabled: !authService.isLoading,
                            hint: 'At least 6 characters and a special character',
                            suffix: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                size: 20,
                                color: AppColors.textGray,
                              ),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                            ),
                            validator: (v) {
                              final value = v ?? '';
                              if (value.isEmpty) return 'Password is required';
                              if (value.length < 6) return 'Password must be at least 6 characters';
                              if (!_hasSpecialCharacter(value)) {
                                return 'Password must include at least one special character';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          _field(
                            controller: _passwordConfirmController,
                            label: 'Confirm Password',
                            icon: Icons.lock_outline_rounded,
                            obscure: _obscurePasswordConfirm,
                            enabled: !authService.isLoading,
                            suffix: IconButton(
                              icon: Icon(
                                _obscurePasswordConfirm
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                size: 20,
                                color: AppColors.textGray,
                              ),
                              onPressed: () => setState(() =>
                                  _obscurePasswordConfirm =
                                      !_obscurePasswordConfirm),
                            ),
                            validator: (v) {
                              final value = v ?? '';
                              if (value.isEmpty) return 'Please confirm your password';
                              if (value != _passwordController.text) return 'Passwords do not match';
                              return null;
                            },
                          ),

                          const SizedBox(height: 28),

                          // ── Submit button ─────────────────
                          GestureDetector(
                            onTap: authService.isLoading
                                ? null
                                : () => _handleRegister(authService),
                            child: Container(
                              width: double.infinity,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                gradient: authService.isLoading
                                    ? null
                                    : const LinearGradient(
                                        colors: [
                                          AppColors.primaryBlue,
                                          AppColors.primaryGreen,
                                        ],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                color: authService.isLoading
                                    ? AppColors.backgroundGray
                                    : null,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: authService.isLoading
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: AppColors.primaryBlue
                                              .withValues(alpha: 0.35),
                                          blurRadius: 16,
                                          spreadRadius: -2,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                              ),
                              child: Center(
                                child: authService.isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  AppColors.textGray),
                                        ),
                                      )
                                    : const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                              Icons.health_and_safety_rounded,
                                              color: Colors.white,
                                              size: 18),
                                          SizedBox(width: 8),
                                          Text(
                                            'Create My Account',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ── Sign in link ──────────────────
                          Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 14, horizontal: 20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color:
                                      AppColors.borderColor.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Already have an account?',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textGray),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: authService.isLoading
                                      ? null
                                      : () => Navigator.pushNamed(
                                          context, AppRoutes.login),
                                  child: const Text(
                                    'Sign In',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primaryBlue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 28),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OTPDialog extends StatefulWidget {
  final String email;
  final String phoneNumber;
  final VoidCallback onSuccess;

  const _OTPDialog({
    required this.email,
    required this.onSuccess,
    this.phoneNumber = '',
  });

  @override
  State<_OTPDialog> createState() => _OTPDialogState();
}

class _OTPDialogState extends State<_OTPDialog> {
  final _otpController = TextEditingController();
  late AuthService _authService;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    _authService = Provider.of<AuthService>(context, listen: false);
    _sendOTP();
  }

  Future<void> _sendOTP() async {
    await _authService.sendOTP(widget.phoneNumber, OtpPurpose.phoneReg.value);
  }

  void _handleVerify() async {
    if (_otpController.text.isEmpty || _otpController.text.length != ApiConstants.otpLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid ${ApiConstants.otpLength}-digit OTP')),
      );
      return;
    }

    setState(() => _verifying = true);
    bool success = false;
    try {
      success = await _authService.verifyOTP(
        phoneNumber: widget.phoneNumber,
        code: _otpController.text,
        purpose: OtpPurpose.phoneReg.value,
      );
    } finally {
      if (mounted) setState(() => _verifying = false);
    }

    if (success) {
      if (mounted) widget.onSuccess();
    } else {
      final message = _authService.errorMessage ??
          'Verification failed. Please try again.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

 @override
Widget build(BuildContext context) {
  return Dialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    backgroundColor: Colors.white,
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Consumer<AuthService>(
        builder: (context, authService, _) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Icon header ──────────────────────────────
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryBlue, AppColors.primaryGreen],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(height: 18),

              // ── Title & subtitle ─────────────────────────
              const Text(
                'Verify Your Identity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Enter the ${ApiConstants.otpLength}-digit code sent to '
                'your number or email you provided.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textGray,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              // ── Error banner ─────────────────────────────
              if (authService.errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.errorRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.errorRed.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppColors.errorRed, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          authService.errorMessage!,
                          style: const TextStyle(
                            color: AppColors.errorRed,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── OTP input ────────────────────────────────
              TextField(
                controller: _otpController,
                autofocus: true,
                maxLength: ApiConstants.otpLength,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 10,
                  color: AppColors.textDark,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '000000',
                  hintStyle: TextStyle(
                    fontSize: 24,
                    letterSpacing: 10,
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w400,
                  ),
                  filled: true,
                  fillColor: AppColors.backgroundLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                        color: AppColors.primaryBlue, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 18),
                ),
              ),

              const SizedBox(height: 24),

              // ── Buttons ──────────────────────────────────
              Row(
                children: [
                  // Cancel
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundGray,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textGray,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Verify
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: _verifying ? null : _handleVerify,
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: _verifying
                              ? null
                              : const LinearGradient(
                                  colors: [
                                    AppColors.primaryBlue,
                                    AppColors.primaryGreen,
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                          color: _verifying
                              ? AppColors.backgroundGray
                              : null,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: _verifying
                              ? null
                              : [
                                  BoxShadow(
                                    color: AppColors.primaryBlue
                                        .withValues(alpha: 0.35),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                        ),
                        child: Center(
                          child: _verifying
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(
                                            AppColors.textGray),
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle_rounded,
                                        color: Colors.white, size: 17),
                                    SizedBox(width: 7),
                                    Text(
                                      'Verify',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    ),
  );
}
}