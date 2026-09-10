import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../models/doctor_availability_override_model.dart';
import '../../models/doctor_schedule_model.dart';
import '../../services/availability_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/custom_components.dart';

enum _AvailabilityMode { weekly, calendar }

class DoctorAvailabilityScreen extends StatefulWidget {
  const DoctorAvailabilityScreen({super.key});

  @override
  State<DoctorAvailabilityScreen> createState() => _DoctorAvailabilityScreenState();
}

class _DoctorAvailabilityScreenState extends State<DoctorAvailabilityScreen> {
  final _formKey = GlobalKey<FormState>();
  DayOfWeek _selectedDay = DayOfWeek.monday;
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  int _slotDuration = 15;
  int _maxPatients = 30;
  
  // Per-action loading states
  bool _addingSchedule = false;
  int? _deletingScheduleId;

  // Calendar mode state
  _AvailabilityMode _mode = _AvailabilityMode.weekly;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDate = DateTime.now();
  bool _loadingOverrides = false;
  int? _deletingOverrideId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAvailability();
      _loadMonthOverrides();
    });
  }

  Future<void> _loadAvailability() async {
    final service = context.read<AvailabilityService>();
    await service.fetchMyAvailability();
  }

  Future<void> _loadMonthOverrides() async {
    final service = context.read<AvailabilityService>();
    setState(() => _loadingOverrides = true);
    await service.fetchDateOverrides(month: _focusedDay);
    if (!mounted) return;
    setState(() => _loadingOverrides = false);
  }

  Future<void> _addScheduleEntry() async {
    final service = context.read<AvailabilityService>();
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _addingSchedule = true);

    final startStr =
        '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}';
    final endStr =
        '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}';

    final success = await service.createAvailabilityEntry({
      'day_of_week': _selectedDay.value,
      'start_time': startStr,
      'end_time': endStr,
      'slot_duration_minutes': _slotDuration,
      'max_patients_per_day': _maxPatients,
    });

    if (!mounted) return;
    setState(() => _addingSchedule = false);
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Availability added successfully'),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
      _resetForm();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(service.errorMessage ?? 'Failed to add availability'),
          backgroundColor: AppColors.emergencyRed,
        ),
      );
    }
  }

  Future<void> _deleteEntry(int id) async {
    final service = context.read<AvailabilityService>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: 'Remove Availability',
        message: 'Are you sure you want to remove this schedule entry?',
        confirmButtonText: 'Remove',
        cancelButtonText: 'Cancel',
        confirmButtonColor: AppColors.emergencyRed,
        onConfirm: () => Navigator.of(context).pop(true),
      ),
    );
    if (confirmed != true) return;

    setState(() => _deletingScheduleId = id);
    final success = await service.deleteAvailabilityEntry(id);
    if (!mounted) return;
    setState(() => _deletingScheduleId = null);
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Availability removed'),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(service.errorMessage ?? 'Failed to remove availability'),
          backgroundColor: AppColors.emergencyRed,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Calendar (date-specific) availability
  // ---------------------------------------------------------------------------

  Future<void> _onMonthChanged(DateTime date) async {
    setState(() => _focusedDay = date);
    await _loadMonthOverrides();
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    final service = context.read<AvailabilityService>();
    setState(() {
      _selectedDate = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
      _focusedDay = focusedDay;
    });
    _openOverrideDialog(service);
  }

  DoctorAvailabilityOverride? _overrideFor(DateTime date, List<DoctorAvailabilityOverride> overrides) {
    for (final o in overrides) {
      if (o.date.year == date.year &&
          o.date.month == date.month &&
          o.date.day == date.day) {
        return o;
      }
    }
    return null;
  }

  Future<void> _openOverrideDialog(AvailabilityService service) async {
    final existing = _overrideFor(_selectedDate, service.overrides);

    final result = await showDialog<_OverrideDialogResult>(
      context: context,
      builder: (context) => _OverrideDialog(
        date: _selectedDate,
        existing: existing,
      ),
    );
    if (result == null || !mounted) return;

    final dateStr =
        '${_selectedDate.year.toString().padLeft(4, '0')}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

    bool success;
    if (result.deleteExisting && existing != null) {
      success = await service.deleteDateOverride(existing.id);
    } else if (existing != null) {
      success = await service.updateDateOverride(existing.id, {
        'override_type': result.overrideType.value,
        'start_time': result.startTime,
        'end_time': result.endTime,
        'slot_duration_minutes': result.slotDurationMinutes,
        'max_patients_per_day': result.maxPatientsPerDay,
      });
    } else {
      success = await service.createDateOverride({
        'date': dateStr,
        'override_type': result.overrideType.value,
        'start_time': result.startTime,
        'end_time': result.endTime,
        'slot_duration_minutes': result.slotDurationMinutes,
        'max_patients_per_day': result.maxPatientsPerDay,
      });
    }

    if (!mounted) return;
    final label = '${_selectedDate.month}/${_selectedDate.day}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? result.deleteExisting && existing != null
                  ? 'Override removed for $label'
                  : 'Availability updated for $label'
              : (service.errorMessage ?? 'Failed to update availability'),
        ),
        backgroundColor: success ? AppColors.primaryGreen : AppColors.emergencyRed,
      ),
    );
  }

  Future<void> _deleteOverride(int id) async {
    final service = context.read<AvailabilityService>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: 'Remove Override',
        message: 'Are you sure you want to remove this date override?',
        confirmButtonText: 'Remove',
        cancelButtonText: 'Cancel',
        confirmButtonColor: AppColors.emergencyRed,
        onConfirm: () => Navigator.of(context).pop(true),
      ),
    );
    if (confirmed != true) return;

    setState(() => _deletingOverrideId = id);
    final success = await service.deleteDateOverride(id);
    if (!mounted) return;
    setState(() => _deletingOverrideId = null);
    await _loadMonthOverrides();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Override removed' : (service.errorMessage ?? 'Failed to remove override')),
        backgroundColor: success ? AppColors.primaryGreen : AppColors.emergencyRed,
      ),
    );
  }

  Future<void> _openEditDialog(DoctorSchedule schedule) async {
    final service = context.read<AvailabilityService>();
    final startParts = schedule.startTime.split(':');
    final endParts = schedule.endTime.split(':');
    var selectedDay = schedule.day;
    var startTime = TimeOfDay(
      hour: int.tryParse(startParts.first) ?? 8,
      minute: int.tryParse(startParts.last) ?? 0,
    );
    var endTime = TimeOfDay(
      hour: int.tryParse(endParts.first) ?? 17,
      minute: int.tryParse(endParts.last) ?? 0,
    );
    var slotDuration = schedule.slotDurationMinutes;
    var maxPatients = schedule.maxPatientsPerDay;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit availability'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DaySelector(
                  selectedDay: selectedDay,
                  onChanged: (d) => setDialogState(() => selectedDay = d),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _DialogTimeField(
                        label: 'Start time',
                        icon: Icons.access_time_rounded,
                        time: startTime,
                        onPick: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: startTime,
                          );
                          if (picked != null && mounted) {
                            setDialogState(() => startTime = picked);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DialogTimeField(
                        label: 'End time',
                        icon: Icons.access_time_filled_rounded,
                        time: endTime,
                        onPick: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: endTime,
                          );
                          if (picked != null && mounted) {
                            setDialogState(() => endTime = picked);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _DropdownField<int>(
                        label: 'Slot duration (min)',
                        icon: Icons.timer_rounded,
                        value: slotDuration,
                        items: const [15, 20, 30],
                        onChanged: (v) =>
                            setDialogState(() => slotDuration = v ?? 15),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DropdownField<int>(
                        label: 'Max patients / day',
                        icon: Icons.people_rounded,
                        value: maxPatients,
                        items: const [10, 20, 30, 50],
                        onChanged: (v) =>
                            setDialogState(() => maxPatients = v ?? 30),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final body = <String, dynamic>{
                  'day_of_week': selectedDay.value,
                  'start_time':
                      '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
                  'end_time':
                      '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
                  'slot_duration_minutes': slotDuration,
                  'max_patients_per_day': maxPatients,
                };
                final success = await service.updateAvailabilityEntry(schedule.id, body);
                if (context.mounted) {
                  Navigator.of(context).pop(success);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;
    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Availability updated'),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
    } else if (result == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(service.errorMessage ?? 'Failed to update availability'),
          backgroundColor: AppColors.emergencyRed,
        ),
      );
    }
  }

  void _resetForm() {
    setState(() {
      _selectedDay = DayOfWeek.monday;
      _startTime = const TimeOfDay(hour: 8, minute: 0);
      _endTime = const TimeOfDay(hour: 17, minute: 0);
      _slotDuration = 15;
      _maxPatients = 30;
    });
    _formKey.currentState?.reset();
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
            'My Availability',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3),
            ),
           
          ],
        ),
       
      ),
      body: Consumer<AvailabilityService>(
        builder: (context, service, _) {
          final schedules = service.schedules;

          return ListView(
            padding: const EdgeInsets.all(16),
            physics: const BouncingScrollPhysics(),
            children: [
              // Mode toggle
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SegmentedButton<_AvailabilityMode>(
                  segments: const [
                    ButtonSegment(
                      value: _AvailabilityMode.weekly,
                      label: Text('Weekly'),
                      icon: Icon(Icons.calendar_view_week_rounded, size: 18),
                    ),
                    ButtonSegment(
                      value: _AvailabilityMode.calendar,
                      label: Text('Date-specific'),
                      icon: Icon(Icons.event_available_rounded, size: 18),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (selection) {
                    setState(() => _mode = selection.first);
                    if (selection.first == _AvailabilityMode.calendar) {
                      _loadMonthOverrides();
                    }
                  },
                ),
              ),
              if (_mode == _AvailabilityMode.weekly) ...[
              // Active Schedule Section
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Active Schedule',
                      style: TextStyle(
                        color: AppColors.textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage your working days and hours',
                      style: TextStyle(
                        color: AppColors.textGray,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (service.isLoading && schedules.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading schedules...',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textGray,
                        ),
                      ),
                    ],
                  ),
                )
              else if (schedules.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.borderColor.withValues(alpha: 0.3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadowColor.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.event_busy_rounded,
                          size: 32,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No availability set',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add your working days below to get started',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textGray,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                ...schedules.map(
                  (s) => _ScheduleTile(
                    schedule: s,
                    isDeleting: _deletingScheduleId == s.id,
                    onDelete: () => _deleteEntry(s.id),
                    onEdit: () => _openEditDialog(s),
                  ),
                ),
              const SizedBox(height: 32),

              // Add Schedule Section
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add Schedule Entry',
                      style: TextStyle(
                        color: AppColors.textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Create a new availability slot',
                      style: TextStyle(
                        color: AppColors.textGray,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.borderColor.withValues(alpha: 0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadowColor.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _DaySelector(
                        selectedDay: _selectedDay,
                        onChanged: (d) => setState(() => _selectedDay = d),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _TimePickerField(
                              label: 'Start time',
                              icon: Icons.access_time_rounded,
                              time: _startTime,
                              onPick: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: _startTime,
                                );
                                if (picked != null) {
                                  setState(() => _startTime = picked);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _TimePickerField(
                              label: 'End time',
                              icon: Icons.access_time_filled_rounded,
                              time: _endTime,
                              onPick: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: _endTime,
                                );
                                if (picked != null) {
                                  setState(() => _endTime = picked);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _DropdownField<int>(
                              label: 'Slot duration',
                              icon: Icons.timer_rounded,
                              value: _slotDuration,
                              items: const [15, 20, 30],
                              onChanged: (v) =>
                                  setState(() => _slotDuration = v ?? 15),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _DropdownField<int>(
                              label: 'Max patients',
                              icon: Icons.people_rounded,
                              value: _maxPatients,
                              items: const [10, 20, 30, 50],
                              onChanged: (v) =>
                                  setState(() => _maxPatients = v ?? 30),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child:Container(
  width: double.infinity,
  decoration: BoxDecoration(
    gradient: _addingSchedule
        ? LinearGradient(
            colors: [
              AppColors.primaryBlue.withValues(alpha: 0.6),
              AppColors.primaryGreen.withValues(alpha: 0.6),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [
              AppColors.primaryGreen,
              AppColors.primaryBlue,
              
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
    borderRadius: BorderRadius.circular(14),
  ),
  child: ElevatedButton(
    onPressed: _addingSchedule ? null : _addScheduleEntry,
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.transparent,
      shadowColor: Colors.transparent,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      elevation: 0,
    ),
    child: _addingSchedule
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.white,
              ),
            ),
          )
        : const Text(
            'Add Availability',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
  ),
)
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ], // end: weekly mode content

              // ------------------------------------------------------------------
              // Calendar mode content
              // ------------------------------------------------------------------
              if (_mode == _AvailabilityMode.calendar) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Date-specific overrides',
                        style: TextStyle(
                          color: AppColors.textDark,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap a date to mark it available or unavailable. '
                        'Overrides take priority over your weekly schedule.',
                        style: TextStyle(
                          color: AppColors.textGray,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.borderColor.withValues(alpha: 0.3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadowColor.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      TableCalendar<DoctorAvailabilityOverride>(
                        firstDay: DateTime(
                          DateTime.now().year - 1,
                          DateTime.now().month,
                          1,
                        ),
                        lastDay: DateTime(
                          DateTime.now().year + 2,
                          12,
                          31,
                        ),
                        focusedDay: _focusedDay,
                        calendarFormat: CalendarFormat.month,
                        startingDayOfWeek: StartingDayOfWeek.monday,
                        selectedDayPredicate: (day) =>
                            isSameDay(day, _selectedDate),
                        eventLoader: (day) {
                          final o = _overrideFor(day, service.overrides);
                          return o == null ? const [] : [o];
                        },
                        onDaySelected: _onDaySelected,
                        onPageChanged: _onMonthChanged,
                        availableCalendarFormats: const {
                          CalendarFormat.month: 'Month',
                        },
                        headerStyle: const HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true,
                          titleTextStyle: TextStyle(
                            color: AppColors.textDark,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        daysOfWeekStyle: const DaysOfWeekStyle(
                          weekdayStyle: TextStyle(
                            color: AppColors.textGray,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                          weekendStyle: TextStyle(
                            color: AppColors.emergencyRed,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        calendarStyle: CalendarStyle(
                          outsideDaysVisible: false,
                          defaultTextStyle: TextStyle(
                            color: AppColors.textDark,
                            fontSize: 13,
                          ),
                          weekendTextStyle: TextStyle(
                            color: AppColors.emergencyRed,
                            fontSize: 13,
                          ),
                          todayTextStyle: TextStyle(
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.w800,
                          ),
                          todayDecoration: BoxDecoration(
                            color: AppColors.primaryBlue.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                        ),
                        calendarBuilders:
                            CalendarBuilders<DoctorAvailabilityOverride>(
                          markerBuilder: (context, day, overrides) {
                            if (overrides.isEmpty) return null;
                            final color = overrides.first.isAvailable
                                ? AppColors.primaryGreen
                                : AppColors.emergencyRed;
                            return Positioned(
                              bottom: 2,
                              child: Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: color,
                                ),
                              ),
                            );
                          },
                          selectedBuilder: (context, day, focusedDay) {
                            return Container(
                              margin: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  '${day.day}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const _LegendDot(
                            color: AppColors.primaryGreen,
                            label: 'Available',
                          ),
                          const SizedBox(width: 16),
                          _LegendDot(
                            color: AppColors.emergencyRed,
                            label: 'Unavailable',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Month override list
                if (_loadingOverrides && service.overrides.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primaryBlue,
                        ),
                      ),
                    ),
                  )
                else if (service.overrides.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.borderColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'No date-specific overrides this month. '
                      'Tap a date on the calendar to add one.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textGray,
                      ),
                    ),
                  )
                else
                  ...service.overrides.map(
                    (o) => _OverrideTile(
                      availabilityOverride: o,
                      isDeleting: _deletingOverrideId == o.id,
                      onTap: () {
                        setState(() => _selectedDate = o.date);
                        _openOverrideDialog(service);
                      },
                      onDelete: () => _deleteOverride(o.id),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ScheduleTile extends StatelessWidget {
  final DoctorSchedule schedule;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final bool isDeleting;

  const _ScheduleTile({
    required this.schedule,
    required this.onDelete,
    required this.onEdit,
    this.isDeleting = false,
  });

  @override
  Widget build(BuildContext context) {
    final day = schedule.day.displayName;
    final start = schedule.startTime;
    final end = schedule.endTime;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.calendar_today_rounded,
              color: AppColors.primaryBlue,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$start – $end',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textGray,
                  ),
                ),
              ],
            ),
          ),
          if (isDeleting)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.emergencyRed.withValues(alpha: 0.7),
                  ),
                ),
              ),
            )
          else ...[
            IconButton(
              onPressed: onEdit,
              icon: Icon(
                Icons.edit_calendar_sharp,
                color: AppColors.primaryGreen.withValues(alpha: 0.7),
              ),
              tooltip: 'Edit',
            ),
            IconButton(
              onPressed: onDelete,
              icon: Icon(
                Icons.delete_outline_rounded,
                color: AppColors.emergencyRed.withValues(alpha: 0.7),
              ),
              tooltip: 'Remove',
            ),
          ],
        ],
      ),
    );
  }
}

class _DaySelector extends StatelessWidget {
  final DayOfWeek selectedDay;
  final ValueChanged<DayOfWeek> onChanged;

  const _DaySelector({
    required this.selectedDay,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: DayOfWeek.values.map((day) {
          final isSelected = day == selectedDay;
          return GestureDetector(
            onTap: () => onChanged(day),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color:
                    isSelected ? AppColors.primaryBlue : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primaryBlue
                      : AppColors.borderColor.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                day.displayName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textGray,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _DialogTimeField extends StatelessWidget {
  final String label;
  final IconData icon;
  final TimeOfDay time;
  final VoidCallback onPick;

  const _DialogTimeField({
    required this.label,
    required this.icon,
    required this.time,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final formatted =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primaryBlue),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textGray,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatted,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimePickerField extends StatelessWidget {
  final String label;
  final IconData icon;
  final TimeOfDay time;
  final VoidCallback onPick;

  const _TimePickerField({
    required this.label,
    required this.icon,
    required this.time,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final formatted =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primaryBlue),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textGray,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatted,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  final String label;
  final IconData icon;
  final T value;
  final List<T> items;
  final ValueChanged<T?> onChanged;

  const _DropdownField({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primaryBlue),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                isExpanded: true,
                value: value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textGray),
                items: items
                    .map(
                      (item) => DropdownMenuItem<T>(
                        value: item,
                        child: Text('$item'),
                      ),
                    )
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverrideDialogResult {
  final OverrideType overrideType;
  final String? startTime;
  final String? endTime;
  final int slotDurationMinutes;
  final int maxPatientsPerDay;
  final bool deleteExisting;

  const _OverrideDialogResult({
    required this.overrideType,
    this.startTime,
    this.endTime,
    required this.slotDurationMinutes,
    required this.maxPatientsPerDay,
    this.deleteExisting = false,
  });
}

class _OverrideDialog extends StatefulWidget {
  final DateTime date;
  final DoctorAvailabilityOverride? existing;

  const _OverrideDialog({
    required this.date,
    this.existing,
  });

  @override
  State<_OverrideDialog> createState() => _OverrideDialogState();
}

class _OverrideDialogState extends State<_OverrideDialog> {
  late OverrideType _type;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  bool _customTimes = false;
  late int _slotDuration;
  late int _maxPatients;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _type = existing?.overrideType ?? OverrideType.available;
    _slotDuration = existing?.slotDurationMinutes ?? 15;
    _maxPatients = existing?.maxPatientsPerDay ?? 20;

    if (existing?.startTime != null) {
      final parts = existing!.startTime!.split(':');
      _startTime = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
      _customTimes = true;
    } else {
      _startTime = const TimeOfDay(hour: 8, minute: 0);
    }

    if (existing?.endTime != null) {
      final parts = existing!.endTime!.split(':');
      _endTime = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    } else {
      _endTime = const TimeOfDay(hour: 17, minute: 0);
    }
  }

  void _save() {
    if (_customTimes && _type == OverrideType.available) {
      final start = _startTime.hour * 60 + _startTime.minute;
      final end = _endTime.hour * 60 + _endTime.minute;
      if (start >= end) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('End time must be after start time.'),
            backgroundColor: AppColors.emergencyRed,
          ),
        );
        return;
      }
    }

    Navigator.of(context).pop(
      _OverrideDialogResult(
        overrideType: _type,
        startTime: _customTimes && _type == OverrideType.available
            ? '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}'
            : null,
        endTime: _customTimes && _type == OverrideType.available
            ? '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}'
            : null,
        slotDurationMinutes: _slotDuration,
        maxPatientsPerDay: _maxPatients,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final date = widget.date;
    final label =
        '${date.month}/${date.day}/${date.year}  (${_weekdayName(date.weekday)})';
    return AlertDialog(
      title: Text(
        widget.existing == null ? 'Set availability' : 'Edit availability',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<OverrideType>(
                segments: const [
                  ButtonSegment(
                    value: OverrideType.available,
                    label: Text('Available'),
                    icon: Icon(Icons.check_circle_rounded, size: 18),
                  ),
                  ButtonSegment(
                    value: OverrideType.unavailable,
                    label: Text('Unavailable'),
                    icon: Icon(Icons.block_rounded, size: 18),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (s) =>
                    setState(() => _type = s.first),
              ),
            ),
            if (_type == OverrideType.available) ...[
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text(
                  'Custom time range',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  'Off = use your weekly schedule hours',
                  style: TextStyle(fontSize: 11, color: AppColors.textGray),
                ),
                value: _customTimes,
                onChanged: (v) => setState(() => _customTimes = v),
              ),
              if (_customTimes) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _DialogTimeField(
                        label: 'Start time',
                        icon: Icons.access_time_rounded,
                        time: _startTime,
                        onPick: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: _startTime,
                          );
                          if (picked != null && mounted) {
                            setState(() => _startTime = picked);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DialogTimeField(
                        label: 'End time',
                        icon: Icons.access_time_filled_rounded,
                        time: _endTime,
                        onPick: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: _endTime,
                          );
                          if (picked != null && mounted) {
                            setState(() => _endTime = picked);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _DropdownField<int>(
                      label: 'Slot duration (min)',
                      icon: Icons.timer_rounded,
                      value: _slotDuration,
                      items: const [15, 20, 30],
                      onChanged: (v) =>
                          setState(() => _slotDuration = v ?? _slotDuration),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DropdownField<int>(
                      label: 'Max patients / day',
                      icon: Icons.people_rounded,
                      value: _maxPatients,
                      items: const [10, 20, 30, 50],
                      onChanged: (v) =>
                          setState(() => _maxPatients = v ?? _maxPatients),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (widget.existing != null)
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(
              _OverrideDialogResult(
                overrideType: _type,
                slotDurationMinutes: _slotDuration,
                maxPatientsPerDay: _maxPatients,
                deleteExisting: true,
              ),
            ),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Remove'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.emergencyRed,
            ),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  String _weekdayName(int weekday) {
    const names = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[weekday];
  }
}

class _OverrideTile extends StatelessWidget {
  final DoctorAvailabilityOverride availabilityOverride;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool isDeleting;

  const _OverrideTile({
    required this.availabilityOverride,
    required this.onTap,
    required this.onDelete,
    this.isDeleting = false,
  });

  @override
  Widget build(BuildContext context) {
    final available = availabilityOverride.isAvailable;
    final date = availabilityOverride.date;
    final timeLabel = availabilityOverride.startTime != null
        ? '${availabilityOverride.startTime} - ${availabilityOverride.endTime}  |  ${availabilityOverride.slotDurationMinutes} min slots'
        : 'Uses weekly schedule hours';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (available ? AppColors.primaryGreen : AppColors.emergencyRed)
              .withValues(alpha: 0.35),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (available
                        ? AppColors.primaryGreen
                        : AppColors.emergencyRed)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                available
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                color: available
                    ? AppColors.primaryGreen
                    : AppColors.emergencyRed,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${date.month}/${date.day}/${date.year}  -  ${available ? 'Available' : 'Unavailable'}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textGray,
                    ),
                  ),
                ],
              ),
            ),
            if (isDeleting)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.emergencyRed.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              )
            else
              IconButton(
                onPressed: onDelete,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.emergencyRed.withValues(alpha: 0.7),
                ),
                tooltip: 'Remove',
              ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textGray,
          ),
        ),
      ],
    );
  }
}
