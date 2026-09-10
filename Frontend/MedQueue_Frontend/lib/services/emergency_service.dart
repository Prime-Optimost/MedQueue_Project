import 'package:flutter/foundation.dart';
import '../models/emergency_model.dart';
import 'api_client.dart';

class EmergencyService extends ChangeNotifier {
  final List<EmergencyRequest> _emergencies = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<EmergencyRequest> get emergencies => _emergencies;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<EmergencyRequest?> getActiveEmergency() async {
    try {
      final resp = await ApiClient.getWithAuth<Map<String, dynamic>>(
        '/auth/sos/active/',
        parser: (json) => json,
      );

      if (!resp.isSuccess || resp.data == null) {
        return null;
      }

      final data = resp.data!;
      if (data['has_active'] != true || data['request'] == null) {
        return null;
      }

      return EmergencyRequest.fromJson(data['request'] as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<bool> cancelEmergency(int emergencyId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final resp = await ApiClient.postWithAuth<EmergencyRequest>(
        '/auth/sos/$emergencyId/cancel/',
        body: {},
        parser: (json) => EmergencyRequest.fromJson(json),
      );

      _isLoading = false;
      if (!resp.isSuccess || resp.data == null) {
        _errorMessage = resp.message;
        notifyListeners();
        return false;
      }

      final updated = resp.data!;
      final index = _emergencies.indexWhere((e) => e.id == updated.id);
      if (index != -1) {
        _emergencies[index] = updated;
      } else {
        _emergencies.add(updated);
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to cancel emergency: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Request emergency help
  Future<bool> requestEmergency({
    required String patientId,
    required String patientName,
    required String patientPhone,
    required String description,
    double? latitude,
    double? longitude,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final resp = await ApiClient.postWithAuth<EmergencyRequest>(
        '/auth/sos/',
        body: {
          'latitude': latitude,
          'longitude': longitude,
          'gps_accuracy': null,
          'emergency_type': 'medical',
          'description': description,
        },
        parser: (json) => EmergencyRequest.fromJson(json),
      );

      if (!resp.isSuccess || resp.data == null) {
        _errorMessage = resp.message;
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _emergencies.add(resp.data!);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to request emergency help: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Get emergency requests for admin
  // Uses the admin log endpoint (admin-only) to list all SOS records.
  Future<List<EmergencyRequest>> getEmergencies() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final resp = await ApiClient.getWithAuth<Map<String, dynamic>>(
        '/auth/admin/log/',
        parser: (json) => json,
      );

      _isLoading = false;
      if (!resp.isSuccess || resp.data == null) {
        _errorMessage = resp.message;
        notifyListeners();
        return [];
      }

      final results = <EmergencyRequest>[];
      final list = resp.data!['results'] as List<dynamic>? ?? [];
      for (final item in list) {
        results.add(EmergencyRequest.fromJson(item as Map<String, dynamic>));
      }

      // Replace local cache
      _emergencies
        ..clear()
        ..addAll(results);

      notifyListeners();
      return _emergencies;
    } catch (e) {
      _errorMessage = 'Failed to fetch emergencies: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  // Get active emergencies only
  // An emergency is "active" while it is pending or dispatched.
  List<EmergencyRequest> get activeEmergencies =>
      _emergencies.where((e) => e.status == EmergencyStatus.pending || e.status == EmergencyStatus.dispatched).toList();

  // Acknowledge emergency (for admin): acknowledge -> dispatch
  Future<bool> acknowledgeEmergency(int emergencyId) async {
    return updateEmergencyStatus(emergencyId, EmergencyStatus.dispatched);
  }

  // Update emergency status (admin / doctor)
  Future<bool> updateEmergencyStatus(int emergencyId, EmergencyStatus status) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      String statusToApiString(EmergencyStatus s) {
        switch (s) {
          case EmergencyStatus.pending:
            return 'pending';
          case EmergencyStatus.dispatched:
            return 'dispatched';
          case EmergencyStatus.resolved:
            return 'resolved';
          case EmergencyStatus.cancelled:
            return 'cancelled';
          case EmergencyStatus.falseAlarm:
            return 'false_alarm';
        }
      }

      final resp = await ApiClient.patchWithAuth<EmergencyRequest>(
        '/auth/admin/$emergencyId/status/',
        body: {
          'new_status': statusToApiString(status),
        },
        parser: (json) => EmergencyRequest.fromJson(json),
      );

      _isLoading = false;
      if (!resp.isSuccess || resp.data == null) {
        _errorMessage = resp.message;
        notifyListeners();
        return false;
      }

      final updated = resp.data!;
      final index = _emergencies.indexWhere((e) => e.id == updated.id);
      if (index != -1) {
        _emergencies[index] = updated;
      } else {
        _emergencies.add(updated);
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update emergency status: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
