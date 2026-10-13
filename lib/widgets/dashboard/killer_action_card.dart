import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/game_engine_service.dart';
import '../../services/json_storage_service.dart';

class KillerActionCard extends StatefulWidget {
  final User currentUser;
  final List<User> players;

  const KillerActionCard({
    super.key,
    required this.currentUser,
    required this.players,
  });

  @override
  State<KillerActionCard> createState() => _KillerActionCardState();
}

class _KillerActionCardState extends State<KillerActionCard> {
  String? _selectedTargetId;
  String? _selectedQuestionId;
  bool _isSubmitting = false;
  String? _lastRoundToken;

  DateTime _timeOf(dynamic ts) => ts is Timestamp ? ts.toDate() : DateTime.now();

  List<User> get _validTargets {
    return widget.players.where((p) {
      final isSelf = p.id == widget.currentUser.id;
      final isKiller = p.identity.toLowerCase() == 'killer';
      return !isSelf && !isKiller && p.isAlive && !p.isTerminated;
    }).toList();
  }

  List<Map<String, dynamic>> _readOptions(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .where((m) => (m['id']?.toString() ?? '').isNotEmpty)
        .toList();
  }

  String _questionTitle(Map<String, dynamic> q) =>
      (q['question'] ?? q['question_text'] ?? 'Question').toString();

  Future<void> _submitVote({
    required String targetId,
    required Map<String, dynamic> question,
  }) async {
    setState(() => _isSubmitting = true);

    try {
      await FirebaseFirestore.instance
          .collection('game_state')
          .doc('current')
          .collection('killer_votes')
          .doc(widget.currentUser.id)
          .set({
        'voterId': widget.currentUser.id,
        'voterName': widget.currentUser.username,
        'targetUserId': targetId,
        'selectedQuestion': question,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vote submitted! You can change it until the phase is locked.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit vote: $e'), backgroundColor: Colors.red),
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
        final String phase = (gameState['phase'] ?? 'idle').toString();
        final bool isKillerPhase = phase == 'killerPhase';
        final List<Map<String, dynamic>> options =
            _readOptions(gameState['killerQuestionOptions']);

        // A new round starts with a fresh target/quiz selection, otherwise a
        // stale (possibly dead) target would break the dropdown.
        final String roundToken = (gameState['roundToken'] ?? '').toString();
        if (roundToken != _lastRoundToken) {
          _lastRoundToken = roundToken;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _selectedTargetId = null;
              _selectedQuestionId = null;
            });
          });
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('game_state')
              .doc('current')
              .collection('killer_votes')
              .snapshots(),
          builder: (context, votesSnapshot) {
            final voteDocs = votesSnapshot.data?.docs ?? [];

            // Live consensus (display only - the moderator's lock decides).
            final targetResult = GameEngineService.tally(
              voteDocs
                  .where((d) => d.data()['targetUserId'] != null)
                  .map((d) => MapEntry(
                        d.data()['targetUserId'].toString(),
                        _timeOf(d.data()['timestamp']),
                      )),
            );
            final questionResult = GameEngineService.tally(
              voteDocs
                  .where((d) => d.data()['selectedQuestion'] is Map)
                  .map((d) => MapEntry(
                        (d.data()['selectedQuestion'] as Map)['id'].toString(),
                        _timeOf(d.data()['timestamp']),
                      )),
            );

            final leadingTarget =
                widget.players.where((p) => p.id == targetResult.winner).firstOrNull;
            final leadingQuestion = options
                .where((q) => q['id'].toString() == questionResult.winner)
                .firstOrNull;

            // What this killer already voted this round.
            final myVote = voteDocs
                .where((doc) => doc.id == widget.currentUser.id)
                .firstOrNull
                ?.data();
            final String? myVotedTarget = myVote?['targetUserId'] as String?;
            final String? myVotedQuestionId = myVote?['selectedQuestion'] is Map
                ? (myVote!['selectedQuestion'] as Map)['id']?.toString()
                : null;

            final bool canVote = isKillerPhase &&
                widget.currentUser.isAlive &&
                !widget.currentUser.isTerminated &&
                options.isNotEmpty;

            final String closedMessage = !widget.currentUser.isAlive
                ? 'You have been eliminated and can no longer vote.'
                : (isKillerPhase
                    ? 'Waiting for the quiz options to be published...'
                    : (phase == 'idle' || phase == 'roundCompleted'
                        ? 'Waiting for the Moderator to start the next night phase...'
                        : 'Killer voting is closed for this round.'));

            final Set<String> validTargetIds = _validTargets.map((u) => u.id).toSet();
            final Set<String> optionIds = options.map((q) => q['id'].toString()).toSet();

            // Effective selections: what I picked now, else what I voted before.
            String? effectiveTarget = _selectedTargetId ?? myVotedTarget;
            if (effectiveTarget != null && !validTargetIds.contains(effectiveTarget)) {
              effectiveTarget = null;
            }
            String? effectiveQuestionId = _selectedQuestionId ?? myVotedQuestionId;
            if (effectiveQuestionId != null && !optionIds.contains(effectiveQuestionId)) {
              effectiveQuestionId = null;
            }

            final Map<String, dynamic>? effectiveQuestion = effectiveQuestionId == null
                ? null
                : options
                    .where((q) => q['id'].toString() == effectiveQuestionId)
                    .firstOrNull;

            return Card(
              elevation: 4,
              color: Colors.red.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.red.shade300, width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.red.shade100,
                          child: Icon(Icons.do_not_step, color: Colors.red.shade900),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Killer Night Action & Quiz Selection',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Chip(
                          label: Text('${voteDocs.length} Votes'),
                          backgroundColor: Colors.red.shade800,
                          labelStyle: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Live Killer Consensus:',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Target: ${leadingTarget?.username ?? 'Pending...'}'
                            '${targetResult.isTie ? ' (tie)' : ''}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'Quiz: ${leadingQuestion != null ? _questionTitle(leadingQuestion) : 'Pending...'}'
                            '${questionResult.isTie ? ' (tie)' : ''}',
                            style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (!canVote) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.lock, size: 18, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                closedMessage,
                                style: const TextStyle(fontSize: 13, color: Colors.black54),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    const Text('1. Choose Target to Eliminate:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        fillColor: Colors.white,
                        filled: true,
                        border: OutlineInputBorder(),
                      ),
                      hint: const Text('Select target...'),
                      value: effectiveTarget,
                      items: _validTargets
                          .map((user) =>
                              DropdownMenuItem(value: user.id, child: Text(user.username)))
                          .toList(),
                      onChanged:
                          canVote ? (val) => setState(() => _selectedTargetId = val) : null,
                    ),
                    const SizedBox(height: 16),

                    const Text('2. Pick 1 MCQ Quiz for Healers:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      'Every killer chooses from the same options this round.',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: options.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: Text(
                                'No quiz options published yet.',
                                style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                              ),
                            )
                          : Column(
                              children: options.map((qObj) {
                                final String id = qObj['id'].toString();
                                final List rawOpts = qObj['options'] as List? ?? [];
                                return RadioListTile<String>(
                                  title: Text(
                                    _questionTitle(qObj),
                                    style: const TextStyle(
                                        fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Text(
                                    'Options: ${rawOpts.join(', ')}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  value: id,
                                  groupValue: effectiveQuestionId,
                                  activeColor: Colors.red.shade800,
                                  onChanged: canVote
                                      ? (val) => setState(() => _selectedQuestionId = val)
                                      : null,
                                );
                              }).toList(),
                            ),
                    ),
                    const SizedBox(height: 20),

                    ElevatedButton.icon(
                      onPressed: (canVote &&
                              effectiveTarget != null &&
                              effectiveQuestion != null &&
                              !_isSubmitting)
                          ? () => _submitVote(
                                targetId: effectiveTarget!,
                                question: effectiveQuestion,
                              )
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.how_to_vote),
                      label: Text(
                        _isSubmitting
                            ? 'Submitting...'
                            : (myVote != null
                                ? 'Update Target & Quiz Selection'
                                : 'Submit Target & Quiz Selection'),
                      ),
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