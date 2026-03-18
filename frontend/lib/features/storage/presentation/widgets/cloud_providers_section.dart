import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/storage/presentation/bloc/storage_accounts_bloc.dart';
import 'package:frontend/models/storage_account.dart';
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
  final List<StorageAccount> accounts;
  const CloudProvidersSection({Key? key, required this.accounts}) : super(key: key);

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
          'CLOUD PROVIDERS',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _providers.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final provider = _providers[index];
            final providerAccounts = accounts
                .where((a) => a.providerName == provider.name)
                .toList();
            return _CloudProviderGroup(
              provider: provider,
              connectedAccounts: providerAccounts,
            );
          },
        ),
      ],
    );
  }
}

enum ConnectionState { idle, connecting, success }

class _CloudProviderGroup extends StatefulWidget {
  final CloudProviderInfo provider;
  final List<StorageAccount> connectedAccounts;

  const _CloudProviderGroup({
    Key? key,
    required this.provider,
    required this.connectedAccounts,
  }) : super(key: key);

  @override
  State<_CloudProviderGroup> createState() => _CloudProviderGroupState();
}

class _CloudProviderGroupState extends State<_CloudProviderGroup> {
  ConnectionState _viewState = ConnectionState.idle;

  Future<void> _handleConnect() async {
    if (_viewState != ConnectionState.idle) return;

    setState(() => _viewState = ConnectionState.connecting);
    
    // Simulate connection delay
    await Future.delayed(const Duration(milliseconds: 1500));

    if (widget.provider.id == 'gdrive') {
      try {
        await StorageConnectionService().connectGoogleDrive();
        if (mounted) {
          setState(() => _viewState = ConnectionState.success);
          await Future.delayed(const Duration(milliseconds: 1000));
          if (mounted) setState(() => _viewState = ConnectionState.idle);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _viewState = ConnectionState.idle);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to connect: $e'), backgroundColor: Colors.redAccent),
          );
        }
      }
    } else {
      // Mock success for other providers for demonstration
      if (mounted) {
        setState(() => _viewState = ConnectionState.success);
        await Future.delayed(const Duration(milliseconds: 1000));
        if (mounted) {
          setState(() => _viewState = ConnectionState.idle);
          // In a real app, the BLoC would trigger a reload and we'd see the new account
          context.read<StorageAccountsBloc>().add(LoadStorageAccounts());
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAccounts = widget.connectedAccounts.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProviderHeader(),
        if (hasAccounts) ...[
          const SizedBox(height: 12),
          ...widget.connectedAccounts.map((account) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0, left: 12),
            child: _GroupedAccountCard(account: account),
          )),
        ],
        const SizedBox(height: 8),
        _buildActionButton(),
      ],
    );
  }

  Widget _buildProviderHeader() {
    return Row(
      children: [
        Icon(widget.provider.icon, color: const Color(0xFFF97316).withOpacity(0.7), size: 18),
        const SizedBox(width: 8),
        Text(
          widget.provider.name.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _viewState == ConnectionState.idle ? _handleConnect : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _viewState == ConnectionState.success 
                    ? Colors.green.withOpacity(0.1) 
                    : Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _viewState == ConnectionState.success 
                      ? Colors.green.withOpacity(0.3) 
                      : Colors.white.withOpacity(0.05),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_viewState == ConnectionState.connecting)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF97316)),
                    )
                  else if (_viewState == ConnectionState.success)
                    const Icon(Icons.check_circle_outline, color: Colors.green, size: 18)
                  else
                    Icon(Icons.add_circle_outline, color: Colors.white.withOpacity(0.4), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    _viewState == ConnectionState.connecting 
                        ? 'CONNECTING...' 
                        : _viewState == ConnectionState.success 
                            ? 'CONNECTED' 
                            : 'ADD ACCOUNT',
                    style: TextStyle(
                      color: _viewState == ConnectionState.success 
                          ? Colors.green 
                          : Colors.white.withOpacity(0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
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

class _GroupedAccountCard extends StatelessWidget {
  final StorageAccount account;
  const _GroupedAccountCard({Key? key, required this.account}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isPrimary = account.isPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPrimary ? const Color(0xFFF97316).withOpacity(0.3) : Colors.white.withOpacity(0.05),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                ),
                Text(
                  account.email,
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              isPrimary ? Icons.star_rounded : Icons.star_border_rounded,
              color: isPrimary ? const Color(0xFFF97316) : Colors.white.withOpacity(0.3),
              size: 20,
            ),
            onPressed: () {
              context.read<StorageAccountsBloc>().add(TogglePrimaryAccount(account.id));
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
