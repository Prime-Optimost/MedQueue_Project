import 'package:flutter/foundation.dart';
import '../models/doctor_model.dart';
import '../models/time_slot_model.dart';
import 'api_client.dart';

class DoctorService extends ChangeNotifier {
  final List<Doctor> _doctors = [];
  final List<TimeSlot> _slots = [];
  final Set<String> _availableDates = {};
  bool _isLoading = false;
  bool _availabilityLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _fieldErrors;

  // Getters
  List<Doctor> get doctors => _doctors;
  List<TimeSlot> get slots => _slots;
  Set<String> get availableDates => _availableDates;
  bool get isLoading => _isLoading;
  bool get availabilityLoading => _availabilityLoading;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get fieldErrors => _fieldErrors;

  /// Fetch the set of dates (YYYY-MM-DD) on which a doctor can be booked,
  /// used by the booking calendar to grey-out unavailable days (FR-2.2).
  Future<bool> fetchDoctorAvailability(int doctorId, {String? from, String? to}) async {
    _availabilityLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final params = <String, String>{};
      if (from != null && from.isNotEmpty) params['from'] = from;
      if (to != null && to.isNotEmpty) params['to'] = to;
      final query = params.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      final endpoint = '/auth/doctors/$doctorId/availability/'
          '${query.isEmpty ? '' : '?$query'}';

      final response = await ApiClient.getWithAuth<Map<String, dynamic>>(
        endpoint,
        parser: (json) => json,
      );

      if (response.isSuccess && response.data != null) {
        final dates = (response.data!['dates'] as List?)?.cast<String>() ?? [];
        _availableDates..clear()..addAll(dates);
        _availabilityLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response.message;
        _availabilityLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Network error: ${e.toString()}';
      _availabilityLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Fetch all doctors with optional filters
  /// Filters can include: specialization, hospital, name, date
  Future<bool> fetchDoctors({
    String? specialization,
    String? hospital,
    String? name,
    String? date,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _fieldErrors = null;
    notifyListeners();

    try {
      // Build query parameters
      final queryParams = <String, String>{};
      if (specialization != null && specialization.isNotEmpty) {
        queryParams['specialization'] = specialization;
      }
      if (hospital != null && hospital.isNotEmpty) {
        queryParams['hospital'] = hospital;
      }
      if (name != null && name.isNotEmpty) {
        queryParams['search'] = name;
      }
      if (date != null && date.isNotEmpty) {
        queryParams['date'] = date;
      }

      // Build endpoint with query parameters
      String endpoint = '/auth/doctors/';
      if (queryParams.isNotEmpty) {
        final queryString = queryParams.entries
            .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
            .join('&');
        endpoint += '?$queryString';
      }

      final response = await ApiClient.getWithAuth<DoctorsResponse>(
        endpoint,
        parser: (json) => DoctorsResponse.fromJson(json),
      );

      if (response.isSuccess && response.data != null) {
        _doctors.clear();
        _doctors.addAll(response.data!.doctors);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response.message ;
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

  /// Fetch available slots for a doctor on a specific date
  /// date should be in format 'YYYY-MM-DD'
  Future<bool> fetchDoctorSlots(int doctorId, String date) async {
    _isLoading = true;
    _errorMessage = null;
    _fieldErrors = null;
    notifyListeners();

    try {
      String endpoint = '/auth/doctors/$doctorId/slots/?date=$date';
      debugPrint('Fetching slots with endpoint: $endpoint');
      final response = await ApiClient.getWithAuth<SlotsResponse>(
        endpoint,
        parser: (json) => SlotsResponse.fromJson(json),
      );

      if (response.isSuccess && response.data != null) {
        _slots.clear();
        _slots.addAll(response.data!.slots);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response.message ;
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

  /// Get a specific doctor by ID (convenience method)
  Doctor? getDoctorById(int id) {
    try {
      return _doctors.firstWhere((doc) => doc.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get doctors by specialization (convenience method)
  List<Doctor> getDoctorsBySpecialization(String specialization) {
    return _doctors
        .where((doc) =>
            doc.specialization
                .toLowerCase()
                .contains(specialization.toLowerCase()) ||
            specialization.toLowerCase().contains(doc.specialization.toLowerCase()))
        .toList();
  }

  /// Clear cached data
  void clearCache() {
    _doctors.clear();
    _slots.clear();
    notifyListeners();
  }
}

/// Helper class to parse doctors list response
class DoctorsResponse {
  final int count;
  final List<Doctor> doctors;

  DoctorsResponse({
    required this.count,
    required this.doctors,
  });

  factory DoctorsResponse.fromJson(Map<String, dynamic> json) {
    final doctorsList = json['doctors'] as List?;
    return DoctorsResponse(
      count: json['count'] as int? ?? 0,
      doctors: doctorsList != null
          ? (doctorsList)
              .map((doc) => Doctor.fromJson(doc as Map<String, dynamic>))
              .toList()
          : [],
    );
  }
}

/// Helper class to parse slots response
class SlotsResponse {
  final int doctorId;
  final String date;
  final List<TimeSlot> slots;
  final int total;
  final int available;

  SlotsResponse({
    required this.doctorId,
    required this.date,
    required this.slots,
    required this.total,
    required this.available,
  });

  factory SlotsResponse.fromJson(Map<String, dynamic> json) {
    final slotsList = json['slots'] as List?;
    return SlotsResponse(
      doctorId: json['doctor_id'] as int? ?? 0,
      date: json['date'] as String? ?? '',
      slots: slotsList != null
          ? (slotsList)
              .map((slot) => TimeSlot.fromJson(slot as Map<String, dynamic>))
              .toList()
          : [],
      total: json['total'] as int? ?? 0,
      available: json['available'] as int? ?? 0,
    );
  }
}
