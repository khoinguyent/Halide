import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/storage/presentation/bloc/storage_accounts_bloc.dart';
import 'package:frontend/models/storage_account.dart';
import '../widgets/storage_tier_selector.dart';
import '../widgets/cloud_providers_section.dart';

class StorageAccountListView extends StatefulWidget {
  const StorageAccountListView({Key? key}) : super(key: key);

  @override
  State<StorageAccountListView> createState() => _StorageAccountListViewState();
}

class _StorageAccountListViewState extends State<StorageAccountListView> {
  int _selectedTierIndex = 0;

  @override
  Widget build(BuildContext context) {
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
                  const Text(
                    'Storage Management',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage your cloud and local storage accounts',
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
                    child: _buildContentForTier(context),
                  ),
                ],
              ),
            ),
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
        return SingleChildScrollView(child: const CloudProvidersSection());
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
        const Text(
          'Connected Accounts',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: BlocBuilder<StorageAccountsBloc, StorageAccountsState>(
            builder: (context, state) {
              if (state is StorageAccountsLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state is StorageAccountsError) {
                return Center(
                  child: Text(state.message, style: const TextStyle(color: Colors.red)),
                );
              }
              if (state is StorageAccountsLoaded) {
                final localOnly = state.accounts
                    .where((a) => a.type == StorageAccountType.local)
                    .toList();
                if (localOnly.isEmpty) {
                  return Center(
                    child: Text(
                      'No local device account',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: localOnly.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    return _StorageAccountCard(account: localOnly[index]);
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSystemCloudContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'System Cloud',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Upgrade above to get Pro storage. After upgrading, your account will appear here.',
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 24),
        const SizedBox.shrink(),
      ],
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
