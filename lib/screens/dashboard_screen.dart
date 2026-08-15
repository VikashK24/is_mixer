import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/user_model.dart';
import '../services/json_storage_service.dart';

class GameDashboardScreen extends StatefulWidget {
  final User user;
  final VoidCallback onLogout;

  const GameDashboardScreen({
    super.key,
    required this.user,
    required this.onLogout,
  });

  @override
  State<GameDashboardScreen> createState() => _GameDashboardScreenState();
}

class _GameDashboardScreenState extends State<GameDashboardScreen> {
  bool _isViolated = false;

  @override
  void initState() {
    super.initState();
    
    // Keep screen awake during game
    WakelockPlus.enable();

    // Enable Anti-Cheat Integrity Guard ONLY for Mafia players
    if (widget.user.role == 'mafia') {
      _enableIntegrityGuard();
    }
  }

  void _enableIntegrityGuard() {
    web.document.addEventListener(
      'visibilitychange',
      (web.Event _) {
        if (web.document.hidden) {
          _handleIntegrityViolation('Tab switch detected');
        }
      }.toJS,
    );

    web.window.addEventListener(
      'blur',
      (web.Event _) {
        _handleIntegrityViolation('Application focus lost');
      }.toJS,
    );
  }

  Future<void> _handleIntegrityViolation(String reason) async {
    if (_isViolated) return;
    _isViolated = true;

    await JsonStorageService.softDeleteUser(widget.user.id);

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.gavel, color: Colors.red),
              SizedBox(width: 8),
              Text('Integrity Violation!'),
            ],
          ),
          content: Text(
            'Game Integrity Triggered ($reason).\n\nSwitching to other apps or tabs during an active game is prohibited. Your account has been terminated. Please contact a Moderator to regain access.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onLogout();
              },
              child: const Text('OK'),
            )
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSuperAdmin = widget.user.role == 'superadmin';
    final isModerator = widget.user.role == 'moderator';

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Mafia Quiz Game - (${widget.user.role.toUpperCase()})'),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: () async {
                await JsonStorageService.clearSession();
                widget.onLogout();
              },
            )
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 750),
              child: Column(
                children: [
                  Icon(
                    isSuperAdmin
                        ? Icons.admin_panel_settings
                        : (isModerator ? Icons.security : Icons.sports_esports),
                    size: 72,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Welcome back, ${widget.user.username}!',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  if (widget.user.role == 'mafia')
                    const Chip(
                      avatar: Icon(Icons.shield, color: Colors.green),
                      label: Text('Anti-Cheat Active: Do not leave or switch tabs!'),
                    ),
                  const SizedBox(height: 24),

                  StreamBuilder<List<User>>(
                    stream: JsonStorageService.streamAllUsers(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final allUsers = snapshot.data ?? [];
                      final moderatorList = allUsers.where((u) => u.role == 'moderator').toList();
                      final playerList = allUsers.where((u) => u.role == 'mafia').toList();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // SUPER ADMIN SECTION
                          if (isSuperAdmin) ...[
                            Text(
                              'Moderator Approval Queue',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Card(
                              child: moderatorList.isEmpty
                                  ? const ListTile(title: Text('No Moderator accounts registered yet.'))
                                  : ListView.separated(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: moderatorList.length,
                                      separatorBuilder: (_, __) => const Divider(height: 1),
                                      itemBuilder: (context, index) {
                                        final mod = moderatorList[index];
                                        return ListTile(
                                          title: Text(mod.username),
                                          subtitle: Text(
                                            mod.isApproved
                                                ? 'Status: Approved'
                                                : 'Status: Pending Approval',
                                          ),
                                          trailing: !mod.isApproved
                                              ? ElevatedButton.icon(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.blue,
                                                    foregroundColor: Colors.white,
                                                  ),
                                                  icon: const Icon(Icons.verified_user, size: 16),
                                                  label: const Text('Grant Approval'),
                                                  onPressed: () async {
                                                    await JsonStorageService.approveModerator(mod.id);
                                                  },
                                                )
                                              : const Chip(
                                                  label: Text('Approved'),
                                                  backgroundColor: Colors.lightBlueAccent,
                                                ),
                                        );
                                      },
                                    ),
                            ),
                            const SizedBox(height: 32),
                          ],

                          // MODERATOR / SUPER ADMIN SECTION
                          if (isModerator || isSuperAdmin) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Player Access Management',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                TextButton.icon(
                                  icon: const Icon(Icons.phonelink_erase, size: 18),
                                  label: const Text('Clear Local Device Lock'),
                                  onPressed: () async {
                                    await JsonStorageService.clearDeviceLock();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Device lock cleared on this browser.'),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Card(
                              child: playerList.isEmpty
                                  ? const ListTile(title: Text('No Mafia players active.'))
                                  : ListView.separated(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: playerList.length,
                                      separatorBuilder: (_, __) => const Divider(height: 1),
                                      itemBuilder: (context, index) {
                                        final player = playerList[index];
                                        return ListTile(
                                          title: Text(player.username),
                                          subtitle: Text('Role: ${player.role.toUpperCase()}'),
                                          trailing: player.isTerminated
                                              ? ElevatedButton.icon(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.green,
                                                    foregroundColor: Colors.white,
                                                  ),
                                                  icon: const Icon(Icons.check, size: 16),
                                                  label: const Text('Re-grant Access'),
                                                  onPressed: () async {
                                                    await JsonStorageService.reactivateUser(player.id);
                                                  },
                                                )
                                              : const Chip(
                                                  label: Text('Active'),
                                                  backgroundColor: Colors.greenAccent,
                                                ),
                                        );
                                      },
                                    ),
                            ),
                            const SizedBox(height: 32),
                          ],
                        ],
                      );
                    },
                  ),

                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Terminate Account (Soft Delete)'),
                    onPressed: () async {
                      await JsonStorageService.softDeleteUser(widget.user.id);
                      widget.onLogout();
                    },
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