import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/staff_provider.dart';
import '../widgets/state_views.dart';

/// Owner-only Staff Management list (GET /api/users?role=STAFF).
/// STAFF users never see the entry point (dashboard hides it, router
/// redirects them), and the backend rejects them with 403 regardless.
class StaffListScreen extends StatefulWidget {
  const StaffListScreen({super.key});

  @override
  State<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends State<StaffListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!context.read<AuthProvider>().isOwner) return;
      context.read<StaffProvider>().loadStaff();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isOwner) {
      return Scaffold(
        appBar: AppBar(title: const Text('Staff')),
        body: const EmptyView(
          message: 'Staff management is available to owners only.',
        ),
      );
    }

    final provider = context.watch<StaffProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Staff Management')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/staff/new'),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Add Staff'),
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<StaffProvider>().loadStaff(),
        child: Builder(
          builder: (context) {
            if (provider.isLoading && provider.staff.isEmpty) {
              return const LoadingView(message: 'Loading staff…');
            }
            if (provider.errorMessage != null && provider.staff.isEmpty) {
              return ErrorView(
                message: provider.errorMessage!,
                onRetry: () => context.read<StaffProvider>().loadStaff(),
              );
            }
            if (provider.staff.isEmpty) {
              return EmptyView(
                message: 'No staff yet. Add your first staff member.',
                actionLabel: 'Add Staff',
                onAction: () => context.push('/staff/new'),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: provider.staff.length,
              itemBuilder: (context, i) {
                final s = provider.staff[i];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                      ),
                    ),
                    title: Text(s.name),
                    subtitle: Text(s.email),
                    trailing: _ActiveChip(isActive: s.isActive),
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

class _ActiveChip extends StatelessWidget {
  final bool isActive;
  const _ActiveChip({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}
