import 'dart:ui';
import 'package:flutter/material.dart';

class GlassNavigationDock extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTabSelected;

  const GlassNavigationDock({
    Key? key,
    required this.currentIndex,
    required this.onTabSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(Icons.home_outlined, 0),
                _buildNavItem(Icons.search, 1),
                const SizedBox(width: 48), // Space for FAB
                _buildNavItem(Icons.notifications_none, 2),
                _buildNavItem(Icons.person_outline, 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index) {
    final isSelected = currentIndex == index;
    return GestureDetector(
      onTap: () => onTabSelected(index),
      child: Icon(
        icon,
        color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
        size: 28,
      ),
    );
  }
}
