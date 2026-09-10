import '../utils/type_helpers.dart';

/// Aggregated "System Overview" statistics for the admin dashboard.
/// Mirrors the payload returned by GET /auth/admin/dashboard/stats/.
class AdminDashboardStats {
  final int totalUsers;
  final int activeUsers;
  final int patients;
  final int doctors;
  final int admins;
  final int totalAppointments;
  final AppointmentStatusCounts appointmentStatus;
  final int totalEmergencies;
  final EmergencyStatusCounts emergencyStatus;

  const AdminDashboardStats({
    required this.totalUsers,
    required this.activeUsers,
    required this.patients,
    required this.doctors,
    required this.admins,
    required this.totalAppointments,
    required this.appointmentStatus,
    required this.totalEmergencies,
    required this.emergencyStatus,
  });

  factory AdminDashboardStats.fromJson(Map<String, dynamic> json) {
    return AdminDashboardStats(
      totalUsers: TypeHelpers.toInt(json['total_users']),
      activeUsers: TypeHelpers.toInt(json['active_users']),
      patients: TypeHelpers.toInt(json['patients']),
      doctors: TypeHelpers.toInt(json['doctors']),
      admins: TypeHelpers.toInt(json['admins']),
      totalAppointments: TypeHelpers.toInt(json['total_appointments']),
      appointmentStatus:
          AppointmentStatusCounts.fromJson(
            json['appointment_status'] as Map<String, dynamic>? ?? const {},
          ),
      totalEmergencies: TypeHelpers.toInt(json['total_emergencies']),
      emergencyStatus:
          EmergencyStatusCounts.fromJson(
            json['emergency_status'] as Map<String, dynamic>? ?? const {},
          ),
    );
  }
}

class AppointmentStatusCounts {
  final int pending;
  final int confirmed;
  final int completed;
  final int cancelled;
  final int noShow;
  final int rescheduled;

  const AppointmentStatusCounts({
    required this.pending,
    required this.confirmed,
    required this.completed,
    required this.cancelled,
    required this.noShow,
    required this.rescheduled,
  });

  factory AppointmentStatusCounts.fromJson(Map<String, dynamic> json) {
    return AppointmentStatusCounts(
      pending: TypeHelpers.toInt(json['pending']),
      confirmed: TypeHelpers.toInt(json['confirmed']),
      completed: TypeHelpers.toInt(json['completed']),
      cancelled: TypeHelpers.toInt(json['cancelled']),
      noShow: TypeHelpers.toInt(json['no_show']),
      rescheduled: TypeHelpers.toInt(json['rescheduled']),
    );
  }
}

class EmergencyStatusCounts {
  final int pending;
  final int dispatched;
  final int resolved;
  final int cancelled;
  final int falseAlarm;

  const EmergencyStatusCounts({
    required this.pending,
    required this.dispatched,
    required this.resolved,
    required this.cancelled,
    required this.falseAlarm,
  });

  factory EmergencyStatusCounts.fromJson(Map<String, dynamic> json) {
    return EmergencyStatusCounts(
      pending: TypeHelpers.toInt(json['pending']),
      dispatched: TypeHelpers.toInt(json['dispatched']),
      resolved: TypeHelpers.toInt(json['resolved']),
      cancelled: TypeHelpers.toInt(json['cancelled']),
      falseAlarm: TypeHelpers.toInt(json['false_alarm']),
    );
  }
}
