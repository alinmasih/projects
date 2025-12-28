import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/call_model.dart';
import '../services/auth_service.dart';
import '../services/call_service.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({super.key});

  static const String routeName = '/call';

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _joinIfCaller();
    });
  }

  Future<void> _joinIfCaller() async {
    final callService = context.read<CallService>();
    final authService = context.read<AuthService>();
    final call = callService.activeCall;
    if (call == null) {
      if (mounted) Navigator.of(context).maybePop();
      return;
    }

    if (call.callerId == authService.currentUser?.uid) {
      await _joinAgora();
    }
  }

  Future<void> _joinAgora() async {
    final callService = context.read<CallService>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _joining = true);
    try {
      await callService.joinAgoraChannel();
    } on Exception catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _joining = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<CallService, AuthService>(
      builder: (context, callService, authService, _) {
        final call = callService.activeCall;
        if (call == null) {
          final navigator = Navigator.of(context);
          Future.microtask(navigator.maybePop);
          return const SizedBox.shrink();
        }

        final isCaller = call.callerId == authService.currentUser?.uid;
        final counterParty = isCaller ? call.calleeName : call.callerName;
        final isRinging = call.status == CallStatus.ringing;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Voice call'),
            automaticallyImplyLeading: false,
          ),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 48,
                  child: Text(
                    counterParty.characters.first.toUpperCase(),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  counterParty,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  isRinging ? 'Ringing…' : call.status.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 32),
                if (isRinging && !isCaller)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        onPressed: () async {
                          await callService.declineActiveCall();
                          if (context.mounted) {
                            Navigator.of(context).maybePop();
                          }
                        },
                        icon: const Icon(Icons.call_end),
                        label: const Text('Decline'),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        onPressed: () async {
                          await callService.acceptActiveCall();
                          await _joinAgora();
                        },
                        icon: _joining
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.call),
                        label: const Text('Accept'),
                      ),
                    ],
                  )
                else
                  _buildOngoingControls(context, callService),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOngoingControls(BuildContext context, CallService callService) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _ControlButton(
              icon: callService.isMuted ? Icons.mic_off : Icons.mic,
              label: callService.isMuted ? 'Unmute' : 'Mute',
              onTap: callService.toggleMute,
            ),
            _ControlButton(
              icon: callService.isSpeakerOn
                  ? Icons.volume_up
                  : Icons.volume_off,
              label: callService.isSpeakerOn ? 'Speaker' : 'Earpiece',
              onTap: callService.toggleSpeaker,
            ),
          ],
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
            shape: const StadiumBorder(),
          ),
          onPressed: () async {
            await callService.endActiveCall();
            if (context.mounted) {
              Navigator.of(context).maybePop();
            }
          },
          icon: const Icon(Icons.call_end),
          label: const Text('Hang up'),
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(40),
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(label),
      ],
    );
  }
}
