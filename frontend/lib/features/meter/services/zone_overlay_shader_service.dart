import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// Loads and configures the GPU zone-overlay fragment shader (Impeller / ImageFilter).
class ZoneOverlayShaderService {
  ZoneOverlayShaderService._();

  static final ZoneOverlayShaderService instance = ZoneOverlayShaderService._();

  ui.FragmentProgram? _program;
  bool _loadFailed = false;

  Future<bool> ensureLoaded() async {
    if (_program != null) return true;
    if (_loadFailed) return false;
    try {
      _program = await ui.FragmentProgram.fromAsset('shaders/zone_overlay.frag');
      return true;
    } catch (e) {
      _loadFailed = true;
      debugPrint('[ZoneOverlayShader] load failed: $e');
      return false;
    }
  }

  /// Creates a configured [ui.FragmentShader] for [ui.ImageFilter.shader].
  ///
  /// Uniform layout (ImageFilter convention):
  ///   0–1: vec2 u_size (engine)
  ///   sampler: u_texture (engine)
  ///   2: u_ev_target
  ///   3: u_ev_anchor
  ///   4: u_anchor_luminance
  ui.FragmentShader? createConfiguredShader({
    required double evTarget,
    required double evAnchor,
    required double anchorLuminance,
  }) {
    final program = _program;
    if (program == null) return null;
    final shader = program.fragmentShader();
    shader.setFloat(2, evTarget);
    shader.setFloat(3, evAnchor);
    shader.setFloat(4, anchorLuminance.clamp(0.001, 1.0));
    return shader;
  }

  bool get isAvailable => _program != null;
}
