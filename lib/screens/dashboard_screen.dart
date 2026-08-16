import 'dart:async';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/user_model.dart';
import '../services/json_storage_service.dart';

import '../widgets/dashboard/user_profile_header.dart';
import '../widgets/dashboard/identity_allocation_card.dart';
import '../widgets/dashboard/game_moderator_controls.dart';
import '../widgets/dashboard/navigatable_management_cards.dart';

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
  StreamSubscription<web.Event>? _visibilitySub;
  StreamSubscription<web.Event>? _blurSub;

  final List<String> _moderatorQuestionBank = const [
    'What is the time complexity of Bubble Sort?',
    'Which data structure uses LIFO order?',
    'What is the average time complexity of QuickSort?',
    'Which algorithm is used to find the shortest path in a graph?',
    'What is the worst-case space complexity of Merge Sort?',
    'Which data structure uses FIFO order?',
    'What is the height of a balanced Binary Search Tree with N nodes?',
    'What is the space complexity of iterative Binary Search?',
    'What keyword is used to declare a constant in Dart?',
    'Which data structure is non-linear?',
    'What is the worst-case time complexity of Linear Search?',
    'What algorithm technique does Dynamic Programming rely on?',
    'What is the worst-case time complexity of inserting into a Hash Table?',
    'Which traversal prints binary tree nodes in sorted order?',
    'What is the maximum number of children a binary tree node can have?',
    'Which data structure is ideal for Breadth-First Search?',
    'Which data structure is ideal for Depth-First Search?',
    'What is the primary feature of an immutable object?',
    'What is the result of 5 ~/ 2 in Dart integer division?',
    'Which collection type ensures unique elements in Dart?',
  ];

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();

    if (widget.user.role == 'mafia') {
      _enableIntegrityGuard();
    }
  }

  void _enableIntegrityGuard() {
    _visibilitySub = const web.EventStreamProvider<web.Event>('visibilitychange')
        .forTarget(web.document)
        .listen((_) {
      if (web.document.hidden) {
        _handleIntegrityViolation('Tab switch detected');
      }
    });

    _blurSub = const web.EventStreamProvider<web.Event>('blur')
        .forTarget(web.window)
        .listen((_) {
      _handleIntegrityViolation('Application focus lost');
    });
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
    _visibilitySub?.cancel();
    _blurSub?.cancel();
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
                  UserProfileHeader(user: widget.user),
                  const SizedBox(height: 24),

                  StreamBuilder<List<User>>(
                    stream: JsonStorageService.streamAllUsers(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final allUsers = snapshot.data ?? [];
                      final moderatorList =
                          allUsers.where((u) => u.role == 'moderator').toList();
                      final playerList =
                          allUsers.where((u) => u.role == 'mafia').toList();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isModerator || isSuperAdmin) ...[
                            IdentityAllocationCard(playerList: playerList),
                            const SizedBox(height: 20),
                            GameModeratorControls(
                              playerList: playerList,
                              moderatorQuestionBank: _moderatorQuestionBank,
                            ),
                            const SizedBox(height: 24),
                          ],
                          if (isSuperAdmin) ...[
                            ApprovalQueueCardPreview(moderatorList: moderatorList),
                            const SizedBox(height: 16),
                          ],
                          if (isModerator || isSuperAdmin) ...[
                            PlayerAccessCardPreview(playerList: playerList),
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