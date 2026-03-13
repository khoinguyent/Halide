import 'package:flutter/material.dart';
import '../core/widgets/halide_scaffold.dart';
import '../core/widgets/glass_panel.dart';

class LockerView extends StatelessWidget {
  const LockerView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return HalideScaffold(
      appBar: AppBar(
        title: const Text(
          'YOUR LOCKER',
          style: TextStyle(
            letterSpacing: 2,
            fontWeight: FontWeight.w300,
            fontSize: 24,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: const [
          _GearCard(
            nickname: 'Main Shooter',
            model: 'Leica M6',
            serial: '2468135',
          ),
          SizedBox(height: 20),
          _GearCard(
            nickname: 'Pocket Beast',
            model: 'Contax T2',
            serial: '9876543',
          ),
          SizedBox(height: 40),
          _ComingSoonCard(title: 'Lenses'),
        ],
      ),
    );
  }
}

class _GearCard extends StatelessWidget {
  final String nickname;
  final String model;
  final String serial;

  const _GearCard({
    Key? key,
    required this.nickname,
    required this.model,
    required this.serial,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.camera_alt_outlined, color: Colors.white54),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nickname,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                model,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                'S/N: $serial',
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ComingSoonCard extends StatelessWidget {
  final String title;

  const _ComingSoonCard({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.6,
      child: GlassPanel(
        child: Center(
          child: Column(
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Coming Soon',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
