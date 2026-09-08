import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/l10n/l10n_extension.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/features/storage/presentation/bloc/storage_accounts_bloc.dart';
import 'package:frontend/models/storage_account.dart';
import '../widgets/storage_tier_selector.dart';
import '../widgets/cloud_providers_section.dart';
import 'package:frontend/core/theme/halide_colors.dart';

class StorageAccountListView extends StatefulWidget {
  const StorageAccountListView({Key? key}) : super(key: key);

  @override
  State<StorageAccountListView> createState() => _StorageAccountListViewState();
}

class _StorageAccountListViewState extends State<StorageAccountListView> {
  int _selectedTierIndex = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocProvider(
      create: (context) => StorageAccountsBloc()..add(LoadStorageAccounts()),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.storageManagement,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.manageStorageAccountsSubtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 32),
                  StorageTierSelector(
                    selectedIndex: _selectedTierIndex,
                    onSelected: (index) => setState(() => _selectedTierIndex = index),
                  ),
                  const SizedBox(height: 32),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: _buildContentForTier(context, l10n),
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

  Widget _buildContentForTier(BuildContext context, AppLocalizations l10n) {
    return BlocBuilder<StorageAccountsBloc, StorageAccountsState>(
      builder: (context, state) {
        if (state is StorageAccountsLoading) {
          return Center(child: CircularProgressIndicator(color: HalideColors.of(context).accent));
        }
        if (state is StorageAccountsError) {
          return Center(
            child: Text(state.message, style: const TextStyle(color: Colors.redAccent)),
          );
        }
        if (state is StorageAccountsLoaded) {
          switch (_selectedTierIndex) {
            case 0:
              return _buildAccountList(
                context,
                state.accounts.where((a) => a.type == StorageAccountType.local).toList(),
                l10n: l10n,
                title: l10n.localAccounts,
              );
            case 1:
              return CloudProvidersSection(accounts: state.accounts);
            case 2:
              return _buildAccountList(
                context,
                state.accounts.where((a) => a.type == StorageAccountType.system).toList(),
                l10n: l10n,
                title: l10n.systemCloud,
                emptyDescription: l10n.systemCloudAfterUpgradeHint,
              );
            default:
              return const SizedBox.shrink();
          }
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildAccountList(
    BuildContext context,
    List<StorageAccount> accounts, {
    required AppLocalizations l10n,
    required String title,
    String? emptyDescription,
  }) {
    if (accounts.isEmpty && emptyDescription != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: title),
          const SizedBox(height: 12),
          Text(
            emptyDescription,
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13, height: 1.5),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: title),
        const SizedBox(height: 16),
        ListView.separated(
          key: const Key('account_list_view'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: accounts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return _StorageAccountCard(account: accounts[index]);
          },
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
      ),
    );
  }
}

class _StorageAccountCard extends StatelessWidget {
  final StorageAccount account;

  const _StorageAccountCard({Key? key, required this.account}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              _buildIcon(account.type),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      account.email,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  account.isPrimary ? Icons.star : Icons.star_border,
                  color: account.isPrimary ? const Color(0xFFFFD700) : Colors.white.withOpacity(0.3),
                  size: 28,
                ),
                onPressed: () {
                  context.read<StorageAccountsBloc>().add(TogglePrimaryAccount(account.id));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(StorageAccountType type) {
    IconData iconData;
    Color color;

    switch (type) {
      case StorageAccountType.local:
        iconData = Icons.smartphone;
        color = const Color(0xFF60A5FA);
        break;
      case StorageAccountType.personal:
        iconData = Icons.cloud_outlined;
        color = const Color(0xFFF472B6);
        break;
      case StorageAccountType.system:
        iconData = Icons.auto_awesome;
        color = const Color(0xFFA78BFA);
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, color: color, size: 24),
    );
  }
}
