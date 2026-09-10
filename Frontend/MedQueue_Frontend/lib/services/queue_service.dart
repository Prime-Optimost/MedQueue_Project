import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/queue_model.dart';
import 'queue_api_service.dart';

/// Queue Service with real-time polling and Firebase fallback
class QueueService extends ChangeNotifier {
  final QueueApiService _apiService = QueueApiService();

  // Patient queue state
  QueueEntry? _currentQueueEntry;
  WaitTimeInfo? _waitTimeInfo;
  bool _isLoading = false;
  String? _errorMessage;

  // Doctor queue state
  QueueSession? _currentQueueSession;
  bool _isDoctorQueueLoading = false;
  String? _doctorQueueError;

  // Polling
  Timer? _pollTimer;
  final Duration _pollInterval = const Duration(seconds: 5);
  DateTime? _currentPollingDate; // Store the date being polled

  // Getters
  QueueEntry? get currentQueueEntry => _currentQueueEntry;
  WaitTimeInfo? get waitTimeInfo => _waitTimeInfo;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  QueueSession? get currentQueueSession => _currentQueueSession;
  bool get isDoctorQueueLoading => _isDoctorQueueLoading;
  String? get doctorQueueError => _doctorQueueError;

  bool get inQueue => _currentQueueEntry != null;
  int? get positionInQueue => _currentQueueEntry?.queueNumber;
  int? get positionsAhead => _currentQueueEntry?.positionsAhead;
  int? get estimatedWaitMinutes => _currentQueueEntry?.estimatedWaitMinutes;
  DateTime? get currentPollingDate => _currentPollingDate;

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }

  // ============================================================================
  // PATIENT OPERATIONS
  // ============================================================================

  /// Fetch patient's queue position once
  Future<void> fetchPatientQueuePosition({DateTime? date}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Use an explicit date when provided; otherwise fall back to today.
      final targetDate = date ?? _currentPollingDate ?? DateTime.now();
      final response = await _apiService.getPatientQueuePosition(date: targetDate);

      if (response.isSuccess && response.data != null) {
        _currentQueueEntry = response.data!.entry;
        _waitTimeInfo = response.data!.waitInfo;
      } else {
        _errorMessage = response.message;
        _currentQueueEntry = null;
        _waitTimeInfo = null;
      }
    } catch (e) {
      _errorMessage = 'Failed to fetch queue position: ${e.toString()}';
      _currentQueueEntry = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Start auto-polling patient queue position
  void startPatientQueuePolling({DateTime? date}) {
    // Clear any existing timer
    _stopPolling();

    _currentPollingDate = date ?? DateTime.now();

    // Fetch immediately using stored date or provided date
    fetchPatientQueuePosition(date: _currentPollingDate);

    // Then poll at interval
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (_currentQueueEntry != null) {
        // Only continue polling if still in queue
        fetchPatientQueuePosition(date: _currentPollingDate);
      } else {
        _stopPolling();
      }
    });
  }

  /// Stop polling
  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Patient leaves the queue
  Future<bool> leaveQueue() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.leaveQueue();

      if (response.isSuccess) {
        _currentQueueEntry = null;
        _waitTimeInfo = null;
        _stopPolling();
        return true;
      } else {
        _errorMessage = response.message;
        return false;
      }
    } catch (e) {
      _errorMessage = 'Failed to leave queue: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============================================================================
  // DOCTOR OPERATIONS
  // ============================================================================

  /// Fetch doctor's queue
  Future<void> fetchDoctorQueue({DateTime? date}) async {
    _isDoctorQueueLoading = true;
    _doctorQueueError = null;
    notifyListeners();

    try {
      final response = await _apiService.getDoctorQueue(date: date);

      if (response.isSuccess && response.data != null) {
        _currentQueueSession = response.data;
      } else {
        _doctorQueueError = response.message;
        _currentQueueSession = null;
      }
    } catch (e) {
      _doctorQueueError = 'Failed to fetch queue: ${e.toString()}';
      _currentQueueSession = null;
    } finally {
      _isDoctorQueueLoading = false;
      notifyListeners();
    }
  }

  /// Start auto-polling doctor's queue
  void startDoctorQueuePolling({DateTime? date}) {
    _stopPolling();
    fetchDoctorQueue(date: date);

    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (_currentQueueSession != null) {
        fetchDoctorQueue(date: date);
      } else {
        _stopPolling();
      }
    });
  }

  /// Doctor calls next patient
  Future<bool> callNextPatient() async {
    _isDoctorQueueLoading = true;
    _doctorQueueError = null;
    notifyListeners();

    try {
      final response = await _apiService.callNextPatient();

      if (response.isSuccess) {
        // Refresh queue immediately
        await fetchDoctorQueue();
        return true;
      } else {
        _doctorQueueError = response.message;
        return false;
      }
    } catch (e) {
      _doctorQueueError = 'Failed to call next patient: ${e.toString()}';
      return false;
    } finally {
      _isDoctorQueueLoading = false;
      notifyListeners();
    }
  }

  /// Doctor marks consultation complete
  Future<bool> markEntryComplete(int entryId) async {
    _isDoctorQueueLoading = true;
    _doctorQueueError = null;
    notifyListeners();

    try {
      final response = await _apiService.markEntryComplete(entryId);

      if (response.isSuccess) {
        await fetchDoctorQueue();
        return true;
      } else {
        _doctorQueueError = response.message;
        return false;
      }
    } catch (e) {
      _doctorQueueError = 'Failed to mark complete: ${e.toString()}';
      return false;
    } finally {
      _isDoctorQueueLoading = false;
      notifyListeners();
    }
  }

  /// Doctor pauses the queue
  Future<bool> pauseQueue(String reason) async {
    _isDoctorQueueLoading = true;
    _doctorQueueError = null;
    notifyListeners();

    try {
      final response = await _apiService.pauseQueue(reason);

      if (response.isSuccess) {
        await fetchDoctorQueue();
        return true;
      } else {
        _doctorQueueError = response.message;
        return false;
      }
    } catch (e) {
      _doctorQueueError = 'Failed to pause queue: ${e.toString()}';
      return false;
    } finally {
      _isDoctorQueueLoading = false;
      notifyListeners();
    }
  }

  /// Doctor resumes the queue
  Future<bool> resumeQueue() async {
    _isDoctorQueueLoading = true;
    _doctorQueueError = null;
    notifyListeners();

    try {
      final response = await _apiService.resumeQueue();

      if (response.isSuccess) {
        await fetchDoctorQueue();
        return true;
      } else {
        _doctorQueueError = response.message;
        return false;
      }
    } catch (e) {
      _doctorQueueError = 'Failed to resume queue: ${e.toString()}';
      return false;
    } finally {
      _isDoctorQueueLoading = false;
      notifyListeners();
    }
  }

  /// Doctor closes the queue
  Future<bool> closeQueue() async {
    _isDoctorQueueLoading = true;
    _doctorQueueError = null;
    notifyListeners();

    try {
      final response = await _apiService.closeQueue();

      if (response.isSuccess) {
        await fetchDoctorQueue();
        return true;
      } else {
        _doctorQueueError = response.message;
        return false;
      }
    } catch (e) {
      _doctorQueueError = 'Failed to close queue: ${e.toString()}';
      return false;
    } finally {
      _isDoctorQueueLoading = false;
      notifyListeners();
    }
  }

  /// Clear all state
  void clearState() {
    _stopPolling();
    _currentQueueEntry = null;
    _waitTimeInfo = null;
    _currentQueueSession = null;
    _currentPollingDate = null;
    _errorMessage = null;
    _doctorQueueError = null;
    notifyListeners();
  }

  /// Stop polling
  void stopPolling() {
    _stopPolling();
  }
}
