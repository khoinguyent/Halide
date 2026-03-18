import 'dart:ui';
import 'package:flutter/material.dart';

class StorageTierSelector extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int>? onSelected;

  const StorageTierSelector({
    Key? key,
    this.selectedIndex = 0,
    this.onSelected,
  }) : super(key: key);

  @override
  State<StorageTierSelector> createState() => _StorageTierSelectorState();
}

class _StorageTierSelectorState extends State<StorageTierSelector> {
  int _selectedIndex = 0;

  static const List<TierData> _tiers = [
    TierData(
      label: 'Local Device',
      subtitle: 'Free',
      icon: Icons.smartphone_outlined,
      description: 'No cloud backup',
      isPro: false,
    ),
    TierData(
      label: 'Personal Cloud',
      subtitle: 'BYO',
      icon: Icons.cloud_outlined,
      description: 'Google Drive / OneDrive / NAS',
      isPro: false,
    ),
    TierData(
      label: 'System Cloud',
      subtitle: 'Pro',
      icon: Icons.auto_awesome,
      description: 'Paid subscription',
      isPro: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final selectedIndex = widget.onSelected != null ? widget.selectedIndex : _selectedIndex;
    return Column(
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _tiers.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () {
                if (widget.onSelected != null) {
                  widget.onSelected!(index);
                } else {
                  setState(() => _selectedIndex = index);
                }
              },
              child: _TierItem(
                data: _tiers[index],
                isSelected: selectedIndex == index,
              ),
            );
          },
        ),
        if (_tiers[selectedIndex].isPro) ...[
          const SizedBox(height: 24),
          const _ProUpgradePath(),
        ],
      ],
    );
  }
}

class TierData {
  final String label;
  final String? subtitle;
  final IconData icon;
  final String description;
  final bool isPro;

  const TierData({
    required this.label,
    this.subtitle,
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected 
                ? const Color(0xFFF97316).withOpacity(0.08) 
                : Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected 
                  ? const Color(0xFFF97316).withOpacity(0.5) 
                  : Colors.white.withOpacity(0.05),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isSelected ? const Color(0xFFF97316) : Colors.white).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  data.icon, 
                  color: isSelected ? const Color(0xFFF97316) : Colors.white70, 
                  size: 24
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.description,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (data.subtitle != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: data.isPro 
                        ? const Color(0xFFF97316).withOpacity(0.15) 
                        : Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: data.isPro 
                          ? const Color(0xFFF97316).withOpacity(0.3) 
                          : Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Text(
                    data.subtitle!,
                    style: TextStyle(
                      color: data.isPro ? const Color(0xFFF97316) : Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProUpgradePath extends StatelessWidget {
  const _ProUpgradePath();

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                          'Unlock system-level features and cloud sync.',
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
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Storage included',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Each account includes 5–10 GB of cloud storage by default. You can add more storage anytime; pricing for extra capacity will be shown at checkout.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
