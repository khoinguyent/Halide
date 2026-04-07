import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/glass_panel.dart';
import '../../core/widgets/halide_scaffold.dart';

/// Shared layout for Terms & Conditions and Privacy Policy — matches [SettingsView] / profile stack styling.
class LegalDocumentView extends StatelessWidget {
  const LegalDocumentView({
    super.key,
    required this.appBarTitle,
    required this.documentLabel,
    required this.sections,
    required this.lastUpdated,
  });

  final String appBarTitle;
  /// Short uppercase label above the body (e.g. TERMS OF SERVICE).
  final String documentLabel;
  final List<({String title, String body})> sections;
  final String lastUpdated;

  static TextStyle get _headingStyle => TextStyle(
        color: Colors.white.withValues(alpha: 0.88),
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.25,
      );

  static TextStyle get _bodyStyle => TextStyle(
        color: Colors.white.withValues(alpha: 0.62),
        fontSize: 15,
        height: 1.55,
      );

  static TextStyle get _documentLabelStyle => TextStyle(
        color: Colors.white.withValues(alpha: 0.92),
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 3.2,
      );

  static TextStyle get _footerStyle => TextStyle(
        color: Colors.white.withValues(alpha: 0.38),
        fontSize: 12,
        height: 1.45,
        letterSpacing: 0.3,
      );

  @override
  Widget build(BuildContext context) {
    return HalideScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
          color: Colors.white,
        ),
        centerTitle: true,
        title: Text(
          appBarTitle,
          style: const TextStyle(
            letterSpacing: 4,
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
        child: GlassPanel(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(documentLabel, style: _documentLabelStyle),
              const SizedBox(height: 20),
              ...sections.expand((s) => [
                    Text(s.title, style: _headingStyle),
                    const SizedBox(height: 8),
                    Text(s.body, style: _bodyStyle),
                    const SizedBox(height: 22),
                  ]),
              const Divider(height: 1, color: Colors.white12),
              const SizedBox(height: 16),
              Text(
                'Last updated: $lastUpdated',
                style: _footerStyle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
