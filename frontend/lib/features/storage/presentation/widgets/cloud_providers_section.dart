import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/widgets/halide_dialog.dart';
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
    CloudProviderInfo(id: 'gdrive', name: 'Google Drive', icon: Icons.drive_file_move_outlined),
    CloudProviderInfo(id: 'nas', name: 'NAS', icon: Icons.storage_outlined),
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
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Add your own cloud or network storage. Tap a provider to connect.',
          style: TextStyle(
            color: Colors.white.withOpacity(0.55),
            fontSize: 13,
            height: 1.35,
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

  Future<_NasConfig?> _showNasConfigDialog() async {
    final hostController = TextEditingController();
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();

    return showHalideDialog<_NasConfig>(
      context: context,
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(dialogContext).viewInsets.bottom),
              child: Container(
                width: MediaQuery.of(dialogContext).size.width * 0.9,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1C29),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Connect NAS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.left,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter your NAS details to set up storage.',
                      style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.35),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: hostController,
                      maxLines: 1,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Host',
                        labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Colors.blueAccent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: usernameController,
                      maxLines: 1,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Username',
                        labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Colors.blueAccent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      maxLines: 1,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Colors.blueAccent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(null),
                          child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 42,
                          child: ElevatedButton(
                            onPressed: () {
                              final host = hostController.text.trim();
                              final username = usernameController.text.trim();
                              final password = passwordController.text;

                              if (host.isEmpty || username.isEmpty || password.isEmpty) {
                                ScaffoldMessenger.of(dialogContext).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please fill in host, username, and password.'),
                                  ),
                                );
                                return;
                              }

                              Navigator.of(dialogContext).pop(
                                _NasConfig(host: host, username: username, password: password),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.95),
                              foregroundColor: Colors.black,
                              shape: const StadiumBorder(),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 18),
                            ),
                            child: const Text(
                              'Connect',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleConnect() async {
    if (_viewState != ConnectionState.idle) return;

    if (widget.provider.id == 'nas') {
      final config = await _showNasConfigDialog();
      if (config == null) return;

      setState(() => _viewState = ConnectionState.connecting);
      try {
        await StorageConnectionService().connectNas(
          host: config.host,
          username: config.username,
          password: config.password,
        );
        if (mounted) {
          setState(() => _viewState = ConnectionState.success);
          await Future.delayed(const Duration(milliseconds: 800));
          if (mounted) {
            setState(() => _viewState = ConnectionState.idle);
            context.read<StorageAccountsBloc>().add(LoadStorageAccounts());
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _viewState = ConnectionState.idle);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to connect: $e'), backgroundColor: Colors.redAccent),
          );
        }
      }
      return;
    }

    if (widget.provider.id == 'gdrive') {
      setState(() => _viewState = ConnectionState.connecting);
      // Short delay so the UI switches to the loading state immediately.
      await Future.delayed(const Duration(milliseconds: 400));
      try {
        await StorageConnectionService().connectGoogleDrive();
        if (mounted) {
          setState(() => _viewState = ConnectionState.success);
          await Future.delayed(const Duration(milliseconds: 1000));
          if (mounted) {
            setState(() => _viewState = ConnectionState.idle);
            context.read<StorageAccountsBloc>().add(LoadStorageAccounts());
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _viewState = ConnectionState.idle);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to connect: $e'), backgroundColor: Colors.redAccent),
          );
        }
      }
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAccounts = widget.connectedAccounts.isNotEmpty;
    final connectedIds = widget.connectedAccounts.map((a) => a.id).where((id) => id.isNotEmpty).toList();
    final connectedSubtitle = hasAccounts
        ? 'Connected${widget.connectedAccounts.first.email.isNotEmpty ? ' • ${widget.connectedAccounts.first.email}' : ''}'
        : null;
    return _ProviderTile(
      icon: widget.provider.icon,
      label: widget.provider.name,
      actionLabel: _viewState == ConnectionState.connecting
          ? '...'
          : (hasAccounts ? 'Remove' : 'Add'),
      onTap: _viewState == ConnectionState.idle
          ? (hasAccounts
              ? () => context.read<StorageAccountsBloc>().add(RemoveStorageAccounts(connectedIds))
              : _handleConnect)
          : null,
      subtitle: connectedSubtitle,
    );
  }
}

class _ProviderTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String actionLabel;
  final VoidCallback? onTap;
  final String? subtitle;

  const _ProviderTile({
    required this.icon,
    required this.label,
    required this.actionLabel,
    required this.onTap,
    required this.subtitle,
  });

  static const _orange500 = Color(0xFFF97316);
  static const _blue400 = Color(0xFF60A5FA);

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Material(
        color: Colors.white.withOpacity(0.06),
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withOpacity(0.10)),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _blue400.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _blue400.withOpacity(0.22)),
                  ),
                  child: Icon(icon, size: 18, color: _blue400.withOpacity(0.9)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.42),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  actionLabel,
                  style: const TextStyle(
                    color: _orange500,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.35)),
              ],
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPrimary ? const Color(0xFFF97316) : Colors.white.withOpacity(0.10),
          width: isPrimary ? 2.0 : 1.0,
        ),
        boxShadow: isPrimary
            ? [
                BoxShadow(
                  color: const Color(0xFFF97316).withOpacity(0.30),
                  spreadRadius: 2,
                  blurRadius: 15,
                  offset: const Offset(0, 0),
                ),
              ]
            : const [],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        account.name,
                        style: TextStyle(
                          color: Colors.white.withOpacity(isPrimary ? 1.0 : 0.75),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isPrimary) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF97316),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'PRIMARY',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  account.email,
                  style: TextStyle(color: Colors.white.withOpacity(isPrimary ? 0.70 : 0.40), fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              isPrimary ? Icons.star_rounded : Icons.star_border_rounded,
              color: isPrimary ? const Color(0xFFF97316) : Colors.white.withOpacity(0.30),
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

class _NasConfig {
  final String host;
  final String username;
  final String password;

  const _NasConfig({
    required this.host,
    required this.username,
    required this.password,
  });
}
