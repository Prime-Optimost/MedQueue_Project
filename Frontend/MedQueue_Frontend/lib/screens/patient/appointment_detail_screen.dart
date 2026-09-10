import 'package:flutter/material.dart';
import 'package:medqueue_frontend/models/appointment_model.dart';
import 'package:provider/provider.dart';
import '../../services/appointment_service.dart';
import '../../services/doctor_service.dart';
import '../../services/queue_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/custom_components.dart';
import '../../widgets/slot_grid.dart';
import '../../widgets/appointment_card.dart';
import '../../models/time_slot_model.dart';
import '../../models/queue_model.dart';

class AppointmentDetailScreen extends StatefulWidget {
  const AppointmentDetailScreen({super.key});

  @override
  State<AppointmentDetailScreen> createState() => _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  late int appointmentId;
  Appointment? appointment;
  bool _isLoading = true;
  String? _errorMessage;
  List<TimeSlot> _availableSlots = [];
  bool _isFetchingSlots = false;
  
  // Queue info
  QueueEntry? _queueEntry;
  WaitTimeInfo? _waitTimeInfo;
  bool _isLoadingQueueInfo = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is int) {
      appointmentId = args;
      _fetchAppointmentDetail();
    } else {
      // Handle error: no appointment ID provided
      if (mounted) {
        setState(() {
          _errorMessage = 'Appointment ID not provided';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchAppointmentDetail() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final appointmentService = context.read<AppointmentService>();
    final result = await appointmentService.fetchAppointmentDetail(appointmentId);

    if (!mounted) return;

    if (result != null) {
      setState(() {
        appointment = result;
        _isLoading = false;
      });
      
      // If appointment is confirmed, fetch queue info
      if (result.status == 'confirmed') {
        _fetchQueueInfo();
      }
    } else {
      setState(() {
        _errorMessage = appointmentService.errorMessage ?? 'Failed to load appointment details';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchQueueInfo() async {
    if (appointment == null) return;
    
    if (!mounted) return;
    setState(() {
      _isLoadingQueueInfo = true;
    });

    try {
      final queueService = context.read<QueueService>();
      final appointmentDate = DateTime.parse(appointment!.appointmentDate);
      
      // Fetch the queue position for this appointment date
      await queueService.fetchPatientQueuePosition(date: appointmentDate);
      
      if (!mounted) return;
      setState(() {
        _queueEntry = queueService.currentQueueEntry;
        _waitTimeInfo = queueService.waitTimeInfo;
        _isLoadingQueueInfo = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingQueueInfo = false;
      });
    }
  }

  Future<void> _fetchAvailableSlotsForReschedule() async {
    if (appointment == null) return;

    final doctorId = appointment!.doctorDetail.id;
    final date = appointment!.appointmentDate; // format: yyyy-MM-dd

    if (!mounted) return;
    setState(() {
      _isFetchingSlots = true;
      _availableSlots = [];
    });

    final doctorService = context.read<DoctorService>();
    final success = await doctorService.fetchDoctorSlots(doctorId, date);

    if (!mounted) return;

    if (success) {
      setState(() {
        _availableSlots = doctorService.slots.where((slot) => slot.isAvailable).toList();
        _isFetchingSlots = false;
      });
    } else {
      setState(() {
        _isFetchingSlots = false;
        // Error will be shown via snack bar in the doctor service? We'll show our own.
      });
      if (doctorService.errorMessage != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(doctorService.errorMessage ?? 'Failed to load available slots'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _cancelAppointment() async {
    // Show dialog to get cancellation reason
    final reasonTextController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Appointment'),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              const Text('Please provide a reason for cancellation (optional):'),
              const SizedBox(height: 8),
              TextField(
                controller: reasonTextController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Reason for cancellation',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, reasonTextController.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
            ),
            child: const Text('Confirm Cancellation'),
          ),
        ],
      ),
    );

    if (reason == null) return; // User cancelled

    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    final appointmentService = context.read<AppointmentService>();
    final success = await appointmentService.cancelAppointment(appointmentId, cancellationReason: reason);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (success != null) {
      // Show success message and go back
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment cancelled successfully'),
            backgroundColor: AppColors.successGreen,
          ),
        );
        // Wait a bit then pop
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(appointmentService.errorMessage ?? 'Failed to cancel appointment'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _rescheduleAppointment() async {
    if (appointment == null) return;

    // Block rescheduling for phone/call-in appointments
    if (appointment!.bookedByReception) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone/call-in appointments cannot be rescheduled online. Please contact the hospital directly.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // First, fetch available slots for the doctor on the appointment date
    await _fetchAvailableSlotsForReschedule();

    if (!mounted) return;

    // Show a full-screen modal to select a new slot
    final selectedSlot = await showDialog<TimeSlot>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(0),
        child: Container(
          width: double.infinity,
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Reschedule Appointment',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: _isFetchingSlots
                    ? const Center(child: CircularProgressIndicator())
                    : _availableSlots.isEmpty
                        ? const Center(child: Text('No available slots for rescheduling'))
                        : SingleChildScrollView(
                            child: SlotGrid(
                              slots: _availableSlots,
                              selectedSlot: null,
                              onSlotSelected: (slot) {
                                // Close dialog and return the selected slot
                                Navigator.pop(context, slot);
                              },
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selectedSlot == null) return; // User cancelled or no slot selected

    if (!mounted) return;

    // Optional: get reason for rescheduling
    final reasonTextController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reschedule Reason'),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              const Text('Please provide a reason for rescheduling (optional):'),
              const SizedBox(height: 8),
              TextField(
                controller: reasonTextController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Reason for rescheduling',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, reasonTextController.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
            ),
            child: const Text('Confirm Reschedule'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    final appointmentService = context.read<AppointmentService>();
    final success = await appointmentService.rescheduleAppointment(
      appointmentId,
      newSlotId: selectedSlot.id,
      reason: reason ?? '',
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (success != null) {
      // Show success message and go back
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment rescheduled successfully'),
            backgroundColor: AppColors.successGreen,
          ),
        );
        // Wait a bit then pop
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(appointmentService.errorMessage ?? 'Failed to reschedule appointment'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              'Appointment Details',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3),
            ),
           
          ],
        ),
       
      ),
      body: _isLoading
          ? const CustomLoadingIndicator(message: 'Loading appointment details...')
          : _errorMessage != null
              ? Center(
                  child: AppErrorWidget(
                    title: 'Error Loading Appointment',
                    message: _errorMessage ?? 'An error occurred',
                    onRetry: _fetchAppointmentDetail,
                  ),
                )
              : appointment == null
                  ? const Center(child: Text('Appointment not found'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Appointment Card (using AppointmentCard widget)
                          AppointmentCard(
                            appointment: appointment!,
                            actions: [
                              if (appointment!.canCancel)
                                ElevatedButton.icon(
                                  onPressed: _cancelAppointment,
                                  icon: const Icon(Icons.cancel, size: 16),
                                  label: const Text('Cancel'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.errorRed,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                  ),
                                ),
                              if (appointment!.canReschedule)
                                OutlinedButton.icon(
                                  onPressed: (_isLoading || appointment!.bookedByReception)
                                      ? null
                                      : _rescheduleAppointment,
                                  icon: const Icon(Icons.change_circle, size: 16),
                                  label: Text(
                                    appointment!.bookedByReception
                                        ? 'Call to Reschedule'
                                        : 'Reschedule',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primaryBlue,
                                    side: const BorderSide(color: AppColors.primaryBlue),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          
                          // Queue Information Section (if appointment is confirmed)
                          if (appointment!.status == 'confirmed')
                            _buildQueueInfoSection(),
                          
                          const SizedBox(height: 24),
                          
                          // Message if appointment cannot be cancelled or rescheduled
                          if (!(appointment!.canCancel || appointment!.canReschedule))
                            const Center(
                              child: Text(
                                'This appointment cannot be cancelled or rescheduled',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textGray),
                              ),
                            ),
                        ],
                      ),
                    ),
    );
  }

 

Widget _buildQueueInfoSection() {
  if (_isLoadingQueueInfo) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const SizedBox(
        height: 120,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
              ),
              SizedBox(height: 12),
              Text(
                'Syncing live queue status...',
                style: TextStyle(color: AppColors.textGray, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  if (_queueEntry == null) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), style: BorderStyle.values[1]), // dashed border style
      ),
      child: const Row(
        children: [
          Icon(Icons.layers_clear_outlined, color: AppColors.textGray, size: 20),
          SizedBox(width: 12),
          Text(
            'Queue information not available',
            style: TextStyle(
              color: AppColors.textGray,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.only(left: 4, bottom: 10),
        child: Text(
          'Live Queue Tracker',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
            letterSpacing: -0.1,
          ),
        ),
      ),
      Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.03),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Icon(Icons.confirmation_num_outlined, color: AppColors.primaryBlue, size: 28),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'YOUR TICKET NUMBER',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textGray,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '#${_queueEntry!.queueNumber}',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textDark,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.15)),
                    ),
                    child: Text(
                      _getQueueStatusLabel(_queueEntry!.status).toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryBlue,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
              if (_waitTimeInfo != null) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(color: Color(0xFFF1F5F9), height: 1),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.people_alt_outlined, size: 14, color: AppColors.textGray),
                                SizedBox(width: 6),
                                Text(
                                  'People Ahead',
                                  style: TextStyle(color: AppColors.textGray, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${_waitTimeInfo!.positionsAhead} Patients',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.hourglass_top_rounded, size: 14, color: AppColors.textGray),
                                SizedBox(width: 6),
                                Text(
                                  'Est. Wait Time',
                                  style: TextStyle(color: AppColors.textGray, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '~ ${_waitTimeInfo!.estimatedWaitMinutes} mins',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    ],
  );
}

  String _getQueueStatusLabel(QueueEntryStatus status) {
    switch (status) {
      case QueueEntryStatus.waiting:
        return 'Waiting';
      case QueueEntryStatus.called:
        return 'Called';
      case QueueEntryStatus.inConsult:
        return 'In Consultation';
      case QueueEntryStatus.completed:
        return 'Completed';
      case QueueEntryStatus.skipped:
        return 'Skipped';
      case QueueEntryStatus.left:
        return 'Left';
    }
  }
}