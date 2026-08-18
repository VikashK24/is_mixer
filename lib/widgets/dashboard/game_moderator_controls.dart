import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/game_engine_service.dart';
import '../../services/json_storage_service.dart';

class GameModeratorControls extends StatefulWidget {
  final List<User> playerList;
  final List<Map<String, dynamic>> moderatorQuestionBank;

  const GameModeratorControls({
    super.key,
    required this.playerList,
    required this.moderatorQuestionBank,
  });

  @override
  State<GameModeratorControls> createState() => _GameModeratorControlsState();
}

class _GameModeratorControlsState extends State<GameModeratorControls> {
  Timer? _phaseTimer;
  static const int _standardDuration = 30;
  int _townDiscussionDuration = 60;
  final TextEditingController _timerController = TextEditingController(text: '60');

  bool get _areIdentitiesAllocated =>
      widget.playerList.isNotEmpty &&
      !widget.playerList.any((p) => p.identity == 'NONE' || p.identity.isEmpty);

  List<User> get _activeHealers =>
      widget.playerList.where((p) => p.identity.toLowerCase() == 'healer' && p.isAlive).toList();

  bool get _isHealerAlive => _activeHealers.isNotEmpty;
  bool get _isDetectiveAlive =>
      widget.playerList.any((p) => p.identity.toLowerCase() == 'detective' && p.isAlive);

  void _startTimer(VoidCallback onTimeout, [int? customDuration]) {
    _phaseTimer?.cancel();
    int secondsLeft = customDuration ?? _standardDuration;

    _phaseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (secondsLeft > 1) {
        secondsLeft--;
        FirebaseFirestore.instance
            .collection('game_state')
            .doc('current')
            .update({'secondsRemaining': secondsLeft});
      } else {
        timer.cancel();
        FirebaseFirestore.instance
            .collection('game_state')
            .doc('current')
            .update({'secondsRemaining': 0});
        onTimeout();
      }
    });
  }

  void _stopTimer() {
    _phaseTimer?.cancel();
  }

  void _startNewRound() async {
    if (!_areIdentitiesAllocated) return;

    try {
      final victim = GameEngineService.selectSecretTarget(widget.playerList);

      await JsonStorageService.updateGameState({
        'phase': 'killerPhase',
        'isNight': true,
        'activeQuestion': null,
        'targetedPlayerId': victim.id,
        'targetedPlayerName': victim.username,
        'secondsRemaining': _standardDuration,
        'announcement': 'Night has fallen! Killers are voting on a target and selecting a quiz question.',
      });

      _startTimer(() {
        _onKillerPhaseComplete();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot start round: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _onKillerPhaseComplete() async {
    _stopTimer();

    String? targetedUserId;
    Map<String, dynamic>? selectedQuestionObj;
    List<String> usedIds = [];

    try {
      final docSnap = await FirebaseFirestore.instance.collection('game_state').doc('current').get();
      usedIds = List<String>.from(docSnap.data()?['usedQuestionIds'] ?? []);
      targetedUserId = docSnap.data()?['targetedPlayerId'] as String?;

      final snapshot = await FirebaseFirestore.instance
          .collection('game_state')
          .doc('current')
          .collection('killer_votes')
          .get();

      final docs = snapshot.docs;
      if (docs.isNotEmpty) {
        final Map<String, int> targetCounts = {};
        final Map<String, int> questionCounts = {};
        final Map<String, Map<String, dynamic>> questionMap = {};

        for (var doc in docs) {
          final t = doc.data()['targetUserId'] as String?;
          final qData = doc.data()['selectedQuestion'] as Map<String, dynamic>?;

          if (t != null && t.isNotEmpty) targetCounts[t] = (targetCounts[t] ?? 0) + 1;
          if (qData != null && qData['id'] != null) {
            final qId = qData['id'].toString();
            questionCounts[qId] = (questionCounts[qId] ?? 0) + 1;
            questionMap[qId] = qData;
          }
        }

        if (targetCounts.isNotEmpty) {
          targetedUserId = targetCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
        }

        if (questionCounts.isNotEmpty) {
          final majorityQuestionId = questionCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
          selectedQuestionObj = questionMap[majorityQuestionId];
        }
      }
    } catch (e) {
      debugPrint('Error resolving killer selections: $e');
    }

    if (selectedQuestionObj != null && selectedQuestionObj['id'] != null) {
      usedIds.add(selectedQuestionObj['id'].toString());
    }

    final String nextPhase = _isHealerAlive
        ? 'awaitingHealerStart'
        : (_isDetectiveAlive ? 'awaitingDetectiveStart' : 'awaitingVillagersStart');

    await JsonStorageService.updateGameState({
      'phase': nextPhase,
      'targetedPlayerId': targetedUserId,
      'selectedQuestion': selectedQuestionObj,
      'usedQuestionIds': usedIds,
      'secondsRemaining': 0,
    });
  }

  void _transferToHealer() async {
    final docSnap = await FirebaseFirestore.instance.collection('game_state').doc('current').get();
    final selectedQuestion = docSnap.data()?['selectedQuestion'];
    final targetedName = docSnap.data()?['targetedPlayerName'] ?? 'the target';

    await JsonStorageService.updateGameState({
      'phase': 'healerPhase',
      'isNight': true,
      'activeQuestion': selectedQuestion,
      'secondsRemaining': _standardDuration,
      'announcement': 'Healers Active: Solve the question picked by Killers to save $targetedName!',
    });

    _startTimer(() {
      _resolveHealerPhase(timeout: true);
    });
  }

  void _resolveHealerPhase({required bool timeout}) async {
    _stopTimer();
    final String nextPhase = _isDetectiveAlive ? 'awaitingDetectiveStart' : 'awaitingVillagersStart';
    await JsonStorageService.updateGameState({
      'phase': nextPhase,
      'secondsRemaining': 0,
    });
  }

  void _transferToDetective() async {
    await JsonStorageService.updateGameState({
      'phase': 'detectivePhase',
      'isNight': true,
      'activeQuestion': null,
      'secondsRemaining': _standardDuration,
      'announcement': 'Detective Action Active: Performing identity investigation.',
    });

    _startTimer(() {
      _resolveDetectivePhase(timeout: true);
    });
  }

  void _resolveDetectivePhase({required bool timeout}) async {
    _stopTimer();
    await JsonStorageService.updateGameState({
      'phase': 'awaitingVillagersStart',
      'secondsRemaining': 0,
    });
  }

  void _transferToVillagers() async {
    final docSnap = await FirebaseFirestore.instance.collection('game_state').doc('current').get();
    final targetedUserId = docSnap.data()?['targetedPlayerId'] as String?;

    bool allHealersCorrect = false;

    if (_isHealerAlive) {
      final healerAnswersSnap = await FirebaseFirestore.instance
          .collection('game_state')
          .doc('current')
          .collection('healer_answers')
          .get();

      if (healerAnswersSnap.docs.isNotEmpty) {
        allHealersCorrect = _activeHealers.every((healer) {
          final doc = healerAnswersSnap.docs.where((d) => d.id == healer.id).firstOrNull;
          return doc != null && doc.data()['isCorrect'] == true;
        });
      }
    }

    final targetedUser = widget.playerList.firstWhere(
      (p) => p.id == targetedUserId,
      orElse: () => widget.playerList.isNotEmpty
          ? widget.playerList.first
          : User(
              id: '',
              username: 'Unknown',
              role: 'player',
              identity: '',
              createdAt: DateTime.now(),
            ),
    );

    final String terminationNotice = (targetedUserId != null && !allHealersCorrect)
        ? 'ALERT: ${targetedUser.username} was terminated!'
        : 'GOOD NEWS: Everyone survived the night!';

    await JsonStorageService.updateGameState({
      'phase': 'villagersPhase',
      'isNight': false,
      'activeQuestion': null,
      'secondsRemaining': _townDiscussionDuration,
      'announcement': 'Everyone awakes! Day discussion & voting begins. $terminationNotice',
    });

    _startTimer(() {
      _finalizeRound(targetSaved: allHealersCorrect, targetedUserId: targetedUserId);
    }, _townDiscussionDuration);
  }

  Future<void> _finalizeRound({required bool targetSaved, String? targetedUserId}) async {
    _stopTimer();

    if (targetedUserId != null && widget.playerList.isNotEmpty) {
      final targetedUser = widget.playerList.firstWhere(
        (p) => p.id == targetedUserId,
        orElse: () => widget.playerList.first,
      );
      if (targetedUser.id.isNotEmpty) {
        await JsonStorageService.updateUserIdentity(
          userId: targetedUser.id,
          identity: targetedUser.identity,
          isAlive: targetSaved,
        );
      }

      final String statusMsg = targetSaved
          ? 'Player ${targetedUser.username} was targeted but SAVED by Healers!'
          : 'Player ${targetedUser.username} was targeted and TERMINATED by Killers!';

      await JsonStorageService.updateGameState({
        'phase': 'roundCompleted',
        'isNight': false,
        'secondsRemaining': 0,
        'announcement': statusMsg,
      });
    } else {
      await JsonStorageService.updateGameState({
        'phase': 'roundCompleted',
        'isNight': false,
        'secondsRemaining': 0,
        'announcement': 'Round completed.',
      });
    }
  }

  void _showQuestionBankUploadDialog() {
    final TextEditingController jsonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upload MCQ Question Bank (JSON)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste array of MCQs matching standard format:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: jsonController,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: '[\n  {\n    "id": "q1",\n    "question": "Sample?",\n    "options": ["A", "B", "C", "D"],\n    "correctAnswer": "A"\n  }\n]',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                final List parsed = jsonDecode(jsonController.text);
                final List<Map<String, dynamic>> formatted = List<Map<String, dynamic>>.from(parsed);

                await FirebaseFirestore.instance.collection('game_state').doc('question_bank').set({'questions': formatted});

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Successfully uploaded ${formatted.length} questions!'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Invalid JSON format: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Upload Bank'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    _timerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('game_state').doc('current').snapshots(),
      builder: (context, snapshot) {
        final gameState = snapshot.data?.data() ?? {};
        final currentPhase = gameState['phase'] as String? ?? 'idle';
        final secondsRemaining = gameState['secondsRemaining'] as int? ?? 0;
        final targetedPlayerName = gameState['targetedPlayerName'] as String? ?? 'None';
        final usedQuestionIds = List<String>.from(gameState['usedQuestionIds'] ?? []);
        final selectedQuestion = gameState['selectedQuestion'] as Map<String, dynamic>?;

        return Card(
          elevation: 2,
          color: Colors.deepPurple.shade50,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Moderator Control Center',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple.shade900,
                          ),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.upload_file, size: 16),
                      label: const Text('Upload MCQ Bank', style: TextStyle(fontSize: 12)),
                      onPressed: _showQuestionBankUploadDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Town Discussion Duration (seconds):',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                    SizedBox(
                      width: 80,
                      height: 40,
                      child: TextField(
                        controller: _timerController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10),
                        ),
                        onChanged: (val) {
                          final parsed = int.tryParse(val);
                          if (parsed != null && parsed > 0) {
                            _townDiscussionDuration = parsed;
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.deepPurple.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Targeted Player: $targetedPlayerName', style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (selectedQuestion != null)
                        Text(
                          'Selected MCQ: "${selectedQuestion['question']}"',
                          style: TextStyle(color: Colors.deepPurple.shade800, fontStyle: FontStyle.italic),
                        ),
                      Text('Used Questions Count: ${usedQuestionIds.length}', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                if (currentPhase != 'idle' && currentPhase != 'roundCompleted') ...[
                  LinearProgressIndicator(value: (secondsRemaining / _standardDuration).clamp(0.0, 1.0)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Phase: $currentPhase', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('$secondsRemaining s', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (currentPhase == 'idle')
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple.shade700, foregroundColor: Colors.white),
                        icon: const Icon(Icons.nights_stay),
                        label: const Text('Start Night Phase'),
                        onPressed: _areIdentitiesAllocated ? _startNewRound : null,
                      ),
                    if (currentPhase == 'killerPhase')
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple.shade700, foregroundColor: Colors.white),
                        onPressed: _onKillerPhaseComplete,
                        child: const Text('Lock Killer Selection'),
                      ),
                    if (currentPhase == 'awaitingHealerStart')
                      ElevatedButton.icon(
                        icon: const Icon(Icons.medical_services),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white),
                        label: const Text('Transfer Question to Healer'),
                        onPressed: _transferToHealer,
                      ),
                    if (currentPhase == 'healerPhase')
                      ElevatedButton.icon(
                        icon: const Icon(Icons.arrow_forward),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade800, foregroundColor: Colors.white),
                        label: const Text('End Healer Phase Early'),
                        onPressed: () => _resolveHealerPhase(timeout: false),
                      ),
                    if (currentPhase == 'awaitingDetectiveStart')
                      ElevatedButton.icon(
                        icon: const Icon(Icons.search),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo.shade700, foregroundColor: Colors.white),
                        label: const Text('Start Detective Phase'),
                        onPressed: _transferToDetective,
                      ),
                    if (currentPhase == 'detectivePhase')
                      ElevatedButton.icon(
                        icon: const Icon(Icons.arrow_forward),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo.shade800, foregroundColor: Colors.white),
                        label: const Text('End Detective Phase Early'),
                        onPressed: () => _resolveDetectivePhase(timeout: false),
                      ),
                    if (currentPhase == 'awaitingVillagersStart')
                      ElevatedButton.icon(
                        icon: const Icon(Icons.wb_sunny),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white),
                        label: const Text('Start Day / Villagers Phase'),
                        onPressed: _transferToVillagers,
                      ),
                    if (currentPhase == 'villagersPhase')
                      ElevatedButton.icon(
                        icon: const Icon(Icons.flag),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
                        label: const Text('Finalize Round Early'),
                        onPressed: () async {
                          final docSnap = await FirebaseFirestore.instance.collection('game_state').doc('current').get();
                          final targetedUserId = docSnap.data()?['targetedPlayerId'] as String?;
                          _finalizeRound(targetSaved: false, targetedUserId: targetedUserId);
                        },
                      ),
                    if (currentPhase == 'roundCompleted')
                      ElevatedButton(
                        onPressed: () => JsonStorageService.updateGameState({'phase': 'idle'}),
                        child: const Text('Reset for Next Round'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}