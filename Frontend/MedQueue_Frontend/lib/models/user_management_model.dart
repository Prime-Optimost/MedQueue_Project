import '../utils/type_helpers.dart';

/// A single user entry as returned by GET /auth/users/.
class AdminUserEntry {
  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String fullName;
  final String role;
  final String phoneNumber;
  final String gender;
  final bool isActive;
  final bool isPhoneVerified;
  final bool isEmailVerified;
  final String? createdAt;
  final AdminDoctorProfile? doctorProfile;
  final AdminPatientProfile? patientProfile;

  const AdminUserEntry({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.role,
    required this.phoneNumber,
    required this.gender,
    required this.isActive,
    required this.isPhoneVerified,
    required this.isEmailVerified,
    required this.createdAt,
    required this.doctorProfile,
    required this.patientProfile,
  });

  factory AdminUserEntry.fromJson(Map<String, dynamic> json) {
    return AdminUserEntry(
      id: TypeHelpers.toInt(json['id']),
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      role: json['role'] as String? ?? '',
      phoneNumber: json['phone_number'] as String? ?? '',
      gender: json['gender'] as String? ?? 'unspecified',
      isActive: TypeHelpers.toBool(json['is_active']),
      isPhoneVerified: TypeHelpers.toBool(json['is_phone_verified']),
      isEmailVerified: TypeHelpers.toBool(json['is_email_verified']),
      createdAt: json['created_at'] as String?,
      doctorProfile: json['doctor_profile'] is Map<String, dynamic>
          ? AdminDoctorProfile.fromJson(json['doctor_profile'] as Map<String, dynamic>)
          : null,
      patientProfile: json['patient_profile'] is Map<String, dynamic>
          ? AdminPatientProfile.fromJson(json['patient_profile'] as Map<String, dynamic>)
          : null,
    );
  }

  String get displayName => fullName.isNotEmpty ? fullName : username;
}

/// Doctor-specific profile fields surfaced for admins.
class AdminDoctorProfile {
  final String specialization;
  final String hospitalName;
  final String medicalLicenseNumber;
  final bool isAcceptingPatients;
  final double consultationFee;

  const AdminDoctorProfile({
    required this.specialization,
    required this.hospitalName,
    required this.medicalLicenseNumber,
    required this.isAcceptingPatients,
    required this.consultationFee,
  });

  factory AdminDoctorProfile.fromJson(Map<String, dynamic> json) {
    return AdminDoctorProfile(
      specialization: json['specialization'] as String? ?? '',
      hospitalName: json['hospital_name'] as String? ?? '',
      medicalLicenseNumber: json['medical_license_number'] as String? ?? '',
      isAcceptingPatients: TypeHelpers.toBool(json['is_accepting_patients']),
      consultationFee: TypeHelpers.toDouble(json['consultation_fee']),
    );
  }
}

/// Patient-specific profile fields surfaced for admins.
class AdminPatientProfile {
  final String bloodGroup;
  final String emergencyContactName;
  final String emergencyContactPhone;

  const AdminPatientProfile({
    required this.bloodGroup,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
  });

  factory AdminPatientProfile.fromJson(Map<String, dynamic> json) {
    return AdminPatientProfile(
      bloodGroup: json['blood_group'] as String? ?? '',
      emergencyContactName: json['emergency_contact_name'] as String? ?? '',
      emergencyContactPhone: json['emergency_contact_phone'] as String? ?? '',
    );
  }
}

/// Paginated payload from GET /auth/users/.
class AdminUserListResult {
  final int count;
  final int page;
  final int pages;
  final List<AdminUserEntry> users;

  const AdminUserListResult({
    required this.count,
    required this.page,
    required this.pages,
    required this.users,
  });

  factory AdminUserListResult.fromJson(Map<String, dynamic> json) {
    final rawUsers = json['results'];
    return AdminUserListResult(
      count: TypeHelpers.toInt(json['count']),
      page: TypeHelpers.toInt(json['page']),
      pages: TypeHelpers.toInt(json['pages']),
      users: rawUsers is List
          ? rawUsers
              .whereType<Map<String, dynamic>>()
              .map((u) => AdminUserEntry.fromJson(u))
              .toList()
          : const [],
    );
  }
}
