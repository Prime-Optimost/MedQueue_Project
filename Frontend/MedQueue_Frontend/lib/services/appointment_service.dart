import 'package:flutter/foundation.dart';
import '../models/appointment_model.dart';
import 'api_client.dart';

class AppointmentService extends ChangeNotifier {
  final List<Appointment> _appointments = [];
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _fieldErrors;
  //get number of appoinntments
  int get appointmentCount => _appointments.length;

  // Getters
  List<Appointment> get appointments =>
      _appointments
        ..sort((a, b) => a.appointmentDate.compareTo(b.appointmentDate));
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get fieldErrors => _fieldErrors;

  //upcoming appointments sort by date ascending, past appointments sort by date descending
  List<Appointment> get upcomingAppointments =>
      _appointments
          .where(
            (a) =>
                a.isUpcoming &&
                (a.status == 'confirmed' || a.status == 'rescheduled'),
          )
          .toList()
        ..sort((a, b) => a.appointmentDate.compareTo(b.appointmentDate));
  //

  List<Appointment> get pastAppointments =>
      _appointments.where((a) => a.isPast || a.status == 'completed').toList()
        ..sort((a, b) => b.appointmentDate.compareTo(a.appointmentDate));

  /// Fetch all user's appointments (patient/doctor specific based on JWT token role)
  /// Optional filters: status, from_date, to_date, doctor_id, page, page_size
  /// Fetches full details for each appointment by calling the detail endpoint
  Future<bool> fetchAppointments({
    String? status,
    String? fromDate,
    String? toDate,
    int? doctorId,
    int page = 1,
    int pageSize = 20,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _fieldErrors = null;
    notifyListeners();

    try {
      // Build query parameters
      final queryParams = <String, String>{};
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }
      if (fromDate != null && fromDate.isNotEmpty) {
        queryParams['from'] = fromDate;
      }
      if (toDate != null && toDate.isNotEmpty) {
        queryParams['to'] = toDate;
      }
      if (doctorId != null) {
        queryParams['doctor_id'] = doctorId.toString();
      }
      queryParams['page'] = page.toString();
      queryParams['page_size'] = pageSize.toString();

      // Build endpoint with query parameters
      String endpoint = '/auth/history/';
      if (queryParams.isNotEmpty) {
        final queryString = queryParams.entries
            .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
            .join('&');
        endpoint += '?$queryString';
      }
      debugPrint('calling endpoint: $endpoint');
      final response = await ApiClient.getWithAuth<AppointmentListResponse>(
        endpoint,
        parser: (json) => AppointmentListResponse.fromJson(json),
      );

      if (response.isSuccess && response.data != null) {
        _appointments.clear();

        // Fetch full details for each appointment in parallel
        final appointmentIds = response.data!.appointments
            .map((a) => a.id)
            .toList();
        final detailFutures = appointmentIds
            .map((id) => _fetchDetailQuietly(id))
            .toList();
        final detailedAppointments = await Future.wait(detailFutures);

        // Filter out nulls and add to list
        final validAppointments = detailedAppointments
            .whereType<Appointment>()
            .toList();
        for (final apt in validAppointments) {
          final index = _appointments.indexWhere((a) => a.id == apt.id);
          if (index != -1) {
            _appointments[index] = apt; // update existing
          } else {
            _appointments.add(apt); // add new only
          }
        }

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response.message;
        _fieldErrors = response.errors;
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Network error: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Helper function to fetch appointment detail without updating loading state
  /// Used internally by fetchAppointments to fetch details in parallel
  Future<Appointment?> _fetchDetailQuietly(int appointmentId) async {
    try {
      final response = await ApiClient.getWithAuth<Appointment>(
        '/auth/$appointmentId/',
        parser: (json) => Appointment.fromJson(json),
      );

      if (response.isSuccess && response.data != null) {
        return response.data;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching appointment detail for ID $appointmentId: $e');
      return null;
    }
  }

  // fetch appointment detail by id

  Future<Appointment?> fetchAppointmentDetail(int appointmentId) async {
    _isLoading = true;
    _errorMessage = null;
    _fieldErrors = null;
    notifyListeners();

    try {
      final response = await ApiClient.getWithAuth<Appointment>(
        '/auth/$appointmentId/',
        parser: (json) => Appointment.fromJson(json),
      );

      if (response.isSuccess && response.data != null) {
        // Update or add the appointment in the list
        final index = _appointments.indexWhere((a) => a.id == appointmentId);
        if (index != -1) {
          _appointments[index] = response.data!;
        } else {
          _appointments.add(response.data!);
        }
        _isLoading = false;
        notifyListeners();
        return response.data;
      } else {
        _errorMessage = response.message;
        _fieldErrors = response.errors;
        _isLoading = false;
        notifyListeners();
        return null;
      }
    } catch (e) {
      _errorMessage = 'Network error: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Book a new appointment
  /// slotId: ID of the TimeSlot to book
  /// reason: Optional reason for appointment
  Future<Appointment?> bookAppointment({
    required int slotId,
    String reason = '',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _fieldErrors = null;
    notifyListeners();

    try {
      final response = await ApiClient.postWithAuth<Appointment>(
        '/auth/book/',
        body: {'slot_id': slotId, if (reason.isNotEmpty) 'reason': reason},
        parser: (json) => Appointment.fromJson(json),
      );

      if (response.isSuccess && response.data != null) {
        _appointments.add(response.data!);
        _isLoading = false;
        notifyListeners();
        return response.data;
      } else {
        _errorMessage = response.message;
        _fieldErrors = response.errors;
        _isLoading = false;
        notifyListeners();
        return null;
      }
    } catch (e) {
      _errorMessage = 'Network error: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Cancel an appointment
  /// appointmentId: ID of appointment to cancel
  /// cancellationReason: Optional reason for cancellation
  Future<Appointment?> cancelAppointment(
    int appointmentId, {
    String cancellationReason = '',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _fieldErrors = null;
    notifyListeners();

    try {
      final response = await ApiClient.postWithAuth<Appointment>(
        '/auth/$appointmentId/cancel/',
        body: {
          if (cancellationReason.isNotEmpty)
            'cancellation_reason': cancellationReason,
        },
        parser: (json) => Appointment.fromJson(json),
      );

      if (response.isSuccess && response.data != null) {
        // Update the appointment in the list
        final index = _appointments.indexWhere((a) => a.id == appointmentId);
        if (index != -1) {
          _appointments[index] = response.data!;
        }
        _isLoading = false;
        notifyListeners();
        return response.data;
      } else {
        _errorMessage = response.message;
        _fieldErrors = response.errors;
        _isLoading = false;
        notifyListeners();
        return null;
      }
    } catch (e) {
      _errorMessage = 'Network error: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Reschedule an appointment to a new slot
  /// appointmentId: ID of appointment to reschedule
  /// newSlotId: ID of new TimeSlot
  /// reason: Optional reason for rescheduling
  Future<Appointment?> rescheduleAppointment(
    int appointmentId, {
    required int newSlotId,
    String reason = '',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _fieldErrors = null;
    notifyListeners();

    try {
      final response = await ApiClient.postWithAuth<Appointment>(
        '/auth/$appointmentId/reschedule/',
        body: {
          'new_slot_id': newSlotId,
          if (reason.isNotEmpty) 'reason': reason,
        },
        parser: (json) => Appointment.fromJson(json),
      );

      if (response.isSuccess && response.data != null) {
        // Update the appointment in the list
        final index = _appointments.indexWhere((a) => a.id == appointmentId);
        if (index != -1) {
          _appointments[index] = response.data!;
        }
        _isLoading = false;
        notifyListeners();
        return response.data;
      } else {
        _errorMessage = response.message;
        _fieldErrors = response.errors;
        _isLoading = false;
        notifyListeners();
        return null;
      }
    } catch (e) {
      _errorMessage = 'Network error: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Mark an appointment as completed or no-show (Doctor role)
  /// appointmentId: ID of appointment
  /// newStatus: 'completed' or 'no_show'
  /// notes: Optional notes from doctor
  Future<Appointment?> markAppointmentStatus(
    int appointmentId, {
    required String newStatus,
    String notes = '',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _fieldErrors = null;
    notifyListeners();

    try {
      final response = await ApiClient.postWithAuth<Appointment>(
        '/auth/$appointmentId/mark/',
        body: {'new_status': newStatus, if (notes.isNotEmpty) 'notes': notes},
        parser: (json) => Appointment.fromJson(json),
      );

      if (response.isSuccess && response.data != null) {
        // Update the appointment in the list
        final index = _appointments.indexWhere((a) => a.id == appointmentId);
        if (index != -1) {
          _appointments[index] = response.data!;
        }
        _isLoading = false;
        notifyListeners();
        return response.data;
      } else {
        _errorMessage = response.message;
        _fieldErrors = response.errors;
        _isLoading = false;
        notifyListeners();
        return null;
      }
    } catch (e) {
      _errorMessage = 'Network error: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Get a specific appointment by ID
  Appointment? getAppointmentById(int id) {
    try {
      return _appointments.firstWhere((a) => a.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Filter appointments by status
  List<Appointment> getAppointmentsByStatus(String status) {
    return _appointments.where((a) => a.status == status).toList();
  }

  /// Clear all cached appointments
  void clearCache() {
    _appointments.clear();
    notifyListeners();
  }

  /// Clear error messages
  void clearError() {
    _errorMessage = null;
    _fieldErrors = null;
    notifyListeners();
  }
}

/// Helper class to parse appointment list response
class AppointmentListResponse {
  final List<Appointment> appointments;
  final int total;
  final int page;
  final int pages;

  AppointmentListResponse({
    required this.appointments,
    required this.total,
    required this.page,
    required this.pages,
  });

  factory AppointmentListResponse.fromJson(Map<String, dynamic> json) {
    final results = json['results'] as List?;
    return AppointmentListResponse(
      appointments: results != null
          ? (results)
                .map(
                  (apt) =>
                      Appointment.fromListJson(apt as Map<String, dynamic>),
                )
                .toList()
          : [],
      total: json['count'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pages: json['pages'] as int? ?? 1,
    );
  }
}
