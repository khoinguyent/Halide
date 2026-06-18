import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../core/widgets/glass_panel.dart';
import 'aperture_diagram.dart';
import 'aperture_slider_control.dart';

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

          ApertureSliderControl(
            apertures: _apertures,
            value: _apertures[_apertureIndex],
            onChanged: (v) {
              final i = nearestApertureIndex(_apertures, v);
              setState(() => _apertureIndex = i);
            },
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
            data: halideApertureSliderTheme(context),
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

}
