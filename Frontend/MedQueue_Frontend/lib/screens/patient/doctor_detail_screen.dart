import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/doctor_model.dart';
import '../../models/time_slot_model.dart';
import '../../services/doctor_service.dart';
import '../../services/whatsapp_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/custom_components.dart';
import '../../widgets/slot_grid.dart';

class DoctorDetailScreen extends StatefulWidget {
  const DoctorDetailScreen({super.key});

  @override
  State<DoctorDetailScreen> createState() => _DoctorDetailScreenState();
}

class _DoctorDetailScreenState extends State<DoctorDetailScreen> {
  late int doctorId;
  Doctor? selectedDoctor;
  DateTime? selectedDate;
  TimeSlot? selectedSlot;
  bool _slotsLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is int) {
      doctorId = args;
      final doctorService = context.read<DoctorService>();
      selectedDoctor = doctorService.getDoctorById(doctorId);
      _loadAvailability(doctorService);
    }
  }

  Future<void> _loadAvailability(DoctorService doctorService) async {
    final now = DateTime.now();
    final from = DateFormat('yyyy-MM-dd').format(now);
    final to = DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 365)));
    await doctorService.fetchDoctorAvailability(doctorId, from: from, to: to);
  }

  Future<void> _selectDate() async {
    final doctorService = context.read<DoctorService>();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primaryBlue,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
      selectableDayPredicate: (day) {
        // Grey out dates the doctor has no availability for (FR-2.2).
        final available = doctorService.availableDates;
        if (available.isEmpty) return true; // fall back to open calendar
        final key = DateFormat('yyyy-MM-dd').format(day);
        return available.contains(key);
      },
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        selectedSlot = null;
        _slotsLoaded = false;
      });
      _fetchSlots();
    }
  }

  void _fetchSlots() async {
    if (selectedDate == null) return;
    final doctorService = context.read<DoctorService>();
    final dateString = DateFormat('yyyy-MM-dd').format(selectedDate!);
    final success =
        await doctorService.fetchDoctorSlots(doctorId, dateString);
    if (mounted) {
      setState(() => _slotsLoaded = true);
      if (!success && doctorService.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.error_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(doctorService.errorMessage ?? 'Error loading slots'),
            ]),
            backgroundColor: AppColors.emergencyRed,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  void _proceedToBooking() {
    if (selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.info_rounded, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Please select a time slot first'),
          ]),
          backgroundColor: AppColors.warningOrange,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }
    Navigator.pushNamed(
      context,
      '/patient/appointment-booking-confirm',
      arguments: {
        'slotId': selectedSlot!.id,
        'doctorName': selectedDoctor?.fullName ?? '',
        'doctorSpecialization': selectedDoctor?.specialization ?? '',
        'date': selectedDate,
        'time': selectedSlot!.startTime,
      },
    );
  }

  String _friendlyDate(DateTime date) {
    final today = DateTime.now();
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    final d = DateTime(date.year, date.month, date.day);
    if (d == DateTime(today.year, today.month, today.day)) return 'Today';
    if (d == tomorrow) return 'Tomorrow';
    return DateFormat('EEEE, MMM d').format(date);
  }

  @override
  Widget build(BuildContext context) {
    if (selectedDoctor == null) {
      return Scaffold(
        appBar: _buildAppBar('Doctor Details'),
        body: const Center(
          child: Text('Doctor not found',
              style: TextStyle(color: AppColors.textGray)),
        ),
      );
    }

    final doctor = selectedDoctor!;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: _buildAppBar(doctor.specialization),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Hero Profile Banner ──────────────────────
                _buildHeroBanner(doctor),

                const SizedBox(height: 16),

                // ── Stats row ────────────────────────────────
                _buildStatsRow(doctor),

                const SizedBox(height: 16),

                // ── Bio ──────────────────────────────────────
                if (doctor.bio != null && doctor.bio!.isNotEmpty)
                  _buildBioSection(doctor.bio!),

                const SizedBox(height: 16),

                // ── WhatsApp contact ─────────────────────────
                if (doctor.hasWhatsApp) _buildWhatsAppSection(doctor),

                if (doctor.hasWhatsApp) const SizedBox(height: 16),

                // ── Date picker ──────────────────────────────
                _buildDateSection(),

                const SizedBox(height: 16),

                // ── Time slots ───────────────────────────────
                if (selectedDate != null) _buildSlotsSection(),

                const SizedBox(height: 16),
              ],
            ),
          ),

          // ── Sticky bottom CTA ────────────────────────────
          if (selectedDate != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomCTA(),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // APP BAR
  // ─────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(String subtitle) {
    return AppBar(
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
            'Doctor Profile',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // HERO BANNER
  // ─────────────────────────────────────────────────────────────
  Widget _buildHeroBanner(Doctor doctor) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryBlue, AppColors.primaryGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            right: -20,
            top: 10,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            left: -15,
            bottom: -15,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.5),
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                    image: doctor.profilePictureUrl.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(doctor.profilePictureUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: doctor.profilePictureUrl.isEmpty
                      ? Center(
                          child: Text(
                            doctor.initials,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : null,
                ),

                const SizedBox(width: 16),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        'Dr. ${doctor.fullName}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        doctor.specialization,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (doctor.hospitalName.isNotEmpty)
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded,
                                size: 13, color: Colors.white60),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                doctor.hospitalName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white60,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 10),
                      // Accepting badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: doctor.isAcceptingPatients
                              ? Colors.white.withValues(alpha: 0.2)
                              : Colors.red.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: doctor.isAcceptingPatients
                                    ? const Color(0xFF90EE90)
                                    : Colors.red.shade200,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              doctor.isAcceptingPatients
                                  ? 'Accepting Patients'
                                  : 'Not Accepting',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
  // STATS ROW
  // ─────────────────────────────────────────────────────────────
  Widget _buildStatsRow(Doctor doctor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
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
              icon: Icons.workspace_premium_rounded,
              value: '${doctor.yearsOfExperience} yrs',
              label: 'Experience',
              color: AppColors.warningOrange,
            ),
            _VerticalDivider(),
            _StatItem(
              icon: Icons.payments_rounded,
              value: 'GHS ${doctor.consultationFee.toStringAsFixed(0)}',
              label: 'Consult Fee',
              color: AppColors.primaryGreen,
            ),
            _VerticalDivider(),
            _StatItem(
              icon: Icons.timer_rounded,
              value: '${doctor.avgConsultationMinutes} min',
              label: 'Avg. Duration',
              color: AppColors.primaryBlue,
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // BIO
  // ─────────────────────────────────────────────────────────────
  Widget _buildBioSection(String bio) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: AppColors.borderColor.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowColor.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.person_outline_rounded,
                    size: 15, color: AppColors.textGray),
                SizedBox(width: 6),
                Text(
                  'ABOUT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textGray,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              bio,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textDark,
                height: 1.6,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // WHATSAPP
  // ─────────────────────────────────────────────────────────────
  Widget _buildWhatsAppSection(Doctor doctor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => WhatsAppService.openWhatsApp(
          doctor.whatsappNumber,
          message:
              'Hello Dr. ${doctor.fullName}, I would like to enquire about a consultation.',
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF25D366).withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF25D366).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.chat_rounded,
                  color: Color(0xFF25D366),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Chat on WhatsApp',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF128C7E),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Send Dr. ${doctor.fullName.split(' ').first} a direct message',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textGray,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF25D366).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Text(
                  'Open',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // DATE PICKER
  // ─────────────────────────────────────────────────────────────
  Widget _buildDateSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(Icons.calendar_month_rounded,
                    size: 15, color: AppColors.textGray),
                SizedBox(width: 6),
                Text(
                  'PICK A DATE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textGray,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _selectDate,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selectedDate != null
                      ? AppColors.primaryBlue.withValues(alpha: 0.4)
                      : AppColors.borderColor.withValues(alpha: 0.5),
                  width: selectedDate != null ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadowColor.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: selectedDate != null
                          ? const LinearGradient(
                              colors: [
                                AppColors.primaryBlue,
                                AppColors.primaryGreen,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: selectedDate == null
                          ? AppColors.backgroundGray
                          : null,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.event_rounded,
                      size: 18,
                      color: selectedDate != null
                          ? Colors.white
                          : AppColors.textGray,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedDate == null
                              ? 'Choose an appointment date'
                              : _friendlyDate(selectedDate!),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: selectedDate == null
                                ? AppColors.textGray
                                : AppColors.textDark,
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (selectedDate != null)
                          Text(
                            DateFormat('MMMM d, yyyy').format(selectedDate!),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textGray,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: selectedDate != null
                        ? AppColors.primaryBlue
                        : AppColors.textLight,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SLOTS
  // ─────────────────────────────────────────────────────────────
  Widget _buildSlotsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(Icons.schedule_rounded,
                    size: 15, color: AppColors.textGray),
                SizedBox(width: 6),
                Text(
                  'AVAILABLE SLOTS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textGray,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          Consumer<DoctorService>(
            builder: (context, doctorService, _) {
              if (doctorService.isLoading) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.borderColor.withValues(alpha: 0.4)),
                  ),
                  child: const CustomLoadingIndicator(
                      message: 'Loading available slots...'),
                );
              }

              if (doctorService.errorMessage != null) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.borderColor.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.errorRed.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.error_outline_rounded,
                            color: AppColors.errorRed, size: 28),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        doctorService.errorMessage ?? 'Failed to load slots',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppColors.textGray, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _fetchSlots,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 11),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.primaryBlue,
                                AppColors.primaryGreen
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Try Again',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (doctorService.slots.isEmpty && _slotsLoaded) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.borderColor.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.warningOrange.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.event_busy_rounded,
                            color: AppColors.warningOrange, size: 28),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No slots available on this date',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Try selecting a different date',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textGray),
                      ),
                    ],
                  ),
                );
              }

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppColors.borderColor.withValues(alpha: 0.4)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadowColor.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SlotGrid(
                    slots: doctorService.slots,
                    selectedSlot: selectedSlot,
                    onSlotSelected: (slot) =>
                        setState(() => selectedSlot = slot),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // STICKY BOTTOM CTA
  // ─────────────────────────────────────────────────────────────
  Widget _buildBottomCTA() {
    final isReady = selectedSlot != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        border: Border(
          top: BorderSide(color: AppColors.borderColor.withValues(alpha: 0.4)),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Selected slot preview
          if (selectedSlot != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.successGreen, size: 15),
                  const SizedBox(width: 6),
                  Text(
                    '${_friendlyDate(selectedDate!)}  ·  ${_formatTime(selectedSlot!.startTime)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
          GestureDetector(
            onTap: isReady ? _proceedToBooking : null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: isReady
                    ? const LinearGradient(
                        colors: [
                          AppColors.primaryBlue,
                          AppColors.primaryGreen,
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      )
                    : null,
                color: isReady ? null : AppColors.backgroundGray,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isReady
                    ? [
                        BoxShadow(
                          color: AppColors.primaryBlue.withValues(alpha: 0.35),
                          blurRadius: 16,
                          spreadRadius: -2,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isReady
                        ? Icons.calendar_month_rounded
                        : Icons.touch_app_rounded,
                    color: isReady ? Colors.white : AppColors.textLight,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isReady
                        ? 'Confirm Appointment'
                        : 'Select a Time Slot to Continue',
                    style: TextStyle(
                      color: isReady ? Colors.white : AppColors.textLight,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String time) {
    try {
      final parsed = DateFormat('HH:mm').parse(time);
      return DateFormat('h:mm a').format(parsed);
    } catch (_) {
      return time;
    }
  }
}

// ── Supporting widgets ─────────────────────────────────────────

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 7),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textGray,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 52,
      color: AppColors.borderColor.withValues(alpha: 0.5),
    );
  }
}