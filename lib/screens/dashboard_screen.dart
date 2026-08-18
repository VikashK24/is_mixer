import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:web/web.dart' as web;

import '../models/user_model.dart';
import '../services/json_storage_service.dart';

import '../widgets/dashboard/game_moderator_controls.dart';
import '../widgets/dashboard/identity_allocation_card.dart';
import '../widgets/dashboard/navigatable_management_cards.dart';
import '../widgets/dashboard/user_profile_header.dart';

// Player Dashboard Components
import '../widgets/dashboard/phase_banner.dart';
import '../widgets/dashboard/player_status_grid.dart';
import '../widgets/dashboard/role_action_card.dart';

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

  // Standard MCQ Question Bank
  static const List<Map<String, dynamic>> _defaultModeratorQuestionBank = [
    {
      'id': 'mcq_1',
      'question': 'What is the time complexity of Bubble Sort?',
      'options': ['O(N)', 'O(N log N)', 'O(N^2)', 'O(1)'],
      'correctAnswer': 'O(N^2)',
    },
    {
      'id': 'mcq_2',
      'question': 'Which data structure uses LIFO order?',
      'options': ['Queue', 'Stack', 'Array', 'Linked List'],
      'correctAnswer': 'Stack',
    },
    {
      'id': 'mcq_3',
      'question': 'What is the average time complexity of QuickSort?',
      'options': ['O(N)', 'O(N log N)', 'O(N^2)', 'O(log N)'],
      'correctAnswer': 'O(N log N)',
    },
    {
      'id': 'mcq_4',
      'question':
          'Which algorithm is used to find the shortest path in a graph?',
      'options': ['Dijkstra', 'Kruskal', 'Prim', 'BFS'],
      'correctAnswer': 'Dijkstra',
    },
    {
      'id': 'mcq_5',
      'question': 'What keyword is used to declare a constant in Dart?',
      'options': ['var', 'let', 'const', 'final'],
      'correctAnswer': 'const',
    },
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
    _visibilitySub =
        const web.EventStreamProvider<web.Event>(
          'visibilitychange',
        ).forTarget(web.document).listen((_) {
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
            'Game Integrity Triggered ($reason).\n\nSwitching to other apps or tabs during an active game is prohibited. Your account has been terminated and logged out. Please contact a Moderator to regain access.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onLogout();
              },
              child: const Text('OK'),
            ),
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
    final isPlayer = widget.user.role == 'mafia';

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
            ),
          ],
        ),
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('game_state')
              .doc('question_bank')
              .snapshots(),
          builder: (context, qbSnapshot) {
            List<Map<String, dynamic>> activeQuestionBank =
                _defaultModeratorQuestionBank;

            if (qbSnapshot.hasData && qbSnapshot.data?.data() != null) {
              final rawQuestions =
                  qbSnapshot.data!.data()!['questions'] as List?;
              if (rawQuestions != null && rawQuestions.isNotEmpty) {
                activeQuestionBank = rawQuestions
                    .map((q) => Map<String, dynamic>.from(q as Map))
                    .toList();
              }
            }

            return StreamBuilder<List<User>>(
              stream: JsonStorageService.streamAllUsers(),
              builder: (context, snapshot) {
                final allUsers = snapshot.data ?? [];
                final moderatorList = allUsers
                    .where((u) => u.role == 'moderator')
                    .toList();
                final playerList = allUsers
                    .where((u) => u.role == 'mafia')
                    .toList();

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 750),
                      child: Column(
                        children: [
                          UserProfileHeader(user: widget.user),
                          const SizedBox(height: 24),

                          // PLAYER EXCLUSIVE DASHBOARD PANELS
                          if (isPlayer) ...[
                            const PhaseBanner(),
                            const SizedBox(height: 20),
                            RoleActionCard(currentUser: widget.user),
                            const SizedBox(height: 20),
                            PlayerStatusGrid(currentUser: widget.user),
                            const SizedBox(height: 24),
                          ],

                          // MODERATOR & ADMIN CONTROL PANELS
                          if (isModerator || isSuperAdmin) ...[
                            IdentityAllocationCard(playerList: playerList),
                            const SizedBox(height: 20),
                            GameModeratorControls(
                              playerList: playerList,
                              moderatorQuestionBank: activeQuestionBank,
                            ),
                            const SizedBox(height: 24),
                          ],

                          // SUPER ADMIN EXCLUSIVE MANAGEMENTS
                          if (isSuperAdmin) ...[
                            ApprovalQueueCardPreview(
                              moderatorList: moderatorList,
                            ),
                            const SizedBox(height: 16),
                            SuperAdminDangerZoneCard(
                              currentUser: widget.user,
                            ),
                            const SizedBox(height: 16),
                          ],

                          // PLAYER ACCESS MANAGEMENT (BOTH MODERATOR & SUPER ADMIN)
                          if (isModerator || isSuperAdmin) ...[
                            PlayerAccessCardPreview(playerList: playerList),
                            const SizedBox(height: 32),
                          ],
                        ],
                      ),
                    ),
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