import 'package:medqueue_frontend/utils/api_constants.dart';

import '../utils/type_helpers.dart';

class Doctor {
  final int id;
  final String fullName;
  final String specialization;
  final String hospitalName;
  final double consultationFee;
  final int yearsOfExperience;
  final int avgConsultationMinutes;
  final bool isAcceptingPatients;
  final String profilePictureUrl;
  final String? bio;
  final String? whatsappNumber;
  final bool whatsappLinked;

  Doctor({
    required this.id,
    required this.fullName,
    required this.specialization,
    required this.hospitalName,
    required this.consultationFee,
    required this.yearsOfExperience,
    required this.avgConsultationMinutes,
    required this.isAcceptingPatients,
    required this.profilePictureUrl,
    this.bio,
    this.whatsappNumber,
    this.whatsappLinked = false,
  });

  String get displayName => fullName;

  String get initials {
    final names = fullName.split(' ');
    return names.map((n) => n.isNotEmpty ? n[0] : '').join();
  }

  bool get hasWhatsApp =>
      whatsappLinked && (whatsappNumber ?? '').trim().isNotEmpty;

  factory Doctor.fromJson(Map<String, dynamic> json) {
    final rawProfilePic = (json['profile_picture_url'] as String?)?.trim();

    return Doctor(
      id: TypeHelpers.toInt(json['id']),
      fullName: json['full_name'] as String? ?? '',
      specialization: json['specialization'] as String? ?? '',
      hospitalName: json['hospital_name'] as String? ?? '',
      consultationFee: TypeHelpers.toDouble(json['consultation_fee']),
      yearsOfExperience: TypeHelpers.toInt(json['years_of_experience']),
      avgConsultationMinutes:
          TypeHelpers.toInt(json['avg_consultation_minutes']) == 0
          ? 15
          : TypeHelpers.toInt(json['avg_consultation_minutes']),
      isAcceptingPatients: json['is_accepting_patients'] as bool? ?? true,
      profilePictureUrl: (rawProfilePic == null || rawProfilePic.isEmpty)
          ? ''
          : '${ApiConstants.mediaBaseUrl}media/$rawProfilePic',
      bio: json['bio'] as String? ?? '',
      whatsappNumber: json['whatsapp_number'] as String?,
      whatsappLinked: json['whatsapp_linked'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'full_name': fullName,
    'specialization': specialization,
    'hospital_name': hospitalName,
    'consultation_fee': consultationFee,
    'years_of_experience': yearsOfExperience,
    'avg_consultation_minutes': avgConsultationMinutes,
    'is_accepting_patients': isAcceptingPatients,
    'profile_picture_url': profilePictureUrl,
    'bio': bio,
    'whatsapp_number': whatsappNumber,
    'whatsapp_linked': whatsappLinked,
  };
}
