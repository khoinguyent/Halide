import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/widgets/halide_scaffold.dart';
import 'package:frontend/features/storage/presentation/bloc/storage_accounts_bloc.dart';
import 'package:frontend/models/storage_account.dart';
import 'package:frontend/features/storage/presentation/widgets/storage_tier_selector.dart';
import 'package:frontend/features/storage/presentation/widgets/cloud_providers_section.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/storage_accounts_refresh_provider.dart';
import '../../../../models/user_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;
import '../../../../core/providers/notification_provider.dart';
import '../../../../core/models/notification_model.dart';

class StorageStrategyView extends riverpod.ConsumerStatefulWidget {
  final StorageAccountsBloc? bloc;
  const StorageStrategyView({Key? key, this.bloc}) : super(key: key);

  @override
  riverpod.ConsumerState<StorageStrategyView> createState() => _StorageStrategyViewState();
}

class _StorageStrategyViewState extends riverpod.ConsumerState<StorageStrategyView> {
  late int _selectedTierIndex;
  static const _zinc950 = Color(0xFF09090B);
  static const _orange500 = Color(0xFFF97316);

  static String _formatGbFromBytes(int bytes, {int fractionDigits = 2}) {
    final gb = bytes / (1024 * 1024 * 1024);
    return '${gb.toStringAsFixed(fractionDigits)} GB';
  }

  @override
  void initState() {
    super.initState();
    final plan = ref.read(userPlanProvider);
    _selectedTierIndex = plan != UserPlan.free ? 1 : 0;
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(userPlanProvider);
    final isFree = plan == UserPlan.free;
    final storageListVersion = ref.watch(storageAccountsListVersionProvider);

    final shell = HalideScaffold(
        backgroundColor: _zinc950,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
            color: Colors.white,
          ),
          centerTitle: true,
          title: const Text(
            'STORAGE STRATEGY',
            style: TextStyle(
              letterSpacing: 2.0,
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSystemCloudQuotaBanner(ref),
              const SizedBox(height: 16),
              StorageTierSelector(
                selectedIndex: _selectedTierIndex,
                isFree: isFree,
                onSelected: (index) {
                  if (isFree && index > 1) {
                    ref.read(notificationProvider.notifier).show(
                      'System Cloud requires Pro features. Professional sync is limited to individual cloud accounts.',
                      type: NotificationType.warning,
                    );
                    return;
                  }
                  setState(() => _selectedTierIndex = index);
                },
              ),
              const SizedBox(height: 22),
              _buildContentForTier(context),
            ],
          ),
        ),
      );

    if (widget.bloc != null) {
      return BlocProvider(
        create: (_) => widget.bloc!,
        child: shell,
      );
    }

    return BlocProvider(
      key: ValueKey(storageListVersion),
      create: (_) => StorageAccountsBloc()..add(LoadStorageAccounts()),
      child: shell,
    );
  }

  /// Backend quota from GET /api/v1/me (shows **0 GB** when empty, not an em dash).
  Widget _buildSystemCloudQuotaBanner(riverpod.WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    return profileAsync.when(
      data: (UserProfile? p) {
        if (p == null || p.totalStorageLimitBytes == null) {
          return const SizedBox.shrink();
        }
        final used = p.storageUsedBytes ?? 0;
        final cap = p.totalStorageLimitBytes!;
        final usedLabel = _formatGbFromBytes(used, fractionDigits: 2);
        final capLabel = _formatGbFromBytes(cap, fractionDigits: 1);
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SYSTEM CLOUD QUOTA',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$usedLabel used of $capLabel',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if ((p.additionalStorageBytes ?? 0) > 0) ...[
                const SizedBox(height: 6),
                Text(
                  '+${_formatGbFromBytes(p.additionalStorageBytes!, fractionDigits: 1)} from add-on purchases',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: _orange500),
          ),
        ),
      ),
      error: (Object _, StackTrace _) => const SizedBox.shrink(),
    );
  }

  Widget _buildContentForTier(BuildContext context) {
    return BlocBuilder<StorageAccountsBloc, StorageAccountsState>(
      builder: (context, state) {
        if (state is StorageAccountsLoading) {
          return const Padding(
            padding: EdgeInsets.all(64),
            child: Center(child: CircularProgressIndicator(color: _orange500)),
          );
        }
        if (state is StorageAccountsError) {
          return Center(child: Text(state.message, style: const TextStyle(color: Colors.redAccent)));
        }
        if (state is StorageAccountsLoaded) {
          switch (_selectedTierIndex) {
            case 0:
              return _buildAccountList(
                context, 
                state.accounts.where((a) => a.type == StorageAccountType.local).toList(),
                title: 'LOCAL STORAGE',
              );
            case 1:
              return CloudProvidersSection(accounts: state.accounts);
            case 2:
              final systemAccounts = state.accounts.where((a) => a.type == StorageAccountType.system).toList();
              if (systemAccounts.isEmpty) {
                return _buildAccountList(
                  context, 
                  [],
                  title: 'SYSTEM CLOUD',
                  emptyDescription: 'Upgrade above to get Pro storage. Each account includes 5–10 GB by default.',
                );
              }
              final systemAccount = systemAccounts.first;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StorageConsumptionCard(account: systemAccount),
                  const SizedBox(height: 24),
                  _buildAccountList(
                    context, 
                    systemAccounts,
                    title: 'SYSTEM CLOUD CONNECTIONS',
                  ),
                ],
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
    List<StorageAccount> accounts, 
    {required String title, String? emptyDescription}
  ) {
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
        ...accounts.map((a) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _StorageAccountCard(account: a),
        )).toList(),
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
    final isPrimary = account.isPrimary;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isPrimary ? const Color(0xFFF97316) : Colors.white.withOpacity(0.10),
              width: isPrimary ? 2 : 1,
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
              _buildIcon(account.type),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            account.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
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
                    const SizedBox(height: 4),
                    Text(
                      account.email,
                      style: TextStyle(
                        color: Colors.white.withOpacity(isPrimary ? 0.70 : 0.50),
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  account.isPrimary ? Icons.star_rounded : Icons.star_border_rounded,
                  color: account.isPrimary ? const Color(0xFFF97316) : Colors.white.withOpacity(0.35),
                  size: 28,
                ),
                onPressed: () {
                  context.read<StorageAccountsBloc>().add(TogglePrimaryAccount(account.id));
                },
                tooltip: account.isPrimary ? 'Primary' : 'Set as Primary',
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
        iconData = Icons.smartphone_outlined;
        color = const Color(0xFF94A3B8);
        break;
      case StorageAccountType.personal:
        iconData = Icons.cloud_outlined;
        color = const Color(0xFF60A5FA);
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

class _StorageConsumptionCard extends StatelessWidget {
  final StorageAccount account;
  const _StorageConsumptionCard({Key? key, required this.account}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final used = account.storageUsed ?? 0;
    final limit = account.storageLimit ?? (100 * 1024 * 1024);
    final percent = (used / limit).clamp(0.0, 1.0);
    
    final usedGb = (used / (1024 * 1024 * 1024)).toStringAsFixed(2);
    final limitGb = (limit / (1024 * 1024 * 1024)).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'STORAGE USAGE',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                '$usedGb GB of $limitGb GB',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 12,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(
                percent > 0.9 ? Colors.redAccent : const Color(0xFFF97316),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.push('/profile/settings/add-storage'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF97316),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text(
                'ADD MORE STORAGE',
                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
