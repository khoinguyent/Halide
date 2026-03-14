import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:frontend/services/storage_connection_service.dart';

class CloudProviderInfo {
  final String id;
  final String name;
  final IconData icon;
  final bool isConnected;

  const CloudProviderInfo({
    required this.id,
    required this.name,
    required this.icon,
    this.isConnected = false,
  });
}

class CloudProvidersSection extends StatelessWidget {
  const CloudProvidersSection({Key? key}) : super(key: key);

  static const List<CloudProviderInfo> _providers = [
    CloudProviderInfo(id: 'icloud', name: 'iCloud', icon: Icons.cloud_outlined),
    CloudProviderInfo(id: 'gdrive', name: 'Google Drive', icon: Icons.drive_file_move_outlined),
    CloudProviderInfo(id: 'onedrive', name: 'OneDrive', icon: Icons.cloud_queue_outlined),
    CloudProviderInfo(id: 'nas', name: 'NAS', icon: Icons.storage_outlined),
    CloudProviderInfo(id: 'smb', name: 'SMB / Network', icon: Icons.folder_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cloud providers',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Add your own cloud or network storage. Tap a provider to connect.',
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _providers.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final provider = _providers[index];
            return _CloudProviderTile(provider: provider);
          },
        ),
      ],
    );
  }
}

class _CloudProviderTile extends StatefulWidget {
  final CloudProviderInfo provider;

  const _CloudProviderTile({Key? key, required this.provider}) : super(key: key);

  @override
  State<_CloudProviderTile> createState() => _CloudProviderTileState();
}

class _CloudProviderTileState extends State<_CloudProviderTile> {
  bool _isConnecting = false;

  Future<void> _handleTap(BuildContext context) async {
    if (_isConnecting) return;
    if (widget.provider.id == 'gdrive') {
      setState(() => _isConnecting = true);
      // Defer sign-in to next frame so tap completes and native UI is stable
      await Future.delayed(const Duration(milliseconds: 100));
      try {
        await StorageConnectionService().connectGoogleDrive();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Google Drive connected'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          final message = e is StorageConnectionException
              ? e.message
              : 'Failed to connect: ${e.toString().length > 80 ? '${e.toString().substring(0, 80)}...' : e}';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isConnecting = false);
      }
      return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.provider.name} coming soon'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isConnecting ? null : () => _handleTap(context),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF60A5FA).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(provider.icon, color: const Color(0xFF60A5FA), size: 22),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      provider.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_isConnecting)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: const Color(0xFFF97316),
                      ),
                    )
                  else if (provider.isConnected)
                    Text(
                      'Connected',
                      style: TextStyle(
                        color: Colors.green.shade300,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  else
                    Text(
                      'Add',
                      style: TextStyle(
                        color: const Color(0xFFF97316),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.white.withOpacity(0.4),
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
