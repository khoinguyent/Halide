import 'package:flutter/material.dart';

import '../../../../core/widgets/glass_panel.dart';
import '../../logic/advanced_spot_metering_engine.dart';

/// Short Zone System guide shown from the legend help button.
void showZoneOverlayHelpSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          MediaQuery.paddingOf(ctx).bottom + 12,
        ),
        child: GlassPanel(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          borderRadius: 24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'ZONE OVERLAY',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Colors show how bright each part of the scene is compared to your EV target. '
                'Green (Zone V) is middle gray at that exposure.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(ctx).height * 0.42,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (var i = 0; i < _zoneHelp.length; i++)
                        _ZoneHelpRow(
                          color: AdvancedSpotMeteringEngine.zoneColors[i],
                          label: _zoneHelp[i].$1,
                          meaning: _zoneHelp[i].$2,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Tip: Lock exposure, then scan the frame — keep important tones out of deep violet (Zone 0) and bright red (Zone X) unless you want blocked shadows or blown highlights.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

const _zoneHelp = <(String, String)>[
  ('0', 'Pure black — no detail'),
  ('I', 'Very deep shadow'),
  ('II', 'Deep shadow, slight texture'),
  ('III', 'Dark tones with clear texture'),
  ('IV', 'Dark foliage, shadow skin'),
  ('V', 'Middle gray — your EV target'),
  ('VI', 'Light skin, light stone'),
  ('VII', 'Very light skin, bright snow'),
  ('VIII', 'Bright snow, white objects'),
  ('IX', 'Near paper white'),
  ('X', 'Specular highlights, pure white'),
];

class _ZoneHelpRow extends StatelessWidget {
  final Color color;
  final String label;
  final String meaning;

  const _ZoneHelpRow({
    required this.color,
    required this.label,
    required this.meaning,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 14,
            height: 14,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: Colors.white24),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 28,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              meaning,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
