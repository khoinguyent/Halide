import 'package:flutter/material.dart';
import '../models/roll_status.dart';

class StatusSelector extends StatelessWidget {
  final RollStatus currentStatus;
  final Future<bool> Function(RollStatus) onStatusSelected;

  const StatusSelector({
    super.key,
    required this.currentStatus,
    required this.onStatusSelected,
  });

  @override
  Widget build(BuildContext context) {
    final steps = RollStatus.values;
    final currentIndex = steps.indexOf(currentStatus);
    final allowedStatuses = (currentIndex >= 0)
        ? steps.where((s) => steps.indexOf(s) >= currentIndex).toList()
        : steps;

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
            'Update Roll Status',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ...allowedStatuses.map((status) {
            final isSelected = status == currentStatus;
            return ListTile(
              title: Text(status.label),
              trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
              onTap: () async {
                final success = await onStatusSelected(status);
                if (!context.mounted) return;
                if (success) Navigator.pop(context);
              },
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
