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
  static const _zinc950 = Color(0xFF09090B);
  static const _orange500 = Color(0xFFF97316);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => StorageAccountsBloc()..add(LoadStorageAccounts()),
      child: HalideScaffold(
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
              StorageTierSelector(
                selectedIndex: _selectedTierIndex,
                onSelected: (index) => setState(() => _selectedTierIndex = index),
              ),
              const SizedBox(height: 22),
              _buildContentForTier(context),
            ],
          ),
        ),
      ),
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
              return _buildAccountList(
                context, 
                state.accounts.where((a) => a.type == StorageAccountType.system).toList(),
                title: 'SYSTEM CLOUD',
                emptyDescription: 'Upgrade above to get Pro storage. Each account includes 5–10 GB by default.',
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
