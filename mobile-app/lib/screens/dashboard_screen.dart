import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/godown_provider.dart';
import '../widgets/godown_card.dart';
import '../widgets/state_views.dart';

/// Owner Dashboard: greeting + summary + shortcut into My Godowns.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GodownProvider>().loadGodowns();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final godowns = context.watch<GodownProvider>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Owner Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      floatingActionButton: auth.isOwner
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/godowns/new'),
              icon: const Icon(Icons.add),
              label: const Text('Godown'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => context.read<GodownProvider>().loadGodowns(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome, ${user?.name ?? ''}',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text('${user?.email ?? ''} · ${user?.role ?? ''}',
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _StatChip(
                            label: 'My Godowns',
                            value: godowns.isLoading ? '…' : '${godowns.godowns.length}'),
                        const SizedBox(width: 8),
                        FilledButton.tonal(
                          onPressed: () => context.push('/godowns'),
                          child: const Text('View all'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (auth.isOwner)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.people_outline),
                  title: const Text('Staff Management'),
                  subtitle: const Text('Add staff and view your team'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => context.push('/staff'),
                ),
              ),
            if (auth.isOwner) const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent godowns', style: Theme.of(context).textTheme.titleMedium),
                TextButton(
                  onPressed: () => context.push('/godowns'),
                  child: const Text('My Godowns →'),
                ),
              ],
            ),
            if (godowns.isLoading)
              const LoadingView()
            else if (godowns.errorMessage != null)
              ErrorView(
                  message: godowns.errorMessage!,
                  onRetry: () => context.read<GodownProvider>().loadGodowns())
            else if (godowns.godowns.isEmpty)
              EmptyView(
                message: 'No godowns yet. Create your first godown.',
                actionLabel: auth.isOwner ? 'Create Godown' : null,
                onAction: auth.isOwner ? () => context.push('/godowns/new') : null,
              )
            else
              ...godowns.godowns.take(5).map(
                    (g) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GodownCard(
                        godown: g,
                        onTap: () => context.push('/godowns/${g.id}'),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
