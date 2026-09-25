import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/staff_provider.dart';
import '../widgets/state_views.dart';

/// Owner creates a STAFF account (POST /api/users {name,email,password}).
/// Backend forces role=STAFF and links owner=caller; duplicates yield 409.
class StaffCreateScreen extends StatefulWidget {
  const StaffCreateScreen({super.key});

  @override
  State<StaffCreateScreen> createState() => _StaffCreateScreenState();
}

class _StaffCreateScreenState extends State<StaffCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<StaffProvider>();
    final ok = await provider.createStaff(
      name: _name.text.trim(),
      email: _email.text.trim(),
      password: _password.text,
    );
    if (!mounted) return;
    if (ok) {
      showAppMessage(context, 'Staff account created.');
      context.pop();
    } else {
      showAppMessage(context, provider.errorMessage ?? 'Save failed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!context.watch<AuthProvider>().isOwner) {
      return Scaffold(
        appBar: AppBar(title: const Text('Add Staff')),
        body: const EmptyView(
          message: 'Staff management is available to owners only.',
        ),
      );
    }
    final provider = context.watch<StaffProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Add Staff')),
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
                    controller: _email,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) =>
                        (v == null || !v.contains('@')) ? 'Enter a valid email.' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    decoration: InputDecoration(
                      labelText: 'Password (min 6 chars)',
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    obscureText: _obscure,
                    validator: (v) =>
                        (v == null || v.length < 6) ? 'Minimum 6 characters.' : null,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: provider.isSaving ? null : _submit,
                    child: provider.isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Create staff account'),
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
