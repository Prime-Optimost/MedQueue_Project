import 'package:medqueue_frontend/utils/api_constants.dart';

import '../utils/type_helpers.dart';

/// API Response Envelope

/// API Response Envelope
class ApiResponse<T> {
  final String status;
  final String message;
  final T? data;
  final Map<String, dynamic>? errors;

  ApiResponse({
    required this.status,
    required this.message,
    this.data,
    this.errors,
  });

  bool get isSuccess => status == 'success';
  bool get isError => status == 'error';

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>)? dataParser,
  ) {
    final rawData = json['data'];
    dynamic parsedData = rawData;
    if (rawData != null && dataParser != null && rawData is Map<String, dynamic>) {
      parsedData = dataParser(rawData);
    }
    return ApiResponse(
      status: json['status'] ?? 'error',
      message: json['message'] ?? 'Unknown error',
      data: parsedData as T?,
      errors: json['errors'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
    'status': status,
    'message': message,
    'data': data,
    'errors': errors,
  };
}

/// Token Pair Model
class TokenPair {
  final String access;
  final String refresh;

  TokenPair({required this.access, required this.refresh});

  factory TokenPair.fromJson(Map<String, dynamic> json) {
    return TokenPair(
      access: json['access'] as String? ?? '',
      refresh: json['refresh'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'access': access, 'refresh': refresh};
}

/// Decoded Token Claims
class TokenClaims {
  final int userId;
  final String role;
  final String fullName;
  final int exp;
  final int iat;
  final String jti;

  TokenClaims({
    required this.userId,
    required this.role,
    required this.fullName,
    required this.exp,
    required this.iat,
    required this.jti,
  });

  bool get isExpired {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return exp <= now;
  }

  factory TokenClaims.fromJson(Map<String, dynamic> json) {
    return TokenClaims(
      userId: TypeHelpers.toInt(json['user_id']),
      role: json['role'] as String? ?? 'patient',
      fullName: json['full_name'] as String? ?? '',
      exp: TypeHelpers.toInt(json['exp']),
      iat: TypeHelpers.toInt(json['iat']),
      jti: json['jti'] as String? ?? '',
    );
  }
}

/// User Profile Model
class UserProfile {
  final int id;
  final String username;
  final String email;
  final String role;
  final String firstName;
  final String lastName;
  final String fullName;
  final String phoneNumber;
  final String? dateOfBirth;
  final String? gender;
  final String? address;
  final String? profilePictureUrl;
  final bool isPhoneVerified;
  final bool isEmailVerified;
  final String? whatsappNumber;
  final bool whatsappLinked;
  final bool notifPush;
  final bool notifSms;
  final bool notifWhatsapp;
  final PatientProfile? patientProfile;
  final DoctorProfile? doctorProfile;
  final DateTime createdAt;

  UserProfile({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.phoneNumber,
    this.dateOfBirth,
    this.gender,
    this.address,
    this.profilePictureUrl,
    required this.isPhoneVerified,
    required this.isEmailVerified,
    this.whatsappNumber,
    required this.whatsappLinked,
    required this.notifPush,
    required this.notifSms,
    required this.notifWhatsapp,
    this.patientProfile,
    this.doctorProfile,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final rawPicUrl = json['profile_picture_url'] ?? '';
    return UserProfile(
      id: TypeHelpers.toInt(json['id']),
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'patient',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      phoneNumber: json['phone_number'] as String? ?? '',
      dateOfBirth: json['date_of_birth'] as String?,
      gender: json['gender'] as String?,
      address: json['address'] as String?,
      profilePictureUrl: rawPicUrl.isEmpty
          ? ''
          : (rawPicUrl.startsWith('http://') ||
                rawPicUrl.startsWith('https://'))
          ? rawPicUrl as String?
          : "${ApiConstants.mediaBaseUrl}$rawPicUrl" as String?,
      isPhoneVerified: json['is_phone_verified'] as bool? ?? false,
      isEmailVerified: json['is_email_verified'] as bool? ?? false,
      whatsappNumber: json['whatsapp_number'] as String?,
      whatsappLinked: json['whatsapp_linked'] as bool? ?? false,
      notifPush: json['notif_push'] as bool? ?? true,
      notifSms: json['notif_sms'] as bool? ?? true,
      notifWhatsapp: json['notif_whatsapp'] as bool? ?? false,
      patientProfile: json['patient_profile'] != null
          ? PatientProfile.fromJson(json['patient_profile'])
          : null,
      doctorProfile: json['doctor_profile'] != null
          ? DoctorProfile.fromJson(json['doctor_profile'])
          : null,
      createdAt: DateTime.parse(json['created_at'] as String? ?? '2026-05-13'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'email': email,
    'role': role,
    'first_name': firstName,
    'last_name': lastName,
    'full_name': fullName,
    'phone_number': phoneNumber,
    'date_of_birth': dateOfBirth,
    'gender': gender,
    'address': address,
    'profile_picture_url': profilePictureUrl,
    'is_phone_verified': isPhoneVerified,
    'is_email_verified': isEmailVerified,
    'whatsapp_number': whatsappNumber,
    'whatsapp_linked': whatsappLinked,
    'notif_push': notifPush,
    'notif_sms': notifSms,
    'notif_whatsapp': notifWhatsapp,
    'patient_profile': patientProfile?.toJson(),
    'doctor_profile': doctorProfile?.toJson(),
    'created_at': createdAt.toIso8601String(),
  };
}

/// Patient Profile Model
class PatientProfile {
  final String? bloodGroup;
  final String? allergies;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? medicalHistory;

  PatientProfile({
    this.bloodGroup,
    this.allergies,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.medicalHistory,
  });

  factory PatientProfile.fromJson(Map<String, dynamic> json) {
    return PatientProfile(
      bloodGroup: json['blood_group'] as String?,
      allergies: json['allergies'] as String?,
      emergencyContactName: json['emergency_contact_name'] as String?,
      emergencyContactPhone: json['emergency_contact_phone'] as String?,
      medicalHistory: json['medical_history'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'blood_group': bloodGroup,
    'allergies': allergies,
    'emergency_contact_name': emergencyContactName,
    'emergency_contact_phone': emergencyContactPhone,
    'medical_history': medicalHistory,
  };
}

/// Doctor Profile Model
class DoctorProfile {
  final String specialization;
  final String? medicalLicense;
  final String? hospitalName;
  final double? consultationFee;
  final int? yearsOfExperience;
  final bool isAcceptingPatients;
  final String? bio;
  final int? avgConsultationMinutes;

  DoctorProfile({
    required this.specialization,
    this.medicalLicense,
    this.hospitalName,
    this.consultationFee,
    this.yearsOfExperience,
    this.isAcceptingPatients = false,
    this.bio,
    this.avgConsultationMinutes,
  });

  factory DoctorProfile.fromJson(Map<String, dynamic> json) {
    return DoctorProfile(
      specialization: json['specialization'] as String? ?? '',
      medicalLicense: json['medical_license_number'] as String?,
      hospitalName: json['hospital_name'] as String?,
      consultationFee: TypeHelpers.toDouble(json['consultation_fee']),
      yearsOfExperience: TypeHelpers.toInt(json['years_of_experience']),
      isAcceptingPatients: json['is_accepting_patients'] as bool? ?? false,
      bio: json['bio'] as String?,
      avgConsultationMinutes: TypeHelpers.toInt(
        json['avg_consultation_minutes'],
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'specialization': specialization,
    'medical_license_number': medicalLicense,
    'hospital_name': hospitalName,
    'consultation_fee': consultationFee,
    'years_of_experience': yearsOfExperience,
    'is_accepting_patients': isAcceptingPatients,
    'bio': bio,
    'avg_consultation_minutes': avgConsultationMinutes,
  };
}

/// Login Response
class LoginResponse {
  final TokenPair tokens;
  final UserProfile user;

  LoginResponse({required this.tokens, required this.user});

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      tokens: TokenPair.fromJson(json['tokens'] as Map<String, dynamic>),
      user: UserProfile.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

/// Registration Response (same as Login Response)
class RegisterResponse {
  final TokenPair tokens;
  final UserProfile user;

  RegisterResponse({required this.tokens, required this.user});

  factory RegisterResponse.fromJson(Map<String, dynamic> json) {
    return RegisterResponse(
      tokens: TokenPair.fromJson(json['tokens'] as Map<String, dynamic>),
      user: UserProfile.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
