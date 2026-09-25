import 'package:flutter/material.dart';

import '../models/godown.dart';

/// Card for a single godown in the list / dashboard.
class GodownCard extends StatelessWidget {
  final Godown godown;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const GodownCard({
    super.key,
    required this.godown,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(godown.name, style: Theme.of(context).textTheme.titleMedium),
                  ),
                  if (onEdit != null)
                    IconButton(
                      tooltip: 'Edit',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: onEdit,
                    ),
                  if (onDelete != null)
                    IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: onDelete,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 16),
                  const SizedBox(width: 4),
                  Expanded(child: Text(godown.location)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.warehouse_outlined, size: 16),
                  const SizedBox(width: 4),
                  Text('Capacity: ${godown.capacity.toStringAsFixed(godown.capacity % 1 == 0 ? 0 : 2)}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
