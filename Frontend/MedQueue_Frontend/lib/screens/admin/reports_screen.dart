import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/admin_reports_model.dart';
import '../../models/user_management_model.dart';
import '../../services/admin_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/custom_components.dart';

enum _ReportTab { general, patient, doctor }

enum _ReportPeriod { day, week, month, year }

/// Admin "Reports" screen with three report types:
/// General (period-based), per-patient and per-doctor.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  _ReportTab _tab = _ReportTab.general;
  _ReportPeriod _period = _ReportPeriod.day;
  DateTime _date = DateTime.now();
  int? _patientId;
  int? _doctorId;

  String _formatDate(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _generate(AdminService service) async {
    if (_tab == _ReportTab.patient && _patientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a patient first.')),
      );
      return;
    }
    if (_tab == _ReportTab.doctor && _doctorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a doctor first.')),
      );
      return;
    }

    switch (_tab) {
      case _ReportTab.general:
        await service.fetchGeneralReport(
          period: _period.name,
          date: _formatDate(_date),
        );
      case _ReportTab.patient:
        await service.fetchPatientReport(patientId: _patientId!);
      case _ReportTab.doctor:
        await service.fetchDoctorReport(doctorId: _doctorId!);
    }
  }

  void _loadPeople(AdminService service) {
    // Fetch per-role: the shared list is reused across tabs, so check which
    // role is currently cached rather than whether the list is empty.
    final role = _tab == _ReportTab.patient
        ? 'patient'
        : _tab == _ReportTab.doctor
            ? 'doctor'
            : null;
    if (role != null && service.reportPeopleRole != role) {
      service.fetchReportPeople(role: role);
    }
  }

  @override
  void dispose() {
    // Nothing to dispose (Provider-managed service).
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Reports'),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        children: [
          SegmentedButton<_ReportTab>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: _ReportTab.general,
                label: Text('General'),
                icon: Icon(Icons.insights_rounded, size: 18),
              ),
              ButtonSegment(
                value: _ReportTab.patient,
                label: Text('Patient'),
                icon: Icon(Icons.person_outline, size: 18),
              ),
              ButtonSegment(
                value: _ReportTab.doctor,
                label: Text('Doctor'),
                icon: Icon(Icons.badge_outlined, size: 18),
              ),
            ],
            selected: {_tab},
            onSelectionChanged: (selection) {
              setState(() => _tab = selection.first);
              _loadPeople(context.read<AdminService>());
            },
          ),
          const SizedBox(height: 20),
          Consumer<AdminService>(
            builder: (context, service, _) =>
                _buildTabBody(context, service),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBody(BuildContext context, AdminService service) {
    switch (_tab) {
      case _ReportTab.general:
        return _buildGeneralTab(context, service);
      case _ReportTab.patient:
        return _buildPatientTab(context, service);
      case _ReportTab.doctor:
        return _buildDoctorTab(context, service);
    }
  }

  // ── General report (period based) ─────────────────────────────────────

  Widget _buildGeneralTab(BuildContext context, AdminService service) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'Time period',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
        ),
        SegmentedButton<_ReportPeriod>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: _ReportPeriod.day, label: Text('Day')),
            ButtonSegment(value: _ReportPeriod.week, label: Text('Week')),
            ButtonSegment(value: _ReportPeriod.month, label: Text('Month')),
            ButtonSegment(value: _ReportPeriod.year, label: Text('Year')),
          ],
          selected: {_period},
          onSelectionChanged: (selection) =>
              setState(() => _period = selection.first),
        ),
        const SizedBox(height: 14),
        _DateField(
          label: 'Reference date',
          value: _formatDate(_date),
          icon: Icons.calendar_today,
          onTap: _pickDate,
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => _generate(service),
            icon: const Icon(Icons.description_outlined),
            label: const Text(
              'Generate Report',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (service.generalReportLoading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: CustomLoadingIndicator(message: 'Generating report...'),
          )
        else if (service.generalReportError != null &&
            service.generalReport == null)
          AppErrorWidget(
            message: service.generalReportError!,
            onRetry: () => _generate(service),
          )
        else if (service.generalReport != null)
          _GeneralReportView(report: service.generalReport!),
      ],
    );
  }

  // ── Patient report ────────────────────────────────────────────────────

  Widget _buildPatientTab(BuildContext context, AdminService service) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Select a patient',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
        ),
        if (service.reportPeopleLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(8),
              child: CustomLoadingIndicator(message: 'Loading patients...'),
            ),
          )
        else if (service.reportPeopleError != null &&
            service.reportPeople.isEmpty)
          AppErrorWidget(
            message: service.reportPeopleError!,
            onRetry: () => service.fetchReportPeople(role: 'patient'),
          )
        else
          DropdownButtonFormField<AdminUserEntry>(
            initialValue: _patientId == null
                ? null
                : service.reportPeople
                    .where((u) => u.id == _patientId)
                    .firstOrNull,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Patient',
              prefixIcon: const Icon(Icons.person_outline,
                  color: AppColors.primaryBlue),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            items: service.reportPeople
                .map((u) => DropdownMenuItem(
                      value: u,
                      child: Text(
                        u.displayName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList(),
            onChanged: (u) {
              if (u != null) setState(() => _patientId = u.id);
            },
          ),
        const SizedBox(height: 20),
        SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => _generate(service),
            icon: const Icon(Icons.description_outlined),
            label: const Text(
              'Generate Report',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (service.patientReportLoading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: CustomLoadingIndicator(message: 'Generating report...'),
          )
        else if (service.patientReportError != null &&
            service.patientReport == null)
          AppErrorWidget(
            message: service.patientReportError!,
            onRetry: () => _generate(service),
          )
        else if (service.patientReport != null)
          _PatientReportView(report: service.patientReport!),
      ],
    );
  }

  // ── Doctor report ─────────────────────────────────────────────────────

  Widget _buildDoctorTab(BuildContext context, AdminService service) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Select a doctor',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
        ),
        if (service.reportPeopleLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(8),
              child: CustomLoadingIndicator(message: 'Loading doctors...'),
            ),
          )
        else if (service.reportPeopleError != null &&
            service.reportPeople.isEmpty)
          AppErrorWidget(
            message: service.reportPeopleError!,
            onRetry: () => service.fetchReportPeople(role: 'doctor'),
          )
        else
          DropdownButtonFormField<AdminUserEntry>(
            initialValue: _doctorId == null
                ? null
                : service.reportPeople
                    .where((u) => u.id == _doctorId)
                    .firstOrNull,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Doctor',
              prefixIcon: const Icon(Icons.badge_outlined,
                  color: AppColors.primaryBlue),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            items: service.reportPeople
                .map((u) => DropdownMenuItem(
                      value: u,
                      child: Text(
                        u.doctorProfile?.specialization != null &&
                                u.doctorProfile!.specialization.isNotEmpty
                            ? '${u.displayName} — '
                                '${u.doctorProfile!.specialization}'
                            : u.displayName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList(),
            onChanged: (u) {
              if (u != null) setState(() => _doctorId = u.id);
            },
          ),
        const SizedBox(height: 20),
        SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => _generate(service),
            icon: const Icon(Icons.description_outlined),
            label: const Text(
              'Generate Report',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (service.doctorReportLoading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: CustomLoadingIndicator(message: 'Generating report...'),
          )
        else if (service.doctorReportError != null &&
            service.doctorReport == null)
          AppErrorWidget(
            message: service.doctorReportError!,
            onRetry: () => _generate(service),
          )
        else if (service.doctorReport != null)
          _DoctorReportView(report: service.doctorReport!),
      ],
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────

class _DateField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.primaryBlue),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.borderColor),
          ),
        ),
        child: Text(
          value,
          style: const TextStyle(fontSize: 15, color: AppColors.textDark),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primaryBlue),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }
}

class _ReportRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReportRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 14, color: AppColors.textGray)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionPlaceholder extends StatelessWidget {
  final String message;

  const _SectionPlaceholder({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundGray,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: const TextStyle(fontSize: 13, color: AppColors.textGray),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _statusColor(status).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: _statusColor(status),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
      case 'completed':
        return AppColors.primaryGreen;
      case 'cancelled':
      case 'no_show':
        return AppColors.emergencyRed;
      case 'rescheduled':
        return AppColors.warningOrange;
      default:
        return AppColors.primaryBlue;
    }
  }

  String _statusLabel(String status) {
    const map = {
      'pending': 'Pending',
      'confirmed': 'Confirmed',
      'completed': 'Completed',
      'cancelled': 'Cancelled',
      'no_show': 'No Show',
      'rescheduled': 'Rescheduled',
    };
    return map[status] ?? status;
  }
}

// ── General report view ───────────────────────────────────────────────────

class _GeneralReportView extends StatelessWidget {
  final GeneralReport report;

  const _GeneralReportView({required this.report});

  @override
  Widget build(BuildContext context) {
    final summary = report.appointmentSummary;
    final attended =
        (summary['completed'] ?? 0) + (summary['confirmed'] ?? 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_periodTitle(report.period)} report: '
          '${report.fromDate} — ${report.toDate}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 16),

        _SectionHeader(
          title: 'Appointment Summary',
          icon: Icons.people_outline,
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _ReportRow(label: 'Total booked', value: '${report.totalBooked}'),
                _ReportRow(label: 'Attended', value: '$attended'),
                _ReportRow(label: 'Cancelled', value: '${summary['cancelled'] ?? 0}'),
                _ReportRow(label: 'No-shows', value: '${summary['no_show'] ?? 0}'),
                _ReportRow(label: 'Pending', value: '${summary['pending'] ?? 0}'),
                _ReportRow(label: 'Rescheduled', value: '${summary['rescheduled'] ?? 0}'),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),
        _SectionHeader(title: 'Doctors Who Worked', icon: Icons.badge_outlined),
        const SizedBox(height: 8),
        if (report.doctorsWorked.isEmpty)
          const _SectionPlaceholder(message: 'No doctors worked in this period.')
        else
          Card(
            elevation: 1,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ReportRow(
                    label: 'Doctors',
                    value: '${report.doctorsWorkedCount}',
                  ),
                  const Divider(height: 24),
                  for (final d in report.doctorsWorked)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.medical_services_outlined,
                              size: 20, color: AppColors.primaryBlue),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d.name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                if (d.specialization != null)
                                  Text(
                                    d.specialization!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textGray,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            '${d.patientsSeen}/${d.appointments} seen',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textGray,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 20),
        _SectionHeader(title: 'Booked Appointments', icon: Icons.event_note),
        const SizedBox(height: 8),
        if (report.bookings.isEmpty)
          const _SectionPlaceholder(message: 'No bookings in this period.')
        else
          for (final b in report.bookings)
            Card(
              elevation: 1,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            b.patientName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        _StatusChip(status: b.status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Dr. ${b.doctorName}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textGray,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${b.date}${b.time != null ? ' at ${b.time}' : ''}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textGray,
                      ),
                    ),
                  ],
                ),
              ),
            ),

        const SizedBox(height: 20),
        _SectionHeader(title: 'Emergency Alerts', icon: Icons.emergency_outlined),
        const SizedBox(height: 8),
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _ReportRow(label: 'Total alerts', value: '${report.emergencies.total}'),
                _ReportRow(
                  label: 'Dispatched',
                  value: '${report.emergencies.dispatched}',
                ),
                _ReportRow(
                  label: 'Falsed',
                  value: '${report.emergencies.falsed}',
                ),
              ],
            ),
          ),
        ),
        if (report.emergencies.from.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final e in report.emergencies.from)
            Card(
              elevation: 1,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'From: ${e.patientName}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        _EmergencyChip(status: e.status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      e.emergencyType,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textGray,
                      ),
                    ),
                    if (e.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        e.description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textGray,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }

  String _periodTitle(String period) {
    switch (period) {
      case 'week':
        return 'Week';
      case 'month':
        return 'Month';
      case 'year':
        return 'Year';
      default:
        return 'Day';
    }
  }
}

class _EmergencyChip extends StatelessWidget {
  final String status;

  const _EmergencyChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'dispatched' => AppColors.primaryGreen,
      'false_alarm' => AppColors.warningOrange,
      'resolved' => AppColors.primaryGreen,
      'cancelled' => AppColors.emergencyRed,
      _ => AppColors.primaryBlue,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _label(status),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  String _label(String status) {
    const map = {
      'pending': 'Pending',
      'dispatched': 'Dispatched',
      'false_alarm': 'False Alarm',
      'resolved': 'Resolved',
      'cancelled': 'Cancelled',
    };
    return map[status] ?? status;
  }
}

// ── Patient report view ───────────────────────────────────────────────────

class _PatientReportView extends StatelessWidget {
  final PatientReport report;

  const _PatientReportView({required this.report});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${report.patientName} — ${report.totalAppointments} appointments',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 16),
        if (report.appointments.isEmpty)
          const _SectionPlaceholder(message: 'No appointments on record.')
        else
          for (final a in report.appointments)
            Card(
              elevation: 1,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Dr. ${a.doctorName}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        _StatusChip(status: a.status),
                      ],
                    ),
                    if (a.specialization != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        a.specialization!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textGray,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      '${a.date}${a.time != null ? ' at ${a.time}' : ''}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textGray,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Reason: ${a.reason.isEmpty ? '—' : a.reason}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textGray,
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

// ── Doctor report view ────────────────────────────────────────────────────

class _DoctorReportView extends StatelessWidget {
  final DoctorReport report;

  const _DoctorReportView({required this.report});

  static const _dayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${report.doctorName} — patients seen: ${report.totalPatientsSeen}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        if (report.specialization != null) ...[
          const SizedBox(height: 4),
          Text(
            report.specialization!,
            style: const TextStyle(fontSize: 13, color: AppColors.textGray),
          ),
        ],
        const SizedBox(height: 16),

        _SectionHeader(title: 'Active Days', icon: Icons.calendar_view_week),
        const SizedBox(height: 8),
        if (report.activeDays.isEmpty)
          const _SectionPlaceholder(message: 'No active days configured.')
        else
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  for (var i = 0; i < report.activeDays.length; i++)
                    Column(
                      children: [
                        _ReportRow(
                          label: _dayNames[report.activeDays[i].dayOfWeek],
                          value:
                              '${report.activeDays[i].startTime} — '
                              '${report.activeDays[i].endTime}',
                        ),
                        if (i != report.activeDays.length - 1)
                          const Divider(height: 16),
                      ],
                    ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 20),
        _SectionHeader(title: 'Practice Summary', icon: Icons.insights_rounded),
        const SizedBox(height: 8),
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _ReportRow(
                  label: 'Total appointments',
                  value: '${report.totalAppointments}',
                ),
                _ReportRow(
                  label: 'Patients cared for',
                  value: '${report.totalPatientsSeen}',
                ),
                _ReportRow(
                  label: 'Date-specific overrides',
                  value: '${report.dateOverrides.length}',
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),
        _SectionHeader(title: 'Booked Patients', icon: Icons.people_outline),
        const SizedBox(height: 8),
        if (report.bookedPatients.isEmpty)
          const _SectionPlaceholder(message: 'No patients booked.')
        else
          for (final v in report.bookedPatients) _VisitCard(visit: v),

        const SizedBox(height: 20),
        _SectionHeader(title: 'Patients Cared For', icon: Icons.favorite_outline),
        const SizedBox(height: 8),
        if (report.patientsCaredFor.isEmpty)
          const _SectionPlaceholder(message: 'No completed consultations.')
        else
          for (final v in report.patientsCaredFor) _VisitCard(visit: v),
      ],
    );
  }
}

class _VisitCard extends StatelessWidget {
  final ReportPatientVisit visit;

  const _VisitCard({required this.visit});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    visit.patientName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                _StatusChip(status: visit.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${visit.date}${visit.time != null ? ' at ${visit.time}' : ''}',
              style: const TextStyle(fontSize: 13, color: AppColors.textGray),
            ),
          ],
        ),
      ),
    );
  }
}