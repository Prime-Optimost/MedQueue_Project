import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/admin_reports_model.dart';
import '../../services/admin_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/custom_components.dart';

/// Admin "View Live Queue" screen showing each doctor's queue for the selected
/// date, powered by the real backend endpoint GET /auth/admin/overview/.
class LiveQueueScreen extends StatefulWidget {
  const LiveQueueScreen({super.key});

  @override
  State<LiveQueueScreen> createState() => _LiveQueueScreenState();
}

class _LiveQueueScreenState extends State<LiveQueueScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  String _formatDate(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _load() async {
    await context.read<AdminService>().fetchLiveQueue(date: _formatDate(_selectedDate));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Live Queue'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Queues for ${_formatDate(_selectedDate)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: const Text('Change Date'),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Consumer<AdminService>(
      builder: (context, service, _) {
        if (service.queueLoading && service.liveQueue == null) {
          return const CustomLoadingIndicator(message: 'Loading live queues...');
        }
        if (service.queueError != null && service.liveQueue == null) {
          return AppErrorWidget(
            message: service.queueError!,
            onRetry: _load,
          );
        }
        final overview = service.liveQueue;
        if (overview == null || overview.queues.isEmpty) {
          return const EmptyState(
            icon: Icons.storage,
            title: 'No queues found',
            message: 'There are no active doctor queues for the selected date.',
          );
        }
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: overview.queues.length,
            itemBuilder: (context, index) {
              final entry = overview.queues[index];
              return _QueueCard(entry: entry);
            },
          ),
        );
      },
    );
  }
}

class _QueueCard extends StatelessWidget {
  final LiveQueueEntry entry;

  const _QueueCard({required this.entry});

  String get _statusLabel {
    final s = entry.status.toLowerCase();
    if (entry.isPaused) return 'Paused';
    if (s == 'closed') return 'Closed';
    if (s == 'active' || s == 'in_progress' || s == 'open') return 'Active';
    return entry.status;
  }

  Color get _statusColor {
    if (entry.isPaused) return AppColors.warningOrange;
    final s = entry.status.toLowerCase();
    if (s == 'closed') return AppColors.textGray;
    if (s == 'active' || s == 'in_progress' || s == 'open') return AppColors.successGreen;
    return AppColors.textGray;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.12),
                  child: const Icon(Icons.local_hospital, color: AppColors.primaryBlue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.doctorName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      if (entry.specialization.isNotEmpty)
                        Text(
                          entry.specialization,
                          style: const TextStyle(fontSize: 12, color: AppColors.textGray),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _StatTile(label: 'Waiting', value: '${entry.waitingCount}'),
                _StatTile(label: 'Served', value: '${entry.servedCount}'),
                _StatTile(label: 'Current', value: '${entry.currentPosition}'),
                _StatTile(label: 'Avg Consultation', value: '${entry.avgConsultMins} min'),
              ],
            ),
            if (entry.totalPauseMins > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Total paused: ${entry.totalPauseMins} min',
                style: const TextStyle(fontSize: 12, color: AppColors.warningOrange),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;

  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textGray),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
