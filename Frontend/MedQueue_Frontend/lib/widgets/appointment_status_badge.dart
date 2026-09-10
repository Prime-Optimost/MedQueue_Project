import 'package:flutter/material.dart';
import '../models/appointment_model.dart';

class AppointmentStatusBadge extends StatelessWidget {
  final String status;
  final bool isSmall;

  const AppointmentStatusBadge({
    super.key,
    required this.status,
    this.isSmall = false,
  });

  Color get _backgroundColor {
    switch (status) {
      case 'pending':
        return Colors.orange.withValues(alpha: 0.2);
      case 'confirmed':
        return Colors.blue.withValues(alpha: 0.2);
      case 'completed':
        return Colors.green.withValues(alpha: 0.2);
      case 'cancelled':
        return Colors.red.withValues(alpha: 0.2);
      case 'no_show':
        return Colors.redAccent.withValues(alpha: 0.2);
      case 'rescheduled':
        return Colors.purple.withValues(alpha: 0.2);
      default:
        return Colors.grey.withValues(alpha: 0.2);
    }
  }

  Color get _textColor {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'no_show':
        return Colors.redAccent;
      case 'rescheduled':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String get _displayName {
    final statusEnum = AppointmentStatusExtension.fromString(status);
    return statusEnum.displayName;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 8 : 10,
        vertical: isSmall ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _displayName,
        style: TextStyle(
          fontSize: isSmall ? 11 : 12,
          fontWeight: FontWeight.w600,
          color: _textColor,
        ),
      ),
    );
  }
}
