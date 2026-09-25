import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/godown_provider.dart';
import '../widgets/state_views.dart';

/// Create (POST /api/godowns) or edit (PUT /api/godowns/:id).
/// Payload per backend: {name, location, capacity:number}.
class GodownFormScreen extends StatefulWidget {
  final String? godownId; // null -> create
  const GodownFormScreen({super.key, this.godownId});

  bool get isEdit => godownId != null;

  @override
  State<GodownFormScreen> createState() => _GodownFormScreenState();
}

class _GodownFormScreenState extends State<GodownFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _location = TextEditingController();
  final _capacity = TextEditingController();
  bool _prefilled = false;

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _capacity.dispose();
    super.dispose();
  }

  void _prefillIfReady(GodownProvider provider) {
    if (_prefilled || !widget.isEdit) return;
    if (provider.isLoading) return;
    final matches = provider.godowns.where((g) => g.id == widget.godownId).toList();
    if (matches.isNotEmpty) {
      _name.text = matches.first.name;
      _location.text = matches.first.location;
      _capacity.text = matches.first.capacity.toString();
      _prefilled = true;
    } else {
      // Fall back to server fetch (also covers cross-owner 404).
      _prefilled = true; // avoid repeat fetch loops
      provider.loadDetail(widget.godownId!).then((_) {
        final sel = provider.selected;
        if (sel != null && mounted) {
          setState(() {
            _name.text = sel.name;
            _location.text = sel.location;
            _capacity.text = sel.capacity.toString();
          });
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<GodownProvider>();
    final capacity = double.parse(_capacity.text.trim());
    final bool ok;
    if (widget.isEdit) {
      ok = await provider.update(
        widget.godownId!,
        name: _name.text.trim(),
        location: _location.text.trim(),
        capacity: capacity,
      );
    } else {
      ok = await provider.create(
        name: _name.text.trim(),
        location: _location.text.trim(),
        capacity: capacity,
      );
    }
    if (!mounted) return;
    if (ok) {
      showAppMessage(context, widget.isEdit ? 'Godown updated.' : 'Godown created.');
      context.pop();
    } else {
      showAppMessage(context, provider.errorMessage ?? 'Save failed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GodownProvider>();
    _prefillIfReady(provider);

    return Scaffold(
      appBar: AppBar(title: Text(widget.isEdit ? 'Edit Godown' : 'Create Godown')),
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
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Enter a name.' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _location,
                    decoration: const InputDecoration(labelText: 'Location'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Enter a location.' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _capacity,
                    decoration: const InputDecoration(labelText: 'Capacity (number ≥ 0)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      final n = double.tryParse((v ?? '').trim());
                      if (n == null || n < 0) return 'Enter a non-negative number.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: provider.isSaving ? null : _submit,
                    child: provider.isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(widget.isEdit ? 'Save changes' : 'Create godown'),
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
