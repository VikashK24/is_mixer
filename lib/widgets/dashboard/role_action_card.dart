import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/json_storage_service.dart';
import 'healer_action_card.dart';
import 'killer_action_card.dart';

class RoleActionCard extends StatefulWidget {
  final User currentUser;

  const RoleActionCard({
    super.key,
    required this.currentUser,
  });

  @override
  State<RoleActionCard> createState() => _RoleActionCardState();
}

class _RoleActionCardState extends State<RoleActionCard> {
  String? _selectedPlayerId;
  bool _isProcessing = false;
  String? _actionFeedback;
  bool? _isTargetKiller;

  Future<void> _executeRoleAction(List<User> eligibleTargets) async {
    if (_selectedPlayerId == null) {
      setState(() {
        _actionFeedback = 'Please select a target first.';
      });
      return;
    }

    final targetUser = eligibleTargets.firstWhere(
      (u) => u.id == _selectedPlayerId,
      orElse: () => eligibleTargets.first,
    );

    setState(() {
      _isProcessing = true;
      _actionFeedback = null;
      _isTargetKiller = null;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 500));
      final identity = widget.currentUser.identity.toLowerCase();

      if (identity == 'detective') {
        final isKiller = targetUser.identity.toLowerCase() == 'killer';
        setState(() {
          _isTargetKiller = isKiller;
          _actionFeedback = 'Investigation Complete for ${targetUser.username}:';
        });
      } else {
        setState(() {
          _actionFeedback = 'Action submitted against ${targetUser.username}.';
        });
      }
    } catch (e) {
      setState(() {
        _actionFeedback = 'Action failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: JsonStorageService.streamGameState(),
      builder: (context, snapshot) {
        final gameState = snapshot.data ?? {};
        final String phase = (gameState['phase'] ?? 'idle').toString();
        final identity = widget.currentUser.identity.toLowerCase();

        // 1. HEALER ROLE
        if (identity == 'healer') {
          if (phase == 'healerPhase') {
            return HealerActionCard(currentUser: widget.currentUser);
          }
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: const Padding(
              padding: EdgeInsets.all(20.0),
              child: Center(
                child: Text(
                  'Healer Phase is currently inactive. Please wait for the moderator.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey),
                ),
              ),
            ),
          );
        }

        // 2. KILLER ROLE
        if (identity == 'killer') {
          if (phase == 'killerPhase') {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, usersSnap) {
                final userDocs = usersSnap.data?.docs ?? [];
                final List<User> allUsers = userDocs
                    .map((doc) => User.fromJson(doc.data()))
                    .toList();

                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('game_state')
                      .doc('question_bank')
                      .snapshots(),
                  builder: (context, bankSnap) {
                    final bankData = bankSnap.data?.data()?['questions'] as List?;
                    final List<Map<String, dynamic>> questionBank = bankData != null
                        ? List<Map<String, dynamic>>.from(bankData)
                        : [];

                    return KillerActionCard(
                      currentUser: widget.currentUser,
                      players: allUsers,
                      questionBank: questionBank,
                    );
                  },
                );
              },
            );
          }
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: const Padding(
              padding: EdgeInsets.all(20.0),
              child: Center(
                child: Text(
                  'Killer Phase is currently inactive. Please wait for nightfall.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey),
                ),
              ),
            ),
          );
        }

        // 3. DETECTIVE ROLE
        bool isRoleActiveInPhase = false;
        if (identity == 'detective' && phase == 'detectivePhase') {
          isRoleActiveInPhase = true;
        }

        if (!isRoleActiveInPhase) {
          return const SizedBox.shrink();
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('users').snapshots(),
          builder: (context, userSnapshot) {
            final userDocs = userSnapshot.data?.docs ?? [];
            final List<User> allUsers = userDocs
                .map((doc) => User.fromJson(doc.data()))
                .toList();

            final eligibleTargets = allUsers
                .where((u) => u.id != widget.currentUser.id && (u.isAlive ?? false) && u.role == 'mafia')
                .toList();

            final Color primaryColor = Colors.indigo.shade800;
            const IconData icon = Icons.search;
            const String title = 'Detective Investigation';
            const String subtitle = 'Select a player to investigate whether they are a Killer.';

            return Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: primaryColor.withOpacity(0.15),
                          child: Icon(icon, color: primaryColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                              Text(
                                subtitle,
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    DropdownButtonFormField<String>(
                      value: _selectedPlayerId,
                      decoration: const InputDecoration(
                        labelText: 'Select Target Player',
                        border: OutlineInputBorder(),
                      ),
                      items: eligibleTargets.map((u) {
                        return DropdownMenuItem<String>(
                          value: u.id,
                          child: Text('${u.username} (${u.identity.toUpperCase()})'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedPlayerId = val;
                          _actionFeedback = null;
                          _isTargetKiller = null;
                        });
                      },
                    ),

                    if (_actionFeedback != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _isTargetKiller == null
                              ? Colors.blue.shade50
                              : (_isTargetKiller! ? Colors.red.shade50 : Colors.green.shade50),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _isTargetKiller == null
                                ? Colors.blue.shade200
                                : (_isTargetKiller! ? Colors.red.shade300 : Colors.green.shade300),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _actionFeedback!,
                              style: TextStyle(
                                color: _isTargetKiller == null
                                    ? Colors.blue.shade900
                                    : (_isTargetKiller! ? Colors.red.shade900 : Colors.green.shade900),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_isTargetKiller != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                _isTargetKiller! ? 'TARGET IS A KILLER!' : 'TARGET IS NOT A KILLER',
                                style: TextStyle(
                                  color: _isTargetKiller! ? Colors.red.shade900 : Colors.green.shade900,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _isProcessing ? null : () => _executeRoleAction(eligibleTargets),
                      icon: _isProcessing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Icon(icon),
                      label: Text(_isProcessing ? 'Executing...' : 'Submit Action'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}