import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/halide_debug_log.dart';
import '../services/local_sync_service.dart';

/// Long-press on [SyncedImage] in dev/staging — URLs, ids, and **attempts a download** so
/// "local" reflects cache or a clear failure (HTTP / not an image).
Future<void> showImageUrlDiagnosticsSheet(
  BuildContext context, {
  required String rollId,
  required String imageUrl,
  String? imageId,
  required bool preferThumbnail,
  required String requestUrlUsed,
}) async {
  HalideDebugLog.log(
    'Image',
    'inspect roll=$rollId imageId=${imageId ?? "—"} fullUrl=$imageUrl request=$requestUrlUsed',
  );

  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF1a1a1e),
    isScrollControlled: true,
    builder: (ctx) => _ImageUrlDiagnosticsBody(
      rollId: rollId,
      imageUrl: imageUrl,
      imageId: imageId,
      preferThumbnail: preferThumbnail,
      requestUrlUsed: requestUrlUsed,
    ),
  );
}

class _ImageUrlDiagnosticsBody extends StatefulWidget {
  const _ImageUrlDiagnosticsBody({
    required this.rollId,
    required this.imageUrl,
    required this.imageId,
    required this.preferThumbnail,
    required this.requestUrlUsed,
  });

  final String rollId;
  final String imageUrl;
  final String? imageId;
  final bool preferThumbnail;
  final String requestUrlUsed;

  @override
  State<_ImageUrlDiagnosticsBody> createState() => _ImageUrlDiagnosticsBodyState();
}

class _ImageUrlDiagnosticsBodyState extends State<_ImageUrlDiagnosticsBody> {
  String? _localPath;
  String? _downloadNote;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _runDownloadProbe();
  }

  Future<void> _runDownloadProbe() async {
    final svc = LocalSyncService();
    final before = await svc.resolveLocalPath(
      rollId: widget.rollId,
      imageUrl: widget.imageUrl,
      imageId: widget.imageId,
      preferThumbnail: widget.preferThumbnail,
    );
    if (before != null && mounted) {
      setState(() {
        _localPath = before;
        _downloadNote = 'Already on disk (no download needed).';
        _loading = false;
      });
      return;
    }

    final result = await svc.ensureLocalSync(
      widget.rollId,
      widget.imageUrl,
      imageId: widget.imageId,
      preferThumbnail: widget.preferThumbnail,
    );

    if (!mounted) return;

    if (result.startsWith('http')) {
      setState(() {
        _localPath = null;
        _downloadNote =
            'Download did not save a file (see HALIDE DEBUG LOG → Sync). '
            'Common causes: HTTP 403/404, HTML error page instead of JPEG, or offline.';
        _loading = false;
      });
      return;
    }

    final path = result.startsWith('file://') ? Uri.parse(result).toFilePath() : result;
    setState(() {
      _localPath = path;
      _downloadNote = 'Saved to app documents (offline cache).';
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final thumbUrl = thumbUrlForFullImageUrl(widget.imageUrl);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).padding.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'IMAGE LOAD DEBUG',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Plus/Pro: opening a roll prefetches scans in the background. '
                'Free: caching happens when each frame loads. '
                'This sheet always runs one download attempt.',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
              ),
              const SizedBox(height: 12),
              _section('Roll ID', widget.rollId),
              _section('Image ID (DB)', widget.imageId ?? '—'),
              _section('Full image URL (from API)', widget.imageUrl),
              _section('Thumb URL (derived)', thumbUrl),
              _section('URL actually requested', widget.requestUrlUsed),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                    ),
                  ),
                )
              else ...[
                _section('Resolved local file', _localPath ?? '—'),
                _section('Download probe', _downloadNote ?? '—'),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('CLOSE'),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _loading = true;
                        _downloadNote = null;
                        _localPath = null;
                      });
                      _runDownloadProbe();
                    },
                    child: const Text('RETRY DOWNLOAD'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () async {
                      final buf = StringBuffer()
                        ..writeln('roll_id: ${widget.rollId}')
                        ..writeln('image_id: ${widget.imageId ?? "—"}')
                        ..writeln('image_url: ${widget.imageUrl}')
                        ..writeln('request_url: ${widget.requestUrlUsed}')
                        ..writeln('local: ${_localPath ?? "—"}')
                        ..writeln('note: ${_downloadNote ?? "—"}');
                      await Clipboard.setData(ClipboardData(text: buf.toString()));
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('COPY ALL'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _section(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.45),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        SelectableText(
          value,
          style: const TextStyle(
            color: Color(0xFF86EFAC),
            fontSize: 11,
            fontFamily: 'Courier',
            height: 1.35,
          ),
        ),
      ],
    ),
  );
}
