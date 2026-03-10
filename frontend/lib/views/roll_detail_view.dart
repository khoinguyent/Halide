import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/roll_provider.dart';
import '../widgets/status_selector.dart';
import '../models/roll_status.dart';

class RollDetailView extends ConsumerWidget {
  final String rollId;

  const RollDetailView({Key? key, required this.rollId}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roll = ref.watch(rollProvider(rollId));

    return Scaffold(
      appBar: AppBar(
        title: Text('Roll Detail - ${roll.brand} ${roll.name}'),
        backgroundColor: roll.color.withOpacity(0.2),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Status: ${roll.status.label}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (context) => StatusSelector(
                    currentStatus: roll.status,
                    onStatusSelected: (newStatus) {
                      ref.read(rollProvider(rollId).notifier).updateStatus(newStatus);
                    },
                  ),
                );
              },
              icon: const Icon(Icons.edit),
              label: const Text('Change Status'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
