import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/game_engine_service.dart';
import '../../services/json_storage_service.dart';

enum PhaseType {
  idle,
  killerPhase,
  awaitingHealerStart,
  healerPhase,
  awaitingDetectiveStart,
  detectivePhase,
  awaitingVillagersStart,
  villagersPhase,
  roundCompleted,
}

class GameModeratorControls extends StatefulWidget {
  final List<User> playerList;
  final List<String> moderatorQuestionBank;

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
  int _secondsRemaining = 30;
  PhaseType _currentPhase = PhaseType.idle;

  User? _autoSelectedTarget;
  String _selectedQuestion = '';
  final List<String> _usedQuestionIds = [];
  final List<NightPhaseVote> _currentVotes = [];

  // Check if every player has been allocated an identity
  bool get _areIdentitiesAllocated =>
      widget.playerList.isNotEmpty &&
      !widget.playerList.any((p) => p.identity == 'NONE' || p.identity.isEmpty);

  bool get _isHealerAlive => widget.playerList.any((p) => p.identity == 'healer' && p.isAlive);
  bool get _isDetectiveAlive => widget.playerList.any((p) => p.identity == 'detective' && p.isAlive);

  void _startTimer(VoidCallback onTimeout) {
    _phaseTimer?.cancel();
    setState(() => _secondsRemaining = 30);

    _phaseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 1) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
        onTimeout();
      }
    });
  }

  void _stopTimer() {
    _phaseTimer?.cancel();
  }

  void _startNewRound() {
    if (!_areIdentitiesAllocated) return;

    try {
      final victim = GameEngineService.selectSecretTarget(widget.playerList);
      _currentVotes.clear();
      _selectedQuestion = '';

      setState(() {
        _autoSelectedTarget = victim;
        _currentPhase = PhaseType.killerPhase;
      });

      _startTimer(() {
        _onKillerPhaseComplete();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot start round: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _onKillerPhaseComplete() {
    _stopTimer();
    final winningQuestion = GameEngineService.resolveWinningQuestion(_currentVotes);

    _selectedQuestion = winningQuestion.isNotEmpty
        ? winningQuestion
        : (widget.moderatorQuestionBank.isNotEmpty
            ? widget.moderatorQuestionBank.first
            : 'Default Question');

    if (_selectedQuestion.isNotEmpty) {
      _usedQuestionIds.add(_selectedQuestion);
    }

    setState(() {
      if (_isHealerAlive) {
        _currentPhase = PhaseType.awaitingHealerStart;
      } else if (_isDetectiveAlive) {
        _currentPhase = PhaseType.awaitingDetectiveStart;
      } else {
        _currentPhase = PhaseType.awaitingVillagersStart;
      }
    });
  }

  void _transferToHealer() {
    setState(() => _currentPhase = PhaseType.healerPhase);
    _startTimer(() {
      _resolveHealerPhase(timeout: true);
    });
  }

  void _resolveHealerPhase({required bool timeout}) {
    _stopTimer();
    setState(() {
      if (_isDetectiveAlive) {
        _currentPhase = PhaseType.awaitingDetectiveStart;
      } else {
        _currentPhase = PhaseType.awaitingVillagersStart;
      }
    });
  }

  void _transferToDetective() {
    setState(() => _currentPhase = PhaseType.detectivePhase);
    _startTimer(() {
      _resolveDetectivePhase(timeout: true);
    });
  }

  void _resolveDetectivePhase({required bool timeout}) {
    _stopTimer();
    setState(() {
      _currentPhase = PhaseType.awaitingVillagersStart;
    });
  }

  void _transferToVillagers() {
    setState(() => _currentPhase = PhaseType.villagersPhase);
    _startTimer(() {
      _finalizeRound(targetSaved: false, savedBy: 'None');
    });
  }

  Future<void> _finalizeRound({required bool targetSaved, required String savedBy}) async {
    _stopTimer();
    setState(() => _currentPhase = PhaseType.roundCompleted);

    if (_autoSelectedTarget != null) {
      await JsonStorageService.updateUserIdentity(
        userId: _autoSelectedTarget!.id,
        identity: _autoSelectedTarget!.identity,
        isAlive: targetSaved,
      );

      final String statusMsg = targetSaved
          ? 'Villager ${_autoSelectedTarget!.username} was targeted but SAVED by $savedBy!'
          : 'Villager ${_autoSelectedTarget!.username} was targeted and TERMINATED!';

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Round Resolution Announcement'),
            content: Text(statusMsg),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() => _autoSelectedTarget = null);
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      color: Colors.deepPurple.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Moderator Phase Controller',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple.shade900,
                  ),
            ),
            const SizedBox(height: 12),

            // Warning Notice when identities aren't assigned
            if (!_areIdentitiesAllocated) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade700),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.amber),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Identities have not been allocated yet. Allocate identities above to enable game round controls.',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

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
                  Text(
                    _autoSelectedTarget != null
                        ? 'Targeted Villager: ${_autoSelectedTarget!.username}'
                        : 'No Active Target (Start Round to auto-assign)',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  if (_selectedQuestion.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Selected Question: "$_selectedQuestion"',
                      style: TextStyle(
                        color: Colors.deepPurple.shade800,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            if (_currentPhase == PhaseType.killerPhase ||
                _currentPhase == PhaseType.healerPhase ||
                _currentPhase == PhaseType.detectivePhase ||
                _currentPhase == PhaseType.villagersPhase) ...[
              LinearProgressIndicator(value: _secondsRemaining / 30),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Active Phase: ${_currentPhase.name.toUpperCase()}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  Text(
                    '$_secondsRemaining s',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_currentPhase == PhaseType.idle)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple.shade700,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade400,
                    ),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Round (Killer Phase 30s)'),
                    // Disabled when identities are not allocated
                    onPressed: _areIdentitiesAllocated ? _startNewRound : null,
                  ),
                if (_currentPhase == PhaseType.killerPhase)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple.shade700,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _onKillerPhaseComplete,
                    child: const Text('Lock Killer Selection & Pause Timer'),
                  ),
                if (_currentPhase == PhaseType.awaitingHealerStart)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.send),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      foregroundColor: Colors.white,
                    ),
                    label: const Text('Transfer Question to Healer (Start 30s)'),
                    onPressed: _transferToHealer,
                  ),
                if (_currentPhase == PhaseType.awaitingDetectiveStart)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.send),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade700,
                      foregroundColor: Colors.white,
                    ),
                    label: const Text('Transfer Question to Detective (Start 30s)'),
                    onPressed: _transferToDetective,
                  ),
                if (_currentPhase == PhaseType.awaitingVillagersStart)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.groups),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade800,
                      foregroundColor: Colors.white,
                    ),
                    label: const Text('Forward Question to Villagers (Start 30s)'),
                    onPressed: _transferToVillagers,
                  ),
                if (_currentPhase == PhaseType.roundCompleted)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey.shade700,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => setState(() => _currentPhase = PhaseType.idle),
                    child: const Text('Reset Controller for Next Round'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}