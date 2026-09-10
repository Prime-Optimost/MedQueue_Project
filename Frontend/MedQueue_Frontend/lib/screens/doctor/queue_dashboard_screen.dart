import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/queue_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/custom_components.dart';
import '../../models/queue_model.dart';

class DoctorQueueDashboardScreen extends StatefulWidget {
  const DoctorQueueDashboardScreen({super.key});

  @override
  State<DoctorQueueDashboardScreen> createState() =>
      _DoctorQueueDashboardScreenState();
}

class _DoctorQueueDashboardScreenState extends State<DoctorQueueDashboardScreen> {
  final TextEditingController _pauseReasonController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final queueService = context.read<QueueService>();
      queueService.startDoctorQueuePolling(date: _selectedDate);
    });
  }

  @override
  void dispose() {
    _pauseReasonController.dispose();
    final queueService = context.read<QueueService>();
    queueService.stopPolling();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      if (!context.mounted) return;
      // Restart polling with the new date
      final queueService = context.read<QueueService>();
      queueService.stopPolling();
      queueService.startDoctorQueuePolling(date: _selectedDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Queue Dashboard'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Consumer<QueueService>(
        builder: (context, queueService, _) {
          if (queueService.isDoctorQueueLoading &&
              queueService.currentQueueSession == null) {
            return const CustomLoadingIndicator(message: 'Loading queue...');
          }

          final session = queueService.currentQueueSession;
          if (session == null) {
            return EmptyState(
              icon: Icons.event_busy,
              title: 'No Queue for Selected Date',
              message:
                  'There are no queue sessions for the selected date. Create an appointment to start the queue.',
              action: ElevatedButton(
                onPressed: () {
                  queueService.fetchDoctorQueue(date: _selectedDate);
                },
                child: const Text('Refresh'),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Date Selector
                _buildDateSelector(context, queueService),
                const SizedBox(height: 24),
                // Session Status Header
                _buildSessionStatusHeader(session, queueService),
                const SizedBox(height: 24),
                // Stats Cards
                _buildStatsCards(session),
                const SizedBox(height: 24),
                // Action Buttons
                _buildActionButtons(context, queueService, session),
                const SizedBox(height: 24),
                // Queue Entries List
                _buildQueueEntriesList(context, queueService, session),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDateSelector(BuildContext context, QueueService queueService) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Select Date:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        Row(
          children: [
            Text(
              _formatDate(_selectedDate),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => _selectDate(context),
              icon: const Icon(Icons.calendar_today),
              color: AppColors.primaryBlue,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSessionStatusHeader(QueueSession session, QueueService queueService) {
    final statusColor = session.isPaused ? Colors.orange : Colors.green;
    final statusLabel = session.isPaused ? 'PAUSED' : 'ACTIVE';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dr. ${session.doctorName}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(session.date),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textGray,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            if (session.isPaused && session.pauseReason.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Pause Reason: ${session.pauseReason}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards(QueueSession session) {
    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text(
                    'Current',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textGray,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '#${session.currentPosition}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text(
                    'Waiting',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textGray,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${session.waitingCount}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text(
                    'Served',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textGray,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${session.servedCount}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    QueueService queueService,
    QueueSession session,
  ) {
    return Column(
      children: [
        // Primary Actions
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: queueService.isDoctorQueueLoading
                    ? null
                    : () async {
                        final success = await queueService.callNextPatient();
                        if (context.mounted && success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Patient called successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                icon: const Icon(Icons.call),
                label: const Text('Call Next'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: queueService.isDoctorQueueLoading
                    ? null
                    : () async {
                        final currentEntry = session.entries
                            ?.firstWhere(
                              (e) => e.status == QueueEntryStatus.called,
                              orElse: () => session.entries!.first,
                            );

                        if (currentEntry != null) {
                          final success =
                              await queueService.markEntryComplete(currentEntry.id);
                          if (context.mounted && success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Patient marked as completed'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        }
                      },
                icon: const Icon(Icons.done),
                label: const Text('Complete'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Secondary Actions
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: queueService.isDoctorQueueLoading
                    ? null
                    : () {
                        if (session.isPaused) {
                          _resumeQueue(context, queueService);
                        } else {
                          _showPauseDialog(context, queueService);
                        }
                      },
                icon: Icon(
                  session.isPaused ? Icons.play_arrow : Icons.pause,
                ),
                label: Text(session.isPaused ? 'Resume' : 'Pause'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: queueService.isDoctorQueueLoading
                    ? null
                    : () => _showCloseConfirmation(context, queueService),
                icon: const Icon(Icons.exit_to_app),
                label: const Text('Close'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQueueEntriesList(
    BuildContext context,
    QueueService queueService,
    QueueSession session,
  ) {
    final entries = session.entries ?? [];

    if (entries.isEmpty) {
      return Center(
        child: Text(
          'No patients in queue',
          style: TextStyle(color: AppColors.textGray),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Queue Entries (${entries.length})',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...entries.map((entry) => _buildQueueEntryItem(context, entry)),
      ],
    );
  }

  Widget _buildQueueEntryItem(BuildContext context, QueueEntry entry) {
    final statusColor = _getStatusColor(entry.status);
    final statusIcon = _getStatusIcon(entry.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: statusColor.withValues(alpha: 0.1),
            child: Icon(
              statusIcon,
              color: statusColor,
            ),
          ),
          title: Text(
            '#${entry.queueNumber} - ${entry.patientName}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            _getStatusLabel(entry.status),
            style: TextStyle(color: statusColor, fontSize: 12),
          ),
          trailing: entry.positionsAhead > 0
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${entry.positionsAhead} ahead',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                  ),
                )
              : null,
          onTap: () {
            // Navigate to entry detail
          },
        ),
      ),
    );
  }

  void _showPauseDialog(BuildContext context, QueueService queueService) {
    _pauseReasonController.clear();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pause Queue'),
          content: TextField(
            controller: _pauseReasonController,
            decoration: const InputDecoration(
              hintText: 'Enter reason for pause (optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final reason = _pauseReasonController.text;
                final success = await queueService.pauseQueue(reason);
                if (context.mounted) {
                  Navigator.of(context).pop();
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Queue paused'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
              child: const Text('Pause'),
            ),
          ],
        );
      },
    );
  }

  void _resumeQueue(BuildContext context, QueueService queueService) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Resume Queue?'),
          content: const Text('Are you sure you want to resume the queue?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final success = await queueService.resumeQueue();
                if (context.mounted) {
                  Navigator.of(context).pop();
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Queue resumed'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
              child: const Text('Resume'),
            ),
          ],
        );
      },
    );
  }

  void _showCloseConfirmation(BuildContext context, QueueService queueService) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Close Queue?'),
          content: const Text(
            'Are you sure you want to close the queue for today? This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final success = await queueService.closeQueue();
                if (context.mounted) {
                  Navigator.of(context).pop();
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Queue closed for today'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
              child: const Text('Close Queue'),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Color _getStatusColor(QueueEntryStatus status) {
    switch (status) {
      case QueueEntryStatus.waiting:
        return Colors.orange;
      case QueueEntryStatus.called:
        return Colors.blue;
      case QueueEntryStatus.inConsult:
        return Colors.blue;
      case QueueEntryStatus.completed:
        return Colors.green;
      case QueueEntryStatus.left:
        return Colors.grey;
      case QueueEntryStatus.skipped:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(QueueEntryStatus status) {
    switch (status) {
      case QueueEntryStatus.waiting:
        return Icons.schedule;
      case QueueEntryStatus.called:
        return Icons.call;
      case QueueEntryStatus.inConsult:
        return Icons.person;
      case QueueEntryStatus.completed:
        return Icons.check_circle;
      case QueueEntryStatus.left:
        return Icons.exit_to_app;
      case QueueEntryStatus.skipped:
        return Icons.skip_next;
    }
  }

  String _getStatusLabel(QueueEntryStatus status) {
    switch (status) {
      case QueueEntryStatus.waiting:
        return 'Waiting';
      case QueueEntryStatus.called:
        return 'Called';
      case QueueEntryStatus.inConsult:
        return 'In Consultation';
      case QueueEntryStatus.completed:
        return 'Completed';
      case QueueEntryStatus.left:
        return 'Left';
      case QueueEntryStatus.skipped:
        return 'Skipped';
    }
  }
}
