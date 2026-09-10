import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import '../../models/queue_model.dart';
import '../../services/queue_api_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/custom_components.dart';
import '../../widgets/notification_bell.dart';

class DoctorQueueManagementScreen extends StatefulWidget {
  const DoctorQueueManagementScreen({super.key});

  @override
  State<DoctorQueueManagementScreen> createState() =>
      _DoctorQueueManagementScreenState();
}

class _DoctorQueueManagementScreenState
    extends State<DoctorQueueManagementScreen>
    with TickerProviderStateMixin {
  late QueueApiService _queueApiService;
  DateTime _selectedDate = DateTime.now();
  QueueSession? _currentSession;
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _refreshTimer;
  Timer? _pulseTimer;
  final TextEditingController _pauseReasonController = TextEditingController();
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _queueApiService = QueueApiService();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _loadQueue();
    if (_isToday) _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _pulseTimer?.cancel();
    _pulseController.dispose();
    _pauseReasonController.dispose();
    super.dispose();
  }

  bool get _isToday {
    final today = DateTime.now();
    return _selectedDate.year == today.year &&
        _selectedDate.month == today.month &&
        _selectedDate.day == today.day;
  }

  void _startAutoRefresh() {
    _refreshTimer =
        Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && _isToday) _loadQueue();
    });
  }

  Future<void> _loadQueue() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final response =
          await _queueApiService.getDoctorQueue(date: _selectedDate);
      if (mounted) {
        if (response.isSuccess) {
          setState(() { _currentSession = response.data; _isLoading = false; });
        } else {
          setState(() {
            _errorMessage = response.message;
            _isLoading = false;
            _currentSession = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load queue: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primaryBlue,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _refreshTimer?.cancel();
      if (_isToday) _startAutoRefresh();
      _loadQueue();
    }
  }

  Future<void> _callNextPatient() async {
    // Check if queue is paused - safeguard against stale state
    if (_currentSession?.isPaused == true) {
      _showSnackbar('Queue is paused. Resume first to call next patient.', AppColors.warningOrange);
      return;
    }
    
    try {
      final response = await _queueApiService.callNextPatient();
      if (response.isSuccess) {
        _showSnackbar('Next patient called', AppColors.successGreen);
        await Future.delayed(const Duration(milliseconds: 500));
        await _loadQueue();
      } else {
        // Handle backend error (e.g., "Queue is paused")
        _showSnackbar(response.message, AppColors.emergencyRed);
        // Refresh to sync state
        await _loadQueue();
      }
    } catch (e) {
      _showSnackbar('Error: $e', AppColors.emergencyRed);
    }
  }

  Future<void> _pauseQueue() async {
    final reason = _pauseReasonController.text.trim();
    if (reason.isEmpty) {
      _showSnackbar('Please provide a pause reason', AppColors.emergencyRed);
      return;
    }
    try {
      final response = await _queueApiService.pauseQueue(reason);
      if (response.isSuccess) {
        _pauseReasonController.clear();
        // Immediately update the session state to show resume button
        if (_currentSession != null) {
          setState(() {
            _currentSession = _currentSession!.copyWith(isPaused: true, pauseReason: reason);
          });
        }
        _showSnackbar('Queue paused', AppColors.warningOrange);
        await Future.delayed(const Duration(milliseconds: 500));
        await _loadQueue();
      } else {
        _showSnackbar(response.message, AppColors.emergencyRed);
      }
    } catch (e) {
      _showSnackbar('Error: $e', AppColors.emergencyRed);
    }
  }

  Future<void> _resumeQueue() async {
    try {
      final response = await _queueApiService.resumeQueue();
      if (response.isSuccess) {
        _showSnackbar('Queue resumed', AppColors.successGreen);
        await Future.delayed(const Duration(milliseconds: 500));
        await _loadQueue();
      } else {
        _showSnackbar(response.message, AppColors.emergencyRed);
      }
    } catch (e) {
      _showSnackbar('Error: $e', AppColors.emergencyRed);
    }
  }

  Future<void> _markCompleted(int entryId) async {
    // Check if queue is paused - safeguard against stale state
    if (_currentSession?.isPaused == true) {
      _showSnackbar('Queue is paused. Resume first to mark patients complete.', AppColors.warningOrange);
      return;
    }
    
    try {
      final response = await _queueApiService.markEntryComplete(entryId);
      if (response.isSuccess) {
        _showSnackbar('Consultation complete ✓', AppColors.successGreen);
        await Future.delayed(const Duration(milliseconds: 500));
        await _loadQueue();
      } else {
        _showSnackbar(response.message, AppColors.emergencyRed);
        // Refresh to sync state
        await _loadQueue();
      }
    } catch (e) {
      _showSnackbar('Error: $e', AppColors.emergencyRed);
    }
  }

  Future<void> _closeQueue() async {
    final confirmed = await _showModernDialog(
      title: 'Close Queue?',
      message: 'This will end today\'s queue session. Are you sure?',
      confirmLabel: 'Close Queue',
      confirmColor: AppColors.emergencyRed,
    );
    if (confirmed != true) return;
    try {
      final response = await _queueApiService.closeQueue();
      if (response.isSuccess) {
        _showSnackbar('Queue closed for today', AppColors.textGray);
        await Future.delayed(const Duration(milliseconds: 500));
        await _loadQueue();
      } else {
        _showSnackbar(response.message, AppColors.emergencyRed);
      }
    } catch (e) {
      _showSnackbar('Error: $e', AppColors.emergencyRed);
    }
  }

  Future<bool?> _showModernDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: confirmColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.warning_rounded,
                    color: confirmColor, size: 28),
              ),
              const SizedBox(height: 16),
              Text(title,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark)),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.textGray)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context, false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundGray,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: Text('Cancel',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textGray)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context, true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: confirmColor,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: confirmColor.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(confirmLabel,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == AppColors.successGreen
                  ? Icons.check_circle_rounded
                  : color == AppColors.emergencyRed
                      ? Icons.error_rounded
                      : Icons.info_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(message,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: Colors.white)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── STATUS HELPERS ────────────────────────────────────────────
  Color get _statusColor {
    if (_currentSession == null) return AppColors.textGray;
    if (_currentSession!.isPaused) return AppColors.warningOrange;
    if (_currentSession!.status == QueueSessionStatus.closed) return AppColors.textGray;
    return AppColors.successGreen;
  }

  String get _statusLabel {
    if (_currentSession == null) return 'No Queue';
    if (_currentSession!.isPaused) return 'Paused';
    if (_currentSession!.status == QueueSessionStatus.closed) return 'Closed';
    return 'Live';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      // ── AppBar ────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryBlue, AppColors.primaryGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Column(
          children: [
            const Text(
              'Queue Management',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3),
            ),
            Text(
              DateFormat('EEEE, MMM d').format(_selectedDate),
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          const NotificationBell(),
          // Live indicator
          if (_isToday)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) => Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white
                          .withValues(alpha: 0.1 + _pulseController.value * 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Color.lerp(
                                const Color(0xFF90EE90),
                                Colors.white,
                                _pulseController.value),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text('LIVE',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 1)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),

      body: _isLoading && _currentSession == null
          ? const CustomLoadingIndicator(message: 'Loading queue...')
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Date selector ────────────────────────────────
          _buildDateSelector(),
          const SizedBox(height: 16),

          // ── Pause Status Banner ───────────────────────────
          if (_currentSession?.isPaused == true) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warningOrange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.warningOrange.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.pause_circle_rounded,
                      color: AppColors.warningOrange, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Queue is Paused',
                          style: TextStyle(
                              color: AppColors.warningOrange,
                              fontSize: 13,
                              fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(_currentSession?.pauseReason ?? 'No reason provided',
                            style: const TextStyle(
                                color: AppColors.textGray,
                                fontSize: 12,
                                fontWeight: FontWeight.w400)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Error banner ─────────────────────────────────
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.emergencyRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.emergencyRed.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_rounded,
                      color: AppColors.emergencyRed, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_errorMessage!,
                        style: const TextStyle(
                            color: AppColors.emergencyRed,
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── No queue ─────────────────────────────────────
          if (_currentSession == null) ...[
            _buildEmptyQueueState(),
          ] else ...[
            // ── Stats banner ──────────────────────────────
            _buildStatsBanner(),
            const SizedBox(height: 16),

            // ── Current Patient ───────────────────────────
            _buildCurrentPatientCard(),
            const SizedBox(height: 16),

            // ── Controls ─────────────────────────────────
            if (_isToday) ...[
              _buildQueueControls(),
              const SizedBox(height: 16),
            ] else
              _buildReadOnlyBanner(),

            // ── Pause reason banner ───────────────────────
            if (_currentSession!.isPaused &&
                _currentSession!.pauseReason.isNotEmpty) ...[
              _buildPauseReasonBanner(),
              const SizedBox(height: 16),
            ],

            // ── Waiting list ──────────────────────────────
            _buildWaitingQueueList(),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // DATE SELECTOR
  // ─────────────────────────────────────────────────────────────
  Widget _buildDateSelector() {
    return GestureDetector(
      onTap: () => _selectDate(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowColor.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryBlue, AppColors.primaryGreen],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.calendar_month_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isToday ? '● Operational Mode — Live' : 'View-only mode',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _isToday
                          ? AppColors.successGreen
                          : AppColors.textGray,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Change',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryBlue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // STATS BANNER
  // ─────────────────────────────────────────────────────────────
  Widget _buildStatsBanner() {
    final session = _currentSession!;
    final total = session.waitingCount + session.servedCount;
    final progress = total > 0 ? session.servedCount / total : 0.0;

    final bool isActive = !session.isPaused &&
        session.status != QueueSessionStatus.closed;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: isActive
              ? [AppColors.primaryBlue, AppColors.primaryGreen]
              : session.isPaused
                  ? [
                      AppColors.warningOrange,
                      AppColors.warningOrange.withValues(alpha: 0.7)
                    ]
                  : [AppColors.textGray, AppColors.textLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _statusColor.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: -4,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            left: -10,
            bottom: -15,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Queue Overview',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isActive)
                            AnimatedBuilder(
                              animation: _pulseController,
                              builder: (_, _) => Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.only(right: 5),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color.lerp(
                                    const Color(0xFF90EE90),
                                    Colors.white,
                                    _pulseController.value,
                                  ),
                                ),
                              ),
                            ),
                          Text(
                            _statusLabel,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Stat pills
                Row(
                  children: [
                    _QueueStatPill(
                        icon: Icons.people_rounded,
                        label: 'Total',
                        value: '$total'),
                    const SizedBox(width: 8),
                    _QueueStatPill(
                        icon: Icons.hourglass_top_rounded,
                        label: 'Waiting',
                        value: '${session.waitingCount}'),
                    const SizedBox(width: 8),
                    _QueueStatPill(
                        icon: Icons.task_alt_rounded,
                        label: 'Done',
                        value: '${session.servedCount}'),
                  ],
                ),
                const SizedBox(height: 14),

                // Progress
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${session.servedCount} of $total patients served',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // CURRENT PATIENT CARD
  // ─────────────────────────────────────────────────────────────
  Widget _buildCurrentPatientCard() {
    final session = _currentSession!;
    final currentEntry = session.entries?.firstWhere(
      (e) => e.status == QueueEntryStatus.called,
      orElse: () => QueueEntry(
        id: 0,
        patientName: '',
        queueNumber: 0,
        status: QueueEntryStatus.waiting,
        notified2away: false,
        positionsAhead: 0,
        estimatedWaitMinutes: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    final isNoCurrent = (currentEntry?.id ?? 0) == 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isNoCurrent
              ? AppColors.borderColor.withValues(alpha: 0.4)
              : AppColors.primaryBlue.withValues(alpha: 0.3),
          width: isNoCurrent ? 1 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isNoCurrent
                    ? AppColors.shadowColor
                    : AppColors.primaryBlue)
                .withValues(alpha: 0.07),
            blurRadius: 16,
            spreadRadius: -2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Accent bar
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: isNoCurrent
                  ? AppColors.borderColor
                  : AppColors.primaryBlue,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'NOW CONSULTING',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textGray,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const Spacer(),
                    if (!isNoCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.successGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppColors.successGreen
                                  .withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedBuilder(
                              animation: _pulseController,
                              builder: (_, _) => Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.only(right: 5),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color.lerp(
                                      AppColors.successGreen,
                                      const Color(0xFF90EE90),
                                      _pulseController.value),
                                ),
                              ),
                            ),
                            const Text(
                              'In Session',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.successGreen),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                if (isNoCurrent)
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.backgroundGray,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.person_off_rounded,
                            color: AppColors.textLight, size: 28),
                      ),
                      const SizedBox(width: 14),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No patient in session',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Call next to begin consultation',
                            style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textGray),
                          ),
                        ],
                      ),
                    ],
                  )
                else ...[
                  Row(
                    children: [
                      // Avatar
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppColors.primaryBlue,
                              AppColors.primaryGreen
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppColors.primaryBlue.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            (currentEntry!.patientName.isNotEmpty
                                    ? currentEntry.patientName[0]
                                    : '?')
                                .toUpperCase(),
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentEntry.patientName,
                              style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textDark,
                                  letterSpacing: -0.3),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryBlue
                                        .withValues(alpha: 0.08),
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Queue #${currentEntry.queueNumber}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primaryBlue),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_isToday) ...[
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: () => _markCompleted(currentEntry.id),
                      child: Container(
                        width: double.infinity,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppColors.successGreen,
                              Color(0xFF2ECC71)
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.successGreen
                                  .withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.task_alt_rounded,
                                color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Mark Consultation Complete',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // QUEUE CONTROLS
  // ─────────────────────────────────────────────────────────────
  Widget _buildQueueControls() {
    final session = _currentSession!;
    final isClosed = session.status == QueueSessionStatus.closed;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune_rounded,
                  size: 16, color: AppColors.textGray),
              SizedBox(width: 6),
              Text(
                'QUEUE CONTROLS',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textGray,
                    letterSpacing: 1.0),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Call Next — primary CTA
          GestureDetector(
            onTap: isClosed ? null : _callNextPatient,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: isClosed
                    ? null
                    : const LinearGradient(
                        colors: [
                          AppColors.primaryBlue,
                          AppColors.primaryGreen
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                color: isClosed ? AppColors.backgroundGray : null,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isClosed
                    ? null
                    : [
                        BoxShadow(
                          color: AppColors.primaryBlue.withValues(alpha: 0.35),
                          blurRadius: 16,
                          spreadRadius: -2,
                          offset: const Offset(0, 6),
                        ),
                      ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_add_rounded,
                    color:
                        isClosed ? AppColors.textLight : Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Call Next Patient',
                    style: TextStyle(
                      color: isClosed
                          ? AppColors.textLight
                          : Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Pause / Resume + Close row
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: isClosed
                      ? null
                      : session.isPaused
                          ? _resumeQueue
                          : _showPauseDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: isClosed
                          ? AppColors.backgroundGray
                          : session.isPaused
                              ? AppColors.successGreen.withValues(alpha: 0.1)
                              : AppColors.warningOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isClosed
                            ? AppColors.borderColor.withValues(alpha: 0.3)
                            : session.isPaused
                                ? AppColors.successGreen
                                    .withValues(alpha: 0.3)
                                : AppColors.warningOrange
                                    .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          session.isPaused
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded,
                          size: 18,
                          color: isClosed
                              ? AppColors.textLight
                              : session.isPaused
                                  ? AppColors.successGreen
                                  : AppColors.warningOrange,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          session.isPaused ? 'Resume' : 'Pause',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isClosed
                                ? AppColors.textLight
                                : session.isPaused
                                    ? AppColors.successGreen
                                    : AppColors.warningOrange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: isClosed ? null : _closeQueue,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: isClosed
                          ? AppColors.backgroundGray
                          : AppColors.emergencyRed.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isClosed
                            ? AppColors.borderColor.withValues(alpha: 0.3)
                            : AppColors.emergencyRed.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_rounded,
                          size: 18,
                          color: isClosed
                              ? AppColors.textLight
                              : AppColors.emergencyRed,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isClosed ? 'Closed' : 'Close',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isClosed
                                ? AppColors.textLight
                                : AppColors.emergencyRed,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // PAUSE REASON BANNER
  // ─────────────────────────────────────────────────────────────
  Widget _buildPauseReasonBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningOrange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.warningOrange.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.warningOrange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.pause_circle_rounded,
                color: AppColors.warningOrange, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Queue Paused',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warningOrange),
                ),
                Text(
                  _currentSession!.pauseReason,
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // READ-ONLY BANNER
  // ─────────────────────────────────────────────────────────────
  Widget _buildReadOnlyBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.infoBlue.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppColors.infoBlue.withValues(alpha: 0.2)),
      ),
      child: const Row(
        children: [
          Icon(Icons.history_rounded,
              color: AppColors.infoBlue, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Viewing historical queue data — controls are disabled for past/future dates',
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.infoBlue,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // EMPTY STATE
  // ─────────────────────────────────────────────────────────────
  Widget _buildEmptyQueueState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.backgroundGray,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.event_busy_rounded,
                size: 40, color: AppColors.textGray),
          ),
          const SizedBox(height: 16),
          Text(
            'No Queue for ${DateFormat('MMM d').format(_selectedDate)}',
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
                letterSpacing: -0.3),
          ),
          const SizedBox(height: 6),
          Text(
            _isToday
                ? 'No queue has been created for today yet'
                : 'No queue data available for this date',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13, color: AppColors.textGray),
          ),
          if (_isToday) ...[
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _loadQueue,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      AppColors.primaryBlue,
                      AppColors.primaryGreen
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded,
                        color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text('Refresh',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // WAITING QUEUE LIST
  // ─────────────────────────────────────────────────────────────
  Widget _buildWaitingQueueList() {
    final session = _currentSession!;
    final waitingEntries = session.entries
            ?.where((e) => e.status == QueueEntryStatus.waiting)
            .toList() ??
        [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'WAITING QUEUE',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textGray,
                  letterSpacing: 1.0),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${waitingEntries.length}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryBlue),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (waitingEntries.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.borderColor.withValues(alpha: 0.4)),
            ),
            child: const Column(
              children: [
                Icon(Icons.check_circle_rounded,
                    color: AppColors.successGreen, size: 32),
                SizedBox(height: 8),
                Text(
                  'All patients seen!',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark),
                ),
                SizedBox(height: 4),
                Text(
                  'The waiting queue is empty',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textGray),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: waitingEntries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) =>
                _buildQueueEntryCard(waitingEntries[index], index),
          ),
      ],
    );
  }

  Widget _buildQueueEntryCard(QueueEntry entry, int index) {
    final isNext = index == 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isNext
              ? AppColors.primaryBlue.withValues(alpha: 0.3)
              : AppColors.borderColor.withValues(alpha: 0.4),
          width: isNext ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isNext ? AppColors.primaryBlue : AppColors.shadowColor)
                .withValues(alpha: isNext ? 0.1 : 0.04),
            blurRadius: isNext ? 14 : 8,
            spreadRadius: -2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Queue number badge
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: isNext
                    ? const LinearGradient(
                        colors: [
                          AppColors.primaryBlue,
                          AppColors.primaryGreen
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isNext ? null : AppColors.backgroundGray,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  '#${entry.queueNumber}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isNext ? Colors.white : AppColors.textGray,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Patient info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.patientName,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                              letterSpacing: -0.2),
                        ),
                      ),
                      if (isNext)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Up next',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryBlue),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded,
                          size: 12, color: AppColors.textGray),
                      const SizedBox(width: 3),
                      Text(
                        '~${entry.estimatedWaitMinutes} min wait',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textGray),
                      ),
                      if (entry.positionsAhead > 0) ...[
                        const SizedBox(width: 10),
                        const Icon(Icons.people_outline_rounded,
                            size: 12, color: AppColors.textGray),
                        const SizedBox(width: 3),
                        Text(
                          '${entry.positionsAhead} ahead',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textGray),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPauseDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warningOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.pause_rounded,
                        color: AppColors.warningOrange, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Pause Queue',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Reason for pausing',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textGray),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _pauseReasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'e.g. Short break, emergency, etc.',
                  hintStyle:
                      const TextStyle(color: AppColors.textLight),
                  filled: true,
                  fillColor: AppColors.backgroundLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                        color: AppColors.primaryBlue, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundGray,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: Text('Cancel',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textGray)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _pauseQueue();
                      },
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: AppColors.warningOrange,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.warningOrange
                                  .withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text('Pause Queue',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared widget ─────────────────────────────────────────────────
class _QueueStatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _QueueStatPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white70),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.0)),
              Text(label,
                  style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white60,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}