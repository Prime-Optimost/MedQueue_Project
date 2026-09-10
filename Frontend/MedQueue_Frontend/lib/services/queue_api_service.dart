import 'package:flutter/material.dart';
import 'package:medqueue_frontend/models/queue_model.dart';
import 'package:medqueue_frontend/models/appointment_model.dart';
import 'package:medqueue_frontend/utils/api_constants.dart';
import '../models/api_response_model.dart';
import 'api_client.dart';

/// Queue API Service - Handles all queue-related API calls
class QueueApiService {
  static final QueueApiService _instance = QueueApiService._internal();

  factory QueueApiService() {
    return _instance;
  }

  QueueApiService._internal();

  // ============================================================================
  // PATIENT ENDPOINTS
  // ============================================================================

  /// Get patient's queue position for a specific date
  /// GET /auth/my-position/?date=YYYY-MM-DD
  Future<ApiResponse<PatientQueueResponse>> getPatientQueuePosition({
    DateTime? date,
  }) async {
    final dateStr = date != null ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}' : '';
    final queryParams = dateStr.isNotEmpty ? '?date=$dateStr' : '';
    debugPrint('Url: ${ApiConstants.baseUrl}/auth/my-position/$queryParams');
    return ApiClient.getWithAuth(
      '/auth/my-position/$queryParams',
      parser: (json) => PatientQueueResponse.fromJson(json),
    );
  }

  /// Patient leaves the queue voluntarily
  /// POST /auth/leave/
  Future<ApiResponse<Map<String, dynamic>>> leaveQueue() async {
    return ApiClient.postWithAuth(
      '/auth/leave/',
      body: {},
      parser: (json) => json,
    );
  }

  // ============================================================================
  // DOCTOR ENDPOINTS
  // ============================================================================

  /// Get doctor's full queue for a specific date
  /// GET /auth/doctor/?date=YYYY-MM-DD
  Future<ApiResponse<QueueSession>> getDoctorQueue({
    DateTime? date,
  }) async {
    final dateStr = date != null ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}' : '';
    final queryParams = dateStr.isNotEmpty ? '?date=$dateStr' : '';

    return ApiClient.getWithAuth(
      '/auth/doctor/$queryParams',
      parser: (json) {
        return QueueSession.fromJson(json);
      },
    );
  }

  /// Doctor calls the next patient in queue
  /// POST /auth/doctor/call-next/
  Future<ApiResponse<Map<String, dynamic>>> callNextPatient() async {
    return ApiClient.postWithAuth(
      '/auth/doctor/call-next/',
      body: {},
      parser: (json) => json,
    );
  }

  /// Doctor marks current consultation as complete
  /// POST /auth/doctor/entries/{entry_id}/complete/
  Future<ApiResponse<Map<String, dynamic>>> markEntryComplete(int entryId) async {
    return ApiClient.postWithAuth(
      '/auth/doctor/entries/$entryId/complete/',
      body: {},
      parser: (json) => json,
    );
  }

  /// Doctor pauses the queue
  /// POST /auth/doctor/pause/
  Future<ApiResponse<Map<String, dynamic>>> pauseQueue(String pauseReason) async {
    return ApiClient.postWithAuth(
      '/auth/doctor/pause/',
      body: {'pause_reason': pauseReason},
      parser: (json) => json,
    );
  }

  /// Doctor resumes the paused queue
  /// POST /auth/doctor/resume/
  Future<ApiResponse<Map<String, dynamic>>> resumeQueue() async {
    return ApiClient.postWithAuth(
      '/auth/doctor/resume/',
      body: {},
      parser: (json) => json,
    );
  }

  /// Doctor closes the queue for the day
  /// POST /auth/doctor/close/
  Future<ApiResponse<Map<String, dynamic>>> closeQueue() async {
    return ApiClient.postWithAuth(
      '/auth/doctor/close/',
      body: {},
      parser: (json) => json,
    );
  }

  // ============================================================================
  // DOCTOR SCHEDULE ENDPOINTS
  // ============================================================================

  /// Get doctor's schedule for a specific date
  /// GET /auth/doctor/schedule/?date=YYYY-MM-DD
  Future<ApiResponse<DoctorScheduleResponse>> getDoctorSchedule({
    DateTime? date,
  }) async {
    final dateStr = date != null ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}' : '';
    final queryParams = dateStr.isNotEmpty ? '?date=$dateStr' : '';

    return ApiClient.getWithAuth(
      '/auth/doctor/schedule/$queryParams',
      parser: (json) {
        return DoctorScheduleResponse.fromJson(json);
      },
    );
  }

  /// Get doctor's schedule for the next 7 days
  /// GET /auth/doctor/schedule/?range=week
  Future<ApiResponse<DoctorWeeklyScheduleResponse>> getDoctorWeeklySchedule() async {
    return ApiClient.getWithAuth(
      '/auth/doctor/schedule/?range=week',
      parser: (json) {
        return DoctorWeeklyScheduleResponse.fromJson(json);
      },
    );
  }

  /// Get full appointment details by ID
  /// GET /auth/{appointment_id}/
  Future<ApiResponse<Appointment>> getAppointmentDetail(int appointmentId) async {
    return ApiClient.getWithAuth(
      '/auth/$appointmentId/',
      parser: (json) {
        return Appointment.fromJson(json);
      },
    );
  }

  // ============================================================================
  // HELPERS
  // ============================================================================
}

/// Doctor Schedule Response
class DoctorScheduleResponse {
  final List<Appointment> appointments;

  DoctorScheduleResponse({
    required this.appointments,
  });

  factory DoctorScheduleResponse.fromJson(Map<String, dynamic> json) {
    final List<Appointment> appointments = [];
    if (json['results'] is List) {
      appointments.addAll(
        (json['results'] as List)
            .map((e) => Appointment.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } else if (json['appointments'] is List) {
      appointments.addAll(
        (json['appointments'] as List)
            .map((e) => Appointment.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    }
    return DoctorScheduleResponse(appointments: appointments);
  }
}

/// Doctor Weekly Schedule Response
class DoctorWeeklyScheduleResponse {
  final List<Appointment> appointments;

  DoctorWeeklyScheduleResponse({
    required this.appointments,
  });

  factory DoctorWeeklyScheduleResponse.fromJson(Map<String, dynamic> json) {
    final List<Appointment> appointments = [];
    if (json['results'] is List) {
      appointments.addAll(
        (json['results'] as List)
            .map((e) => Appointment.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } else if (json['appointments'] is List) {
      appointments.addAll(
        (json['appointments'] as List)
            .map((e) => Appointment.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    }
    return DoctorWeeklyScheduleResponse(appointments: appointments);
  }
}
