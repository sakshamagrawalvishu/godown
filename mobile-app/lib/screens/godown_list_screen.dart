import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/godown_provider.dart';
import '../widgets/godown_card.dart';
import '../widgets/state_views.dart';

/// GET /api/godowns — shows only the caller's own godowns (backend-scoped).
class GodownListScreen extends StatefulWidget {
  const GodownListScreen({super.key});

  @override
  State<GodownListScreen> createState() => _GodownListScreenState();
}

class _GodownListScreenState extends State<GodownListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GodownProvider>().loadGodowns();
    });
  }

  Future<void> _confirmDelete(BuildContext context, String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete godown?'),
        content: Text(
            'Delete "$name"? This fails on the server while inventory items still reference it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final provider = context.read<GodownProvider>();
    final ok = await provider.remove(id);
    if (!context.mounted) return;
    showAppMessage(
        context, ok ? 'Godown deleted.' : (provider.errorMessage ?? 'Delete failed.'));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GodownProvider>();
    final isOwner = context.watch<AuthProvider>().isOwner;

    return Scaffold(
      appBar: AppBar(title: const Text('My Godowns')),
      floatingActionButton: isOwner
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/godowns/new'),
              icon: const Icon(Icons.add),
              label: const Text('New Godown'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => context.read<GodownProvider>().loadGodowns(),
        child: Builder(
          builder: (context) {
            if (provider.isLoading && provider.godowns.isEmpty) {
              return const LoadingView(message: 'Loading godowns…');
            }
            if (provider.errorMessage != null && provider.godowns.isEmpty) {
              return ErrorView(
                message: provider.errorMessage!,
                onRetry: () => context.read<GodownProvider>().loadGodowns(),
              );
            }
            if (provider.godowns.isEmpty) {
              return EmptyView(
                message: 'No godowns yet. Create your first godown.',
                actionLabel: isOwner ? 'Create Godown' : null,
                onAction: isOwner ? () => context.push('/godowns/new') : null,
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: provider.godowns.length,
              itemBuilder: (context, i) {
                final g = provider.godowns[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GodownCard(
                    godown: g,
                    onTap: () => context.push('/godowns/${g.id}'),
                    onEdit: isOwner ? () => context.push('/godowns/${g.id}/edit') : null,
                    onDelete:
                        isOwner ? () => _confirmDelete(context, g.id, g.name) : null,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
