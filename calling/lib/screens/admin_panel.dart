import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';

class AdminPanel extends StatelessWidget {
  const AdminPanel({super.key});

  static const String routeName = '/admin';

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Admin panel')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add),
        label: const Text('New user'),
        onPressed: () => _showCreateUserDialog(context),
      ),
      body: StreamBuilder<List<AppUser>>(
        stream: authService.usersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final users = snapshot.data ?? [];
          if (users.isEmpty) {
            return const Center(child: Text('No users found.'));
          }
          return ListView.separated(
            itemCount: users.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(user.displayName.characters.first),
                ),
                title: Text(user.displayName),
                subtitle: Text('${user.email} • ${user.role.label}'),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    IconButton(
                      tooltip: 'Edit',
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showEditUserDialog(context, user),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete),
                      onPressed: () => _confirmDeleteUser(context, user),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showCreateUserDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final displayNameCtrl = TextEditingController();
    UserRole role = UserRole.user;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create user'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: displayNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Display name is required.';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || !value.contains('@')) {
                        return 'Enter a valid email.';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: passwordCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Temporary password',
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.length < 6) {
                        return 'Password must be at least 6 characters.';
                      }
                      return null;
                    },
                  ),
                  DropdownButtonFormField<UserRole>(
                    value: role,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: UserRole.values
                        .map(
                          (value) => DropdownMenuItem<UserRole>(
                            value: value,
                            child: Text(value.label),
                          ),
                        )
                        .toList(),
                    onChanged: (selected) {
                      role = selected ?? UserRole.user;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(context).pop(true);
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (result != true || !context.mounted) return;

    final authService = context.read<AuthService>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      await authService.createUserAsAdmin(
        email: emailCtrl.text.trim(),
        password: passwordCtrl.text.trim(),
        displayName: displayNameCtrl.text.trim(),
        role: role,
      );
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('User created successfully')),
      );
    } on Exception catch (error) {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _showEditUserDialog(BuildContext context, AppUser user) async {
    final formKey = GlobalKey<FormState>();
    final displayNameCtrl = TextEditingController(text: user.displayName);
    UserRole role = user.role;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit user'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: displayNameCtrl,
                  decoration: const InputDecoration(labelText: 'Display name'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Display name is required.';
                    }
                    return null;
                  },
                ),
                DropdownButtonFormField<UserRole>(
                  value: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: UserRole.values
                      .map(
                        (value) => DropdownMenuItem<UserRole>(
                          value: value,
                          child: Text(value.label),
                        ),
                      )
                      .toList(),
                  onChanged: (selected) => role = selected ?? user.role,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(context).pop(true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result != true || !context.mounted) return;

    final authService = context.read<AuthService>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      final updated = user.copyWith(
        displayName: displayNameCtrl.text.trim(),
        role: role,
      );
      await authService.updateUserMetadata(updated);
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('User updated successfully')),
      );
    } on Exception catch (error) {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _confirmDeleteUser(BuildContext context, AppUser user) async {
    final passwordCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete user'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Deleting an account requires the user password to satisfy Firebase Auth security rules. Enter the current password to continue.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

    final authService = context.read<AuthService>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      await authService.deleteUserAsAdmin(
        email: user.email,
        password: passwordCtrl.text.trim(),
        uid: user.uid,
      );
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('User deleted successfully')),
      );
    } on Exception catch (error) {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}
