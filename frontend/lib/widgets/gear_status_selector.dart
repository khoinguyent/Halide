import 'package:flutter/material.dart';
import '../models/gear_status.dart';

class GearStatusSelector extends StatelessWidget {
  final GearStatus currentStatus;
  final Function(GearStatus) onStatusSelected;

  const GearStatusSelector({
    super.key,
    required this.currentStatus,
    required this.onStatusSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Update Gear Status',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Mark this gear as Active, In Repair, or Sold so you can filter and track it.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ...GearStatus.values.map((status) {
            final isSelected = status == currentStatus;
            return ListTile(
              title: Text(status.label),
              trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
              onTap: () {
                onStatusSelected(status);
              },
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
