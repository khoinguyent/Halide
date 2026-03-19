import 'package:flutter/material.dart';

class HalideScaffold extends StatelessWidget {
  final Widget child;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final String? title;
  final Color? backgroundColor;

  const HalideScaffold({
    Key? key,
    required this.child,
    this.appBar,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.title,
    this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: appBar,
      body: Stack(
        children: [
          Container(color: backgroundColor ?? const Color(0xFF0D0D0D)),
          SafeArea(
            child: child,
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
