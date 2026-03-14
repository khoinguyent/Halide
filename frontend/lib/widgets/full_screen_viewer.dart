import 'package:flutter/material.dart';
import 'package:frontend/models/film_stock.dart';
import 'package:frontend/models/camera.dart';

class FullScreenViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final FilmStock? filmStock;
  final Camera? camera;
  final int? iso;
  final DateTime? dateScanned;

  const FullScreenViewer({
    Key? key,
    required this.imageUrls,
    this.initialIndex = 0,
    this.filmStock,
    this.camera,
    this.iso,
    this.dateScanned,
  }) : super(key: key);

  @override
  _FullScreenViewerState createState() => _FullScreenViewerState();
}

class _FullScreenViewerState extends State<FullScreenViewer> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showOverlay = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _toggleOverlay() {
    setState(() {
      _showOverlay = !_showOverlay;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleOverlay,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.imageUrls.length,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: Image.network(
                    widget.imageUrls[index],
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(child: Icon(Icons.error, color: Colors.white, size: 48));
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                    },
                  ),
                );
              },
            ),
            
            if (_showOverlay) ...[
              // Top Bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, left: 16, right: 16, bottom: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                      Text(
                        '${_currentIndex + 1} / ${widget.imageUrls.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Metadata Overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 24, left: 24, right: 24, top: 48),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.camera != null)
                        Text(
                          widget.camera!.displayName.toUpperCase(),
                          style: const TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1.5),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (widget.filmStock != null)
                            Text(
                              '${widget.filmStock!.brand} ${widget.filmStock!.name}',
                              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                            ),
                          const Spacer(),
                          if (widget.iso != null)
                            Text(
                              'ISO ${widget.iso}',
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                      if (widget.dateScanned != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Scanned: ${widget.dateScanned!.toLocal().toString().split(' ')[0]}',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ]
                    ],
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
