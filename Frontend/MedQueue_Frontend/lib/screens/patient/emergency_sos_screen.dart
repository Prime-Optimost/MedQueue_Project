import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/emergency_model.dart';
import '../../services/emergency_service.dart';
import '../../services/auth_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_constants.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_textfield.dart';



class EmergencySosScreen extends StatefulWidget {
  const EmergencySosScreen({super.key});

  @override
  State<EmergencySosScreen> createState() => _EmergencySosScreenState();
}

class _EmergencySosScreenState extends State<EmergencySosScreen> {
  final _descriptionController = TextEditingController();
  bool _shareLocation = false;
  Timer? _pollTimer;
  EmergencyRequest? _activeRequest;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _descriptionController.addListener(_handleDescriptionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadActiveEmergency();
      _startPolling();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _descriptionController.removeListener(_handleDescriptionChanged);
    _descriptionController.dispose();
    super.dispose();
  }

  void _handleDescriptionChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadActiveEmergency(silent: true);
    });
  }

  Future<void> _loadActiveEmergency({bool silent = false}) async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    if (mounted && !silent) {
      setState(() {});
    }

    final emergency = await context.read<EmergencyService>().getActiveEmergency();
    if (!mounted) return;

    setState(() {
      _activeRequest = emergency;
      _isRefreshing = false;
    });
  }

  Future<void> _submitEmergency() async {
    final user = context.read<AuthService>().currentUser;
    final success = await context.read<EmergencyService>().requestEmergency(
      patientId: (user?.id ?? 0).toString(),
      patientName: user?.fullName ?? '',
      patientPhone: user?.phoneNumber ?? '',
      description: _descriptionController.text,
      latitude: _shareLocation ? 5.6037 : null,
      longitude: _shareLocation ? -0.1870 : null,
    );

    if (!mounted) return;

    if (success) {
      await _loadActiveEmergency();
    }
  }

  Future<void> _cancelEmergency() async {
    final request = _activeRequest;
    if (request == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancel Emergency SOS?'),
          content: const Text('This will cancel the active SOS request if it is still pending.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep SOS'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Cancel SOS'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    if (!mounted) return;
    final success = await context.read<EmergencyService>().cancelEmergency(request.id);
    if (!mounted) return;

    if (success) {
      await _loadActiveEmergency();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
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
              'Emergency SOS',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3),
            ),
           
          ],
        ),
       
      ),
      body: Consumer<EmergencyService>(
        builder: (context, emergencyService, _) {
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _activeRequest != null
                  ? _buildActiveRequestScreen(context, emergencyService)
                  : Column(
                      children: [
                        const SizedBox(height: 24),
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: AppColors.emergencyRed.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.emergency,
                            size: 80,
                            color: AppColors.emergencyRed,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          AppConstants.emergencySOS,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Use this only for medical emergencies',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textGray,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.emergencyRed.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.emergencyRed.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'When to use Emergency SOS:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.emergencyRed,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _EmergencyListItem('Severe chest pain or difficulty breathing'),
                              _EmergencyListItem('Severe allergic reactions'),
                              _EmergencyListItem('Loss of consciousness'),
                              _EmergencyListItem('Severe bleeding or trauma'),
                              _EmergencyListItem('Acute symptoms needing immediate help'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        CustomTextField(
                          label: 'Describe Emergency',
                          hint: 'Briefly describe what is happening',
                          controller: _descriptionController,
                          maxLines: 4,
                          minLines: 3,
                          prefixIcon: Icons.note,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Description is required';
                            }
                            return null;
                          },
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.infoBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.infoBlue.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: _shareLocation,
                                onChanged: (value) {
                                  setState(() {
                                    _shareLocation = value ?? false;
                                  });
                                },
                                activeColor: AppColors.infoBlue,
                              ),
                              const Expanded(
                                child: Text(
                                  'Share my location with emergency responders',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textGray,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        EmergencyButton(
                          label: AppConstants.requestHelp,
                          isLoading: emergencyService.isLoading,
                          onPressed: _descriptionController.text.trim().isEmpty
                              ? null
                              : _submitEmergency,
                        ),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActiveRequestScreen(BuildContext context, EmergencyService emergencyService) {
    final request = _activeRequest;
    if (request == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Container(
          width: 120,
          height: 120,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.emergencyRed.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.sos,
            size: 72,
            color: AppColors.emergencyRed,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'SOS in progress',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          _statusTitle(request.status),
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textGray,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.infoBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.infoBlue.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow(label: 'Type', value: request.emergencyType),
              const SizedBox(height: 8),
              _InfoRow(label: 'Confirmed', value: _formatDateTime(request.confirmedAt)),
              const SizedBox(height: 8),
              _InfoRow(label: 'Location', value: request.mapsUrl.isEmpty ? 'Location not shared' : 'Shared with responders'),
              const SizedBox(height: 8),
              _InfoRow(label: 'Status', value: _statusTitle(request.status)),
            ],
          ),
        ),
        if (request.mapsUrl.isNotEmpty) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.infoBlue.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Map Link',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  request.mapsUrl,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.infoBlue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        if (request.status == EmergencyStatus.pending)
          EmergencyButton(
            label: 'Cancel SOS',
            isLoading: emergencyService.isLoading,
            onPressed: _cancelEmergency,
          ),
        if (request.status != EmergencyStatus.pending)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.successGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Your request has moved past the cancellation window. Please stay on this screen for live updates.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textDark,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        const SizedBox(height: 20),
        CustomButton(
          label: _isRefreshing ? 'Refreshing...' : 'Refresh Status',
          onPressed: _isRefreshing ? null : _loadActiveEmergency,
        ),
      ],
    );
  }

  String _statusTitle(EmergencyStatus status) {
    switch (status) {
      case EmergencyStatus.pending:
        return 'Pending - awaiting response';
      case EmergencyStatus.dispatched:
        return 'Dispatched - help is on the way';
      case EmergencyStatus.resolved:
        return 'Resolved';
      case EmergencyStatus.cancelled:
        return 'Cancelled';
      case EmergencyStatus.falseAlarm:
        return 'Marked as false alarm';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} $hour:$minute $suffix';
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textGray,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmergencyListItem extends StatelessWidget {
  final String text;

  const _EmergencyListItem(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 8, top: 2),
            child: Icon(Icons.check, size: 16, color: AppColors.emergencyRed),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.emergencyRed,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
