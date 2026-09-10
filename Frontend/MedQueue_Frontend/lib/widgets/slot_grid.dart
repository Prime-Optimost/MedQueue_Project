import 'package:flutter/material.dart';
import '../models/time_slot_model.dart';

class SlotGrid extends StatelessWidget {
  final List<TimeSlot> slots;
  final TimeSlot? selectedSlot;
  final ValueChanged<TimeSlot> onSlotSelected;
  final bool crossAxisCount3;

  const SlotGrid({
    super.key,
    required this.slots,
    required this.onSlotSelected,
    this.selectedSlot,
    this.crossAxisCount3 = true,
  });

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No available slots for this date',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount3 ? 3 : 2,
        childAspectRatio: 2.5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: slots.length,
      itemBuilder: (context, index) {
        final slot = slots[index];
        final isSelected = selectedSlot?.id == slot.id;
        final isAvailable = slot.isAvailable;
        final isPast = slot.isPast;
        final enabled = isAvailable && !isPast;

        return SlotCard(
          slot: slot,
          isSelected: isSelected,
          isAvailable: isAvailable,
          isPast: isPast,
          onTap: enabled
              ? () {
                  onSlotSelected(slot);
                }
              : null,
        );
      },
    );
  }
}

class SlotCard extends StatelessWidget {
  final TimeSlot slot;
  final bool isSelected;
  final bool isAvailable;
  final bool isPast;
  final VoidCallback? onTap;

  const SlotCard({
    super.key,
    required this.slot,
    required this.isSelected,
    required this.isAvailable,
    this.isPast = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue
              : isPast
                  ? Colors.grey.shade200
                  : isAvailable
                      ? Colors.grey.shade100
                      : Colors.grey.shade300,
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              slot.startTime,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: isSelected
                    ? Colors.white
                    : isPast
                        ? Colors.grey
                        : isAvailable
                            ? Colors.black87
                            : Colors.grey,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              slot.endTime,
              style: TextStyle(
                fontSize: 11,
                color: isSelected
                    ? Colors.white70
                    : isPast
                        ? Colors.grey
                        : isAvailable
                            ? Colors.grey
                            : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// List view version of slot selection
class SlotListView extends StatelessWidget {
  final List<TimeSlot> slots;
  final TimeSlot? selectedSlot;
  final ValueChanged<TimeSlot> onSlotSelected;

  const SlotListView({
    super.key,
    required this.slots,
    required this.onSlotSelected,
    this.selectedSlot,
  });

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No available slots for this date',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: slots.length,
      itemBuilder: (context, index) {
        final slot = slots[index];
        final isSelected = selectedSlot?.id == slot.id;
        final isAvailable = slot.isAvailable;
        final isPast = slot.isPast;
        final enabled = isAvailable && !isPast;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: InkWell(
            onTap: enabled
                ? () {
                    onSlotSelected(slot);
                  }
                : null,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.blue.shade50
                    : isPast
                        ? Colors.grey.shade100
                        : isAvailable
                            ? Colors.white
                            : Colors.grey.shade100,
                border: Border.all(
                  color: isSelected ? Colors.blue : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${slot.startTime} - ${slot.endTime}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: isPast
                              ? Colors.grey
                              : isAvailable
                                  ? Colors.black87
                                  : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isPast
                            ? 'Past'
                            : isAvailable
                                ? 'Available'
                                : 'Booked',
                        style: TextStyle(
                          fontSize: 12,
                          color: isPast
                              ? Colors.grey
                              : isAvailable
                                  ? Colors.green
                                  : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle, color: Colors.blue)
                  else if (!isAvailable)
                    const Icon(Icons.lock_outline, color: Colors.grey),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
