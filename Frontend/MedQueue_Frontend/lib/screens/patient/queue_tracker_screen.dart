import 'package:flutter/material.dart';
import 'package:medqueue_frontend/widgets/appointment_card.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../../services/queue_service.dart';
import '../../services/appointment_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/custom_components.dart';
import '../../models/queue_model.dart';
import '../../models/appointment_model.dart';

class QueueTrackerScreen extends StatefulWidget {
  final DateTime? initialDate;

  const QueueTrackerScreen({super.key, this.initialDate});

  @override
  State<QueueTrackerScreen> createState() => _QueueTrackerScreenState();
}

class _QueueTrackerScreenState extends State<QueueTrackerScreen>
    with TickerProviderStateMixin {
  Appointment? _currentAppointment;
  bool _isLoadingAppointment = false;

  late AnimationController _pulseController;
  late AnimationController _ringController;
  late AnimationController _slideController;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    );
    _slideController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final queueService = context.read<QueueService>();
      final targetDate = widget.initialDate ?? DateTime.now();
      queueService.startPatientQueuePolling(date: targetDate);
      _fetchAppointmentForDate(targetDate);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _ringController.dispose();
    _slideController.dispose();
    context.read<QueueService>().clearState();
    super.dispose();
  }

  Future<void> _fetchAppointmentForDate(DateTime date) async {
    if (!mounted) return;
    setState(() => _isLoadingAppointment = true);
    try {
      final appointmentService = context.read<AppointmentService>();
      await appointmentService.fetchAppointments();
      if (!mounted) return;
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      Appointment? appointment;
      try {
        appointment = appointmentService.appointments.firstWhere(
          (apt) =>
              apt.appointmentDate == dateStr && apt.status != 'cancelled',
        );
      } catch (_) {
        appointment = null;
      }
      if (!mounted) return;
      setState(() {
        _currentAppointment = appointment;
        _isLoadingAppointment = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingAppointment = false);
    }
  }

  // ── STATUS CONFIG ─────────────────────────────────────────────
  _StatusConfig _getStatusConfig(QueueEntryStatus status) {
    switch (status) {
      case QueueEntryStatus.waiting:
        return _StatusConfig(
          label: 'Waiting',
          sublabel: 'Please wait — we\'ll notify you when it\'s your turn',
          color: AppColors.warningOrange,
          icon: Icons.hourglass_top_rounded,
          gradientColors: [AppColors.primaryBlue, AppColors.primaryGreen],
        );
      case QueueEntryStatus.called:
        return _StatusConfig(
          label: 'You\'ve Been Called!',
          sublabel: 'Please proceed to the consultation room now',
          color: AppColors.successGreen,
          icon: Icons.campaign_rounded,
          gradientColors: [AppColors.successGreen, const Color(0xFF2ECC71)],
        );
      case QueueEntryStatus.inConsult:
        return _StatusConfig(
          label: 'In Consultation',
          sublabel: 'Your consultation is in progress',
          color: AppColors.primaryBlue,
          icon: Icons.medical_services_rounded,
          gradientColors: [AppColors.primaryBlue, AppColors.secondaryBlue],
        );
      case QueueEntryStatus.completed:
        return _StatusConfig(
          label: 'Completed',
          sublabel: 'Thank you for visiting us today!',
          color: AppColors.successGreen,
          icon: Icons.task_alt_rounded,
          gradientColors: [AppColors.successGreen, AppColors.primaryGreen],
        );
      case QueueEntryStatus.left:
        return _StatusConfig(
          label: 'Left Queue',
          sublabel: 'You have left the queue',
          color: AppColors.textGray,
          icon: Icons.exit_to_app_rounded,
          gradientColors: [AppColors.textGray, AppColors.textLight],
        );
      case QueueEntryStatus.skipped:
        return _StatusConfig(
          label: 'Skipped',
          sublabel: 'Your turn was skipped. Please check with reception',
          color: AppColors.emergencyRed,
          icon: Icons.skip_next_rounded,
          gradientColors: [AppColors.emergencyRed, AppColors.emergencyLight],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
         leading: IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/patient-home',
        (route) => false,
      );
    },
  ),

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
        title: const Column(
          children: [
            Text(
              'Queue Tracker',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3),
            ),
            Text(
              'Live status updates',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          // Live pulse indicator
          AnimatedBuilder(
            animation: _pulseController,
            builder: (_, _) => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white
                        .withValues(alpha: 0.1 + _pulseController.value * 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.4)),
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
      body: Consumer<QueueService>(
        builder: (context, queueService, _) {
          if (queueService.isLoading &&
              queueService.currentQueueEntry == null) {
            return const CustomLoadingIndicator(
                message: 'Connecting to queue...');
          }

          final queueEntry = queueService.currentQueueEntry;

          if (queueEntry == null) {
            return _buildEmptyState(context);
          }

          final config = _getStatusConfig(queueEntry.status);

          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(_slideAnimation),
            child: FadeTransition(
              opacity: _slideAnimation,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    // ── Hero Banner ─────────────────────────
                    _buildHeroBanner(queueEntry, config,
                        queueService.estimatedWaitMinutes ?? 0),

                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // ── Status message ───────────────
                          _buildStatusBanner(config),
                          const SizedBox(height: 16),

                          // ── Stats row ────────────────────
                          _buildStatsRow(queueEntry),
                          const SizedBox(height: 16),

                          // ── Appointment card ─────────────
                          if (_isLoadingAppointment)
                            _buildAppointmentSkeleton()
                          else if (_currentAppointment != null)
                            AppointmentCard(
                              appointment: _currentAppointment!,
                              onTap: () => Navigator.of(context).pushNamed(
                                '/patient/appointment-detail',
                                arguments: _currentAppointment!.id,
                              ),
                            ),

                          const SizedBox(height: 16),

                          // ── Progress steps ───────────────
                          _buildProgressSteps(queueEntry.status),
                          const SizedBox(height: 16),

                          // ── Action buttons ───────────────
                          _buildActionButtons(context, queueService),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // HERO BANNER — Queue number + animated rings
  // ─────────────────────────────────────────────────────────────
  Widget _buildHeroBanner(
      QueueEntry entry, _StatusConfig config, int waitMins) {
    final isCalled = entry.status == QueueEntryStatus.called;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: config.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
        boxShadow: [
          BoxShadow(
            color: config.gradientColors.first.withValues(alpha: 0.35),
            blurRadius: 24,
            spreadRadius: -4,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            right: -30,
            top: 10,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            left: -20,
            bottom: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 36),
            child: Column(
              children: [
                // Animated ring + queue number
                AnimatedBuilder(
                  animation: _ringController,
                  builder: (_, child) {
                    return SizedBox(
                      width: 180,
                      height: 180,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer rotating arc (only when waiting/called)
                          if (entry.status == QueueEntryStatus.waiting ||
                              isCalled)
                            Transform.rotate(
                              angle:
                                  _ringController.value * 2 * math.pi,
                              child: CustomPaint(
                                size: const Size(180, 180),
                                painter: _ArcPainter(
                                  color:
                                      Colors.white.withValues(alpha: 0.25),
                                  strokeWidth: 3,
                                ),
                              ),
                            ),
                          // Static outer ring
                          Container(
                            width: 156,
                            height: 156,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25),
                                width: 2,
                              ),
                            ),
                          ),
                          // Inner badge
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (_, _) => Container(
                              width: 130,
                              height: 130,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 
                                    isCalled
                                        ? 0.25 +
                                            _pulseController.value *
                                                0.1
                                        : 0.2),
                                border: Border.all(
                                    color:
                                        Colors.white.withValues(alpha: 0.4),
                                    width: 2),
                              ),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '#${entry.queueNumber}',
                                    style: const TextStyle(
                                      fontSize: 44,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      height: 1.0,
                                      letterSpacing: -2,
                                    ),
                                  ),
                                  Text(
                                    'YOUR NUMBER',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color:
                                          Colors.white.withValues(alpha: 0.7),
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),

                // Wait time + positions ahead
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _HeroStatChip(
                      icon: Icons.people_rounded,
                      label: 'Ahead',
                      value: '${entry.positionsAhead}',
                    ),
                    Container(
                      width: 1,
                      height: 36,
                      color: Colors.white.withValues(alpha: 0.3),
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    _HeroStatChip(
                      icon: Icons.schedule_rounded,
                      label: 'Est. wait',
                      value:
                          waitMins == 0 ? 'Now!' : '~${waitMins}m',
                    ),
                    Container(
                      width: 1,
                      height: 36,
                      color: Colors.white.withValues(alpha: 0.3),
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    _HeroStatChip(
                      icon: Icons.login_rounded,
                      label: 'Joined',
                      value: _formatTime(entry.createdAt),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // STATUS BANNER
  // ─────────────────────────────────────────────────────────────
  Widget _buildStatusBanner(_StatusConfig config) {
    final isCalled = config.label.contains('Called');

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, _) => Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: config.color.withValues(alpha: 
              isCalled ? 0.08 + _pulseController.value * 0.06 : 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: config.color.withValues(alpha: isCalled ? 0.5 : 0.25),
            width: isCalled ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: config.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(config.icon, color: config.color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    config.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: config.color,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    config.sublabel,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textGray),
                  ),
                ],
              ),
            ),
            if (isCalled)
              AnimatedBuilder(
                animation: _pulseController,
                builder: (_, _) => Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.lerp(config.color,
                        const Color(0xFF90EE90), _pulseController.value),
                    boxShadow: [
                      BoxShadow(
                        color: config.color
                            .withValues(alpha: _pulseController.value * 0.6),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // STATS ROW
  // ─────────────────────────────────────────────────────────────
  Widget _buildStatsRow(QueueEntry entry) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: AppColors.borderColor.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _StatItem(
            icon: Icons.tag_rounded,
            label: 'Queue No.',
            value: '#${entry.queueNumber}',
            color: AppColors.primaryBlue,
          ),
          _Divider(),
          _StatItem(
            icon: Icons.people_rounded,
            label: 'Ahead',
            value: '${entry.positionsAhead}',
            color: AppColors.warningOrange,
          ),
          _Divider(),
          _StatItem(
            icon: Icons.schedule_rounded,
            label: 'Joined',
            value: _formatTime(entry.createdAt),
            color: AppColors.primaryGreen,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // PROGRESS STEPS
  // ─────────────────────────────────────────────────────────────
  Widget _buildProgressSteps(QueueEntryStatus status) {
    final steps = [
      _Step('Registered', Icons.how_to_reg_rounded,
          QueueEntryStatus.waiting),
      _Step('Called', Icons.campaign_rounded, QueueEntryStatus.called),
      _Step('Consulting', Icons.medical_services_rounded,
          QueueEntryStatus.inConsult),
      _Step('Done', Icons.task_alt_rounded, QueueEntryStatus.completed),
    ];

    final stepOrder = [
      QueueEntryStatus.waiting,
      QueueEntryStatus.called,
      QueueEntryStatus.inConsult,
      QueueEntryStatus.completed,
    ];

    final currentIndex = stepOrder.indexOf(status);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: AppColors.borderColor.withValues(alpha: 0.4)),
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
              Icon(Icons.linear_scale_rounded,
                  size: 14, color: AppColors.textGray),
              SizedBox(width: 6),
              Text(
                'YOUR JOURNEY',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textGray,
                    letterSpacing: 1.0),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(steps.length * 2 - 1, (i) {
              if (i.isOdd) {
                // Connector line
                final stepIndex = i ~/ 2;
                final isCompleted = stepIndex < currentIndex;
                return Expanded(
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: isCompleted
                          ? const LinearGradient(
                              colors: [
                                AppColors.primaryBlue,
                                AppColors.primaryGreen
                              ],
                            )
                          : null,
                      color: isCompleted
                          ? null
                          : AppColors.borderColor.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }

              final stepIndex = i ~/ 2;
              final step = steps[stepIndex];
              final isCompleted = stepIndex < currentIndex;
              final isCurrent = stepIndex == currentIndex;

              return Column(
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (_, _) => Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: isCompleted || isCurrent
                            ? const LinearGradient(
                                colors: [
                                  AppColors.primaryBlue,
                                  AppColors.primaryGreen
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: isCompleted || isCurrent
                            ? null
                            : AppColors.backgroundGray,
                        shape: BoxShape.circle,
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                  color: AppColors.primaryBlue
                                      .withValues(alpha: 0.15 +
                                          _pulseController.value *
                                              0.2),
                                  blurRadius: 14,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                        border: isCurrent
                            ? Border.all(
                                color: AppColors.primaryBlue
                                    .withValues(alpha: 0.4),
                                width: 2)
                            : null,
                      ),
                      child: Icon(
                        step.icon,
                        size: 18,
                        color: isCompleted || isCurrent
                            ? Colors.white
                            : AppColors.textLight,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    step.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isCurrent
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color: isCurrent
                          ? AppColors.primaryBlue
                          : isCompleted
                              ? AppColors.textDark
                              : AppColors.textLight,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // ACTION BUTTONS
  // ─────────────────────────────────────────────────────────────
  Widget _buildActionButtons(
      BuildContext context, QueueService queueService) {
    return Column(
      children: [
        // Refresh
        GestureDetector(
          onTap: queueService.isLoading
              ? null
              : () => queueService.fetchPatientQueuePosition(),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              gradient: queueService.isLoading
                  ? null
                  : const LinearGradient(
                      colors: [
                        AppColors.primaryBlue,
                        AppColors.primaryGreen
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
              color: queueService.isLoading
                  ? AppColors.backgroundGray
                  : null,
              borderRadius: BorderRadius.circular(16),
              boxShadow: queueService.isLoading
                  ? null
                  : [
                      BoxShadow(
                        color: AppColors.primaryBlue.withValues(alpha: 0.3),
                        blurRadius: 14,
                        spreadRadius: -2,
                        offset: const Offset(0, 5),
                      ),
                    ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _ringController,
                  builder: (_, child) => Transform.rotate(
                    angle: queueService.isLoading
                        ? _ringController.value * 2 * math.pi
                        : 0,
                    child: child,
                  ),
                  child: Icon(
                    Icons.refresh_rounded,
                    color: queueService.isLoading
                        ? AppColors.textLight
                        : Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  queueService.isLoading
                      ? 'Refreshing...'
                      : 'Refresh Status',
                  style: TextStyle(
                    color: queueService.isLoading
                        ? AppColors.textLight
                        : Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Leave queue
        GestureDetector(
          onTap: () => _showLeaveConfirmation(context, queueService),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              color: AppColors.emergencyRed.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppColors.emergencyRed.withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.exit_to_app_rounded,
                    color: AppColors.emergencyRed, size: 18),
                SizedBox(width: 8),
                Text(
                  'Leave Queue',
                  style: TextStyle(
                      color: AppColors.emergencyRed,
                      fontWeight: FontWeight.w700,
                      fontSize: 15),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // EMPTY STATE
  // ─────────────────────────────────────────────────────────────
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.queue_rounded,
                  size: 52, color: AppColors.primaryBlue),
            ),
            const SizedBox(height: 20),
            const Text(
              'Not in a Queue Today',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                  letterSpacing: -0.4),
            ),
            const SizedBox(height: 8),
            const Text(
              'You are currently not in any active queues. Please check back later.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textGray),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // APPOINTMENT SKELETON
  // ─────────────────────────────────────────────────────────────
  Widget _buildAppointmentSkeleton() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, _) => Container(
        height: 90,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: AppColors.borderColor.withValues(alpha: 0.4)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.backgroundGray
                      .withValues(alpha: 0.5 + _pulseController.value * 0.3),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 12,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.backgroundGray.withValues(alpha: 
                            0.5 + _pulseController.value * 0.3),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 10,
                      width: 120,
                      decoration: BoxDecoration(
                        color: AppColors.backgroundGray.withValues(alpha: 
                            0.4 + _pulseController.value * 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLeaveConfirmation(
      BuildContext context, QueueService queueService) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.emergencyRed.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.exit_to_app_rounded,
                    color: AppColors.emergencyRed, size: 30),
              ),
              const SizedBox(height: 16),
              const Text(
                'Leave Queue?',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your queue position will be lost and your appointment cancelled.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textGray),
              ),
              const SizedBox(height: 24),
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
                          child: Text('Stay',
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
                      onTap: () async {
                        Navigator.pop(context);
                        final success =
                            await queueService.leaveQueue();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(
                                    success
                                        ? Icons.check_circle_rounded
                                        : Icons.error_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    success
                                        ? 'You have left the queue'
                                        : queueService.errorMessage ??
                                            'Failed to leave queue',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white),
                                  ),
                                ],
                              ),
                              backgroundColor: success
                                  ? AppColors.successGreen
                                  : AppColors.emergencyRed,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                              margin: const EdgeInsets.all(16),
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: AppColors.emergencyRed,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.emergencyRed
                                  .withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text('Leave',
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

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ── Supporting data classes ────────────────────────────────────

class _StatusConfig {
  final String label;
  final String sublabel;
  final Color color;
  final IconData icon;
  final List<Color> gradientColors;

  const _StatusConfig({
    required this.label,
    required this.sublabel,
    required this.color,
    required this.icon,
    required this.gradientColors,
  });
}

class _Step {
  final String label;
  final IconData icon;
  final QueueEntryStatus status;
  const _Step(this.label, this.icon, this.status);
}

// ── Supporting widgets ─────────────────────────────────────────

class _HeroStatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _HeroStatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.0),
        ),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                color: Colors.white60,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textGray)),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
        width: 1, height: 48, color: AppColors.borderColor.withValues(alpha: 0.4));
  }
}

// ── Arc painter for rotating animation ────────────────────────
class _ArcPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _ArcPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawArc(rect, 0, math.pi * 1.2, false, paint);
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}