import 'package:flutter/foundation.dart';
import '../models/doctor_availability_override_model.dart';
import '../models/doctor_schedule_model.dart';
import '../utils/api_constants.dart';
import 'api_client.dart';

class AvailabilityService extends ChangeNotifier {
  final List<DoctorSchedule> _schedules = [];
  final List<DoctorAvailabilityOverride> _overrides = [];
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _fieldErrors;

  List<DoctorSchedule> get schedules => _schedules;
  List<DoctorAvailabilityOverride> get overrides => _overrides;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get fieldErrors => _fieldErrors;

  Future<bool> fetchMyAvailability() async {
    _isLoading = true;
    _errorMessage = null;
    _fieldErrors = null;
    notifyListeners();

    try {
      final response = await ApiClient.getWithAuth<dynamic>(
        ApiConstants.availabilityMyEndpoint,
        parser: (json) => json,
      );

      if (response.isSuccess && response.data != null) {
        _schedules.clear();
        final raw = response.data!;
        debugPrint('Raw availability data: $raw');
        final List<dynamic> rawList = raw is List<dynamic>
            ? raw
            : (raw is Map && raw['data'] is List)
                ? raw['data'] as List<dynamic>
                : const <dynamic>[];
        _schedules.addAll(
          rawList.map((item) => DoctorSchedule.fromJson(item as Map<String, dynamic>)),
        );
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _errorMessage = response.message;
      _fieldErrors = response.errors;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Network error: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> createAvailabilityEntry(Map<String, dynamic> body) async {
    _isLoading = true;
    _errorMessage = null;
    _fieldErrors = null;
    notifyListeners();

    try {
      final response = await ApiClient.postWithAuth<Map<String, dynamic>>(
        ApiConstants.availabilityMyEndpoint,
        body: body,
        parser: (json) => json,
      );

      if (response.isSuccess && response.data != null) {
        final newSchedule = DoctorSchedule.fromJson(response.data!);
        _schedules.add(newSchedule);
        _schedules.sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _errorMessage = _extractErrorMessage(response.message, response.errors);
      _fieldErrors = response.errors;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Network error: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateAvailabilityEntry(int id, Map<String, dynamic> body) async {
    _isLoading = true;
    _errorMessage = null;
    _fieldErrors = null;
    notifyListeners();

    try {
      final endpoint = '${ApiConstants.availabilityMyEndpoint}$id/';
      final response = await ApiClient.patchWithAuth<Map<String, dynamic>>(
        endpoint,
        body: body,
        parser: (json) => json,
      );

      if (response.isSuccess && response.data != null) {
        final updated = DoctorSchedule.fromJson(response.data!);
        final index = _schedules.indexWhere((s) => s.id == id);
        if (index != -1) {
          _schedules[index] = updated;
        }
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _errorMessage = _extractErrorMessage(response.message, response.errors);
      _fieldErrors = response.errors;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Network error: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteAvailabilityEntry(int id) async {
    _isLoading = true;
    _errorMessage = null;
    _fieldErrors = null;
    notifyListeners();

    try {
      final endpoint = '${ApiConstants.availabilityMyEndpoint}$id/';
      final response = await ApiClient.deleteWithAuth<Map<String, dynamic>>(
        endpoint,
        parser: (json) => json,
      );

      if (response.isSuccess) {
        _schedules.removeWhere((s) => s.id == id);
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _errorMessage = _extractErrorMessage(response.message, response.errors);
      _fieldErrors = response.errors;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Network error: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> fetchDateOverrides({DateTime? month}) async {
    _errorMessage = null;
    _fieldErrors = null;
    notifyListeners();

    try {
      final query = month == null
          ? ''
          : '?month=${month.year}-${month.month.toString().padLeft(2, '0')}';
      final response = await ApiClient.getWithAuth<dynamic>(
        '${ApiConstants.availabilityDatesEndpoint}$query',
        parser: (json) => json,
      );

      if (response.isSuccess && response.data != null) {
        _overrides.clear();
        final raw = response.data!;
        debugPrint('Raw override data: $raw');
        final List<dynamic> rawList = raw is List<dynamic>
            ? raw
            : (raw is Map && raw['data'] is List)
                ? raw['data'] as List<dynamic>
                : const <dynamic>[];
        _overrides.addAll(
          rawList.map(
            (item) => DoctorAvailabilityOverride.fromJson(
              item as Map<String, dynamic>,
            ),
          ),
        );
        _overrides.sort((a, b) => a.date.compareTo(b.date));
        notifyListeners();
        return true;
      }

      _errorMessage = response.message;
      _fieldErrors = response.errors;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Network error: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> createDateOverride(Map<String, dynamic> body) async {
    _errorMessage = null;
    _fieldErrors = null;
    notifyListeners();

    try {
      final response = await ApiClient.postWithAuth<Map<String, dynamic>>(
        ApiConstants.availabilityDatesEndpoint,
        body: body,
        parser: (json) => json,
      );

      if (response.isSuccess && response.data != null) {
        _overrides.removeWhere(
          (o) => o.date ==
              DateTime.parse(response.data!['date'] as String),
        );
        _overrides.add(
          DoctorAvailabilityOverride.fromJson(response.data!),
        );
        _overrides.sort((a, b) => a.date.compareTo(b.date));
        notifyListeners();
        return true;
      }

      _errorMessage = _extractErrorMessage(response.message, response.errors);
      _fieldErrors = response.errors;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Network error: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateDateOverride(int id, Map<String, dynamic> body) async {
    _errorMessage = null;
    _fieldErrors = null;
    notifyListeners();

    try {
      final endpoint = '${ApiConstants.availabilityDatesEndpoint}$id/';
      final response = await ApiClient.patchWithAuth<Map<String, dynamic>>(
        endpoint,
        body: body,
        parser: (json) => json,
      );

      if (response.isSuccess && response.data != null) {
        final updated = DoctorAvailabilityOverride.fromJson(response.data!);
        final index = _overrides.indexWhere((o) => o.id == id);
        if (index != -1) {
          _overrides[index] = updated;
        }
        _overrides.sort((a, b) => a.date.compareTo(b.date));
        notifyListeners();
        return true;
      }

      _errorMessage = _extractErrorMessage(response.message, response.errors);
      _fieldErrors = response.errors;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Network error: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteDateOverride(int id) async {
    _errorMessage = null;
    _fieldErrors = null;
    notifyListeners();

    try {
      final endpoint = '${ApiConstants.availabilityDatesEndpoint}$id/';
      final response = await ApiClient.deleteWithAuth<Map<String, dynamic>>(
        endpoint,
        parser: (json) => json,
      );

      if (response.isSuccess) {
        _overrides.removeWhere((o) => o.id == id);
        notifyListeners();
        return true;
      }

      _errorMessage = _extractErrorMessage(response.message, response.errors);
      _fieldErrors = response.errors;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Network error: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    _fieldErrors = null;
    notifyListeners();
  }

  String _extractErrorMessage(String? message, Map<String, dynamic>? errors) {
    if (errors == null || errors.isEmpty) {
      return _friendlyAvailabilityMessage(message ?? 'Request failed.');
    }

    final preferredKeys = ['detail', 'non_field_errors', 'message'];
    for (final key in preferredKeys) {
      final value = errors[key];
      final extracted = _stringifyErrorValue(value);
      if (extracted != null && extracted.isNotEmpty) {
        return _friendlyAvailabilityMessage(extracted);
      }
    }

    for (final value in errors.values) {
      final extracted = _stringifyErrorValue(value);
      if (extracted != null && extracted.isNotEmpty) {
        return _friendlyAvailabilityMessage(extracted);
      }
    }

    return _friendlyAvailabilityMessage(message ?? 'Request failed.');
  }

  String _friendlyAvailabilityMessage(String message) {
    final normalized = message.toLowerCase();
    if (normalized.contains('unique set') ||
        normalized.contains('already exists') ||
        normalized.contains('active schedule')) {
      return 'This availability already exists. Please update the existing schedule instead.';
    }

    return message;
  }

  String? _stringifyErrorValue(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      return value;
    }
    if (value is List && value.isNotEmpty) {
      return value.first.toString();
    }
    return value.toString();
  }
}
