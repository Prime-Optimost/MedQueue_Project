// Queue Status Enums
enum QueueSessionStatus { active, paused, closed }

enum QueueEntryStatus { waiting, called, inConsult, completed, skipped, left }

// Queue Session Model (one per doctor per day)
class QueueSession {
  final int id;
  final int doctorId;
  final String doctorName;
  final DateTime date;
  final QueueSessionStatus status;
  final int currentPosition;
  final int nextNumber;
  final String pauseReason;
  final DateTime? pausedAt;
  final int totalPauseMinutes;
  final int waitingCount;
  final int servedCount;
  final bool isPaused;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<QueueEntry>? entries;

  QueueSession({
    required this.id,
    required this.doctorId,
    required this.doctorName,
    required this.date,
    required this.status,
    required this.currentPosition,
    required this.nextNumber,
    required this.pauseReason,
    this.pausedAt,
    required this.totalPauseMinutes,
    required this.waitingCount,
    required this.servedCount,
    required this.isPaused,
    required this.createdAt,
    required this.updatedAt,
    this.entries,
  });

  factory QueueSession.fromJson(Map<String, dynamic> json) {
    return QueueSession(
      id: json['id'] ?? 0,
      doctorId: json['doctor_id'] ?? 0,
      doctorName: json['doctor_name'] ?? '',
      date: DateTime.parse(json['date'] ?? DateTime.now().toString()),
      status: QueueSessionStatus.values.byName(json['status'] ?? 'active'),
      currentPosition: json['current_position'] ?? 0,
      nextNumber: json['next_number'] ?? 1,
      pauseReason: json['pause_reason'] ?? '',
      pausedAt:
          json['paused_at'] != null ? DateTime.parse(json['paused_at']) : null,
      totalPauseMinutes: json['total_pause_minutes'] ?? 0,
      waitingCount: json['waiting_count'] ?? 0,
      servedCount: json['served_count'] ?? 0,
      isPaused: (json['status'] as String? ?? '') == 'paused',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toString()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toString()),
      entries: (json['entries'] as List?)
          ?.map((e) => QueueEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'doctor_id': doctorId,
        'doctor_name': doctorName,
        'date': date.toIso8601String(),
        'status': status.name,
        'current_position': currentPosition,
        'next_number': nextNumber,
        'pause_reason': pauseReason,
        'paused_at': pausedAt?.toIso8601String(),
        'total_pause_minutes': totalPauseMinutes,
        'waiting_count': waitingCount,
        'served_count': servedCount,
        'is_paused': isPaused,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'entries': entries?.map((e) => e.toJson()).toList(),
      };

  QueueSession copyWith({
    int? id,
    int? doctorId,
    String? doctorName,
    DateTime? date,
    QueueSessionStatus? status,
    int? currentPosition,
    int? nextNumber,
    String? pauseReason,
    DateTime? pausedAt,
    int? totalPauseMinutes,
    int? waitingCount,
    int? servedCount,
    bool? isPaused,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<QueueEntry>? entries,
  }) {
    return QueueSession(
      id: id ?? this.id,
      doctorId: doctorId ?? this.doctorId,
      doctorName: doctorName ?? this.doctorName,
      date: date ?? this.date,
      status: status ?? this.status,
      currentPosition: currentPosition ?? this.currentPosition,
      nextNumber: nextNumber ?? this.nextNumber,
      pauseReason: pauseReason ?? this.pauseReason,
      pausedAt: pausedAt ?? this.pausedAt,
      totalPauseMinutes: totalPauseMinutes ?? this.totalPauseMinutes,
      waitingCount: waitingCount ?? this.waitingCount,
      servedCount: servedCount ?? this.servedCount,
      isPaused: isPaused ?? this.isPaused,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      entries: entries ?? this.entries,
    );
  }
}

// Queue Entry Model (patient's place in queue)
class QueueEntry {
  final int id;

  final String patientName;
  final int? appointmentId;
  final int queueNumber;
  final QueueEntryStatus status;
  final DateTime? calledAt;
  final DateTime? completedAt;
  final bool notified2away;
  final int positionsAhead;
  final int estimatedWaitMinutes;
  final DateTime createdAt;
  final DateTime updatedAt;

  QueueEntry({
    required this.id,
    
    required this.patientName,
    this.appointmentId,
    required this.queueNumber,
    required this.status,
    this.calledAt,
    this.completedAt,
    required this.notified2away,
    required this.positionsAhead,
    required this.estimatedWaitMinutes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory QueueEntry.fromJson(Map<String, dynamic> json) {
    return QueueEntry(
      id: json['id'] ?? 0,
     
      patientName: json['patient_name'] ?? '',
      appointmentId: json['appointment'] ?? json['appointment_id'],
      queueNumber: json['queue_number'] ?? 0,
      status: QueueEntryStatus.values
          .byName((json['status'] ?? 'waiting').replaceAll('_', '')),
      calledAt: json['called_at'] != null ? DateTime.parse(json['called_at']) : null,
      completedAt:
          json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null,
      notified2away: json['notified_2away'] ?? false,
      positionsAhead: json['positions_ahead'] ?? 0,
      estimatedWaitMinutes: json['estimated_wait_mins'] ?? 0,
      createdAt:
          DateTime.parse(json['created_at'] ?? DateTime.now().toString()),
      updatedAt:
          DateTime.parse(json['updated_at'] ?? DateTime.now().toString()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        
        'patient_name': patientName,
        'appointment_id': appointmentId,
        'queue_number': queueNumber,
        'status': status.name,
        'called_at': calledAt?.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'notified_2away': notified2away,
        'positions_ahead': positionsAhead,
        'estimated_wait_mins': estimatedWaitMinutes,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

// Wait Time Info
class WaitTimeInfo {
  final int positionsAhead;
  final int estimatedWaitMinutes;
  final int currentPosition;

  WaitTimeInfo({
    required this.positionsAhead,
    required this.estimatedWaitMinutes,
    required this.currentPosition,
  });

  factory WaitTimeInfo.fromJson(Map<String, dynamic> json) {
    return WaitTimeInfo(
      positionsAhead: json['positions_ahead'] ?? 0,
      estimatedWaitMinutes: json['estimated_wait_mins'] ?? 0,
      currentPosition: json['current_position'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'positions_ahead': positionsAhead,
        'estimated_wait_mins': estimatedWaitMinutes,
        'current_position': currentPosition,
      };
}

// Patient Queue Response
class PatientQueueResponse {
  final bool inQueue;
  final QueueEntry? entry;
  final WaitTimeInfo? waitInfo;
  final String firebasePath;

  PatientQueueResponse({
    required this.inQueue,
    this.entry,
    this.waitInfo,
    required this.firebasePath,
  });

  factory PatientQueueResponse.fromJson(Map<String, dynamic> json) {
    return PatientQueueResponse(
      inQueue: json['in_queue'] ?? false,
      entry: json['entry'] != null
          ? QueueEntry.fromJson(json['entry'] as Map<String, dynamic>)
          : null,
      waitInfo: json['wait_info'] != null
          ? WaitTimeInfo.fromJson(json['wait_info'] as Map<String, dynamic>)
          : null,
      firebasePath: json['firebase_path'] ?? '',
    );
  }
}

// Legacy compatibility
enum QueueStatus { waiting, inProgress, completed, cancelled }
