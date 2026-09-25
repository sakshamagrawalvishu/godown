import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/godown_provider.dart';
import '../providers/inventory_provider.dart';
import '../utils/inventory_utils.dart';
import '../widgets/state_views.dart';

/// Godown Details + Inventory Management for the selected godown.
/// Inventory: `GET /api/inventory` with godown filter, mutations OWNER-only.
/// Search filters the already-loaded list locally by item name.
class GodownDetailScreen extends StatefulWidget {
  final String godownId;
  const GodownDetailScreen({super.key, required this.godownId});

  @override
  State<GodownDetailScreen> createState() => _GodownDetailScreenState();
}

class _GodownDetailScreenState extends State<GodownDetailScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _search.addListener(() {
      if (_query != _search.text) setState(() => _query = _search.text);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GodownProvider>().loadDetail(widget.godownId);
      context.read<InventoryProvider>().loadItems(widget.godownId);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _confirmDeleteInventory(String id, String name) async {
    final provider = context.read<InventoryProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text('Delete "$name" from this godown?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await provider.remove(id);
    if (!mounted) return;
    showAppMessage(context, ok ? 'Item deleted.' : (provider.errorMessage ?? 'Delete failed.'));
  }

  @override
  Widget build(BuildContext context) {
    final godowns = context.watch<GodownProvider>();
    final inventory = context.watch<InventoryProvider>();
    final isOwner = context.watch<AuthProvider>().isOwner;
    final godown = godowns.selected?.id == widget.godownId
        ? godowns.selected
        : null;
    final visibleItems = filterInventoryByName(inventory.items, _query);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Godown Details'),
        actions: [
          if (isOwner && godown != null)
            IconButton(
              tooltip: 'Edit godown',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/godowns/${widget.godownId}/edit'),
            ),
        ],
      ),
      floatingActionButton: isOwner
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/godowns/${widget.godownId}/inventory/new'),
              icon: const Icon(Icons.add),
              label: const Text('Item'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async {
          if (!mounted) return;
          final godownProvider = context.read<GodownProvider>();
          final inventoryProvider = context.read<InventoryProvider>();
          await godownProvider.loadDetail(widget.godownId);
          await inventoryProvider.loadItems(widget.godownId);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (godowns.isLoading && godown == null)
              const LoadingView(message: 'Loading godown…')
            else if (godowns.errorMessage != null && godown == null)
              ErrorView(
                message: godowns.errorMessage!,
                onRetry: () => context.read<GodownProvider>().loadDetail(widget.godownId),
              )
            else if (godown != null)
              _GodownSummaryCard(
                name: godown.name,
                location: godown.location,
                capacity: godown.capacity,
                itemCount: inventory.items.length,
                stock: stockSummary(inventory.items),
              ),
            const SizedBox(height: 16),
            Text('Inventory', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (inventory.isLoading && inventory.items.isEmpty)
              const LoadingView(message: 'Loading inventory…')
            else if (inventory.errorMessage != null && inventory.items.isEmpty)
              ErrorView(
                message: inventory.errorMessage!,
                onRetry: () =>
                    context.read<InventoryProvider>().loadItems(widget.godownId),
              )
            else if (inventory.items.isEmpty)
              EmptyView(
                message: isOwner
                    ? 'No inventory in this godown yet. Add your first item.'
                    : 'No inventory available in this godown yet.',
                actionLabel: isOwner ? 'Add item' : null,
                onAction: isOwner
                    ? () => context.push('/godowns/${widget.godownId}/inventory/new')
                    : null,
              )
            else ...[
              TextField(
                controller: _search,
                decoration: InputDecoration(
                  labelText: 'Search items',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.clear),
                          onPressed: () => _search.clear(),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              if (visibleItems.isEmpty)
                EmptyView(
                  message: 'No items match "$_query".',
                  actionLabel: 'Clear search',
                  onAction: () => _search.clear(),
                )
              else
                ...visibleItems.map(
                  (item) => Card(
                    child: ListTile(
                      title: Text(item.itemName),
                      subtitle: Text('${formatQuantity(item.quantity)} ${item.unit}'),
                      trailing: isOwner
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Edit',
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => context.push(
                                    '/godowns/${widget.godownId}/inventory/${item.id}/edit',
                                    extra: item,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Delete',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () =>
                                      _confirmDeleteInventory(item.id, item.itemName),
                                ),
                              ],
                            )
                          : null,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Godown summary: capacity plus a separate stock total.
///
/// Stock units vary per item (bags, kg, pieces), so the totals cannot be
/// compared against capacity as a percentage. Both figures are shown
/// side-by-side instead of pretending one represents usage of the other.
class _GodownSummaryCard extends StatelessWidget {
  final String name;
  final String location;
  final double capacity;
  final int itemCount;
  final String stock;

  const _GodownSummaryCard({
    required this.name,
    required this.location,
    required this.capacity,
    required this.itemCount,
    required this.stock,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(location),
            const SizedBox(height: 12),
            Row(
              children: [
                _SummaryStat(label: 'Capacity', value: formatQuantity(capacity)),
                const SizedBox(width: 12),
                _SummaryStat(label: 'Items', value: '$itemCount'),
              ],
            ),
            const SizedBox(height: 8),
            Text('Stock: $stock', style: theme.textTheme.bodyMedium),
            Text(
              'Stock is totaled per unit and shown separately; units vary, so it is not a capacity percentage.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryStat({required this.label, required this.value});

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
