import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import '../features/meter/providers/meter_provider.dart';
import '../core/widgets/halide_scaffold.dart';
import '../core/widgets/glass_panel.dart';

class MeterView extends ConsumerStatefulWidget {
  const MeterView({Key? key}) : super(key: key);

  @override
  ConsumerState<MeterView> createState() => _MeterViewState();
}

class _MeterViewState extends ConsumerState<MeterView> {
  CameraController? _controller;
  bool _isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    _setupCamera();
  }

  Future<void> _setupCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _controller = CameraController(
      cameras[0],
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Camera initialization error: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _handleLockToggle() {
    HapticFeedback.mediumImpact();
    ref.read(meterProvider.notifier).toggleLock();
  }

  Future<void> _showIsoPicker() async {
    final current = ref.read(meterProvider);
    final isoStops = <double>[25, 50, 100, 200, 400, 800, 1600, 3200, 6400];
    double selected = current.iso;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF09090B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'ISO',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: isoStops.map((v) {
                  final isSelected = v == selected;
                  return InkWell(
                    onTap: () {
                      setState(() => selected = v);
                      ref.read(meterProvider.notifier).updateISO(v);
                    },
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFF97316).withOpacity(0.18) : Colors.white10,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFF97316) : Colors.white.withOpacity(0.10),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFFF97316).withOpacity(0.30),
                                  spreadRadius: 2,
                                  blurRadius: 15,
                                ),
                              ]
                            : const [],
                      ),
                      child: Text(
                        v.toStringAsFixed(0),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white.withOpacity(0.75),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Text(
                'Changes will update EV and the computed exposure.',
                style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showEvPicker() async {
    final current = ref.read(meterProvider);
    double comp = current.evComp;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF09090B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'EV',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Compensation: ${comp >= 0 ? '+' : ''}${comp.toStringAsFixed(1)}',
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Slider(
                    value: comp,
                    min: -5,
                    max: 5,
                    divisions: 100,
                    activeColor: const Color(0xFFF97316),
                    inactiveColor: Colors.white12,
                    onChanged: (v) {
                      setModalState(() => comp = v);
                      ref.read(meterProvider.notifier).updateEVComp(v);
                    },
                  ),
                  const SizedBox(height: 6),
                  OutlinedButton(
                    onPressed: () {
                      setModalState(() => comp = 0);
                      ref.read(meterProvider.notifier).updateEVComp(0);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white.withOpacity(0.8),
                      side: BorderSide(color: Colors.white.withOpacity(0.12)),
                      backgroundColor: Colors.white10,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('RESET'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showAperturePicker() async {
    final current = ref.read(meterProvider);
    final stops = <double>[1.4, 2.0, 2.8, 4.0, 5.6, 8.0, 11.0, 16.0, 22.0];
    double selected = current.aperture;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF09090B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'APERTURE',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: stops.map((v) {
                  final isSelected = v == selected;
                  return InkWell(
                    onTap: () {
                      setState(() => selected = v);
                      ref.read(meterProvider.notifier).updateAperture(v);
                    },
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFF97316).withOpacity(0.18) : Colors.white10,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFF97316) : Colors.white.withOpacity(0.10),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFFF97316).withOpacity(0.30),
                                  spreadRadius: 2,
                                  blurRadius: 15,
                                ),
                              ]
                            : const [],
                      ),
                      child: Text(
                        'f/${v.toStringAsFixed(v == 2.0 ? 0 : 1)}',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white.withOpacity(0.75),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showShutterPicker() async {
    final current = ref.read(meterProvider);
    // seconds; includes common 1/x speeds and a few long exposures
    final speeds = <double>[
      1 / 4000,
      1 / 2000,
      1 / 1000,
      1 / 500,
      1 / 250,
      1 / 125,
      1 / 60,
      1 / 30,
      1 / 15,
      1 / 8,
      1 / 4,
      1 / 2,
      1,
      2,
      4,
      8,
      15,
      30,
    ];
    double selected = current.shutterSpeed;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF09090B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'SHUTTER SPEED',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: speeds.map((v) {
                  final isSelected = (v - selected).abs() < 1e-9;
                  return InkWell(
                    onTap: () {
                      setState(() => selected = v);
                      ref.read(meterProvider.notifier).updateShutterSpeed(v);
                    },
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFF97316).withOpacity(0.18) : Colors.white10,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFF97316) : Colors.white.withOpacity(0.10),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFFF97316).withOpacity(0.30),
                                  spreadRadius: 2,
                                  blurRadius: 15,
                                ),
                              ]
                            : const [],
                      ),
                      child: Text(
                        _formatShutterSpeed(v),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white.withOpacity(0.75),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final meterState = ref.watch(meterProvider);

    return HalideScaffold(
      appBar: AppBar(
        title: const Text(
          'PRECISION METER',
          style: TextStyle(
            letterSpacing: 2,
            fontWeight: FontWeight.w300,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      child: Stack(
        children: [
          // Camera Viewfinder
          if (_isCameraInitialized)
            Positioned.fill(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: CameraPreview(_controller!),
              ),
            )
          else
            const Center(child: CircularProgressIndicator()),

          // Spot Metering Target
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                border: Border.all(
                  color: meterState.isLocked ? Colors.orangeAccent : Colors.white54,
                  width: 1,
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: Colors.white54,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),

          // Bottom Overlay
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: GlassPanel(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _infoColumn('LUX', meterState.lux.toStringAsFixed(0)),
                        _infoColumn('EV', meterState.ev.toStringAsFixed(1), onTap: _showEvPicker),
                        _infoColumn('ISO', meterState.iso.toStringAsFixed(0), onTap: _showIsoPicker),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _valueColumn('f/', meterState.aperture.toStringAsFixed(1), onTap: _showAperturePicker),
                        _valueColumn('SS', _formatShutterSpeed(meterState.shutterSpeed), onTap: _showShutterPicker),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _handleLockToggle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: meterState.isLocked ? Colors.orangeAccent : Colors.white10,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Text(
                        meterState.isLocked ? 'UNLOCK' : 'LOCK EXPOSURE',
                        style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoColumn(String label, String value, {VoidCallback? onTap}) {
    final child = Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w300)),
      ],
    );
    if (onTap == null) return child;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: child,
      ),
    );
  }

  Widget _valueColumn(String prefix, String value, {VoidCallback? onTap}) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(prefix, style: const TextStyle(color: Colors.blueAccent, fontSize: 14, fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w200)),
      ],
    );
    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: row,
      ),
    );
  }

  String _formatShutterSpeed(double ss) {
    if (ss >= 1) return ss.toStringAsFixed(1) + 's';
    return '1/${(1 / ss).toStringAsFixed(0)}';
  }
}
