import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/json_storage_service.dart';

class KillerActionCard extends StatefulWidget {
  final User currentUser;
  final List<User> players;
  final List<Map<String, dynamic>> questionBank;

  const KillerActionCard({
    super.key,
    required this.currentUser,
    required this.players,
    required this.questionBank,
  });

  @override
  State<KillerActionCard> createState() => _KillerActionCardState();
}

class _KillerActionCardState extends State<KillerActionCard> {
  String? _selectedTargetId;
  Map<String, dynamic>? _selectedQuestionObj;
  List<Map<String, dynamic>> _questionOptions = [];
  bool _isSubmitting = false;

  static const List<Map<String, dynamic>> _defaultFallbackQuestions = [
    {
      'id': 'fallback_1',
      'question': 'What is the capital of France?',
      'options': ['Paris', 'London', 'Berlin', 'Madrid'],
      'correctAnswer': 'Paris',
    },
    {
      'id': 'fallback_2',
      'question': 'Solve for x: 2x + 6 = 14',
      'options': ['x = 2', 'x = 4', 'x = 6', 'x = 8'],
      'correctAnswer': 'x = 4',
    },
    {
      'id': 'fallback_3',
      'question': 'Which planet is known as the Red Planet?',
      'options': ['Venus', 'Mars', 'Jupiter', 'Saturn'],
      'correctAnswer': 'Mars',
    },
    {
      'id': 'fallback_4',
      'question': 'What is the chemical symbol for Gold?',
      'options': ['Ag', 'Au', 'Fe', 'Cu'],
      'correctAnswer': 'Au',
    },
  ];

  @override
  void initState() {
    super.initState();
    _generateQuestionOptions([]);
  }

  void _generateQuestionOptions(List<String> usedQuestionIds) {
    final rawPool = widget.questionBank.isNotEmpty
        ? widget.questionBank
        : _defaultFallbackQuestions;

    final availablePool = rawPool
        .where((q) => !usedQuestionIds.contains(q['id']?.toString()))
        .toList();

    final poolToUse = availablePool.isNotEmpty ? availablePool : rawPool;

    final random = Random();
    final shuffled = List<Map<String, dynamic>>.from(poolToUse)..shuffle(random);

    setState(() {
      _questionOptions = shuffled.take(4).toList();
    });
  }

  // Filter out non-alive players and other Killers
  List<User> get _validTargets {
    return widget.players
        .where((p) => p.isAlive && p.identity.toLowerCase() != 'killer')
        .toList();
  }

  Future<void> _submitVote() async {
    if (_selectedTargetId == null || _selectedQuestionObj == null) return;

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
        'targetUserId': _selectedTargetId,
        'selectedQuestion': _selectedQuestionObj,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vote submitted! Awaiting killer consensus...'),
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

  String _calculateMajorityTarget(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (docs.isEmpty) return '';
    final Map<String, int> counts = {};

    for (var doc in docs) {
      final val = doc.data()['targetUserId'] as String?;
      if (val != null && val.isNotEmpty) counts[val] = (counts[val] ?? 0) + 1;
    }

    if (counts.isEmpty) return '';
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  Map<String, dynamic>? _calculateMajorityQuestion(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (docs.isEmpty) return null;
    final Map<String, int> counts = {};
    final Map<String, Map<String, dynamic>> questionMap = {};

    for (var doc in docs) {
      final qData = doc.data()['selectedQuestion'] as Map<String, dynamic>?;
      if (qData != null && qData['id'] != null) {
        final qId = qData['id'].toString();
        counts[qId] = (counts[qId] ?? 0) + 1;
        questionMap[qId] = qData;
      }
    }

    if (counts.isEmpty) return null;
    final winningId = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    return questionMap[winningId];
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: JsonStorageService.streamGameState(),
      builder: (context, gameStateSnapshot) {
        final gameState = gameStateSnapshot.data ?? {};
        final List<String> usedIds = List<String>.from(gameState['usedQuestionIds'] ?? []);

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('game_state')
              .doc('current')
              .collection('killer_votes')
              .snapshots(),
          builder: (context, votesSnapshot) {
            final voteDocs = votesSnapshot.data?.docs ?? [];
            final leadingTargetId = _calculateMajorityTarget(voteDocs);
            final leadingQuestion = _calculateMajorityQuestion(voteDocs);

            final leadingTargetUser = widget.players.firstWhere(
              (p) => p.id == leadingTargetId,
              orElse: () => User(id: '', username: 'Pending...', role: '', identity: '', createdAt: DateTime.now()),
            );

            final myVoteDoc = voteDocs.where((doc) => doc.id == widget.currentUser.id).firstOrNull;

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
                          child: Text('Killer Night Action & Quiz Selection', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        Chip(
                          label: Text('${voteDocs.length} Votes'),
                          backgroundColor: Colors.red.shade800,
                          labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // LIVE MAJORITY DASHBOARD
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
                          const Text('Majority Consensus:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                          const SizedBox(height: 4),
                          Text('Target: ${leadingTargetUser.username}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text('Quiz: ${leadingQuestion != null ? leadingQuestion['question'] : "Pending..."}', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 1. CHOOSE TARGET
                    const Text('1. Choose Target to Eliminate:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(fillColor: Colors.white, filled: true, border: OutlineInputBorder()),
                      hint: const Text('Select target...'),
                      value: _selectedTargetId ?? myVoteDoc?.data()['targetUserId'],
                      items: _validTargets.map((user) => DropdownMenuItem(value: user.id, child: Text(user.username))).toList(),
                      onChanged: (val) => setState(() => _selectedTargetId = val),
                    ),
                    const SizedBox(height: 16),

                    // 2. CHOOSE MCQ QUIZ QUESTION
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('2. Pick 1 MCQ Quiz for Healers:', style: TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 20),
                          onPressed: () => _generateQuestionOptions(usedIds),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                      child: Column(
                        children: _questionOptions.map((qObj) {
                          final String qTitle = qObj['question'] ?? 'Question';
                          return RadioListTile<Map<String, dynamic>>(
                            title: Text(qTitle, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            subtitle: Text("Options: ${(qObj['options'] as List? ?? []).join(', ')}", style: const TextStyle(fontSize: 11)),
                            value: qObj,
                            groupValue: _selectedQuestionObj,
                            activeColor: Colors.red.shade800,
                            onChanged: (val) => setState(() => _selectedQuestionObj = val),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),

                    ElevatedButton.icon(
                      onPressed: (_selectedTargetId != null && _selectedQuestionObj != null && !_isSubmitting) ? _submitVote : null,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                      icon: const Icon(Icons.how_to_vote),
                      label: Text(_isSubmitting ? 'Submitting...' : 'Submit Target & Quiz Selection'),
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