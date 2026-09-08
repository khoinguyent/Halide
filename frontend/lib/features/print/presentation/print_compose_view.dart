import 'dart:async' show unawaited;
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:frontend/core/l10n/enum_l10n.dart';
import 'package:frontend/core/l10n/l10n_extension.dart';
import 'package:frontend/core/models/notification_model.dart';
import 'package:frontend/core/providers/notification_provider.dart';
import 'package:frontend/core/theme/halide_colors.dart';
import 'package:frontend/features/print/presentation/print_stamp.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/services/guidance_service.dart';
import 'package:frontend/services/local_sync_service.dart';
import 'package:frontend/services/print_service.dart';
import 'package:frontend/widgets/guidance/lab_drive_sync_guidance.dart';
import 'package:frontend/widgets/synced_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Instagram-style compose: fullscreen photo, flip to verso, place multiple
/// draggable text stickers, pinch to resize, bold/italic.
class PrintComposeView extends ConsumerStatefulWidget {
  const PrintComposeView({
    super.key,
    required this.rollId,
    required this.imageId,
    required this.imageUrl,
  });

  final String rollId;
  final String imageId;
  final String imageUrl;

  @override
  ConsumerState<PrintComposeView> createState() => _PrintComposeViewState();
}

class _TextSticker {
  _TextSticker({
    required this.id,
    this.text = '',
    this.fontFamily = 'hand',
    this.bold = false,
    this.italic = false,
    this.fontSize = 14,
    this.color = const Color(0xFF2C2416),
    this.align = TextAlign.center,
    this.posX = 0.5,
    this.posY = 0.42,
  });

  final String id;
  String text;
  String fontFamily;
  bool bold;
  bool italic;
  double fontSize;
  Color color;
  TextAlign align;
  double posX;
  double posY;

  String get encodedFontStyle {
    final parts = <String>[fontFamily];
    if (bold) parts.add('b');
    if (italic) parts.add('i');
    return parts.join('_');
  }

  String get _colorHex {
    final v = color.toARGB32() & 0xFFFFFF;
    return '#${v.toRadixString(16).padLeft(6, '0')}';
  }

  String get _alignApi => switch (align) {
        TextAlign.left => 'left',
        TextAlign.right => 'right',
        _ => 'center',
      };

  Map<String, dynamic> toApi() => {
        'text': text.trim(),
        'font_style': encodedFontStyle,
        'font_size': fontSize.clamp(14.0, 64.0),
        'text_color': _colorHex,
        'text_align': _alignApi,
        'pos_x': posX.clamp(0.0, 1.0),
        'pos_y': posY.clamp(0.0, 1.0),
      };
}

class _PrintComposeViewState extends ConsumerState<PrintComposeView>
    with SingleTickerProviderStateMixin {
  final _noteController = TextEditingController();
  final _noteFocus = FocusNode();
  final _emailsController = TextEditingController();
  final _fromController = TextEditingController();
  final _printService = PrintService();

  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;

  final List<_TextSticker> _layers = [];
  String? _selectedId;
  bool _editingText = false;
  double _pinchBaseSize = 14;

  static const int _expireDays = 30;
  String _paperStyle = 'cream';
  bool _sending = false;
  bool _showBack = false;

  /// width / height of the photo — keeps front & verso the same print size.
  double? _imageAspect;

  /// Stamp template on the front (display-normalized center + size).
  double _stampCx = 0.72;
  double _stampCy = 0.78;
  double _stampSize = kPrintStampDefaultSize;
  double _stampPinchBase = kPrintStampDefaultSize;
  PrintQrStampCrop? _lockedStamp;
  bool _stampDragging = false;
  final GlobalKey _stampGuidanceKey = GlobalKey();
  bool _stampIntroScheduled = false;

  static const _ink = Color(0xFF2C2416);
  static const _papers = {
    'cream': Color(0xFFF3EBD8),
    'white': Color(0xFFF7F7F5),
    'kraft': Color(0xFFC4A574),
  };

  /// Instagram-style palette (no fill/box — color only).
  static const _textColors = <Color>[
    Color(0xFF2C2416),
    Color(0xFFFFFFFF),
    Color(0xFF111111),
    Color(0xFFE53935),
    Color(0xFFFF8A00),
    Color(0xFFFFD600),
    Color(0xFF43A047),
    Color(0xFF1E88E5),
    Color(0xFF8E24AA),
    Color(0xFFD81B60),
    Color(0xFF00ACC1),
    Color(0xFF795548),
  ];

  static const _minSize = 14.0;
  static const _maxSize = 64.0;
  static const _maxLayers = 12;

  static TextAlign _cycleAlign(TextAlign current) => switch (current) {
        TextAlign.left => TextAlign.right,
        TextAlign.right => TextAlign.center,
        _ => TextAlign.left,
      };

  static IconData _alignIcon(TextAlign align) => switch (align) {
        TextAlign.left => Icons.format_align_left_rounded,
        TextAlign.right => Icons.format_align_right_rounded,
        _ => Icons.format_align_center_rounded,
      };

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _flipAnimation = CurvedAnimation(parent: _flipController, curve: Curves.easeInOutCubic);
    _noteController.addListener(_onNoteChanged);
    _resolveImageAspect();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final profile = ref.read(userProfileProvider).value;
      final seed = (profile?.professionalNickname?.trim().isNotEmpty == true)
          ? profile!.professionalNickname!.trim()
          : (profile?.displayName?.trim().isNotEmpty == true)
              ? profile!.displayName!.trim()
              : '';
      if (seed.isNotEmpty && _fromController.text.isEmpty) {
        _fromController.text = seed;
      }
      _scheduleStampIntroIfNeeded();
    });
  }

  void _scheduleStampIntroIfNeeded() {
    if (_stampIntroScheduled) return;
    _stampIntroScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (await GuidanceService.instance.hasSeenPrintStampIntro) return;
      for (var attempt = 0; attempt < 8; attempt++) {
        await Future<void>.delayed(Duration(milliseconds: attempt == 0 ? 450 : 200));
        if (!mounted || _showBack) return;
        if (_stampGuidanceKey.currentContext != null) break;
      }
      if (!mounted || _showBack || _stampGuidanceKey.currentContext == null) return;
      final coach = buildSingleStepArchiveGuidance(
        context: context,
        targetKey: _stampGuidanceKey,
        identify: 'print_stamp_intro',
        contentAlign: ContentAlign.top,
        paddingFocus: 10,
        radius: 10,
        body: context.l10n.guidancePrintStampIntro,
        onCompleted: () {
          unawaited(GuidanceService.instance.setPrintStampIntroSeen());
        },
      );
      coach.show(context: context);
    });
  }

  void _resolveImageAspect() {
    Future<void> apply(ImageProvider provider) async {
      final stream = provider.resolve(const ImageConfiguration());
      late final ImageStreamListener listener;
      listener = ImageStreamListener(
        (info, _) {
          final w = info.image.width.toDouble();
          final h = info.image.height.toDouble();
          if (w > 0 && h > 0 && mounted) {
            setState(() => _imageAspect = w / h);
          }
          stream.removeListener(listener);
        },
        onError: (_, __) {
          stream.removeListener(listener);
        },
      );
      stream.addListener(listener);
    }

    final url = widget.imageUrl.trim();
    if (url.startsWith('/') || url.startsWith('file://')) {
      final path = url.startsWith('file://') ? Uri.parse(url).toFilePath() : url;
      apply(FileImage(File(path)));
      return;
    }

    // Prefer local synced file so portrait aspect is correct offline / on device.
    () async {
      try {
        final local = await LocalSyncService().resolveLocalPath(
          rollId: widget.rollId,
          imageUrl: widget.imageUrl,
          imageId: widget.imageId,
          preferThumbnail: false,
        );
        if (!mounted) return;
        if (local != null && local.isNotEmpty) {
          await apply(FileImage(File(local)));
          return;
        }
      } catch (_) {}
      if (!mounted) return;
      if (url.startsWith('http')) {
        await apply(NetworkImage(url));
      }
    }();
  }

  @override
  void dispose() {
    _noteController.removeListener(_onNoteChanged);
    _noteController.dispose();
    _noteFocus.dispose();
    _emailsController.dispose();
    _fromController.dispose();
    _flipController.dispose();
    super.dispose();
  }

  void _onNoteChanged() {
    if (!_editingText) return;
    final layer = _selectedLayer;
    if (layer == null) return;
    final next = _noteController.text;
    if (layer.text == next) return;
    layer.text = next;
    if (mounted) setState(() {});
  }

  _TextSticker? get _selectedLayer {
    final id = _selectedId;
    if (id == null) return null;
    for (final layer in _layers) {
      if (layer.id == id) return layer;
    }
    return null;
  }

  List<_TextSticker> get _nonEmptyLayers =>
      _layers.where((l) => l.text.trim().isNotEmpty).toList();

  TextStyle _styleFor(_TextSticker layer, {Color? color, double? size}) {
    final family = layer.fontFamily == 'type' ? 'Be Vietnam Pro' : 'Mali';
    return TextStyle(
      fontFamily: family,
      fontSize: size ?? layer.fontSize,
      height: 1.25,
      color: color ?? layer.color,
      fontWeight: layer.bold ? FontWeight.w700 : FontWeight.w400,
      fontStyle: layer.italic ? FontStyle.italic : FontStyle.normal,
      // Instagram text stickers: no shadow / glow.
      shadows: const [],
      decoration: TextDecoration.none,
    );
  }

  List<String> _parseEmails(String raw) {
    final parts = raw.split(RegExp(r'[,;\s]+'));
    final seen = <String>{};
    final out = <String>[];
    for (final p in parts) {
      final e = p.trim().toLowerCase();
      if (e.isEmpty || !e.contains('@') || seen.contains(e)) continue;
      seen.add(e);
      out.add(e);
    }
    return out;
  }

  Future<void> _toggleFlip() async {
    if (_editingText) {
      _finishEditing();
      return;
    }
    HapticFeedback.selectionClick();
    if (_showBack) {
      await _flipController.reverse();
      if (mounted) setState(() => _showBack = false);
    } else {
      setState(() => _showBack = true);
      await _flipController.forward();
    }
  }

  void _finishEditing() {
    // Guard against double-invoke (DONE + unfocus/tap-through) which would
    // re-read an already-cleared controller and wipe the sticker.
    if (!_editingText) return;
    final layer = _selectedLayer;
    final committed = _noteController.text.trim();
    _noteFocus.unfocus();
    setState(() {
      _editingText = false;
      if (layer != null) {
        layer.text = committed;
        if (committed.isEmpty) {
          _layers.removeWhere((l) => l.id == layer.id);
          if (_selectedId == layer.id) _selectedId = null;
        }
      }
    });
    if (_noteController.text.isNotEmpty) {
      _noteController.clear();
    }
  }

  void _selectAndEdit(_TextSticker layer) {
    if (_editingText && _selectedId != layer.id) {
      _finishEditing();
    }
    _noteController.value = TextEditingValue(
      text: layer.text,
      selection: TextSelection.collapsed(offset: layer.text.length),
    );
    setState(() {
      _selectedId = layer.id;
      _editingText = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _noteFocus.requestFocus();
    });
  }

  void _addLayerAt(double posX, double posY) {
    if (_editingText) {
      _finishEditing();
    }
    if (_layers.length >= _maxLayers) {
      ref.read(notificationProvider.notifier).show(
            'MAX ${_maxLayers} TEXT NOTES',
            type: NotificationType.warning,
          );
      return;
    }
    final styleSource = _selectedLayer;
    final layer = _TextSticker(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      text: '',
      posX: posX,
      posY: posY,
      fontFamily: styleSource?.fontFamily ?? 'hand',
      bold: styleSource?.bold ?? false,
      italic: styleSource?.italic ?? false,
      fontSize: styleSource?.fontSize ?? 14,
      color: styleSource?.color ?? _ink,
      align: styleSource?.align ?? TextAlign.center,
    );
    // Reset controller before editing so the new sticker never inherits the
    // previous note from the shared TextEditingController.
    _noteController.clear();
    setState(() {
      _layers.add(layer);
      _selectedId = layer.id;
      _editingText = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _noteFocus.requestFocus();
    });
  }

  void _deleteSelected() {
    final id = _selectedId;
    if (id == null) return;
    _noteFocus.unfocus();
    setState(() {
      _layers.removeWhere((l) => l.id == id);
      _selectedId = null;
      _editingText = false;
    });
    _noteController.clear();
  }

  void _moveLayer(_TextSticker layer, Offset delta, Size size) {
    setState(() {
      layer.posX = (layer.posX + delta.dx / size.width).clamp(0.08, 0.92);
      layer.posY = (layer.posY + delta.dy / size.height).clamp(0.08, 0.88);
      _selectedId = layer.id;
    });
  }

  Future<void> _openSendSheet() async {
    if (_editingText) _finishEditing();
    if (_lockedStamp == null) {
      ref.read(notificationProvider.notifier).show(
            halideCaps(context.l10n.printStampRequired),
            type: NotificationType.warning,
          );
      if (_showBack) await _toggleFlip();
      return;
    }
    if (_nonEmptyLayers.isEmpty) {
      ref.read(notificationProvider.notifier).show(
            halideCaps(context.l10n.printNoteRequired),
            type: NotificationType.warning,
          );
      if (!_showBack) await _toggleFlip();
      return;
    }
    // Free: compose + stamp allowed; sending needs Pro (cloud upload).
    if (!ref.read(userPlanProvider).isPro) {
      ref.read(notificationProvider.notifier).show(
            halideCaps(context.l10n.printNeedsCloudScan),
            type: NotificationType.warning,
          );
      if (mounted) context.push('/paywall');
      return;
    }
    if (!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(widget.imageId)) {
      ref.read(notificationProvider.notifier).show(
            halideCaps(context.l10n.printNeedsCloudScan),
            type: NotificationType.warning,
          );
      return;
    }
    if (!mounted) return;
    final colors = HalideColors.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surfaceSheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: _SendSheet(
            fromController: _fromController,
            emailsController: _emailsController,
            sending: _sending,
            onSend: () async {
              Navigator.of(ctx).pop();
              await _send();
            },
          ),
        );
      },
    );
  }

  Future<void> _send() async {
    final l10n = context.l10n;
    if (_editingText) _finishEditing();
    final stamp = _lockedStamp;
    if (stamp == null) {
      ref.read(notificationProvider.notifier).show(
            halideCaps(l10n.printStampRequired),
            type: NotificationType.warning,
          );
      return;
    }
    final layers = _nonEmptyLayers;
    if (layers.isEmpty) {
      ref.read(notificationProvider.notifier).show(
            halideCaps(l10n.printNoteRequired),
            type: NotificationType.warning,
          );
      return;
    }
    final emails = _parseEmails(_emailsController.text);
    if (emails.isEmpty) {
      ref.read(notificationProvider.notifier).show(
            halideCaps(l10n.printRecipientsRequired),
            type: NotificationType.warning,
          );
      return;
    }
    final fromName = _fromController.text.trim();
    if (fromName.isEmpty) {
      ref.read(notificationProvider.notifier).show(
            halideCaps(l10n.printFromRequired),
            type: NotificationType.warning,
          );
      return;
    }
    if (!ref.read(userPlanProvider).isPro) {
      ref.read(notificationProvider.notifier).show(
            halideCaps(l10n.printNeedsCloudScan),
            type: NotificationType.warning,
          );
      if (mounted) context.push('/paywall');
      return;
    }
    if (!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(widget.imageId)) {
      ref.read(notificationProvider.notifier).show(
            halideCaps(l10n.printNeedsCloudScan),
            type: NotificationType.warning,
          );
      return;
    }

    setState(() => _sending = true);
    try {
      final result = await _printService.createPrint(
        imageId: widget.imageId,
        layers: layers.map((l) => l.toApi()).toList(),
        recipientEmails: emails,
        fromName: fromName,
        paperStyle: _paperStyle,
        expireDays: _expireDays,
        sendEmail: true,
        qrStamp: stamp.toApi(),
      );
      if (!mounted) return;
      ref.read(notificationProvider.notifier).show(
            halideCaps(l10n.printSentSuccess(result.emailsSent, _expireDays)),
            type: NotificationType.success,
          );
      // Share sheet is optional; print + email already succeeded.
      try {
        final box = context.findRenderObject() as RenderBox?;
        late final Rect origin;
        if (box != null && box.hasSize && box.size.width > 0 && box.size.height > 0) {
          origin = box.localToGlobal(Offset.zero) & box.size;
        } else {
          final size = MediaQuery.sizeOf(context);
          origin = Rect.fromCenter(
            center: Offset(size.width / 2, size.height / 2),
            width: 1,
            height: 1,
          );
        }
        await Share.share(
          result.publicUrl,
          subject: l10n.printShareSubject,
          sharePositionOrigin: origin,
        );
      } catch (_) {
        // User cancelled or iOS popover origin issue — ignore.
      }
      if (mounted) Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      ref.read(notificationProvider.notifier).show(
            halideCaps(e.toString().replaceFirst('Exception: ', '')),
            type: NotificationType.error,
          );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final media = MediaQuery.of(context);
    final topPad = media.padding.top;
    final bottomPad = media.padding.bottom;
    final keyboard = media.viewInsets.bottom;
    final paper = _papers[_paperStyle]!;
    final selected = _selectedLayer;
    final showFontSlider = _showBack && _editingText && selected != null;
    // Overlay chrome (hints / toolbar) sits in the Stack — don't carve a huge
    // empty band out of the photo. Portrait frames need the vertical room.
    // When the keyboard is up, Scaffold already shrinks the body; keep a
    // compact toolbar band so the card doesn't collapse.
    // Verso adds a paper-swatch row under the app bar.
    final topChrome = topPad + 48 + (_showBack ? 40 : 0);
    final toolbarBand = (_editingText || selected != null)
        ? (keyboard > 0 ? 96.0 : 148.0)
        : 40.0;
    final bottomReserve = _showBack
        ? bottomPad + toolbarBand
        : bottomPad + 28;
    // Landscape needs a dedicated left column; portrait often has side gutters
    // but we still reserve so the track never sits on the paper.
    final sliderGutter = showFontSlider ? 48.0 : 0.0;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(8, topChrome, 8, bottomReserve),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final aspect = _imageAspect ?? (3 / 2);
                  final availW = (constraints.maxWidth - sliderGutter).clamp(1.0, double.infinity);
                  final availH = constraints.maxHeight;
                  // Contain in available box while maximizing size (portrait fills height).
                  double cardW;
                  double cardH;
                  if (aspect >= 1) {
                    cardW = availW;
                    cardH = cardW / aspect;
                    if (cardH > availH) {
                      cardH = availH;
                      cardW = cardH * aspect;
                    }
                  } else {
                    cardH = availH;
                    cardW = cardH * aspect;
                    if (cardW > availW) {
                      cardW = availW;
                      cardH = cardW / aspect;
                    }
                  }
                  final card = SizedBox(
                    width: cardW,
                    height: cardH,
                    child: AnimatedBuilder(
                      animation: _flipAnimation,
                      builder: (context, _) {
                        final angle = _flipAnimation.value * math.pi;
                        final showBackFace = angle > math.pi / 2;
                        return Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.001)
                            ..rotateY(angle),
                          child: showBackFace
                              ? Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.identity()..rotateY(math.pi),
                                  child: _buildBack(paper, l10n),
                                )
                              : _buildFront(),
                        );
                      },
                    ),
                  );

                  if (!showFontSlider) {
                    return Center(child: card);
                  }

                  // Slider column = card height, left of paper (never over image).
                  final sliderH = cardH.clamp(120.0, availH);
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: sliderGutter,
                        height: sliderH,
                        child: _InstagramFontSizeSlider(
                          value: selected.fontSize,
                          min: _minSize,
                          max: _maxSize,
                          onChanged: (v) {
                            setState(() {
                              selected.fontSize = v;
                              _pinchBaseSize = v;
                            });
                          },
                        ),
                      ),
                      Expanded(child: Center(child: card)),
                    ],
                  );
                },
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(8, topPad + 4, 8, _showBack ? 8 : 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                      const Spacer(),
                      Text(
                        halideCaps(_showBack ? l10n.printVersoHint : l10n.printComposeTitle),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _sending ? null : _openSendSheet,
                        child: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                halideCaps(l10n.printSend),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                      ),
                    ],
                  ),
                  if (_showBack) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          halideCaps(l10n.printPaperLabel),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 10,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        for (final e in _papers.entries)
                          Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: GestureDetector(
                              onTap: () => setState(() => _paperStyle = e.key),
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: e.value,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _paperStyle == e.key
                                        ? Colors.white
                                        : Colors.white24,
                                    width: _paperStyle == e.key ? 2.5 : 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_showBack && (_editingText || selected != null))
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _StyleToolbar(
                bottomPad: keyboard > 0 ? 8 : bottomPad,
                fontFamily: selected?.fontFamily ?? 'hand',
                bold: selected?.bold ?? false,
                italic: selected?.italic ?? false,
                fontSize: selected?.fontSize ?? 14,
                color: selected?.color ?? _ink,
                align: selected?.align ?? TextAlign.center,
                colors: _textColors,
                onFamily: (f) => setState(() {
                  selected?.fontFamily = f;
                }),
                onBold: () => setState(() {
                  if (selected != null) selected.bold = !selected.bold;
                }),
                onItalic: () => setState(() {
                  if (selected != null) selected.italic = !selected.italic;
                }),
                onColor: (c) => setState(() {
                  selected?.color = c;
                }),
                onAlign: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (selected != null) {
                      selected.align = _cycleAlign(selected.align);
                    }
                  });
                },
                onDelete: selected != null ? _deleteSelected : null,
                onDone: _finishEditing,
                handLabel: l10n.printFontHand,
                typeLabel: l10n.printFontType,
                alignIcon: _alignIcon(selected?.align ?? TextAlign.center),
              ),
            ),
          if (_showBack && _layers.isEmpty && !_editingText)
            Positioned(
              left: 24,
              right: 24,
              bottom: bottomPad + 28,
              child: Text(
                halideCaps(l10n.printTapToWrite),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _ink.withValues(alpha: 0.45),
                  fontSize: 13,
                  letterSpacing: 1.1,
                  fontFamily: 'Be Vietnam Pro',
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _lockStamp(Size displaySize) {
    final aspect = _imageAspect ?? (3 / 2);
    final crop = mapStampToSource(
      displaySize: displaySize,
      imageAspect: aspect,
      stampCx: _stampCx,
      stampCy: _stampCy,
      stampSize: _stampSize,
    );
    HapticFeedback.mediumImpact();
    setState(() => _lockedStamp = crop);
    ref.read(notificationProvider.notifier).show(
          halideCaps(context.l10n.printStampLocked),
          type: NotificationType.success,
        );
  }

  void _unlockStamp() {
    HapticFeedback.selectionClick();
    setState(() => _lockedStamp = null);
  }

  Widget _buildFront() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final stampPx = _stampSize * math.min(size.width, size.height);
        final left = _stampCx * size.width - stampPx / 2;
        final top = _stampCy * size.height - stampPx / 2;
        final locked = _lockedStamp != null;

        return ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                onTap: () {
                  if (_stampDragging) return;
                  _toggleFlip();
                },
                behavior: HitTestBehavior.opaque,
                child: ColoredBox(
                  color: Colors.black,
                  child: SyncedImage(
                    imageUrl: widget.imageUrl,
                    rollId: widget.rollId,
                    imageId: widget.imageId,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              // Dim outside stamp slightly when unlocked so the template reads clearly
              if (!locked)
                IgnorePointer(
                  child: CustomPaint(
                    painter: _StampVignettePainter(
                      center: Offset(_stampCx * size.width, _stampCy * size.height),
                      radius: stampPx * 0.55,
                    ),
                  ),
                ),
              Positioned(
                left: left,
                top: top,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onDoubleTap: () {
                    if (locked) {
                      _unlockStamp();
                    } else {
                      _lockStamp(size);
                    }
                  },
                  onScaleStart: (_) {
                    _stampPinchBase = _stampSize;
                    _stampDragging = true;
                    if (locked) _unlockStamp();
                    HapticFeedback.selectionClick();
                  },
                  onScaleUpdate: (d) {
                    setState(() {
                      if (d.pointerCount >= 2) {
                        _stampSize = (_stampPinchBase * d.scale)
                            .clamp(kPrintStampMinSize, kPrintStampMaxSize);
                      } else {
                        _stampCx = (_stampCx + d.focalPointDelta.dx / size.width)
                            .clamp(0.12, 0.88);
                        _stampCy = (_stampCy + d.focalPointDelta.dy / size.height)
                            .clamp(0.12, 0.88);
                      }
                    });
                  },
                  onScaleEnd: (_) {
                    _stampDragging = false;
                  },
                  child: PrintStampFrame(
                    key: _stampGuidanceKey,
                    size: stampPx,
                    locked: locked,
                    child: locked
                        ? const Center(
                            child: Icon(
                              Icons.qr_code_2_rounded,
                              color: Color(0xFFE8C547),
                              size: 28,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBack(Color paper, AppLocalizations l10n) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        // Parent only handles empty-paper taps. Drag/pinch live on each sticker
        // (ScaleGestureRecognizer on the parent would steal 1-finger pans).
        return ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) {
              if (_editingText) {
                _finishEditing();
                return;
              }
              final dx = (d.localPosition.dx / size.width).clamp(0.08, 0.92);
              final dy = (d.localPosition.dy / size.height).clamp(0.08, 0.88);
              _addLayerAt(dx, dy);
            },
            child: ColoredBox(
              color: paper,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(painter: _PaperGrainPainter(color: _ink.withValues(alpha: 0.04))),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.35),
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: l10n.printTapFront,
                        onPressed: _toggleFlip,
                        icon: const Icon(Icons.flip_camera_android_rounded, color: Colors.white),
                      ),
                    ),
                  ),
                  for (final layer in _layers)
                    _buildLayerWidget(layer, size, l10n),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLayerWidget(_TextSticker layer, Size size, AppLocalizations l10n) {
    final selected = layer.id == _selectedId;
    final editing = selected && _editingText;
    final boxWidth = size.width * 0.72;

    return Positioned(
      left: (layer.posX * size.width) - (boxWidth / 2),
      top: (layer.posY * size.height) - (layer.fontSize * 0.75),
      width: boxWidth,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (editing) return;
          _selectAndEdit(layer);
        },
        onScaleStart: (_) {
          if (_editingText && layer.id != _selectedId) {
            _finishEditing();
          }
          setState(() => _selectedId = layer.id);
          _pinchBaseSize = layer.fontSize;
          HapticFeedback.selectionClick();
        },
        onScaleUpdate: (d) {
          // Pinch always resizes font (including while typing), Instagram-style.
          if (d.pointerCount >= 2) {
            setState(() {
              layer.fontSize = (_pinchBaseSize * d.scale).clamp(_minSize, _maxSize);
            });
            return;
          }
          // One-finger pan moves the sticker; skip while typing so caret stays usable.
          if (editing) return;
          _moveLayer(layer, d.focalPointDelta, size);
        },
        child: editing
            ? TextField(
                key: ValueKey('print-note-${layer.id}'),
                controller: _noteController,
                focusNode: _noteFocus,
                maxLines: null,
                maxLength: 2000,
                textAlign: layer.align,
                style: _styleFor(layer),
                cursorColor: layer.color,
                cursorWidth: 2,
                decoration: InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  hintText: l10n.printNoteHint,
                  hintStyle: _styleFor(
                    layer,
                    color: layer.color.withValues(alpha: 0.35),
                  ),
                ),
              )
            : Text(
                layer.text.trim().isEmpty ? l10n.printNoteHint : layer.text,
                textAlign: layer.align,
                style: _styleFor(
                  layer,
                  color: layer.text.trim().isEmpty
                      ? layer.color.withValues(alpha: 0.35)
                      : layer.color,
                ),
              ),
      ),
    );
  }
}

class _StampVignettePainter extends CustomPainter {
  _StampVignettePainter({required this.center, required this.radius});

  final Offset center;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRect(Offset.zero & size)
      ..addOval(Rect.fromCircle(center: center, radius: radius))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: 0.32));
  }

  @override
  bool shouldRepaint(covariant _StampVignettePainter oldDelegate) =>
      oldDelegate.center != center || oldDelegate.radius != radius;
}

class _InstagramFontSizeSlider extends StatelessWidget {
  const _InstagramFontSizeSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final trackH = constraints.maxHeight.clamp(120.0, 420.0);
          return Align(
            alignment: Alignment.center,
            child: SizedBox(
              height: trackH,
              width: 44,
              child: RotatedBox(
                // Horizontal slider → vertical: drag up increases size (Instagram).
                quarterTurns: 3,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.28),
                    thumbColor: Colors.white,
                    overlayColor: Colors.white.withValues(alpha: 0.12),
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 9,
                      elevation: 0,
                      pressedElevation: 0,
                    ),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                    trackShape: const RoundedRectSliderTrackShape(),
                  ),
                  child: Slider(
                    value: value.clamp(min, max),
                    min: min,
                    max: max,
                    onChanged: onChanged,
                    onChangeStart: (_) => HapticFeedback.selectionClick(),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StyleToolbar extends StatelessWidget {
  const _StyleToolbar({
    required this.bottomPad,
    required this.fontFamily,
    required this.bold,
    required this.italic,
    required this.fontSize,
    required this.color,
    required this.align,
    required this.colors,
    required this.onFamily,
    required this.onBold,
    required this.onItalic,
    required this.onColor,
    required this.onAlign,
    required this.onDone,
    required this.handLabel,
    required this.typeLabel,
    required this.alignIcon,
    this.onDelete,
  });

  final double bottomPad;
  final String fontFamily;
  final bool bold;
  final bool italic;
  final double fontSize;
  final Color color;
  final TextAlign align;
  final List<Color> colors;
  final ValueChanged<String> onFamily;
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final ValueChanged<Color> onColor;
  final VoidCallback onAlign;
  final VoidCallback onDone;
  final VoidCallback? onDelete;
  final String handLabel;
  final String typeLabel;
  final IconData alignIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, bottomPad + 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.78),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _Chip(
                  label: handLabel,
                  selected: fontFamily == 'hand',
                  style: const TextStyle(fontFamily: 'Mali', color: Colors.white),
                  onTap: () => onFamily('hand'),
                ),
                const SizedBox(width: 8),
                _Chip(
                  label: typeLabel,
                  selected: fontFamily == 'type',
                  style: const TextStyle(
                    fontFamily: 'Be Vietnam Pro',
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                  onTap: () => onFamily('type'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: colors.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final c = colors[i];
                final selectedSwatch = c.toARGB32() == color.toARGB32();
                return GestureDetector(
                  onTap: () => onColor(c),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c,
                      border: Border.all(
                        color: selectedSwatch ? Colors.white : Colors.white38,
                        width: selectedSwatch ? 2.5 : 1,
                      ),
                      boxShadow: c.computeLuminance() > 0.85
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _IconToggle(
                selected: false,
                onTap: onAlign,
                child: Icon(alignIcon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 6),
              _IconToggle(
                selected: bold,
                onTap: onBold,
                child: const Text(
                  'B',
                  style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
                ),
              ),
              const SizedBox(width: 6),
              _IconToggle(
                selected: italic,
                onTap: onItalic,
                child: const Text(
                  'I',
                  style: TextStyle(fontStyle: FontStyle.italic, color: Colors.white),
                ),
              ),
              if (onDelete != null) ...[
                const SizedBox(width: 6),
                _IconToggle(
                  selected: false,
                  onTap: onDelete!,
                  child: const Icon(Icons.delete_outline, color: Colors.white, size: 18),
                ),
              ],
              const Spacer(),
              Text(
                '${fontSize.round()}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onDone,
                child: const Text(
                  'DONE',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.style,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withValues(alpha: 0.22) : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? Colors.white70 : Colors.white24),
        ),
        child: Text(label, style: style.copyWith(fontSize: 13)),
      ),
    );
  }
}

class _IconToggle extends StatelessWidget {
  const _IconToggle({required this.selected, required this.onTap, required this.child});

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.white.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.08),
          shape: BoxShape.circle,
          border: Border.all(color: selected ? Colors.white70 : Colors.white24),
        ),
        child: child,
      ),
    );
  }
}

class _PaperGrainPainter extends CustomPainter {
  _PaperGrainPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final rnd = math.Random(7);
    for (var i = 0; i < 400; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      canvas.drawCircle(Offset(x, y), 0.6, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PaperGrainPainter oldDelegate) => false;
}

class _SendSheet extends StatelessWidget {
  const _SendSheet({
    required this.fromController,
    required this.emailsController,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController fromController;
  final TextEditingController emailsController;
  final bool sending;
  final VoidCallback onSend;

  InputDecoration _fieldDecoration(HalideColors colors, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: colors.textSecondary.withValues(alpha: 0.7)),
      filled: true,
      fillColor: colors.surface.withValues(alpha: 0.65),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.borderSubtle),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.borderSubtle),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.accent, width: 1.5),
      ),
    );
  }

  TextStyle _labelStyle(HalideColors colors) => TextStyle(
        color: colors.textSecondary,
        fontSize: 11,
        letterSpacing: 1.3,
        fontWeight: FontWeight.w600,
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = HalideColors.of(context);
    return StatefulBuilder(
      builder: (context, setModal) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.muted.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(halideCaps(l10n.printFromLabel), style: _labelStyle(colors)),
            const SizedBox(height: 8),
            TextField(
              controller: fromController,
              textCapitalization: TextCapitalization.words,
              maxLength: 80,
              style: TextStyle(color: colors.textPrimary, fontFamily: 'Be Vietnam Pro'),
              cursorColor: colors.accent,
              decoration: _fieldDecoration(colors, l10n.printFromHint).copyWith(counterText: ''),
            ),
            const SizedBox(height: 16),
            Text(halideCaps(l10n.printRecipientsLabel), style: _labelStyle(colors)),
            const SizedBox(height: 8),
            TextField(
              controller: emailsController,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: colors.textPrimary, fontFamily: 'Be Vietnam Pro'),
              cursorColor: colors.accent,
              decoration: _fieldDecoration(colors, l10n.printRecipientsHint),
            ),
            const SizedBox(height: 14),
            Text(
              l10n.printPrivacyHint,
              style: TextStyle(color: colors.textMuted(), fontSize: 12, height: 1.35),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: sending ? null : onSend,
              style: FilledButton.styleFrom(
                backgroundColor: colors.light,
                foregroundColor: colors.textOnLight,
                disabledBackgroundColor: colors.muted.withValues(alpha: 0.35),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                halideCaps(l10n.printSend),
                style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1),
              ),
            ),
          ],
        );
      },
    );
  }
}
