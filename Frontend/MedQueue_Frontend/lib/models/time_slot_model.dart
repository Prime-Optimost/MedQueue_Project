import '../utils/type_helpers.dart';

/// Slot status enum matching backend values
enum SlotStatus { available, booked, blocked }

extension SlotStatusExtension on SlotStatus {
  String get value {
    switch (this) {
      case SlotStatus.available:
        return 'available';
      case SlotStatus.booked:
        return 'booked';
      case SlotStatus.blocked:
        return 'blocked';
    }
  }

  static SlotStatus fromString(String value) {
    return SlotStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => SlotStatus.available,
    );
  }
}

class TimeSlot {
  final int id;
  final String date;
  final String startTime;
  final String endTime;
  final String status;
  final bool isAvailable;

  TimeSlot({
    required this.id,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.isAvailable,
  });

  SlotStatus get statusEnum => SlotStatusExtension.fromString(status);

  bool get isPast {
    try {
      final slotDateTime =
          DateTime.parse('$date ${startTime.padLeft(8, '0')}');
      return slotDateTime.isBefore(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  bool get isToday {
    try {
      final today = DateTime.now();
      final slotDate = DateTime.parse(date);
      return slotDate.day == today.day &&
          slotDate.month == today.month &&
          slotDate.year == today.year;
    } catch (e) {
      return false;
    }
  }

  factory TimeSlot.fromJson(Map<String, dynamic> json) {
    return TimeSlot(
      id: TypeHelpers.toInt(json['id']),
      date: json['date'] as String? ?? '',
      startTime: json['start_time'] as String? ?? '',
      endTime: json['end_time'] as String? ?? '',
      status: json['status'] as String? ?? 'available',
      isAvailable: json['is_available'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'start_time': startTime,
        'end_time': endTime,
        'status': status,
        'is_available': isAvailable,
      };
}
