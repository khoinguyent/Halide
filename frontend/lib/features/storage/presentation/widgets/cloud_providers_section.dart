import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/l10n/l10n_extension.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/core/providers/notification_provider.dart';
import 'package:frontend/core/models/notification_model.dart';
import 'package:frontend/core/widgets/halide_dialog.dart';
import 'package:frontend/features/storage/presentation/bloc/storage_accounts_bloc.dart';
import 'package:frontend/models/storage_account.dart';
import 'package:frontend/services/storage_connection_service.dart';
import 'package:frontend/core/theme/halide_colors.dart';

class CloudProviderInfo {
  final String id;
  /// Canonical provider name from the backend (used for account matching).
  final String backendName;
  final IconData icon;

  const CloudProviderInfo({
    required this.id,
    required this.backendName,
    required this.icon,
  });
}

class CloudProvidersSection extends StatelessWidget {
  final List<StorageAccount> accounts;
  const CloudProvidersSection({Key? key, required this.accounts}) : super(key: key);

  static const List<CloudProviderInfo> _providers = [
    CloudProviderInfo(id: 'gdrive', backendName: 'Google Drive', icon: Icons.drive_file_move_outlined),
    CloudProviderInfo(id: 'nas', backendName: 'NAS', icon: Icons.storage_outlined),
  ];

  String _providerLabel(AppLocalizations l10n, CloudProviderInfo provider) {
    switch (provider.id) {
      case 'gdrive':
        return l10n.googleDrive;
      case 'nas':
        return l10n.nasProvider;
      default:
        return provider.backendName;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.cloudProvidersTitle,
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.cloudProvidersSubtitle,
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
                .where((a) => a.providerName == provider.backendName)
                .toList();
            return _CloudProviderGroup(
              provider: provider,
              displayName: _providerLabel(l10n, provider),
              connectedAccounts: providerAccounts,
            );
          },
        ),
      ],
    );
  }
}

enum ConnectionState { idle, connecting, success }

class _NasConfig {
  final String host;
  final String username;
  final String password;
  _NasConfig({required this.host, required this.username, required this.password});
}

class _CloudProviderGroup extends ConsumerStatefulWidget {
  final CloudProviderInfo provider;
  final String displayName;
  final List<StorageAccount> connectedAccounts;
  const _CloudProviderGroup({
    Key? key,
    required this.provider,
    required this.displayName,
    required this.connectedAccounts,
  }) : super(key: key);

  @override
  _CloudProviderGroupState createState() => _CloudProviderGroupState();
}

class _CloudProviderGroupState extends ConsumerState<_CloudProviderGroup> {
  ConnectionState _viewState = ConnectionState.idle;

  Future<_NasConfig?> _showNasConfigDialog() async {
    final hostController = TextEditingController();
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();

    final l10n = context.l10n;
    return showHalideDialog<_NasConfig>(
      context: context,
      builder: (dialogContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(dialogContext).viewInsets.bottom),
        child: HalideModalContainer(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.nasConfigurationTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.nasConfigSubtitle.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 32),
              HalideTextField(
                controller: hostController,
                label: l10n.host.toUpperCase(),
                prefixIcon: Icons.dns_outlined,
              ),
              const SizedBox(height: 16),
              HalideTextField(
                controller: usernameController,
                label: l10n.username.toUpperCase(),
                prefixIcon: Icons.person_outline,
              ),
              const SizedBox(height: 16),
              HalideTextField(
                controller: passwordController,
                label: l10n.passwordField.toUpperCase(),
                prefixIcon: Icons.lock_outline,
                obscureText: true,
              ),
              const SizedBox(height: 48),
              HalideActionButton(
                text: l10n.connectNas.toUpperCase(),
                onPressed: () {
                  final host = hostController.text.trim();
                  final username = usernameController.text.trim();
                  final password = passwordController.text;

                  if (host.isEmpty || username.isEmpty || password.isEmpty) {
                    ref.read(notificationProvider.notifier).show(
                      l10n.fillAllFields,
                      type: NotificationType.error,
                    );
                    return;
                  }

                  Navigator.of(dialogContext).pop(
                    _NasConfig(host: host, username: username, password: password),
                  );
                },
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(null),
                child: Text(
                  l10n.cancelUpper,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
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
          showHalideDialog(
            context: context,
            builder: (dialogContext) => HalideSimpleDialog(
              title: context.l10n.connectionFailed,
              message: e.toString(),
            ),
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
          showHalideDialog(
            context: context,
            builder: (dialogContext) => HalideSimpleDialog(
              title: context.l10n.connectionFailed,
              message: e.toString(),
            ),
          );
        }
      }
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasAccounts = widget.connectedAccounts.isNotEmpty;
    final isGDrive = widget.provider.id == 'gdrive';
    // Only allow one GDrive account. If connected, hide the 'Add' action.
    final hideAddAction = isGDrive && hasAccounts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProviderTile(
          icon: widget.provider.icon,
          label: widget.displayName,
          actionLabel: hideAddAction ? null : (_viewState == ConnectionState.connecting ? '...' : l10n.addAction),
          onTap: (hideAddAction || _viewState != ConnectionState.idle) ? null : _handleConnect,
          subtitle: hasAccounts ? l10n.connectedCount(widget.connectedAccounts.length) : null,
          showChevron: !hideAddAction,
        ),
        if (hasAccounts) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Column(
              children: widget.connectedAccounts
                  .map((a) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _GroupedAccountCard(account: a, l10n: l10n),
                      ))
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }
}

class _ProviderTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? actionLabel;
  final VoidCallback? onTap;
  final String? subtitle;
  final bool showChevron;

  const _ProviderTile({
    required this.icon,
    required this.label,
    required this.actionLabel,
    required this.onTap,
    required this.subtitle,
    this.showChevron = true,
  });

  static const _blue400 = Color(0xFF60A5FA);

  @override
  Widget build(BuildContext context) {
    final accent = HalideColors.of(context).accent;
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
                if (actionLabel != null)
                  Text(
                    actionLabel!,
                    style: TextStyle(
                      color: accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                if (showChevron) ...[
                  const SizedBox(width: 10),
                  Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.35)),
                ],
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
  final AppLocalizations l10n;
  const _GroupedAccountCard({Key? key, required this.account, required this.l10n}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isPrimary = account.isPrimary;
    final isGDrive = account.providerName == 'Google Drive';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPrimary ? HalideColors.of(context).accent : Colors.white.withOpacity(0.10),
          width: isPrimary ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        children: [
          Row(
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
                              color: Colors.white.withOpacity(isPrimary ? 1.0 : 0.85),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isPrimary) ...[
                          SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: HalideColors.of(context).accent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              l10n.priBadge,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      account.email,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.40),
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.redAccent.withOpacity(0.7),
                  size: 20,
                ),
                onPressed: () {
                  context.read<StorageAccountsBloc>().add(RemoveStorageAccounts([account.id]));
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 12),
          // Feature Toggles
          _FeatureToggleRow(
            label: l10n.archiveStorage,
            description: l10n.archiveStorageDescription,
            value: account.isArchive,
            onChanged: (val) {
              context.read<StorageAccountsBloc>().add(
                    UpdateStorageAccountFlags(accountId: account.id, isArchive: val),
                  );
            },
          ),
          if (isGDrive) ...[
            const SizedBox(height: 8),
            _FeatureToggleRow(
              label: l10n.labScanSync,
              description: l10n.labScanSyncDescription,
              value: account.isScanSync,
              onChanged: (val) {
                context.read<StorageAccountsBloc>().add(
                      UpdateStorageAccountFlags(accountId: account.id, isScanSync: val),
                    );
              },
            ),
            const SizedBox(height: 12),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 12),
            _BackupRollsAction(),
          ],
        ],
      ),
    );
  }
}

/// Entry point into the roll picker that triggers Agxel Vault backups on this
/// connected Google Drive account. Lives here since backup is per-connection.
class _BackupRollsAction extends StatelessWidget {
  const _BackupRollsAction();

  @override
  Widget build(BuildContext context) {
    final accent = HalideColors.of(context).accent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => context.push('/personal-drive-backup'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(Icons.cloud_upload_outlined, size: 16, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Backup rolls to this Drive',
                  style: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 18, color: accent.withOpacity(0.7)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureToggleRow extends StatelessWidget {
  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _FeatureToggleRow({
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Text(
                description,
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
              ),
            ],
          ),
        ),
        Transform.scale(
          scale: 0.8,
          child: Switch(
            value: value,
            onChanged: onChanged,
            activeColor: HalideColors.of(context).accent,
            activeTrackColor: HalideColors.of(context).accent.withOpacity(0.2),
          ),
        ),
      ],
    );
  }
}

