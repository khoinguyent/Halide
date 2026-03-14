import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/widgets/halide_scaffold.dart';
import 'package:frontend/features/storage/presentation/bloc/storage_accounts_bloc.dart';
import 'package:frontend/models/storage_account.dart';
import 'package:frontend/features/storage/presentation/widgets/storage_tier_selector.dart';
import 'package:frontend/features/storage/presentation/widgets/cloud_providers_section.dart';

class StorageStrategyView extends StatefulWidget {
  const StorageStrategyView({Key? key}) : super(key: key);

  @override
  State<StorageStrategyView> createState() => _StorageStrategyViewState();
}

class _StorageStrategyViewState extends State<StorageStrategyView> {
  int _selectedTierIndex = 0;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => StorageAccountsBloc()..add(LoadStorageAccounts()),
      child: HalideScaffold(
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
              letterSpacing: 4,
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
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StorageTierSelector(
                selectedIndex: _selectedTierIndex,
                onSelected: (index) => setState(() => _selectedTierIndex = index),
              ),
              const SizedBox(height: 28),
              _buildContentForTier(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContentForTier(BuildContext context) {
    switch (_selectedTierIndex) {
      case 0:
        return _buildLocalDeviceContent(context);
      case 1:
        return const CloudProvidersSection();
      case 2:
        return _buildSystemCloudContent(context);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildLocalDeviceContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Connected Accounts',
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        BlocBuilder<StorageAccountsBloc, StorageAccountsState>(
          builder: (context, state) {
            if (state is StorageAccountsLoading) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator(color: Colors.white54)),
              );
            }
            if (state is StorageAccountsError) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text(state.message, style: const TextStyle(color: Colors.redAccent)),
              );
            }
            if (state is StorageAccountsLoaded) {
              final localOnly = state.accounts
                  .where((a) => a.type == StorageAccountType.local)
                  .toList();
              return Column(
                children: localOnly
                    .map((a) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _StorageAccountCard(account: a),
                        ))
                    .toList(),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Widget _buildSystemCloudContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'System Cloud',
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Upgrade above to get Pro storage. Each account includes 5–10 GB by default; you can add more storage at checkout. After upgrading, your account will appear here.',
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ],
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
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isPrimary ? const Color(0xFFF97316) : Colors.white.withOpacity(0.1),
              width: isPrimary ? 2 : 1,
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
                              color: const Color(0xFFF97316).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFF97316).withOpacity(0.5)),
                            ),
                            child: const Text(
                              'PRIMARY',
                              style: TextStyle(
                                color: Color(0xFFF97316),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
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
                        color: Colors.white.withOpacity(0.5),
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
