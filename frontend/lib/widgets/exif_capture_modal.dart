import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../core/widgets/glass_panel.dart';

class ExifCaptureModal extends StatefulWidget {
  final Function(double aperture, String shutterSpeed, double lat, double lng) onLog;

  const ExifCaptureModal({Key? key, required this.onLog}) : super(key: key);

  @override
  State<ExifCaptureModal> createState() => _ExifCaptureModalState();
}

class _ExifCaptureModalState extends State<ExifCaptureModal> {
  final List<double> _apertures = [
    0.9, 1.2, 1.4, 1.7, 1.8, 2.0, 2.4, 2.8, 3.5, 4.0, 4.5, 5.6, 6.7, 8.0, 11, 16, 22
  ];
  final List<String> _shutterSpeeds = [
    '1/4000', '1/2000', '1/1000', '1/500', '1/250', '1/125', '1/60', '1/30', '1/15', '1/8', '1/4', '1/2', '1s'
  ];

  int _apertureIndex = 2; // Default 1.4
  int _shutterIndex = 3;  // Default 1/500

  double _lat = 0.0;
  double _lng = 0.0;
  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    setState(() => _isLoadingLocation = true);

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Location services are disabled.';
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions are denied';
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw 'Location permissions are permanently denied.';
      } 

      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _lat = position.latitude;
          _lng = position.longitude;
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D0D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 24),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('RECORD SHOT', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white54)),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Aperture Mimic & Value
          Row(
            children: [
              // Visual Aperture
              SizedBox(
                width: 100,
                height: 100,
                child: CustomPaint(
                  painter: AperturePainter(
                    aperture: _apertures[_apertureIndex],
                    maxAperture: _apertures.first,
                    minAperture: _apertures.last,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('APERTURE', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('f/${_apertures[_apertureIndex]}', style: const TextStyle(color: Colors.orange, fontSize: 32, fontWeight: FontWeight.w200, fontFamily: 'monospace')),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Aperture Slider
          SliderTheme(
            data: _sliderTheme(context),
            child: Slider(
              value: _apertureIndex.toDouble(),
              min: 0,
              max: (_apertures.length - 1).toDouble(),
              divisions: _apertures.length - 1,
              onChanged: (val) {
                HapticFeedback.selectionClick();
                setState(() => _apertureIndex = val.toInt());
              },
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Shutter Speed
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('SHUTTER SPEED', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
              Text(_shutterSpeeds[_shutterIndex], style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: _sliderTheme(context),
            child: Slider(
              value: _shutterIndex.toDouble(),
              min: 0,
              max: (_shutterSpeeds.length - 1).toDouble(),
              divisions: _shutterSpeeds.length - 1,
              onChanged: (val) {
                HapticFeedback.selectionClick();
                setState(() => _shutterIndex = val.toInt());
              },
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Meta info (Location & Time)
          GlassPanel(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.location_on_outlined, size: 16, color: Colors.white.withOpacity(0.4)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isLoadingLocation ? 'Locating...' : '${_lat.toStringAsFixed(4)}, ${_lng.toStringAsFixed(4)}',
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12, fontFamily: 'monospace'),
                  ),
                ),
                Icon(Icons.access_time, size: 16, color: Colors.white.withOpacity(0.4)),
                const SizedBox(width: 8),
                Text(
                  TimeOfDay.now().format(context),
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 40),
          
          // Submit Button
          SizedBox(
            height: 60,
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                widget.onLog(
                  _apertures[_apertureIndex],
                  _shutterSpeeds[_shutterIndex],
                  _lat,
                  _lng,
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text('LOG SHOT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 2)),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  SliderThemeData _sliderTheme(BuildContext context) {
    return SliderTheme.of(context).copyWith(
      activeTrackColor: Colors.orange.withOpacity(0.8),
      inactiveTrackColor: Colors.white10,
      trackHeight: 2.0,
      thumbColor: Colors.white,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10, elevation: 4),
      overlayColor: Colors.orange.withOpacity(0.2),
      tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 1),
      activeTickMarkColor: Colors.orange,
      inactiveTickMarkColor: Colors.white24,
    );
  }
}

class AperturePainter extends CustomPainter {
  final double aperture;
  final double maxAperture;
  final double minAperture;

  AperturePainter({
    required this.aperture,
    required this.maxAperture,
    required this.minAperture,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    // Scale factor: f/0.9 (open) -> 1.0, f/22 (closed) -> 0.1
    // Diagram shows f/1.4 is very wide, f/22 is very narrow.
    final t = (log(aperture) - log(minAperture)) / (log(maxAperture) - log(minAperture));
    final openFactor = 0.15 + (0.8 * t); // Adjust range for better visual matching
    final holeRadius = radius * openFactor;

    final bladePaint = Paint()
      ..color = const Color(0xFF1E1E1E)
      ..style = PaintingStyle.fill;
    
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Draw background outer ring
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF0A0A0A));
    canvas.drawCircle(center, radius, borderPaint);

    const int numBlades = 6;
    final double angleStep = (2 * pi) / numBlades;
    
    // The "tangent angle" offset determines how much the blades overlap/tilt
    // To form a hexagon with holeRadius, the tangent lines are at distance holeRadius from center.
    for (int i = 0; i < numBlades; i++) {
      final double angle = i * angleStep;
      
      final path = Path();
      
      // Point 1: On the outer circle at current angle
      final p1 = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
      
      // Point 2: On the outer circle at next angle (plus some over-extension for overlap)
      final p2 = Offset(
        center.dx + radius * cos(angle + angleStep * 1.5),
        center.dy + radius * sin(angle + angleStep * 1.5),
      );
      
      // Point 3: The magic point. It's the intersection of the tangent line 
      // of this blade and the tangent line of the PREVIOUS blade.
      // A simpler approximation that looks like the diagram:
      // Construct a line segment that is tangent to the inner holeRadius.
      
      // Start of the straight edge (tangent point or near it)
      final pTangent = Offset(
        center.dx + holeRadius * cos(angle + angleStep * 0.5),
        center.dy + holeRadius * sin(angle + angleStep * 0.5),
      );
      
      // We want a line that passes through pTangent and is perpendicular to the radius at that point.
      final double tangentAngle = angle + angleStep * 0.5 + pi / 2;
      final double lineLength = radius * 2;
      
      final pEdgeStart = Offset(
        pTangent.dx + lineLength * cos(tangentAngle),
        pTangent.dy + lineLength * sin(tangentAngle),
      );
      final pEdgeEnd = Offset(
        pTangent.dx - lineLength * cos(tangentAngle),
        pTangent.dy - lineLength * sin(tangentAngle),
      );

      // We clip this blade path against the outer circle
      path.moveTo(p1.dx, p1.dy);
      path.lineTo(p2.dx, p2.dy);
      path.lineTo(pEdgeStart.dx, pEdgeStart.dy);
      path.lineTo(pEdgeEnd.dx, pEdgeEnd.dy);
      path.close();

      canvas.save();
      // Clip to the outer circle
      canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)));
      canvas.drawPath(path, bladePaint);
      canvas.drawPath(path, borderPaint);
      canvas.restore();
    }
    
    // Draw the clear hexagonal hole border if narrow
    final holePath = Path();
    for (int i = 0; i <= numBlades; i++) {
      final double angle = i * angleStep + angleStep * 0.5;
      // The distance to vertex of hexagon to have in-circle of holeRadius is holeRadius / cos(pi/6)
      final double rVertex = holeRadius / cos(pi / numBlades);
      final p = Offset(
        center.dx + rVertex * cos(angle),
        center.dy + rVertex * sin(angle),
      );
      if (i == 0) holePath.moveTo(p.dx, p.dy); else holePath.lineTo(p.dx, p.dy);
    }
    
    // Clear inner hole
    canvas.drawPath(holePath, Paint()..blendMode = BlendMode.clear);
    
    // Aesthetic orange inner glow/border
    canvas.drawPath(
      holePath, 
      Paint()
        ..color = Colors.orange.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
    );
  }

  @override
  bool shouldRepaint(covariant AperturePainter oldDelegate) => oldDelegate.aperture != aperture;
}
