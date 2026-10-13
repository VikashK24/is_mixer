import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/json_storage_service.dart';

class HealerActionCard extends StatefulWidget {
  final User currentUser;
  final List<User> players;

  const HealerActionCard({
    super.key,
    required this.currentUser,
    required this.players,
  });

  @override
  State<HealerActionCard> createState() => _HealerActionCardState();
}

class _HealerActionCardState extends State<HealerActionCard> {
  String? _selectedOption;
  String? _selectedTargetId;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _lastRoundToken;

  DocumentReference<Map<String, dynamic>> get _answerRef => FirebaseFirestore.instance
      .collection('game_state')
      .doc('current')
      .collection('healer_answers')
      .doc(widget.currentUser.id);

  /// Healers may protect any living player (including themselves).
  List<User> get _validTargets =>
      widget.players.where((p) => p.isAlive && !p.isTerminated).toList();

  Future<void> _submitAnswer(String correctAnswer) async {
    if (_selectedTargetId == null) {
      setState(() => _errorMessage = 'Please select a player to protect.');
      return;
    }
    if (_selectedOption == null) {
      setState(() => _errorMessage = 'Please select an answer option.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final bool isCorrect = _selectedOption!.trim().toLowerCase() ==
          correctAnswer.trim().toLowerCase();

      // One document per healer: it can only be written once per round (the
      // card locks afterwards and the moderator clears it every round).
      await _answerRef.set({
        'healerId': widget.currentUser.id,
        'healerName': widget.currentUser.username,
        'targetUserId': _selectedTargetId,
        'selectedOption': _selectedOption,
        'isCorrect': isCorrect,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Could not submit your answer: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Colors.teal;

    return StreamBuilder<Map<String, dynamic>>(
      stream: JsonStorageService.streamGameState(),
      builder: (context, snapshot) {
        final gameState = snapshot.data ?? {};
        final String phase = (gameState['phase'] ?? 'idle').toString();

        // Fresh selections every round.
        final String roundToken = (gameState['roundToken'] ?? '').toString();
        if (roundToken != _lastRoundToken) {
          _lastRoundToken = roundToken;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _selectedOption = null;
              _selectedTargetId = null;
              _errorMessage = null;
            });
          });
        }

        // The quiz only exists while the moderator has the healer phase open.
        final dynamic rawQuestion = gameState['activeQuestion'];
        String questionText = '';
        String correctAnswer = '';
        List<String> options = [];

        if (rawQuestion is Map) {
          questionText = rawQuestion['question']?.toString() ??
              rawQuestion['text']?.toString() ??
              rawQuestion['question_text']?.toString() ??
              '';
          correctAnswer = rawQuestion['correctAnswer']?.toString() ??
              rawQuestion['answer']?.toString() ??
              '';
          if (rawQuestion['options'] is List) {
            options = (rawQuestion['options'] as List).map((o) => o.toString()).toList();
          }
        } else if (rawQuestion is String) {
          questionText = rawQuestion;
        }

        final bool isHealerPhase = phase == 'healerPhase' && questionText.isNotEmpty;

        if (!widget.currentUser.isAlive) return const SizedBox.shrink();

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _answerRef.snapshots(),
          builder: (context, answerSnapshot) {
            final bool alreadySubmitted = answerSnapshot.data?.exists == true;
            final bool canAnswer = isHealerPhase && !alreadySubmitted && !_isSubmitting;

            final Set<String> validIds = _validTargets.map((u) => u.id).toSet();
            final String? targetValue =
                (_selectedTargetId != null && validIds.contains(_selectedTargetId))
                    ? _selectedTargetId
                    : null;

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
                          child: const Icon(Icons.medical_services, color: primaryColor),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Healer Action: Save Target',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                              Text(
                                'Choose who to protect and pick the correct answer.',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    if (!isHealerPhase && !alreadySubmitted) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20.0),
                        child: Center(
                          child: Text(
                            'Waiting for the Moderator to open the Healer phase...',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                          ),
                        ),
                      ),
                    ] else if (alreadySubmitted) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.teal.shade200),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.teal),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Your answer has been recorded. The result is revealed when the day begins.',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      const Text('1. Select Player to Protect:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          fillColor: Colors.white,
                          filled: true,
                          border: OutlineInputBorder(),
                        ),
                        hint: const Text('Select player to save...'),
                        value: targetValue,
                        items: _validTargets
                            .map((user) =>
                                DropdownMenuItem(value: user.id, child: Text(user.username)))
                            .toList(),
                        onChanged: canAnswer
                            ? (val) => setState(() => _selectedTargetId = val)
                            : null,
                      ),
                      const SizedBox(height: 16),

                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: primaryColor.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'QUIZ QUESTION:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              questionText,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      const Text('2. Select Your Answer:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
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
                                  'This question has no answer options.',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              )
                            : Column(
                                children: options.map((opt) {
                                  return RadioListTile<String>(
                                    dense: true,
                                    title: Text(
                                      opt,
                                      style: const TextStyle(
                                          fontSize: 14, fontWeight: FontWeight.w500),
                                    ),
                                    value: opt,
                                    groupValue: _selectedOption,
                                    activeColor: primaryColor,
                                    onChanged: canAnswer
                                        ? (val) => setState(() => _selectedOption = val)
                                        : null,
                                  );
                                }).toList(),
                              ),
                      ),
                      const SizedBox(height: 12),

                      if (_errorMessage != null) ...[
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
                        const SizedBox(height: 12),
                      ],

                      Text(
                        'You can only submit once. Every healer must answer correctly and protect the right player to save the target.',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 10),

                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: canAnswer ? () => _submitAnswer(correctAnswer) : null,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.healing),
                        label: Text(
                            _isSubmitting ? 'Submitting...' : 'Submit Answer & Protect Target'),
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