import '../utils/type_helpers.dart';

/// Aggregate queue statistics over a date range.
/// Mirrors GET /auth/admin/stats/aggregate/.
class AggregateQueueStats {
  final String fromDate;
  final String toDate;
  final String doctor;
  final int totalQueueEntries;
  final int totalServed;
  final int totalNoShows;
  final int totalLeftQueue;
  final double noShowRatePct;
  final int? avgConsultationMins;

  const AggregateQueueStats({
    required this.fromDate,
    required this.toDate,
    required this.doctor,
    required this.totalQueueEntries,
    required this.totalServed,
    required this.totalNoShows,
    required this.totalLeftQueue,
    required this.noShowRatePct,
    required this.avgConsultationMins,
  });

  factory AggregateQueueStats.fromJson(Map<String, dynamic> json) {
    final avg = json['avg_consultation_mins'];
    return AggregateQueueStats(
      fromDate: json['from_date'] as String? ?? '',
      toDate: json['to_date'] as String? ?? '',
      doctor: json['doctor'] as String? ?? '',
      totalQueueEntries: TypeHelpers.toInt(json['total_queue_entries']),
      totalServed: TypeHelpers.toInt(json['total_served']),
      totalNoShows: TypeHelpers.toInt(json['total_no_shows']),
      totalLeftQueue: TypeHelpers.toInt(json['total_left_queue']),
      noShowRatePct: TypeHelpers.toDouble(json['no_show_rate_pct']),
      avgConsultationMins: avg == null ? null : TypeHelpers.toInt(avg),
    );
  }
}

/// Emergency request summary statistics.
/// Mirrors GET /auth/admin/summary/.
class EmergencySummaryStats {
  final int total;
  final int pending;
  final int dispatched;
  final int resolved;
  final int cancelled;
  final int falseAlarms;
  final int? avgResponseSeconds;
  final Map<String, int> typeBreakdown;

  const EmergencySummaryStats({
    required this.total,
    required this.pending,
    required this.dispatched,
    required this.resolved,
    required this.cancelled,
    required this.falseAlarms,
    required this.avgResponseSeconds,
    required this.typeBreakdown,
  });

  factory EmergencySummaryStats.fromJson(Map<String, dynamic> json) {
    final rawBreakdown = json['type_breakdown'];
    final typeBreakdown = <String, int>{};
    if (rawBreakdown is Map<String, dynamic>) {
      rawBreakdown.forEach((key, value) {
        typeBreakdown[key] = TypeHelpers.toInt(value);
      });
    }

    final avg = json['avg_response_seconds'];
    return EmergencySummaryStats(
      total: TypeHelpers.toInt(json['total']),
      pending: TypeHelpers.toInt(json['pending']),
      dispatched: TypeHelpers.toInt(json['dispatched']),
      resolved: TypeHelpers.toInt(json['resolved']),
      cancelled: TypeHelpers.toInt(json['cancelled']),
      falseAlarms: TypeHelpers.toInt(json['false_alarms']),
      avgResponseSeconds: avg == null ? null : TypeHelpers.toInt(avg),
      typeBreakdown: typeBreakdown,
    );
  }
}

/// A single doctor's live queue as returned by GET /auth/admin/overview/.
class LiveQueueEntry {
  final int sessionId;
  final int doctorId;
  final String doctorName;
  final String specialization;
  final String status;
  final int currentPosition;
  final int waitingCount;
  final int servedCount;
  final bool isPaused;
  final String pauseReason;
  final int totalPauseMins;
  final int avgConsultMins;

  const LiveQueueEntry({
    required this.sessionId,
    required this.doctorId,
    required this.doctorName,
    required this.specialization,
    required this.status,
    required this.currentPosition,
    required this.waitingCount,
    required this.servedCount,
    required this.isPaused,
    required this.pauseReason,
    required this.totalPauseMins,
    required this.avgConsultMins,
  });

  factory LiveQueueEntry.fromJson(Map<String, dynamic> json) {
    return LiveQueueEntry(
      sessionId: TypeHelpers.toInt(json['session_id']),
      doctorId: TypeHelpers.toInt(json['doctor_id']),
      doctorName: json['doctor_name'] as String? ?? '',
      specialization: json['specialization'] as String? ?? '',
      status: json['status'] as String? ?? '',
      currentPosition: TypeHelpers.toInt(json['current_position']),
      waitingCount: TypeHelpers.toInt(json['waiting_count']),
      servedCount: TypeHelpers.toInt(json['served_count']),
      isPaused: TypeHelpers.toBool(json['is_paused']),
      pauseReason: json['pause_reason'] as String? ?? '',
      totalPauseMins: TypeHelpers.toInt(json['total_pause_mins']),
      avgConsultMins: TypeHelpers.toInt(json['avg_consult_mins']),
    );
  }

  bool get isActive =>
      status == 'active' || status == 'in_progress' || status == 'open';
}

/// Paginated payload from GET /auth/admin/overview/.
class LiveQueueOverview {
  final String date;
  final int count;
  final List<LiveQueueEntry> queues;

  const LiveQueueOverview({
    required this.date,
    required this.count,
    required this.queues,
  });

  factory LiveQueueOverview.fromJson(Map<String, dynamic> json) {
    final rawQueues = json['queues'];
    return LiveQueueOverview(
      date: json['date'] as String? ?? '',
      count: TypeHelpers.toInt(json['count']),
      queues: rawQueues is List
          ? rawQueues
              .whereType<Map<String, dynamic>>()
              .map((q) => LiveQueueEntry.fromJson(q))
              .toList()
          : const [],
    );
  }
}

// ---------------------------------------------------------------------------
// Admin Reports (general / patient / doctor)
// Mirrors GET /auth/admin/reports/{general,patient,doctor}/
// ---------------------------------------------------------------------------

/// A single booked appointment inside the general report.
class ReportBooking {
  final int appointmentId;
  final int patientId;
  final String patientName;
  final int doctorId;
  final String doctorName;
  final String date;
  final String? time;
  final String status;

  const ReportBooking({
    required this.appointmentId,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
    required this.doctorName,
    required this.date,
    this.time,
    required this.status,
  });

  factory ReportBooking.fromJson(Map<String, dynamic> json) {
    return ReportBooking(
      appointmentId: TypeHelpers.toInt(json['appointment_id']),
      patientId: TypeHelpers.toInt(json['patient_id']),
      patientName: json['patient_name'] as String? ?? '',
      doctorId: TypeHelpers.toInt(json['doctor_id']),
      doctorName: json['doctor_name'] as String? ?? '',
      date: json['date'] as String? ?? '',
      time: json['time'] as String?,
      status: json['status'] as String? ?? '',
    );
  }
}

/// One doctor's workload entry in the general report.
class ReportDoctorWork {
  final int id;
  final String name;
  final String? specialization;
  final int appointments;
  final int patientsSeen;

  const ReportDoctorWork({
    required this.id,
    required this.name,
    this.specialization,
    required this.appointments,
    required this.patientsSeen,
  });

  factory ReportDoctorWork.fromJson(Map<String, dynamic> json) {
    return ReportDoctorWork(
      id: TypeHelpers.toInt(json['id']),
      name: json['name'] as String? ?? '',
      specialization: json['specialization'] as String?,
      appointments: TypeHelpers.toInt(json['appointments']),
      patientsSeen: TypeHelpers.toInt(json['patients_seen']),
    );
  }
}

/// An emergency alert listed in the general report.
class ReportEmergency {
  final int alertId;
  final int patientId;
  final String patientName;
  final String emergencyType;
  final String status;
  final String description;
  final String createdAt;

  const ReportEmergency({
    required this.alertId,
    required this.patientId,
    required this.patientName,
    required this.emergencyType,
    required this.status,
    required this.description,
    required this.createdAt,
  });

  factory ReportEmergency.fromJson(Map<String, dynamic> json) {
    return ReportEmergency(
      alertId: TypeHelpers.toInt(json['alert_id']),
      patientId: TypeHelpers.toInt(json['patient_id']),
      patientName: json['patient_name'] as String? ?? '',
      emergencyType: json['emergency_type'] as String? ?? '',
      status: json['status'] as String? ?? '',
      description: json['description'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

/// Emergency block inside the general report.
class ReportEmergencySummary {
  final int total;
  final int dispatched;
  final int falsed;
  final List<ReportEmergency> from;

  const ReportEmergencySummary({
    required this.total,
    required this.dispatched,
    required this.falsed,
    required this.from,
  });

  factory ReportEmergencySummary.fromJson(Map<String, dynamic> json) {
    final rawFrom = json['from'];
    return ReportEmergencySummary(
      total: TypeHelpers.toInt(json['total']),
      dispatched: TypeHelpers.toInt(json['dispatched']),
      falsed: TypeHelpers.toInt(json['falsed']),
      from: rawFrom is List
          ? rawFrom
              .whereType<Map<String, dynamic>>()
              .map((e) => ReportEmergency.fromJson(e))
              .toList()
          : const [],
    );
  }
}

/// Full general report payload.
class GeneralReport {
  final String period;
  final String fromDate;
  final String toDate;
  final int totalBooked;
  final List<ReportBooking> bookings;
  final Map<String, int> appointmentSummary;
  final int doctorsWorkedCount;
  final List<ReportDoctorWork> doctorsWorked;
  final ReportEmergencySummary emergencies;

  const GeneralReport({
    required this.period,
    required this.fromDate,
    required this.toDate,
    required this.totalBooked,
    required this.bookings,
    required this.appointmentSummary,
    required this.doctorsWorkedCount,
    required this.doctorsWorked,
    required this.emergencies,
  });

  factory GeneralReport.fromJson(Map<String, dynamic> json) {
    final rawBookings = json['bookings'];
    final rawDoctors = json['doctors_worked'] ?? const <String, dynamic>{};
    final rawDoctorsList = rawDoctors is Map<String, dynamic>
        ? rawDoctors['doctors']
        : rawDoctors;

    final summary = <String, int>{};
    final rawSummary = json['appointment_summary'];
    if (rawSummary is Map<String, dynamic>) {
      rawSummary.forEach((k, v) => summary[k] = TypeHelpers.toInt(v));
    }

    return GeneralReport(
      period: json['period'] as String? ?? 'day',
      fromDate: json['from_date'] as String? ?? '',
      toDate: json['to_date'] as String? ?? '',
      totalBooked: TypeHelpers.toInt(json['total_booked']),
      bookings: rawBookings is List
          ? rawBookings
              .whereType<Map<String, dynamic>>()
              .map((b) => ReportBooking.fromJson(b))
              .toList()
          : const [],
      appointmentSummary: summary,
      doctorsWorkedCount: rawDoctors is Map<String, dynamic>
          ? TypeHelpers.toInt(rawDoctors['count'])
          : 0,
      doctorsWorked: rawDoctorsList is List
          ? rawDoctorsList
              .whereType<Map<String, dynamic>>()
              .map((d) => ReportDoctorWork.fromJson(d))
              .toList()
          : const [],
      emergencies: ReportEmergencySummary.fromJson(
        json['emergencies'] ?? const <String, dynamic>{},
      ),
    );
  }
}

/// A single appointment in the patient report.
class PatientReportAppointment {
  final int appointmentId;
  final int doctorId;
  final String doctorName;
  final String? specialization;
  final String date;
  final String? time;
  final String reason;
  final String status;
  final String notes;

  const PatientReportAppointment({
    required this.appointmentId,
    required this.doctorId,
    required this.doctorName,
    this.specialization,
    required this.date,
    this.time,
    required this.reason,
    required this.status,
    required this.notes,
  });

  factory PatientReportAppointment.fromJson(Map<String, dynamic> json) {
    return PatientReportAppointment(
      appointmentId: TypeHelpers.toInt(json['appointment_id']),
      doctorId: TypeHelpers.toInt(json['doctor_id']),
      doctorName: json['doctor_name'] as String? ?? '',
      specialization: json['specialization'] as String?,
      date: json['date'] as String? ?? '',
      time: json['time'] as String?,
      reason: json['reason'] as String? ?? '',
      status: json['status'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
    );
  }
}

/// Full patient report payload.
class PatientReport {
  final int patientId;
  final String patientName;
  final int totalAppointments;
  final List<PatientReportAppointment> appointments;

  const PatientReport({
    required this.patientId,
    required this.patientName,
    required this.totalAppointments,
    required this.appointments,
  });

  factory PatientReport.fromJson(Map<String, dynamic> json) {
    final rawAppts = json['appointments'];
    return PatientReport(
      patientId: TypeHelpers.toInt(json['patient_id']),
      patientName: json['patient_name'] as String? ?? '',
      totalAppointments: TypeHelpers.toInt(json['total_appointments']),
      appointments: rawAppts is List
          ? rawAppts
              .whereType<Map<String, dynamic>>()
              .map((a) => PatientReportAppointment.fromJson(a))
              .toList()
          : const [],
    );
  }
}

/// Recurring active day in the doctor report.
class ReportActiveDay {
  final int id;
  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final int slotDurationMinutes;
  final int maxPatientsPerDay;

  const ReportActiveDay({
    required this.id,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.slotDurationMinutes,
    required this.maxPatientsPerDay,
  });

  factory ReportActiveDay.fromJson(Map<String, dynamic> json) {
    return ReportActiveDay(
      id: TypeHelpers.toInt(json['id']),
      dayOfWeek: TypeHelpers.toInt(json['day_of_week']),
      startTime: json['start_time'] as String? ?? '',
      endTime: json['end_time'] as String? ?? '',
      slotDurationMinutes: TypeHelpers.toInt(json['slot_duration_minutes']),
      maxPatientsPerDay: TypeHelpers.toInt(json['max_patients_per_day']),
    );
  }
}

/// A patient visit entry in the doctor report.
class ReportPatientVisit {
  final int appointmentId;
  final int patientId;
  final String patientName;
  final String date;
  final String? time;
  final String status;
  final String notes;

  const ReportPatientVisit({
    required this.appointmentId,
    required this.patientId,
    required this.patientName,
    required this.date,
    this.time,
    required this.status,
    required this.notes,
  });

  factory ReportPatientVisit.fromJson(Map<String, dynamic> json) {
    return ReportPatientVisit(
      appointmentId: TypeHelpers.toInt(json['appointment_id']),
      patientId: TypeHelpers.toInt(json['patient_id']),
      patientName: json['patient_name'] as String? ?? '',
      date: json['date'] as String? ?? '',
      time: json['time'] as String?,
      status: json['status'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
    );
  }
}

/// A date-specific override entry in the doctor report.
class ReportDateOverride {
  final int id;
  final String date;
  final String overrideType;
  final String? startTime;
  final String? endTime;

  const ReportDateOverride({
    required this.id,
    required this.date,
    required this.overrideType,
    this.startTime,
    this.endTime,
  });

  factory ReportDateOverride.fromJson(Map<String, dynamic> json) {
    return ReportDateOverride(
      id: TypeHelpers.toInt(json['id']),
      date: json['date'] as String? ?? '',
      overrideType: json['override_type'] as String? ?? 'available',
      startTime: json['start_time'] as String?,
      endTime: json['end_time'] as String?,
    );
  }
}

/// Full doctor report payload.
class DoctorReport {
  final int doctorId;
  final String doctorName;
  final String? specialization;
  final String? hospitalName;
  final bool isAcceptingPatients;
  final List<ReportActiveDay> activeDays;
  final List<ReportDateOverride> dateOverrides;
  final int totalAppointments;
  final int totalPatientsSeen;
  final List<ReportPatientVisit> bookedPatients;
  final List<ReportPatientVisit> patientsCaredFor;

  const DoctorReport({
    required this.doctorId,
    required this.doctorName,
    this.specialization,
    this.hospitalName,
    required this.isAcceptingPatients,
    required this.activeDays,
    required this.dateOverrides,
    required this.totalAppointments,
    required this.totalPatientsSeen,
    required this.bookedPatients,
    required this.patientsCaredFor,
  });

  factory DoctorReport.fromJson(Map<String, dynamic> json) {
    return DoctorReport(
      doctorId: TypeHelpers.toInt(json['doctor_id']),
      doctorName: json['doctor_name'] as String? ?? '',
      specialization: json['specialization'] as String?,
      hospitalName: json['hospital_name'] as String?,
      isAcceptingPatients: TypeHelpers.toBool(json['is_accepting_patients']),
      activeDays: _asList(json['active_days'], ReportActiveDay.fromJson),
      dateOverrides: _asList(json['date_overrides'], ReportDateOverride.fromJson),
      totalAppointments: TypeHelpers.toInt(json['total_appointments']),
      totalPatientsSeen: TypeHelpers.toInt(json['total_patients_seen']),
      bookedPatients: _asList(json['booked_patients'], ReportPatientVisit.fromJson),
      patientsCaredFor: _asList(
        json['patients_cared_for'],
        ReportPatientVisit.fromJson,
      ),
    );
  }
}

List<T> _asList<T>(dynamic raw, T Function(Map<String, dynamic>) fromJson) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map<String, dynamic>>()
      .map((e) => fromJson(e))
      .toList();
}
