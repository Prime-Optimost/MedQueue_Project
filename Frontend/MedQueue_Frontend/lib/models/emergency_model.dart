import '../utils/type_helpers.dart';

enum EmergencyStatus { pending, dispatched, resolved, cancelled, falseAlarm }

class EmergencyStatusLog {
  final int id;
  final String previousStatus;
  final String newStatus;
  final String changedByName;
  final String notes;
  final DateTime createdAt;

  EmergencyStatusLog({
    required this.id,
    required this.previousStatus,
    required this.newStatus,
    required this.changedByName,
    required this.notes,
    required this.createdAt,
  });

  factory EmergencyStatusLog.fromJson(Map<String, dynamic> json) {
    return EmergencyStatusLog(
      id: TypeHelpers.toInt(json['id']),
      previousStatus: json['previous_status'] as String? ?? '',
      newStatus: json['new_status'] as String? ?? '',
      changedByName: json['changed_by_name'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }
}

class EmergencyRequest {
  final int id;
  final String patientName;
  final String patientPhone;
  final double? latitude;
  final double? longitude;
  final double? gpsAccuracyMeters;
  final String mapsUrl;
  final String emergencyType;
  final String description;
  final EmergencyStatus status;
  final bool isActive;
  final DateTime confirmedAt;
  final DateTime? dispatchedAt;
  final DateTime? resolvedAt;
  final int? responseTimeSeconds;
  final String? handledByName;
  final String ambulancePlate;
  final int? ambulanceEtaMinutes;
  final String resolutionNotes;
  final bool adminNotified;
  final bool patientAckSent;
  final List<String> allowedNextStatuses;
  final List<EmergencyStatusLog> statusLogs;
  final DateTime createdAt;
  final DateTime updatedAt;

  EmergencyRequest({
    required this.id,
    required this.patientName,
    required this.patientPhone,
    this.latitude,
    this.longitude,
    this.gpsAccuracyMeters,
    this.mapsUrl = '',
    this.emergencyType = 'medical',
    required this.description,
    required this.status,
    required this.isActive,
    required this.confirmedAt,
    this.dispatchedAt,
    this.resolvedAt,
    this.responseTimeSeconds,
    this.handledByName,
    this.ambulancePlate = '',
    this.ambulanceEtaMinutes,
    this.resolutionNotes = '',
    this.adminNotified = false,
    this.patientAckSent = false,
    this.allowedNextStatuses = const [],
    this.statusLogs = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  bool get active => isActive;

  factory EmergencyRequest.fromJson(Map<String, dynamic> json) {
    EmergencyStatus parseStatus(String s) {
      switch (s) {
        case 'pending':
          return EmergencyStatus.pending;
        case 'dispatched':
          return EmergencyStatus.dispatched;
        case 'resolved':
          return EmergencyStatus.resolved;
        case 'cancelled':
          return EmergencyStatus.cancelled;
        case 'false_alarm':
          return EmergencyStatus.falseAlarm;
        default:
          return EmergencyStatus.pending;
      }
    }

    return EmergencyRequest(
      id: TypeHelpers.toInt(json['id']),
      patientName: json['patient_name'] as String? ?? '',
      patientPhone: json['patient_phone'] as String? ?? '',
      latitude: json['latitude'] != null ? TypeHelpers.toDouble(json['latitude']) : null,
      longitude: json['longitude'] != null ? TypeHelpers.toDouble(json['longitude']) : null,
      gpsAccuracyMeters: json['gps_accuracy_meters'] != null ? TypeHelpers.toDouble(json['gps_accuracy_meters']) : null,
      mapsUrl: json['maps_url'] as String? ?? '',
      emergencyType: json['emergency_type'] as String? ?? 'medical',
      description: json['description'] as String? ?? '',
      status: parseStatus(json['status'] as String? ?? 'pending'),
      isActive: json['is_active'] as bool? ?? false,
      confirmedAt: DateTime.parse(json['confirmed_at'] as String? ?? DateTime.now().toIso8601String()),
      dispatchedAt: json['dispatched_at'] != null ? DateTime.parse(json['dispatched_at'] as String) : null,
      resolvedAt: json['resolved_at'] != null ? DateTime.parse(json['resolved_at'] as String) : null,
      responseTimeSeconds: json['response_time_seconds'] != null ? TypeHelpers.toInt(json['response_time_seconds']) : null,
      handledByName: json['handled_by_name'] as String?,
      ambulancePlate: json['ambulance_plate'] as String? ?? '',
      ambulanceEtaMinutes: json['ambulance_eta_minutes'] != null ? TypeHelpers.toInt(json['ambulance_eta_minutes']) : null,
      resolutionNotes: json['resolution_notes'] as String? ?? '',
      adminNotified: json['admin_notified'] as bool? ?? false,
      patientAckSent: json['patient_ack_sent'] as bool? ?? false,
      allowedNextStatuses: (json['allowed_next_statuses'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      statusLogs: json['status_logs'] != null
          ? (json['status_logs'] as List<dynamic>).map((e) => EmergencyStatusLog.fromJson(e as Map<String, dynamic>)).toList()
          : [],
      createdAt: DateTime.parse(json['created_at'] as String? ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }
}
