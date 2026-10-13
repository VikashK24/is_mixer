import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/json_storage_service.dart';

/// Town trial vote. Every living player can accuse someone during the day
/// phase; the moderator counts the votes when the round is finalized.
///
/// Villagers always see the card (locked outside the day phase). For the other
/// roles pass [hideWhenClosed] so it only appears while voting is open.
class VillagerActionCard extends StatefulWidget {
  final User currentUser;
  final List<User> players;
  final bool hideWhenClosed;

  const VillagerActionCard({
    super.key,
    required this.currentUser,
    required this.players,
    this.hideWhenClosed = false,
  });

  @override
  State<VillagerActionCard> createState() => _VillagerActionCardState();
}

class _VillagerActionCardState extends State<VillagerActionCard> {
  String? _selectedAccusedId;
  bool _isSubmitting = false;
  String? _lastRoundToken;

  // Filter out self and dead/terminated players
  List<User> get _validAccusationTargets {
    return widget.players.where((p) {
      final isSelf = p.id == widget.currentUser.id;
      return !isSelf && p.isAlive && !p.isTerminated;
    }).toList();
  }

  Future<void> _submitDayVote() async {
    if (_selectedAccusedId == null) return;
    if (!_validAccusationTargets.any((u) => u.id == _selectedAccusedId)) return;

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
            content: Text('Accusation vote recorded! You can change it until time runs out.'),
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
    // Eliminated players can no longer vote (the quiz card already tells them).
    if (!widget.currentUser.isAlive || widget.currentUser.isTerminated) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<Map<String, dynamic>>(
      stream: JsonStorageService.streamGameState(),
      builder: (context, gameStateSnapshot) {
        final gameState = gameStateSnapshot.data ?? {};
        final String phase = (gameState['phase'] ?? 'idle').toString();

        // Voting is only open during the day / villagers phase.
        final bool isVotingOpen = phase == 'villagersPhase';

        if (!isVotingOpen && widget.hideWhenClosed) {
          return const SizedBox.shrink();
        }

        // Fresh selection every round.
        final String roundToken = (gameState['roundToken'] ?? '').toString();
        if (roundToken != _lastRoundToken) {
          _lastRoundToken = roundToken;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _selectedAccusedId = null);
          });
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('game_state')
              .doc('current')
              .collection('day_votes')
              .snapshots(),
          builder: (context, dayVotesSnapshot) {
            final voteDocs = dayVotesSnapshot.data?.docs ?? [];
            final myVoteDoc =
                voteDocs.where((doc) => doc.id == widget.currentUser.id).firstOrNull;

            final Set<String> validIds = _validAccusationTargets.map((u) => u.id).toSet();
            final String? savedVote = isVotingOpen
                ? myVoteDoc?.data()['accusedUserId'] as String?
                : null;

            // What I picked now, else what I voted earlier - only if still valid.
            String? dropdownValue = _selectedAccusedId ?? savedVote;
            if (dropdownValue != null && !validIds.contains(dropdownValue)) {
              dropdownValue = null;
            }

            final String? votedName = savedVote == null
                ? null
                : widget.players.where((p) => p.id == savedVote).firstOrNull?.username;

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
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isVotingOpen
                                ? Colors.green.shade100
                                : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isVotingOpen ? 'VOTING OPEN' : 'LOCKED',
                            style: TextStyle(
                              color: isVotingOpen
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

                    if (!isVotingOpen) ...[
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
                                'Accusation voting opens when the Moderator starts the Day phase.',
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
                        value: dropdownValue,
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

                      if (votedName != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Your current vote: $votedName',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      ElevatedButton.icon(
                        onPressed: (dropdownValue != null && !_isSubmitting)
                            ? () {
                                _selectedAccusedId = dropdownValue;
                                _submitDayVote();
                              }
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
                              : (votedName != null ? 'Change Accusation Vote' : 'Cast Accusation Vote'),
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