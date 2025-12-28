import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/call_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/call_service.dart';
import '../widgets/custom_button.dart';
import 'admin_panel.dart';
import 'call_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const String routeName = '/home';

  Future<void> _initiateCall(BuildContext context, AppUser target) async {
    final callService = context.read<CallService>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      await callService.startCall(target);
      if (!context.mounted) return;
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const CallScreen()));
    } on Exception catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final callService = context.watch<CallService>();
    final currentUser = authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Hi, ${currentUser?.displayName ?? 'Operator'}'),
        actions: [
          if (authService.isAdmin)
            IconButton(
              tooltip: 'Admin panel',
              icon: const Icon(Icons.admin_panel_settings),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const AdminPanel()),
                );
              },
            ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => authService.signOut(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Users',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<List<AppUser>>(
                stream: authService.usersStream,
                builder: (context, snapshot) {
                  final users = snapshot.data ?? [];
                  final filtered = users
                      .where((user) => user.uid != currentUser?.uid)
                      .toList();
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (filtered.isEmpty) {
                    return const Center(child: Text('No users available.'));
                  }
                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final user = filtered[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(user.displayName.characters.first),
                        ),
                        title: Text(user.displayName),
                        subtitle: Text(
                          user.isOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                            color: user.isOnline
                                ? Colors.green
                                : Colors.grey.shade600,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.phone),
                          onPressed: user.isOnline
                              ? () => _initiateCall(context, user)
                              : null,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Recent calls',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 180,
              child: currentUser == null
                  ? const Center(child: Text('Sign in to view call logs.'))
                  : StreamBuilder<List<CallSession>>(
                      stream: callService.callLogsStream(currentUser.uid),
                      builder: (context, snapshot) {
                        final calls = snapshot.data ?? [];
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (calls.isEmpty) {
                          return const Center(
                            child: Text('No call logs available.'),
                          );
                        }
                        return ListView.separated(
                          itemCount: calls.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final call = calls[index];
                            final isCaller = call.callerId == currentUser.uid;
                            final otherParty = isCaller
                                ? call.calleeName
                                : call.callerName;

                            return ListTile(
                              leading: Icon(
                                isCaller
                                    ? Icons.call_made
                                    : Icons.call_received,
                                color: isCaller ? Colors.blue : Colors.orange,
                              ),
                              title: Text(otherParty),
                              subtitle: Text(call.status.label),
                              trailing: Text(
                                call.createdAt.toLocal().toString(),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            if (callService.hasActiveCall)
              CustomButton(
                label: 'Re-open current call',
                icon: Icons.call,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const CallScreen()),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
