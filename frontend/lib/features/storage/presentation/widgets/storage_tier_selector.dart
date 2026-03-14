import 'dart:ui';
import 'package:flutter/material.dart';

class StorageTierSelector extends StatefulWidget {
  const StorageTierSelector({Key? key}) : super(key: key);

  @override
  State<StorageTierSelector> createState() => _StorageTierSelectorState();
}

class _StorageTierSelectorState extends State<StorageTierSelector> {
  int _selectedIndex = 0;

  final List<TierData> _tiers = [
    TierData(
      label: 'Local',
      icon: Icons.storage,
      description: 'Device storage only',
      isPro: false,
    ),
    TierData(
      label: 'Personal',
      icon: Icons.person_outline,
      description: 'Cloud sync enabled',
      isPro: false,
    ),
    TierData(
      label: 'System',
      icon: Icons.diamond_outlined,
      description: 'Unlimited & Enterprise',
      isPro: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 100,
          child: Row(
            children: List.generate(_tiers.length, (index) {
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  child: _TierItem(
                    data: _tiers[index],
                    isSelected: _selectedIndex == index,
                  ),
                ),
              );
            }),
          ),
        ),
        if (_tiers[_selectedIndex].isPro) ...[
          const SizedBox(height: 24),
          _ProUpgradePath(),
        ],
      ],
    );
  }
}

class TierData {
  final String label;
  final IconData icon;
  final String description;
  final bool isPro;

  TierData({
    required this.label,
    required this.icon,
    required this.description,
    required this.isPro,
  });
}

class _TierItem extends StatelessWidget {
  final TierData data;
  final bool isSelected;

  const _TierItem({
    Key? key,
    required this.data,
    required this.isSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.05),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            data.icon,
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.4),
            size: 28,
          ),
          const SizedBox(height: 8),
          Text(
            data.label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.4),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProUpgradePath extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFC084FC).withOpacity(0.2),
                const Color(0xFF6366F1).withOpacity(0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upgrade to Halide Pro',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Unlock system-level features and unlimited storage.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'UPGRADE',
                  style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
