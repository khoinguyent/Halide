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
                        _infoColumn('EV', meterState.ev.toStringAsFixed(1)),
                        _infoColumn('ISO', meterState.iso.toStringAsFixed(0)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _valueColumn('f/', meterState.aperture.toStringAsFixed(1)),
                        _valueColumn('SS', _formatShutterSpeed(meterState.shutterSpeed)),
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

  Widget _infoColumn(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w300)),
      ],
    );
  }

  Widget _valueColumn(String prefix, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(prefix, style: const TextStyle(color: Colors.blueAccent, fontSize: 14, fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w200)),
      ],
    );
  }

  String _formatShutterSpeed(double ss) {
    if (ss >= 1) return ss.toStringAsFixed(1) + 's';
    return '1/${(1 / ss).toStringAsFixed(0)}';
  }
}
