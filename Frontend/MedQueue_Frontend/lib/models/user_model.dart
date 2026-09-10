// User base model
import 'package:medqueue_frontend/utils/api_constants.dart';
  
enum UserRole { patient, doctor, admin }

class User {
  final String id;
  final String email;
  final String password;
  final String fullName;
  final String phone;
  final UserRole role;
  final DateTime createdAt;
  final String? profilePictureUrl;

  User({
    required this.id,
    required this.email,
    required this.password,
    required this.fullName,
    required this.phone,
    required this.role,
    required this.createdAt,
    this.profilePictureUrl,
  });

  // For JSON serialization when backend is ready
  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'fullName': fullName,
    'phone': phone,
    'role': role.toString(),
    'createdAt': createdAt.toIso8601String(),
    //add this to the image url: http://127.0.0.1:8000//media/profile_pictures/filename.jpg
    'profile_picture_url': '${ApiConstants.mediaBaseUrl}${profilePictureUrl ?? ''}',
  };
}

// Patient specific model
class Patient extends User {
  final String? dateOfBirth;
  final String? bloodType;
  final String? emergencyContact;
  final String? emergencyPhone;
  final List<String> medicalHistory;

  Patient({
    required super.id,
    required super.email,
    required super.password,
    required super.fullName,
    required super.phone,
    required super.createdAt,
    super.profilePictureUrl,
    this.dateOfBirth,
    this.bloodType,
    this.emergencyContact,
    this.emergencyPhone,
    this.medicalHistory = const [],
  }) : super(
    role: UserRole.patient,
  );
}

// Doctor specific model
class Doctor extends User {
  final String specialization;
  final String? medicalLicense;
  final double? rating;
  final int? yearsOfExperience;
  final String? bio;
  final List<String> availableDays;
  final String? startTime;
  final String? endTime;
  final bool isAvailable;

  Doctor({
    required super.id,
    required super.email,
    required super.password,
    required super.fullName,
    required super.phone,
    required super.createdAt,
    super.profilePictureUrl,
    required this.specialization,
    this.medicalLicense,
    this.rating = 4.5,
    this.yearsOfExperience = 5,
    this.bio,
    this.availableDays = const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
    this.startTime = '09:00 AM',
    this.endTime = '05:00 PM',
    this.isAvailable = true,
  }) : super(
    role: UserRole.doctor,
  );
}

// Admin specific model
class Admin extends User {
  final String department;
  final String? permissions;

  Admin({
    required super.id,
    required super.email,
    required super.password,
    required super.fullName,
    required super.phone,
    required super.createdAt,
    super.profilePictureUrl,
    required this.department,
    this.permissions,
  }) : super(
    role: UserRole.admin,
  );
}
