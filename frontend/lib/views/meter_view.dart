import 'package:flutter/material.dart';
import '../core/widgets/halide_scaffold.dart';
import '../core/widgets/glass_panel.dart';

class MeterView extends StatelessWidget {
  const MeterView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return HalideScaffold(
      appBar: AppBar(
        title: const Text(
          'LIGHT METER',
          style: TextStyle(
            letterSpacing: 2,
            fontWeight: FontWeight.w300,
            fontSize: 24,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: GlassPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.light_mode_outlined, size: 64, color: Colors.white24),
                SizedBox(height: 20),
                Text(
                  'Precision Metering',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'The AI-powered light meter is currently being calibrated.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
                SizedBox(height: 24),
                Text(
                  'COMING SOON',
                  style: TextStyle(
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
