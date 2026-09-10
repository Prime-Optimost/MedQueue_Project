import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/admin_dashboard_model.dart';
import '../models/admin_reports_model.dart';
import '../models/user_management_model.dart';
import 'api_client.dart';

/// Admin service: fetches dashboard "System Overview" statistics from the
/// backend so the admin screen shows live database numbers.
class AdminService extends ChangeNotifier {
  AdminDashboardStats? _dashboardStats;
  bool _isLoading = false;
  String? _errorMessage;

  List<AdminUserEntry> _users = [];
  bool _usersLoading = false;
  String? _usersError;
  int _userCount = 0;

  AdminDashboardStats? get dashboardStats => _dashboardStats;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<AdminUserEntry> get users => _users;
  bool get usersLoading => _usersLoading;
  String? get usersError => _usersError;
  int get userCount => _userCount;  /// Fetch aggregated system-overview stats for the admin dashboard.
  Future<AdminDashboardStats?> fetchDashboardStats() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final resp = await ApiClient.getWithAuth<Map<String, dynamic>>(
        '/auth/admin/dashboard/stats/',
        parser: (json) => json,
      );

      _isLoading = false;

      if (!resp.isSuccess || resp.data == null) {
        _errorMessage = resp.message;
        notifyListeners();
        return null;
      }

      final stats = AdminDashboardStats.fromJson(resp.data!);
      _dashboardStats = stats;
      notifyListeners();
      return stats;
    } catch (e) {
      _errorMessage = 'Failed to fetch dashboard stats: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Create a user account on behalf of the admin (used to add doctors).
  /// Returns the server message on success, or null on failure (errorMessage is set).
  Future<bool> createUser({
    required String username,
    required String email,
    required String phoneNumber,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
    String specialization = '',
    String hospitalName = '',
    String consultationFee = '',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final body = <String, dynamic>{
        'username': username.trim(),
        'email': email.trim(),
        'phone_number': phoneNumber.trim(),
        'password': password,
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'role': role,
      };

      if (role == 'doctor') {
        body['specialization'] = specialization.trim();
        body['hospital_name'] = hospitalName.trim();
        if (consultationFee.trim().isNotEmpty) {
          body['consultation_fee'] = consultationFee.trim();
        }
      }

      final resp = await ApiClient.postWithAuth<Map<String, dynamic>>(
        '/auth/admin/users/',
        body: body,
        parser: (json) => json,
      );

      _isLoading = false;

      if (!resp.isSuccess) {
        _errorMessage = resp.message;
        notifyListeners();
        return false;
      }

      // Refresh the overview counts since a new user was added. Fire it without
      // blocking so the UI responds to the button tap immediately.
      unawaited(_refreshAfterMutation());
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to create user: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Fetch a paginated, filterable list of users for the admin user-management
  /// screen. Supports role and search filters.
  Future<AdminUserListResult?> fetchUsers({
    String role = '',
    String search = '',
    int page = 1,
    int pageSize = 50,
  }) async {
    _usersLoading = true;
    _usersError = null;
    notifyListeners();

    try {
      final params = <String, String>{
        'page': '$page',
        'page_size': '$pageSize',
      };
      if (role.isNotEmpty) params['role'] = role;
      if (search.trim().isNotEmpty) params['search'] = search.trim();

      // Build query string with proper URL encoding for each value.
      final query = params.entries
          .map((e) =>
              '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
          .join('&');
      final resp = await ApiClient.getWithAuth<Map<String, dynamic>>(
        '/auth/users/?$query',
        parser: (json) => json,
      );

      _usersLoading = false;

      if (!resp.isSuccess || resp.data == null) {
        _usersError = resp.message;
        notifyListeners();
        return null;
      }

      final result = AdminUserListResult.fromJson(resp.data!);
      _users = result.users;
      _userCount = result.count;
      notifyListeners();
      return result;
    } catch (e) {
      _usersError = 'Failed to fetch users: ${e.toString()}';
      _usersLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Update a user's profile fields via `PATCH /auth/users/<id>/`.
  /// Sends only the provided fields (PATCH semantics).
  Future<bool> updateUser(
    int userId, {
    String? email,
    String? phoneNumber,
    String? firstName,
    String? lastName,
    String? specialization,
    String? hospitalName,
    String? consultationFee,
    bool? isAcceptingPatients,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final body = <String, dynamic>{};
      if (firstName != null) body['first_name'] = firstName.trim();
      if (lastName != null) body['last_name'] = lastName.trim();
      if (email != null) body['email'] = email.trim();
      if (phoneNumber != null) body['phone_number'] = phoneNumber.trim();

      final doctorProfile = <String, dynamic>{};
      if (specialization != null) doctorProfile['specialization'] = specialization.trim();
      if (hospitalName != null) doctorProfile['hospital_name'] = hospitalName.trim();
      if (consultationFee != null && consultationFee.trim().isNotEmpty) {
        doctorProfile['consultation_fee'] = consultationFee.trim();
      }
      if (isAcceptingPatients != null) {
        doctorProfile['is_accepting_patients'] = isAcceptingPatients;
      }
      if (doctorProfile.isNotEmpty) body['doctor_profile'] = doctorProfile;

      final resp = await ApiClient.patchWithAuth<Map<String, dynamic>>(
        '/auth/users/$userId/',
        body: body,
        parser: (json) => json,
      );

      _isLoading = false;

      if (!resp.isSuccess) {
        _errorMessage = resp.message;
        notifyListeners();
        return false;
      }

      // Refresh counts in the background so the button responds immediately.
      unawaited(_refreshAfterMutation());
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update user: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Activate or deactivate a user account via `PATCH /auth/users/<id>/`.
  Future<bool> setUserActive(int userId, {required bool isActive}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final resp = await ApiClient.patchWithAuth<Map<String, dynamic>>(
        '/auth/users/$userId/',
        body: {'is_active': isActive},
        parser: (json) => json,
      );

      _isLoading = false;

      if (!resp.isSuccess) {
        _errorMessage = resp.message;
        notifyListeners();
        return false;
      }

      unawaited(_refreshAfterMutation());
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update user status: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Permanently delete a user account via `DELETE /auth/users/<id>/`.
  /// Returns the server message on success, or null on failure (errorMessage set).
  Future<bool> deleteUser(int userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final resp = await ApiClient.deleteWithAuth<Map<String, dynamic>>(
        '/auth/users/$userId/',
        parser: (json) => json,
      );

      _isLoading = false;

      if (!resp.isSuccess) {
        _errorMessage = resp.message;
        notifyListeners();
        return false;
      }

      unawaited(_refreshAfterMutation());
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete user: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Re-fetch the current user list (preserving the active role filter) and the
  /// dashboard counts after a mutation. Best-effort and fire-and-forget.
  Future<void> _refreshAfterMutation() async {
    try {
      final recentRole = _users.isNotEmpty ? _users.first.role : '';
      await fetchUsers(role: recentRole);
      await fetchDashboardStats();
    } catch (_) {
      // Best-effort refresh only.
    }
  }

  // -------------------------------------------------------------------------
  // Reports & Live Queue
  // -------------------------------------------------------------------------

  bool _reportsLoading = false;
  String? _reportsError;
  AggregateQueueStats? _aggregateStats;
  EmergencySummaryStats? _emergencySummary;

  bool get reportsLoading => _reportsLoading;
  String? get reportsError => _reportsError;
  AggregateQueueStats? get aggregateStats => _aggregateStats;
  EmergencySummaryStats? get emergencySummary => _emergencySummary;

  /// Fetch the aggregate queue statistics for a date range plus the
  /// emergency summary, for the admin reports screen.
  Future<void> fetchReports({
    required String from,
    required String to,
  }) async {
    _reportsLoading = true;
    _reportsError = null;
    notifyListeners();

    try {
      final fromEnc = Uri.encodeQueryComponent(from);
      final toEnc = Uri.encodeQueryComponent(to);

      final aggResp = await ApiClient.getWithAuth<Map<String, dynamic>>(
        '/auth/admin/stats/aggregate/?from=$fromEnc&to=$toEnc',
        parser: (json) => json,
      );
      if (aggResp.isSuccess && aggResp.data != null) {
        _aggregateStats = AggregateQueueStats.fromJson(aggResp.data!);
      }

      final emergencyResp = await ApiClient.getWithAuth<Map<String, dynamic>>(
        '/auth/admin/summary/',
        parser: (json) => json,
      );
      if (emergencyResp.isSuccess && emergencyResp.data != null) {
        _emergencySummary = EmergencySummaryStats.fromJson(emergencyResp.data!);
      }

      _reportsLoading = false;
      notifyListeners();
    } catch (e) {
      _reportsError = 'Failed to load reports: ${e.toString()}';
      _reportsLoading = false;
      notifyListeners();
    }
  }

  bool _queueLoading = false;
  String? _queueError;
  LiveQueueOverview? _liveQueue;

  bool get queueLoading => _queueLoading;
  String? get queueError => _queueError;
  LiveQueueOverview? get liveQueue => _liveQueue;

  /// Fetch the admin live queue overview for a given date (defaults to today
  /// when date is empty).
  Future<void> fetchLiveQueue({String date = ''}) async {
    _queueLoading = true;
    _queueError = null;
    notifyListeners();

    try {
      final query = date.isEmpty
          ? ''
          : '?date=${Uri.encodeQueryComponent(date)}';
      final resp = await ApiClient.getWithAuth<Map<String, dynamic>>(
        '/auth/admin/overview/$query',
        parser: (json) => json,
      );

      _queueLoading = false;

      if (!resp.isSuccess || resp.data == null) {
        _queueError = resp.message;
        notifyListeners();
        return;
      }

      _liveQueue = LiveQueueOverview.fromJson(resp.data!);
      notifyListeners();
    } catch (e) {
      _queueError = 'Failed to load live queue: ${e.toString()}';
      _queueLoading = false;
      notifyListeners();
    }
  }

  /// Clear cached data (e.g. on logout).
  void clear() {
    _dashboardStats = null;
    _users = [];
    _userCount = 0;
    _usersError = null;
    _usersLoading = false;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // Admin Reports (general / patient / doctor)
  // -------------------------------------------------------------------------

  bool _generalReportLoading = false;
  String? _generalReportError;
  GeneralReport? _generalReport;

  bool get generalReportLoading => _generalReportLoading;
  String? get generalReportError => _generalReportError;
  GeneralReport? get generalReport => _generalReport;

  /// Fetch the period-based general report.
  Future<void> fetchGeneralReport({
    required String period,
    String? date,
  }) async {
    _generalReportLoading = true;
    _generalReportError = null;
    notifyListeners();

    try {
      final query = <String, String>{'period': period};
      if (date != null && date.isNotEmpty) query['date'] = date;
      final qs = query.entries
          .map((e) =>
              '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
          .join('&');
      final resp = await ApiClient.getWithAuth<Map<String, dynamic>>(
        '/auth/admin/reports/general/?$qs',
        parser: (json) => json,
      );

      _generalReportLoading = false;
      if (!resp.isSuccess || resp.data == null) {
        _generalReportError = resp.message;
        notifyListeners();
        return;
      }
      _generalReport = GeneralReport.fromJson(resp.data!);
      notifyListeners();
    } catch (e) {
      _generalReportError = 'Failed to load report: ${e.toString()}';
      _generalReportLoading = false;
      notifyListeners();
    }
  }

  bool _patientReportLoading = false;
  String? _patientReportError;
  PatientReport? _patientReport;

  bool get patientReportLoading => _patientReportLoading;
  String? get patientReportError => _patientReportError;
  PatientReport? get patientReport => _patientReport;

  /// Fetch the per-patient appointment report.
  Future<void> fetchPatientReport({required int patientId}) async {
    _patientReportLoading = true;
    _patientReportError = null;
    notifyListeners();

    try {
      final ctx = Uri.encodeQueryComponent('$patientId');
      final resp = await ApiClient.getWithAuth<Map<String, dynamic>>(
        '/auth/admin/reports/patient/?patient_id=$ctx',
        parser: (json) => json,
      );

      _patientReportLoading = false;
      if (!resp.isSuccess || resp.data == null) {
        _patientReportError = resp.message;
        notifyListeners();
        return;
      }
      _patientReport = PatientReport.fromJson(resp.data!);
      notifyListeners();
    } catch (e) {
      _patientReportError = 'Failed to load patient report: ${e.toString()}';
      _patientReportLoading = false;
      notifyListeners();
    }
  }

  bool _doctorReportLoading = false;
  String? _doctorReportError;
  DoctorReport? _doctorReport;

  bool get doctorReportLoading => _doctorReportLoading;
  String? get doctorReportError => _doctorReportError;
  DoctorReport? get doctorReport => _doctorReport;

  /// Fetch the per-doctor activity report.
  Future<void> fetchDoctorReport({required int doctorId}) async {
    _doctorReportLoading = true;
    _doctorReportError = null;
    notifyListeners();

    try {
      final ctx = Uri.encodeQueryComponent('$doctorId');
      final resp = await ApiClient.getWithAuth<Map<String, dynamic>>(
        '/auth/admin/reports/doctor/?doctor_id=$ctx',
        parser: (json) => json,
      );

      _doctorReportLoading = false;
      if (!resp.isSuccess || resp.data == null) {
        _doctorReportError = resp.message;
        notifyListeners();
        return;
      }
      _doctorReport = DoctorReport.fromJson(resp.data!);
      notifyListeners();
    } catch (e) {
      _doctorReportError = 'Failed to load doctor report: ${e.toString()}';
      _doctorReportLoading = false;
      notifyListeners();
    }
  }

  List<AdminUserEntry> _reportPeople = [];
  String? _reportPeopleRole;
  bool _reportPeopleLoading = false;
  String? _reportPeopleError;

  List<AdminUserEntry> get reportPeople => _reportPeople;
  /// Role ('patient' | 'doctor') that currently populates [reportPeople],
  /// so screens can tell when the wrong list is cached.
  String? get reportPeopleRole => _reportPeopleRole;
  bool get reportPeopleLoading => _reportPeopleLoading;
  String? get reportPeopleError => _reportPeopleError;

  /// Fetch doctors or patients for the report pickers. Stored separately from
  /// `_users` so the user-management screen list is not affected.
  Future<void> fetchReportPeople({required String role}) async {
    _reportPeopleLoading = true;
    _reportPeopleError = null;
    notifyListeners();

    try {
      final params = <String, String>{
        'role': role,
        'page': '1',
        'page_size': '200',
      };
      final query = params.entries
          .map((e) =>
              '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
          .join('&');
      final resp = await ApiClient.getWithAuth<Map<String, dynamic>>(
        '/auth/users/?$query',
        parser: (json) => json,
      );

      _reportPeopleLoading = false;
      if (!resp.isSuccess || resp.data == null) {
        _reportPeopleError = resp.message;
        notifyListeners();
        return;
      }
      final result = AdminUserListResult.fromJson(resp.data!);
      _reportPeople = result.users;
      _reportPeopleRole = role;
      notifyListeners();
    } catch (e) {
      _reportPeopleError = 'Failed to load list: ${e.toString()}';
      _reportPeopleLoading = false;
      notifyListeners();
    }
  }
}
