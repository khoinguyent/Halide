import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../services/zone_overlay_shader_service.dart';

/// GPU false-color zone overlay via [BackdropFilter] + fragment shader.
///
/// Samples the live camera preview behind this layer (60 FPS on Impeller).
class ZoneOverlayShaderLayer extends StatefulWidget {
  final double evTarget;
  final double evAnchor;
  final double anchorLuminance;
  final Widget? cpuFallback;

  const ZoneOverlayShaderLayer({
    super.key,
    required this.evTarget,
    required this.evAnchor,
    required this.anchorLuminance,
    this.cpuFallback,
  });

  @override
  State<ZoneOverlayShaderLayer> createState() => _ZoneOverlayShaderLayerState();
}

class _ZoneOverlayShaderLayerState extends State<ZoneOverlayShaderLayer> {
  bool _shaderReady = false;
  bool _shaderFailed = false;

  @override
  void initState() {
    super.initState();
    _loadShader();
  }

  Future<void> _loadShader() async {
    final ok = await ZoneOverlayShaderService.instance.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _shaderReady = ok;
      _shaderFailed = !ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_shaderFailed) {
      return widget.cpuFallback ?? const SizedBox.shrink();
    }
    if (!_shaderReady) {
      return const SizedBox.shrink();
    }

    final shader = ZoneOverlayShaderService.instance.createConfiguredShader(
      evTarget: widget.evTarget,
      evAnchor: widget.evAnchor,
      anchorLuminance: widget.anchorLuminance,
    );
    if (shader == null) {
      return widget.cpuFallback ?? const SizedBox.shrink();
    }

    try {
      final filter = ImageFilter.shader(shader);
      return ClipRect(
        child: BackdropFilter(
          filter: filter,
          child: const ColoredBox(color: Colors.transparent),
        ),
      );
    } catch (e) {
      debugPrint('[ZoneOverlayShaderLayer] ImageFilter.shader unsupported: $e');
      return widget.cpuFallback ?? const SizedBox.shrink();
    }
  }
}
