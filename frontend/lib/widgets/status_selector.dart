import 'package:flutter/material.dart';
import '../models/roll_status.dart';

class StatusSelector extends StatefulWidget {
  final RollStatus currentStatus;
  final Future<bool> Function(RollStatus) onStatusSelected;

  const StatusSelector({
    super.key,
    required this.currentStatus,
    required this.onStatusSelected,
  });

  @override
  State<StatusSelector> createState() => _StatusSelectorState();
}

class _StatusSelectorState extends State<StatusSelector> {
  bool _isBusy = false;

  /// User-pickable lifecycle (syncing is system-only during Drive import).
  static const List<RollStatus> _userStatuses = [
    RollStatus.shooting,
    RollStatus.lab,
    RollStatus.scanned,
    RollStatus.archived,
  ];

  /// Index in [_userStatuses] for forward-only picks; syncing can advance to Scanned+.
  static int _forwardStartIndex(RollStatus current) {
    if (current == RollStatus.syncing) {
      return _userStatuses.indexOf(RollStatus.scanned);
    }
    final i = _userStatuses.indexOf(current);
    return i >= 0 ? i : 0;
  }

  @override
  Widget build(BuildContext context) {
    final startIndex = _forwardStartIndex(widget.currentStatus);
    final allowedStatuses = _userStatuses
        .where((s) => _userStatuses.indexOf(s) >= startIndex)
        .toList();

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
            final isSelected = status == widget.currentStatus;
            return ListTile(
              title: Text(status.label),
              trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
              onTap: () async {
                if (_isBusy) return;
                setState(() => _isBusy = true);
                try {
                  final success = await widget.onStatusSelected(status);
                  if (!mounted) return;
                  if (success) {
                    Navigator.of(context).pop();
                  } else {
                    setState(() => _isBusy = false);
                  }
                } catch (_) {
                  if (mounted) setState(() => _isBusy = false);
                }
              },
            );
          }),
          const SizedBox(height: 16),
          if (_isBusy)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }
}
