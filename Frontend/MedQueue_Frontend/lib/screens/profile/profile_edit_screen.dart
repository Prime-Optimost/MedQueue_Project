import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

import '../../services/auth_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/api_constants.dart';
import '../../widgets/custom_components.dart';

class ProfileEditScreen extends StatefulWidget {
  final UserRole role;

  const ProfileEditScreen({super.key, required this.role});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _whatsappNumberController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  final _addressController = TextEditingController();
  final _bloodGroupController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _emergencyContactNameController = TextEditingController();
  final _emergencyContactPhoneController = TextEditingController();
  final _medicalHistoryController = TextEditingController();
  final _profilePictureController = TextEditingController();

  final _doctorFirstNameController = TextEditingController();
  final _doctorLastNameController = TextEditingController();
  final _doctorEmailController = TextEditingController();
  final _doctorPhoneController = TextEditingController();
  final _doctorWhatsappController = TextEditingController();
  final _specializationController = TextEditingController();
  final _medicalLicenseController = TextEditingController();
  final _hospitalNameController = TextEditingController();
  final _consultationFeeController = TextEditingController();
  final _yearsOfExperienceController = TextEditingController();
  final _bioController = TextEditingController();
  final _avgConsultationMinutesController = TextEditingController();

  bool _initialized = false;
  bool _submitting = false;
  String _selectedGender = 'unspecified';
  bool _notifPush = true;
  bool _notifSms = true;
  bool _notifWhatsapp = false;
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final user = context.read<AuthService>().currentUser;
    if (user == null) return;

    _firstNameController.text = user.firstName;
    _lastNameController.text = user.lastName;
    _emailController.text = user.email;
    _phoneNumberController.text = user.phoneNumber;
    _whatsappNumberController.text = user.whatsappNumber ?? '';
    _dateOfBirthController.text = user.dateOfBirth ?? '';
    _addressController.text = user.address ?? '';
    _bloodGroupController.text = user.patientProfile?.bloodGroup ?? '';
    _allergiesController.text = user.patientProfile?.allergies ?? '';
    _emergencyContactNameController.text =
        user.patientProfile?.emergencyContactName ?? '';
    _emergencyContactPhoneController.text =
        user.patientProfile?.emergencyContactPhone ?? '';
    _medicalHistoryController.text = user.patientProfile?.medicalHistory ?? '';
    _profilePictureController.text = user.profilePictureUrl ?? '';

    _doctorFirstNameController.text = user.firstName;
    _doctorLastNameController.text = user.lastName;
    _doctorEmailController.text = user.email;
    _doctorPhoneController.text = user.phoneNumber;
    _doctorWhatsappController.text = user.whatsappNumber ?? '';
    _specializationController.text = user.doctorProfile?.specialization ?? '';
    _medicalLicenseController.text = user.doctorProfile?.medicalLicense ?? '';
    _hospitalNameController.text = user.doctorProfile?.hospitalName ?? '';
    _consultationFeeController.text =
        user.doctorProfile?.consultationFee == null
        ? ''
        : user.doctorProfile!.consultationFee!.toString();
    _yearsOfExperienceController.text =
        user.doctorProfile?.yearsOfExperience == null
        ? ''
        : user.doctorProfile!.yearsOfExperience!.toString();
    _bioController.text = user.doctorProfile?.bio ?? '';
    _avgConsultationMinutesController.text =
        user.doctorProfile?.avgConsultationMinutes == null
        ? ''
        : user.doctorProfile!.avgConsultationMinutes!.toString();

    _selectedGender = user.gender ?? 'unspecified';
    _notifPush = user.notifPush;
    _notifSms = user.notifSms;
    _notifWhatsapp = user.notifWhatsapp;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneNumberController.dispose();
    _whatsappNumberController.dispose();
    _dateOfBirthController.dispose();
    _addressController.dispose();
    _bloodGroupController.dispose();
    _allergiesController.dispose();
    _emergencyContactNameController.dispose();
    _emergencyContactPhoneController.dispose();
    _medicalHistoryController.dispose();
    _profilePictureController.dispose();
    _doctorFirstNameController.dispose();
    _doctorLastNameController.dispose();
    _doctorEmailController.dispose();
    _doctorPhoneController.dispose();
    _doctorWhatsappController.dispose();
    _specializationController.dispose();
    _medicalLicenseController.dispose();
    _hospitalNameController.dispose();
    _consultationFeeController.dispose();
    _yearsOfExperienceController.dispose();
    _bioController.dispose();
    _avgConsultationMinutesController.dispose();
    super.dispose();
  }

  Future<void> _pickDateOfBirth() async {
    final current = _dateOfBirthController.text.isNotEmpty
        ? DateTime.tryParse(_dateOfBirthController.text)
        : null;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );

    if (picked != null) {
      setState(() {
        _dateOfBirthController.text =
            '${picked.year.toString().padLeft(4, '0')}-'
            '${picked.month.toString().padLeft(2, '0')}-'
            '${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _pickProfileImage() async {
    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
    );
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authService = context.read<AuthService>();
    final body = _buildPayload();

    setState(() {
      _submitting = true;
    });

    bool success;
    // If profile picture is selected, use multipart upload
    if (_selectedImage != null) {
      final fields = <String, String>{};
      // Add fields from body to fields map
      body.forEach((key, value) {
        if (value != null && value is! Map) {
          fields[key] = value.toString();
        }
      });

      success = await authService.updateProfileWithPicture(
        fields: fields,
        pictureBytes: _selectedImageBytes!,
        pictureFilename: _selectedImage!.name,
      );
    } else {
      success = await authService.updateProfile(body);
    }

    if (!mounted) return;

    setState(() {
      _submitting = false;
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
      Navigator.pop(context);
      return;
    }

    final message = _extractErrorMessage(
      authService.errorMessage,
      authService.fieldErrors,
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Map<String, dynamic> _buildPayload() {
    if (widget.role == UserRole.doctor) {
      final feeText = _consultationFeeController.text.trim();
      final expText = _yearsOfExperienceController.text.trim();
      final avgText = _avgConsultationMinutesController.text.trim();
      final doctorProfilePayload = {
        'specialization': _specializationController.text.trim(),
        'medical_license_number': _medicalLicenseController.text.trim(),
        'hospital_name': _hospitalNameController.text.trim(),
        'consultation_fee': feeText.isEmpty ? null : num.tryParse(feeText),
        'years_of_experience': expText.isEmpty ? null : int.tryParse(expText),
        'bio': _bioController.text.trim(),
        'avg_consultation_minutes': avgText.isEmpty
            ? null
            : int.tryParse(avgText),
        'is_accepting_patients': false,
      };

      final payload = <String, dynamic>{
        'first_name': _doctorFirstNameController.text.trim(),
        'last_name': _doctorLastNameController.text.trim(),
        'email': _doctorEmailController.text.trim(),
        'phone_number': _doctorPhoneController.text.trim(),
        'whatsapp_number': _doctorWhatsappController.text.trim(),
        'profile_picture_url': _profilePictureController.text.trim(),
        'doctor_profile': doctorProfilePayload,
      };

      if (_selectedImage != null) {
        payload.remove('profile_picture_url');
        payload['profile_picture'] = 'multipart_file';
      }

      payload.removeWhere((key, value) {
        if (key == 'doctor_profile') return false;
        if (key == 'profile_picture' || key == 'profile_picture_url') {
          return false;
        }
        return value == null || (value is String && value.trim().isEmpty);
      });

      if (payload.containsKey('doctor_profile')) {
        payload['doctor_profile']!.removeWhere(
          (k, v) =>
              k == 'is_accepting_patients' ||
              v == null ||
              (v is String && v.trim().isEmpty),
        );
      }

      return payload;
    }

    return {
      'first_name': _firstNameController.text.trim(),
      'last_name': _lastNameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone_number': _phoneNumberController.text.trim(),
      'whatsapp_number': _whatsappNumberController.text.trim(),
      'date_of_birth': _dateOfBirthController.text.trim().isEmpty
          ? null
          : _dateOfBirthController.text.trim(),
      'gender': _selectedGender,
      'address': _addressController.text.trim(),
      'profile_picture_url': _profilePictureController.text.trim(),
      'notif_push': _notifPush,
      'notif_sms': _notifSms,
      'notif_whatsapp': _notifWhatsapp,
      'patient_profile': {
        'blood_group': _bloodGroupController.text.trim(),
        'allergies': _allergiesController.text.trim(),
        'emergency_contact_name': _emergencyContactNameController.text.trim(),
        'emergency_contact_phone': _emergencyContactPhoneController.text.trim(),
        'medical_history': _medicalHistoryController.text.trim(),
      },
    };
  }

  String _extractErrorMessage(String? message, Map<String, dynamic>? errors) {
    if (errors != null && errors.isNotEmpty) {
      final firstEntry = errors.entries.first;
      final value = firstEntry.value;
      if (value is List && value.isNotEmpty) {
        return value.first.toString();
      }
      if (value is String && value.isNotEmpty) {
        return value;
      }
      return '${firstEntry.key}: $value';
    }
    return message ?? 'Unable to update profile.';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        final user = authService.currentUser;
        final isDoctor = widget.role == UserRole.doctor;
        final title = isDoctor ? 'Edit Doctor Profile' : 'Edit Patient Profile';

        if (user == null) {
          return Scaffold(
            backgroundColor: AppColors.backgroundLight,
            appBar: const CustomAppBar(
              title: 'Edit Profile',
              showBackButton: true,
            ),
            body: const Center(child: Text('No user profile is available.')),
          );
        }

        final isLoading = _submitting || authService.isLoading;

        return Scaffold(
          backgroundColor: AppColors.backgroundLight,
          appBar: CustomAppBar(title: title, showBackButton: true),
          body: AbsorbPointer(
            absorbing: isLoading,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SectionCard(
                      title: 'Account',
                      icon: Icons.verified_user_rounded,
                      children: [
                        _lockedField(
                          label: 'Username',
                          value: user.username,
                          icon: Icons.person_rounded,
                        ),
                        _lockedField(
                          label: 'Role',
                          value: user.role,
                          icon: Icons.badge_rounded,
                        ),
                        _lockedField(
                          label: 'Phone Verified',
                          value: user.isPhoneVerified ? 'Yes' : 'No',
                          icon: Icons.phone_android_rounded,
                        ),
                        _lockedField(
                          label: 'Email Verified',
                          value: user.isEmailVerified ? 'Yes' : 'No',
                          icon: Icons.mark_email_read_rounded,
                          showDivider: false,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (isDoctor) ...[
                      _SectionCard(
                        title: 'Contact Details',
                        icon: Icons.contact_page_rounded,
                        children: [
                          _editableField(
                            controller: _doctorEmailController,
                            label: 'Email',
                            icon: Icons.email_rounded,
                            keyboardType: TextInputType.emailAddress,
                            validator: _validateEmail,
                          ),
                          _editableField(
                            controller: _doctorPhoneController,
                            label: 'Personal Number',
                            icon: Icons.phone_rounded,
                            keyboardType: TextInputType.phone,
                            validator: _validatePhone,
                          ),
                          _editableField(
                            controller: _doctorWhatsappController,
                            label: 'WhatsApp Number',
                            icon: Icons.chat_rounded,
                            keyboardType: TextInputType.phone,
                            validator: _validatePhoneOptional,
                            showDivider: false,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: 'Profile Picture',
                        icon: Icons.photo_camera_rounded,
                        children: [_profilePicturePickerWidget(isLoading)],
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: 'Professional Details',
                        icon: Icons.medical_services_rounded,
                        children: [
                          _lockedField(
                            label: 'First Name',
                            value: user.firstName,
                            icon: Icons.badge_rounded,
                          ),
                          _lockedField(
                            label: 'Last Name',
                            value: user.lastName,
                            icon: Icons.badge_outlined,
                          ),
                          _lockedField(
                            label: 'Specialization',
                            value: user.doctorProfile?.specialization ?? '',
                            icon: Icons.local_hospital_rounded,
                          ),
                          _lockedField(
                            label: 'Medical License',
                            value: user.doctorProfile?.medicalLicense ?? '',
                            icon: Icons.credit_card_rounded,
                          ),
                          _lockedField(
                            label: 'Hospital Name',
                            value: user.doctorProfile?.hospitalName ?? '',
                            icon: Icons.apartment_rounded,
                          ),
                          _lockedField(
                            label: 'Consultation Fee',
                            value: user.doctorProfile?.consultationFee == null
                                ? ''
                                : 'GHS ${user.doctorProfile!.consultationFee!.toStringAsFixed(2)}',
                            icon: Icons.payments_rounded,
                            showDivider: false,
                          ),
                        ],
                      ),
                    ] else ...[
                      _SectionCard(
                        title: 'Personal Details',
                        icon: Icons.person_outline_rounded,
                        children: [
                          _editableField(
                            controller: _firstNameController,
                            label: 'First Name',
                            icon: Icons.badge_rounded,
                            validator: _validateRequired,
                          ),
                          _editableField(
                            controller: _lastNameController,
                            label: 'Last Name',
                            icon: Icons.badge_outlined,
                            validator: _validateRequired,
                          ),
                          _editableField(
                            controller: _emailController,
                            label: 'Email',
                            icon: Icons.email_rounded,
                            keyboardType: TextInputType.emailAddress,
                            validator: _validateEmail,
                          ),
                          _editableField(
                            controller: _phoneNumberController,
                            label: 'Phone Number',
                            icon: Icons.phone_rounded,
                            keyboardType: TextInputType.phone,
                            validator: _validatePhone,
                          ),
                          _editableField(
                            controller: _whatsappNumberController,
                            label: 'WhatsApp Number',
                            icon: Icons.chat_rounded,
                            keyboardType: TextInputType.phone,
                            validator: _validatePhoneOptional,
                          ),
                          _dateField(),
                          _genderField(),
                          _editableField(
                            controller: _addressController,
                            label: 'Address',
                            icon: Icons.location_on_rounded,
                            maxLines: 2,
                            validator: _validateOptional,
                          ),
                          // Profile Picture Picker
                          _profilePicturePickerWidget(isLoading),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: 'Notifications',
                        icon: Icons.notifications_active_rounded,
                        children: [
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Push Notifications'),
                            value: _notifPush,
                            onChanged: (value) =>
                                setState(() => _notifPush = value),
                          ),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('SMS Notifications'),
                            value: _notifSms,
                            onChanged: (value) =>
                                setState(() => _notifSms = value),
                          ),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('WhatsApp Notifications'),
                            value: _notifWhatsapp,
                            onChanged: (value) =>
                                setState(() => _notifWhatsapp = value),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: 'Medical Details',
                        icon: Icons.medical_information_rounded,
                        children: [
                          _editableField(
                            controller: _bloodGroupController,
                            label: 'Blood Group',
                            icon: Icons.bloodtype_rounded,
                            validator: _validateOptional,
                          ),
                          _editableField(
                            controller: _allergiesController,
                            label: 'Allergies',
                            icon: Icons.warning_amber_rounded,
                            maxLines: 2,
                            validator: _validateOptional,
                          ),
                          _editableField(
                            controller: _emergencyContactNameController,
                            label: 'Emergency Contact Name',
                            icon: Icons.contact_emergency_rounded,
                            validator: _validateOptional,
                          ),
                          _editableField(
                            controller: _emergencyContactPhoneController,
                            label: 'Emergency Contact Phone',
                            icon: Icons.phone_in_talk_rounded,
                            keyboardType: TextInputType.phone,
                            validator: _validatePhoneOptional,
                          ),
                          _editableField(
                            controller: _medicalHistoryController,
                            label: 'Medical History',
                            icon: Icons.history_edu_rounded,
                            maxLines: 4,
                            showDivider: false,
                            validator: _validateOptional,
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Save Changes',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String? _validateRequired(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.';
    }
    return null;
  }

  String? _validateOptional(String? value) => null;

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required.';
    }
    if (!value.contains('@')) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required.';
    }
    if (value.trim().length < 8) {
      return 'Enter a valid phone number.';
    }
    return null;
  }

  String? _validatePhoneOptional(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    if (value.trim().length < 8) {
      return 'Enter a valid phone number.';
    }
    return null;
  }

  Widget _lockedField({
    required String label,
    required String value,
    required IconData icon,
    bool showDivider = true,
  }) {
    return _FieldTile(
      showDivider: showDivider,
      child: TextFormField(
        initialValue: value,
        enabled: false,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _editableField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
    bool showDivider = true,
    VoidCallback? onTap,
    bool readOnly = false,
  }) {
    return _FieldTile(
      showDivider: showDivider,
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        readOnly: readOnly,
        onTap: onTap,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _dateField() {
    return _FieldTile(
      showDivider: true,
      child: TextFormField(
        controller: _dateOfBirthController,
        readOnly: true,
        onTap: _pickDateOfBirth,
        decoration: const InputDecoration(
          labelText: 'Date of Birth',
          prefixIcon: Icon(Icons.cake_rounded),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _genderField() {
    return _FieldTile(
      showDivider: true,
      child: DropdownButtonFormField<String>(
        initialValue: _selectedGender,
        decoration: const InputDecoration(
          labelText: 'Gender',
          prefixIcon: Icon(Icons.wc_rounded),
          border: InputBorder.none,
        ),
        items: const [
          DropdownMenuItem(
            value: 'unspecified',
            child: Text('Prefer not to say'),
          ),
          DropdownMenuItem(value: 'male', child: Text('Male')),
          DropdownMenuItem(value: 'female', child: Text('Female')),
          DropdownMenuItem(value: 'other', child: Text('Other')),
        ],
        onChanged: (value) {
          if (value == null) return;
          setState(() {
            _selectedGender = value;
          });
        },
      ),
    );
  }

  Widget _profilePicturePickerWidget(bool isLoading) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.photo_camera_rounded,
                color: AppColors.primaryBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Profile Picture',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_selectedImage != null) ...[
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
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
                  onPressed: isLoading ? null : _pickProfileImage,
                  icon: const Icon(Icons.image_rounded),
                  label: const Text('Change'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: isLoading ? null : _removeProfileImage,
                  icon: const Icon(Icons.delete_rounded),
                  label: const Text('Remove'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.errorRed,
                  ),
                ),
              ],
            ),
          ] else if (_profilePictureController.text.isNotEmpty) ...[
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Image.network(
                _profilePictureController.text,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: AppColors.borderColor,
                    ),
                    child: const Icon(Icons.image_not_supported_rounded),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: isLoading ? null : _pickProfileImage,
              icon: const Icon(Icons.image_rounded),
              label: const Text('Change Picture'),
            ),
          ] else
            ElevatedButton.icon(
              onPressed: isLoading ? null : _pickProfileImage,
              icon: const Icon(Icons.image_rounded),
              label: const Text('Pick Picture'),
            ),
        ],
      ),
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.primaryBlue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _FieldTile extends StatelessWidget {
  final Widget child;
  final bool showDivider;

  const _FieldTile({required this.child, this.showDivider = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        child,
        if (showDivider)
          const Divider(height: 20, thickness: 1, color: Color(0xFFEAECEF)),
      ],
    );
  }
}
