import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'aperture_diagram.dart';

/// Aperture iris preview + f-stop readout + stepped slider (roll EXIF log style).
class ApertureSliderControl extends StatefulWidget {
  final List<double> apertures;
  final double value;
  final ValueChanged<double> onChanged;

  const ApertureSliderControl({
    super.key,
    required this.apertures,
    required this.value,
    required this.onChanged,
  });

  @override
  State<ApertureSliderControl> createState() => _ApertureSliderControlState();
}

class _ApertureSliderControlState extends State<ApertureSliderControl> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = nearestApertureIndex(widget.apertures, widget.value);
  }

  @override
  void didUpdateWidget(covariant ApertureSliderControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value || oldWidget.apertures != widget.apertures) {
      _index = nearestApertureIndex(widget.apertures, widget.value);
    }
  }

  double get _aperture => widget.apertures[_index];

  void _setIndex(int index) {
    if (index == _index) return;
    setState(() => _index = index);
    HapticFeedback.selectionClick();
    widget.onChanged(widget.apertures[index]);
  }

  @override
  Widget build(BuildContext context) {
    final stops = widget.apertures;
    if (stops.isEmpty) return const SizedBox.shrink();

    final maxAperture = stops.first;
    final minAperture = stops.last;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: CustomPaint(
                painter: AperturePainter(
                  aperture: _aperture,
                  maxAperture: maxAperture,
                  minAperture: minAperture,
                ),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'APERTURE',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 10,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'f/${formatApertureFStop(_aperture)}',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 32,
                      fontWeight: FontWeight.w200,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SliderTheme(
          data: halideApertureSliderTheme(context),
          child: Slider(
            value: _index.toDouble(),
            min: 0,
            max: (stops.length - 1).toDouble(),
            divisions: stops.length > 1 ? stops.length - 1 : null,
            onChanged: stops.length <= 1 ? null : (val) => _setIndex(val.round()),
          ),
        ),
      ],
    );
  }
}
