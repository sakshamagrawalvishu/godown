import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/inventory_item.dart';
import '../providers/auth_provider.dart';
import '../providers/godown_provider.dart';
import '../providers/inventory_provider.dart';
import '../utils/inventory_utils.dart';
import '../widgets/state_views.dart';

/// Add (POST /api/inventory) or edit (PUT /api/inventory/:id) an item.
/// Backend payload: {itemName, quantity:number, unit, godown}.
/// Edit mode (OWNER only) also allows moving the item to another godown
/// via PUT /api/inventory/:id {godown}; the backend validates ownership.
class InventoryFormScreen extends StatefulWidget {
  final String godownId;
  final InventoryItem? existing; // null -> create

  const InventoryFormScreen({super.key, required this.godownId, this.existing});

  bool get isEdit => existing != null;

  @override
  State<InventoryFormScreen> createState() => _InventoryFormScreenState();
}

class _InventoryFormScreenState extends State<InventoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _quantity;
  late final TextEditingController _unit;
  String? _selectedGodownId;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.itemName ?? '');
    _quantity = TextEditingController(
        text: widget.existing == null ? '' : formatQuantity(widget.existing!.quantity));
    _unit = TextEditingController(text: widget.existing?.unit ?? '');
    _selectedGodownId = widget.existing?.godownId ?? widget.godownId;
    if (widget.isEdit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final godowns = context.read<GodownProvider>();
        if (godowns.godowns.isEmpty && !godowns.isLoading) {
          godowns.loadGodowns();
        }
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _unit.dispose();
    super.dispose();
  }

  double get _currentQuantity =>
      double.tryParse(_quantity.text.trim()) ?? 0;

  void _stepQuantity(double step) {
    setState(() {
      _quantity.text = formatQuantity(stepQuantity(_currentQuantity, step));
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<InventoryProvider>();
    final quantity = clampQuantity(double.parse(_quantity.text.trim()));
    final bool ok;
    if (widget.isEdit) {
      // Only send godown when it actually changed; backend validates it.
      final original = widget.existing!.godownId;
      final target = _selectedGodownId;
      ok = await provider.update(
        widget.existing!.id,
        itemName: _name.text.trim(),
        quantity: quantity,
        unit: _unit.text.trim(),
        godownId: (target != null && target != original) ? target : null,
      );
    } else {
      ok = await provider.create(
        itemName: _name.text.trim(),
        quantity: quantity,
        unit: _unit.text.trim(),
        godownId: widget.godownId,
      );
    }
    if (!mounted) return;
    if (ok) {
      showAppMessage(context, widget.isEdit ? 'Item updated.' : 'Item added.');
      context.pop();
    } else {
      showAppMessage(context, provider.errorMessage ?? 'Save failed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InventoryProvider>();
    final isOwner = context.watch<AuthProvider>().isOwner;
    return Scaffold(
      appBar: AppBar(title: Text(widget.isEdit ? 'Edit Item' : 'Add Item')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Item name'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Enter an item name.' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: IconButton.filledTonal(
                          tooltip: 'Decrease quantity',
                          icon: const Icon(Icons.remove),
                          onPressed: provider.isSaving ? null : () => _stepQuantity(-1),
                        ),
                      ),
                      Expanded(
                        child: TextFormField(
                          controller: _quantity,
                          decoration: const InputDecoration(
                              labelText: 'Quantity (number ≥ 0)'),
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) {
                            final n = double.tryParse((v ?? '').trim());
                            if (n == null || n < 0) {
                              return 'Enter a non-negative number.';
                            }
                            return null;
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: IconButton.filledTonal(
                          tooltip: 'Increase quantity',
                          icon: const Icon(Icons.add),
                          onPressed: provider.isSaving ? null : () => _stepQuantity(1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _unit,
                    decoration:
                        const InputDecoration(labelText: 'Unit (e.g. bags, kg, pieces)'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Enter a unit.' : null,
                  ),
                  if (widget.isEdit && isOwner) ...[
                    const SizedBox(height: 12),
                    _GodownSelector(
                      selectedId: _selectedGodownId,
                      onChanged: (id) => setState(() => _selectedGodownId = id),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: provider.isSaving ? null : _submit,
                    child: provider.isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(widget.isEdit ? 'Save changes' : 'Add item'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Owner-only godown picker for moving an item. Options come from the
/// existing [GodownProvider] list; the current godown starts selected.
class _GodownSelector extends StatelessWidget {
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  const _GodownSelector({required this.selectedId, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final godowns = context.watch<GodownProvider>();
    final options = godowns.godowns;
    final value = options.any((g) => g.id == selectedId) ? selectedId : null;

    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: const InputDecoration(
        labelText: 'Godown (move item)',
        helperText: 'Changing this moves the item to another godown.',
      ),
      items: options
          .map((g) => DropdownMenuItem(
                value: g.id,
                child: Text('${g.name} · ${g.location}'),
              ))
          .toList(),
      onChanged: godowns.isLoading ? null : onChanged,
      validator: (v) {
        // While the godown list is still loading there is nothing to pick
        // from; submitting then keeps the item in its current godown.
        if (options.isEmpty) return null;
        return v == null ? 'Select a godown.' : null;
      },
    );
  }
}
