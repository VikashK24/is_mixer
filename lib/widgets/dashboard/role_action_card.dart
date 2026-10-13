import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/json_storage_service.dart';

/// Detective investigation card (also the fallback slot for players who have
/// no identity yet - those see nothing).
///
/// Rules enforced here:
///  - only real players can be investigated (never moderators or the God
///    account) and only their usernames are listed, so no role or identity
///    information leaks through the list;
///  - one investigation per night, stored in
///    game_state/current/detective_checks/{detectiveId}; the moderator clears
///    these at the start of every round.
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
  String? _errorMessage;
  String? _lastRoundToken;

  DocumentReference<Map<String, dynamic>> get _checkRef => FirebaseFirestore.instance
      .collection('game_state')
      .doc('current')
      .collection('detective_checks')
      .doc(widget.currentUser.id);

  /// Only in-game players, excluding self and anyone eliminated or blocked.
  List<User> _eligibleTargets(List<User> allUsers) {
    return allUsers.where((u) {
      final isPlayer = u.role == 'mafia'; // excludes moderator + superadmin
      final isSelf = u.id == widget.currentUser.id;
      return isPlayer && !isSelf && u.isAlive && !u.isTerminated;
    }).toList()
      ..sort((a, b) => a.username.toLowerCase().compareTo(b.username.toLowerCase()));
  }

  Future<void> _investigate(User target) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final bool isKiller = target.identity.toLowerCase() == 'killer';
      await _checkRef.set({
        'detectiveId': widget.currentUser.id,
        'targetUserId': target.id,
        'targetName': target.username,
        'isKiller': isKiller,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Investigation failed: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final identity = widget.currentUser.identity.toLowerCase();
    if (identity != 'detective') return const SizedBox.shrink();
    if (!widget.currentUser.isAlive) return const SizedBox.shrink();

    return StreamBuilder<Map<String, dynamic>>(
      stream: JsonStorageService.streamGameState(),
      builder: (context, gameSnapshot) {
        final gameState = gameSnapshot.data ?? {};
        final String phase = (gameState['phase'] ?? 'idle').toString();
        final bool isDetectivePhase = phase == 'detectivePhase';

        // Fresh selection every round.
        final String roundToken = (gameState['roundToken'] ?? '').toString();
        if (roundToken != _lastRoundToken) {
          _lastRoundToken = roundToken;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _selectedPlayerId = null;
              _errorMessage = null;
            });
          });
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _checkRef.snapshots(),
          builder: (context, checkSnapshot) {
            final Map<String, dynamic>? check =
                checkSnapshot.data?.exists == true ? checkSnapshot.data!.data() : null;
            final bool hasInvestigated = check != null;

            return StreamBuilder<List<User>>(
              stream: JsonStorageService.streamAllUsers(),
              builder: (context, usersSnapshot) {
                final eligibleTargets = _eligibleTargets(usersSnapshot.data ?? []);
                final Set<String> validIds = eligibleTargets.map((u) => u.id).toSet();
                final String? dropdownValue =
                    (_selectedPlayerId != null && validIds.contains(_selectedPlayerId))
                        ? _selectedPlayerId
                        : null;
                final User? selectedTarget = dropdownValue == null
                    ? null
                    : eligibleTargets.where((u) => u.id == dropdownValue).firstOrNull;

                final bool canInvestigate =
                    isDetectivePhase && !hasInvestigated && !_isProcessing;

                final Color primaryColor = Colors.indigo.shade800;

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
                              child: Icon(Icons.search, color: primaryColor),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Detective Investigation',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                  const Text(
                                    'Investigate one player each night to learn if they are a Killer.',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),

                        if (hasInvestigated) ...[
                          // Result of tonight's investigation, kept on screen.
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: check['isKiller'] == true
                                  ? Colors.red.shade50
                                  : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: check['isKiller'] == true
                                    ? Colors.red.shade300
                                    : Colors.green.shade300,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Investigation Complete for ${check['targetName'] ?? 'player'}:',
                                  style: TextStyle(
                                    color: check['isKiller'] == true
                                        ? Colors.red.shade900
                                        : Colors.green.shade900,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  check['isKiller'] == true
                                      ? 'TARGET IS A KILLER! 🔪'
                                      : 'TARGET IS NOT A KILLER 🛡️',
                                  style: TextStyle(
                                    color: check['isKiller'] == true
                                        ? Colors.red.shade900
                                        : Colors.green.shade900,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'You can investigate again next night.',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ] else if (!isDetectivePhase) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.0),
                            child: Center(
                              child: Text(
                                'Waiting for the Detective phase to begin...',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          // Usernames only - no role, identity or brackets.
                          DropdownButtonFormField<String>(
                            value: dropdownValue,
                            decoration: const InputDecoration(
                              labelText: 'Select Player to Investigate',
                              border: OutlineInputBorder(),
                            ),
                            items: eligibleTargets.map((u) {
                              return DropdownMenuItem<String>(
                                value: u.id,
                                child: Text(u.username),
                              );
                            }).toList(),
                            onChanged: canInvestigate
                                ? (val) => setState(() {
                                      _selectedPlayerId = val;
                                      _errorMessage = null;
                                    })
                                : null,
                          ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade300),
                              ),
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: Colors.red.shade900,
                                  fontWeight: FontWeight.bold,
                                ),
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
                            onPressed: (canInvestigate && selectedTarget != null)
                                ? () => _investigate(selectedTarget)
                                : null,
                            icon: _isProcessing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.search),
                            label: Text(
                                _isProcessing ? 'Investigating...' : 'Investigate Player'),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'You only get one investigation per night.',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}