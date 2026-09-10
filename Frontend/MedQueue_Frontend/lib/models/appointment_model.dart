import '../utils/type_helpers.dart';

/// Appointment status enum matching backend values
enum AppointmentStatus {
  pending,
  confirmed,
  completed,
  cancelled,
  noShow,
  rescheduled,
}

extension AppointmentStatusExtension on AppointmentStatus {
  String get value {
    switch (this) {
      case AppointmentStatus.pending:
        return 'pending';
      case AppointmentStatus.confirmed:
        return 'confirmed';
      case AppointmentStatus.completed:
        return 'completed';
      case AppointmentStatus.cancelled:
        return 'cancelled';
      case AppointmentStatus.noShow:
        return 'no_show';
      case AppointmentStatus.rescheduled:
        return 'rescheduled';
    }
  }

  static AppointmentStatus fromString(String value) {
    return AppointmentStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => AppointmentStatus.pending,
    );
  }

  String get displayName {
    switch (this) {
      case AppointmentStatus.pending:
        return 'Pending';
      case AppointmentStatus.confirmed:
        return 'Confirmed';
      case AppointmentStatus.completed:
        return 'Completed';
      case AppointmentStatus.cancelled:
        return 'Cancelled';
      case AppointmentStatus.noShow:
        return 'No Show';
      case AppointmentStatus.rescheduled:
        return 'Rescheduled';
    }
  }
}

class PatientDetail {
  final int id;
  final String fullName;
  final String email;
  final String phone;
  final String? whatsappNumber;
  final bool whatsappLinked;
  final String? profilePictureUrl;

  PatientDetail({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    this.whatsappNumber,
    this.whatsappLinked = false,
    this.profilePictureUrl,
  });
  bool get hasWhatsApp => whatsappLinked && (whatsappNumber ?? '').trim().isNotEmpty;
  factory PatientDetail.fromJson(Map<String, dynamic> json) {
    return PatientDetail(
      id: TypeHelpers.toInt(json['id']),
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      whatsappNumber: json['whatsapp_number'] as String?,
      whatsappLinked: json['whatsapp_linked'] as bool? ?? false,
      profilePictureUrl: json['profile_picture_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'whatsapp_number': whatsappNumber,
        'whatsapp_linked': whatsappLinked,
        'profile_picture_url': profilePictureUrl,
      };
}

class DoctorDetail {
  final int id;
  final String fullName;
  final String email;
  final String phone;
  final String specialization;
  final String? whatsappNumber;
  final bool whatsappLinked;
  final String? profilePictureUrl;

  DoctorDetail({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.specialization,
    this.whatsappNumber,
    this.whatsappLinked = false,
    this.profilePictureUrl,
  });

  bool get hasWhatsApp => whatsappLinked && (whatsappNumber ?? '').trim().isNotEmpty;

  factory DoctorDetail.fromJson(Map<String, dynamic> json) {
    return DoctorDetail(
      id: TypeHelpers.toInt(json['id']),
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      specialization: json['specialization'] as String? ?? '',
      whatsappNumber: json['whatsapp_number'] as String?,
      whatsappLinked: json['whatsapp_linked'] as bool? ?? false,
      profilePictureUrl: json['profile_picture_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'specialization': specialization,
        'whatsapp_number': whatsappNumber,
        'whatsapp_linked': whatsappLinked,
        'profile_picture_url': profilePictureUrl,
      };
}

class SlotDetail {
  final int id;
  final String date;
  final String startTime;
  final String endTime;
  final String status;
  final bool isAvailable;

  SlotDetail({
    required this.id,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.isAvailable,
  });

  factory SlotDetail.fromJson(Map<String, dynamic> json) {
    return SlotDetail(
      id: TypeHelpers.toInt(json['id']),
      date: json['date'] as String? ?? '',
      startTime: json['start_time'] as String? ?? '',
      endTime: json['end_time'] as String? ?? '',
      status: json['status'] as String? ?? '',
      isAvailable: json['is_available'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'start_time': startTime,
        'end_time': endTime,
        'status': status,
        'is_available': isAvailable,
      };
}

class Appointment {
  final int id;
  final PatientDetail patientDetail;
  final DoctorDetail doctorDetail;
  final SlotDetail? slotDetail;
  final String appointmentDate;
  final String appointmentTime;
  final String status;
  final String reason;
  final String notes;
  final int? rescheduledFrom;
  final String cancellationReason;
  final bool canCancel;
  final bool canReschedule;
  /// Whether this appointment was booked by a receptionist via phone/call-in.
  /// Phone/call-in appointments cannot be rescheduled online.
  final bool bookedByReception;
  final bool reminder24hSent;
  final bool reminder30mSent;
  final DateTime createdAt;
  final DateTime updatedAt;

  Appointment({
    required this.id,
    required this.patientDetail,
    required this.doctorDetail,
    this.slotDetail,
    required this.appointmentDate,
    required this.appointmentTime,
    required this.status,
    required this.reason,
    required this.notes,
    this.rescheduledFrom,
    required this.cancellationReason,
    required this.canCancel,
    required this.canReschedule,
    this.bookedByReception = false,
    required this.reminder24hSent,
    required this.reminder30mSent,
    required this.createdAt,
    required this.updatedAt,
  });

  AppointmentStatus get statusEnum =>
      AppointmentStatusExtension.fromString(status);

  bool get isPast {
    try {
      final appointmentDateTime = DateTime.parse(
          '$appointmentDate ${appointmentTime.padLeft(8, '0')}');
      return appointmentDateTime.isBefore(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  bool get isToday {
    try {
      final today = DateTime.now();
      final apptDate = DateTime.parse(appointmentDate);
      return apptDate.day == today.day &&
          apptDate.month == today.month &&
          apptDate.year == today.year;
    } catch (e) {
      return false;
    }
  }

  bool get isUpcoming {
    try {
      final appointmentDateTime = DateTime.parse(
          '$appointmentDate ${appointmentTime.padLeft(8, '0')}');
      return appointmentDateTime.isAfter(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: TypeHelpers.toInt(json['id']),
      patientDetail: json['patient_detail'] != null
          ? PatientDetail.fromJson(
              json['patient_detail'] as Map<String, dynamic>)
          : PatientDetail(
              id: 0, fullName: '', email: '', phone: ''),
      doctorDetail: json['doctor_detail'] != null
          ? DoctorDetail.fromJson(
              json['doctor_detail'] as Map<String, dynamic>)
          : DoctorDetail(
              id: 0,
              fullName: '',
              email: '',
              phone: '',
              specialization: ''),
      slotDetail: json['slot_detail'] != null
          ? SlotDetail.fromJson(
              json['slot_detail'] as Map<String, dynamic>)
          : null,
      appointmentDate: json['appointment_date'] as String? ?? '',
      appointmentTime: json['appointment_time'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      reason: json['reason'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      rescheduledFrom: json['rescheduled_from'] != null ? TypeHelpers.toInt(json['rescheduled_from']) : null,
      cancellationReason: json['cancellation_reason'] as String? ?? '',
      canCancel: json['can_cancel'] as bool? ?? false,
      canReschedule: json['can_reschedule'] as bool? ?? false,
      bookedByReception: json['booked_by_reception'] == true,
      reminder24hSent: json['reminder_24h_sent'] as bool? ?? false,
      reminder30mSent: json['reminder_30m_sent'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  /// Create an Appointment from lightweight list format (from history endpoint)
  factory Appointment.fromListJson(Map<String, dynamic> json) {
    return Appointment(
      id: TypeHelpers.toInt(json['id']),
      patientDetail: json['patient_detail'] != null
          ? PatientDetail.fromJson(
              json['patient_detail'] as Map<String, dynamic>)
          : PatientDetail(
              id: 0,
              fullName: json['patient_name'] as String? ?? '',
              email: '',
              phone: '',
            ),
      doctorDetail: json['doctor_detail'] != null
          ? DoctorDetail.fromJson(
              json['doctor_detail'] as Map<String, dynamic>)
          : DoctorDetail(
              id: 0,
              fullName: json['doctor_name'] as String? ?? '',
              email: '',
              phone: '',
              specialization: json['specialization'] as String? ?? '',
            ),
      slotDetail: null,
      appointmentDate: json['appointment_date'] as String? ?? '',
      appointmentTime: json['appointment_time'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      reason: json['reason'] as String? ?? '',
      notes: '',
      rescheduledFrom: null,
      cancellationReason: '',
      canCancel: false,
      canReschedule: false,
      bookedByReception: json['booked_by_reception'] == true,
      reminder24hSent: false,
      reminder30mSent: false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'patient_detail': patientDetail.toJson(),
        'doctor_detail': doctorDetail.toJson(),
        'slot_detail': slotDetail?.toJson(),
        'appointment_date': appointmentDate,
        'appointment_time': appointmentTime,
        'status': status,
        'reason': reason,
        'notes': notes,
        'rescheduled_from': rescheduledFrom,
        'cancellation_reason': cancellationReason,
        'can_cancel': canCancel,
        'can_reschedule': canReschedule,
        'booked_by_reception': bookedByReception,
        'reminder_24h_sent': reminder24hSent,
        'reminder_30m_sent': reminder30mSent,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
