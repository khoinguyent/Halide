import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:frontend/core/l10n/enum_l10n.dart';
import 'package:frontend/core/l10n/l10n_extension.dart';
import '../core/widgets/glass_panel.dart';
import 'aperture_diagram.dart';
import 'aperture_slider_control.dart';

const int kShotNotesMaxLength = 500;

class ExifCaptureModal extends StatefulWidget {
  final Future<void> Function(
    double aperture,
    String shutterSpeed,
    double lat,
    double lng,
    String? notes,
  ) onLog;

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
  bool _isSubmitting = false;
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
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

  String? _trimmedNotes() {
    final t = _notesController.text.trim();
    if (t.isEmpty) return null;
    return t.length > kShotNotesMaxLength ? t.substring(0, kShotNotesMaxLength) : t;
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    HapticFeedback.mediumImpact();
    setState(() => _isSubmitting = true);
    try {
      await widget.onLog(
        _apertures[_apertureIndex],
        _shutterSpeeds[_shutterIndex],
        _lat,
        _lng,
        _trimmedNotes(),
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0D0D0D),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
        ),
        padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottomPadding),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    halideCaps(l10n.recordShot),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white54),
                  ),
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

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    halideCaps(l10n.shutterSpeed),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 10,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _shutterSpeeds[_shutterIndex],
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                  ),
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

              const SizedBox(height: 24),

              GlassPanel(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 16, color: Colors.white.withValues(alpha: 0.4)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isLoadingLocation
                            ? l10n.loading
                            : '${_lat.toStringAsFixed(4)}, ${_lng.toStringAsFixed(4)}',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                      ),
                    ),
                    Icon(Icons.access_time, size: 16, color: Colors.white.withValues(alpha: 0.4)),
                    const SizedBox(width: 8),
                    Text(
                      TimeOfDay.now().format(context),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Text(
                halideCaps(l10n.shotNotesLabel),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                maxLength: kShotNotesMaxLength,
                maxLines: 3,
                minLines: 2,
                textInputAction: TextInputAction.done,
                style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.35),
                cursorColor: Colors.orange,
                decoration: InputDecoration(
                  hintText: l10n.shotNotesHint,
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.28), fontSize: 13),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  counterStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 11),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Colors.orange, width: 1.2),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                height: 60,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: Colors.orange.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : Text(
                          halideCaps(l10n.logShot),
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 2),
                        ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
