import '../utils/type_helpers.dart';

/// Override type for a date-specific availability entry.
enum OverrideType {
  available,
  unavailable,
}

extension OverrideTypeExtension on OverrideType {
  String get value {
    switch (this) {
      case OverrideType.available:
        return 'available';
      case OverrideType.unavailable:
        return 'unavailable';
    }
  }

  static OverrideType fromString(String value) {
    return OverrideType.values.firstWhere(
      (t) => t.value == value,
      orElse: () => OverrideType.available,
    );
  }

  String get displayName {
    switch (this) {
      case OverrideType.available:
        return 'Available';
      case OverrideType.unavailable:
        return 'Unavailable';
    }
  }
}

/// A date-specific override for a doctor's availability.
///
/// When an override exists for a date, only overrides determine availability.
/// This allows doctors to add or remove specific dates from their schedule.
class DoctorAvailabilityOverride {
  final int id;
  final int doctorId;
  final String doctorName;
  final DateTime date;
  final OverrideType overrideType;
  final String? startTime;
  final String? endTime;
  final int slotDurationMinutes;
  final int maxPatientsPerDay;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DoctorAvailabilityOverride({
    required this.id,
    required this.doctorId,
    required this.doctorName,
    required this.date,
    required this.overrideType,
    this.startTime,
    this.endTime,
    required this.slotDurationMinutes,
    required this.maxPatientsPerDay,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isAvailable => overrideType == OverrideType.available;

  factory DoctorAvailabilityOverride.fromJson(Map<String, dynamic> json) {
    return DoctorAvailabilityOverride(
      id: TypeHelpers.toInt(json['id']),
      doctorId: TypeHelpers.toInt(json['doctor']),
      doctorName: json['doctor_name'] as String? ?? '',
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : DateTime.now(),
      overrideType: OverrideTypeExtension.fromString(
        json['override_type'] as String? ?? 'available',
      ),
      startTime: json['start_time'] as String?,
      endTime: json['end_time'] as String?,
      slotDurationMinutes: TypeHelpers.toInt(json['slot_duration_minutes']) == 0
          ? 15
          : TypeHelpers.toInt(json['slot_duration_minutes']),
      maxPatientsPerDay: TypeHelpers.toInt(json['max_patients_per_day']) == 0
          ? 20
          : TypeHelpers.toInt(json['max_patients_per_day']),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'doctor': doctorId,
        'doctor_name': doctorName,
        'date': date.toIso8601String().split('T')[0],
        'override_type': overrideType.value,
        'start_time': startTime,
        'end_time': endTime,
        'slot_duration_minutes': slotDurationMinutes,
        'max_patients_per_day': maxPatientsPerDay,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
