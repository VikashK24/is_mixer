import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/json_storage_service.dart';

class VillagerActionCard extends StatefulWidget {
  final User currentUser;
  final List<User> players;

  const VillagerActionCard({
    super.key,
    required this.currentUser,
    required this.players,
  });

  @override
  State<VillagerActionCard> createState() => _VillagerActionCardState();
}

class _VillagerActionCardState extends State<VillagerActionCard> {
  String? _selectedAccusedId;
  bool _isSubmitting = false;

  // Filter out self and dead/terminated players
  List<User> get _validAccusationTargets {
    return widget.players.where((p) {
      final isSelf = p.id == widget.currentUser.id;
      final isTerminated = p.isTerminated || !p.isAlive;
      return !isSelf && !isTerminated;
    }).toList();
  }

  Future<void> _submitDayVote() async {
    if (_selectedAccusedId == null) return;

    setState(() => _isSubmitting = true);

    try {
      // Record vote in game_state/current/day_votes/{voterId}
      await FirebaseFirestore.instance
          .collection('game_state')
          .doc('current')
          .collection('day_votes')
          .doc(widget.currentUser.id)
          .set({
        'voterId': widget.currentUser.id,
        'voterName': widget.currentUser.username,
        'accusedUserId': _selectedAccusedId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Accusation vote recorded in Firebase!'),
            backgroundColor: Colors.amber,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit vote: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: JsonStorageService.streamGameState(),
      builder: (context, gameStateSnapshot) {
        final gameState = gameStateSnapshot.data ?? {};
        final bool isNight = gameState['isNight'] ?? false;
        final String phase = (gameState['phase'] ?? '').toString().toLowerCase();

        // Enable voting during Day Phase or when discussion phase is explicitly active
        final bool isDiscussionActive = !isNight ||
            phase.contains('day') ||
            phase.contains('discussion') ||
            (gameState['discussionPhaseActive'] ?? false) == true;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('game_state')
              .doc('current')
              .collection('day_votes')
              .snapshots(),
          builder: (context, dayVotesSnapshot) {
            final voteDocs = dayVotesSnapshot.data?.docs ?? [];
            final myVoteDoc = voteDocs
                .where((doc) => doc.id == widget.currentUser.id)
                .firstOrNull;

            final currentVotedId =
                _selectedAccusedId ?? myVoteDoc?.data()['accusedUserId'];

            return Card(
              elevation: 4,
              color: Colors.orange.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.orange.shade300, width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.orange.shade100,
                          child: Icon(Icons.gavel, color: Colors.orange.shade900),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Town Discussion & Trial Vote',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDiscussionActive
                                ? Colors.green.shade100
                                : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isDiscussionActive ? 'VOTING OPEN' : 'LOCKED',
                            style: TextStyle(
                              color: isDiscussionActive
                                  ? Colors.green.shade900
                                  : Colors.grey.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    if (!isDiscussionActive) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.lock, color: Colors.grey, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Accusation voting is disabled during Night Phase. Wait for the Moderator to start the Discussion phase.',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      const Text(
                        'Accuse a suspect to vote them out of the town:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),

                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          fillColor: Colors.white,
                          filled: true,
                          border: OutlineInputBorder(),
                          hintText: 'Select suspect to accuse...',
                        ),
                        value: currentVotedId,
                        items: _validAccusationTargets.map((user) {
                          return DropdownMenuItem<String>(
                            value: user.id,
                            child: Text(user.username),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() => _selectedAccusedId = val);
                        },
                      ),
                      const SizedBox(height: 16),

                      ElevatedButton.icon(
                        onPressed: (_selectedAccusedId != null && !_isSubmitting)
                            ? _submitDayVote
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade800,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.how_to_vote),
                        label: Text(
                          _isSubmitting
                              ? 'Recording Vote...'
                              : 'Cast Accusation Vote',
                        ),
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
  }
}