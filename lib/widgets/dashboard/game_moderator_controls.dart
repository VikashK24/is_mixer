import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/game_engine_service.dart';
import '../../services/json_storage_service.dart';

/// When true, healers only save the victim if the healer team's chosen
/// protection target matches the killers' target AND every living healer
/// answered the quiz correctly. Set to false to require only the quiz.
const bool _requireProtectTargetMatch = true;

/// The game counts as started once the first night phase has begun
/// (`gameStarted` flag) or whenever the phase is anything other than idle.
bool _isGameStarted(Map<String, dynamic> state) {
  if (state['gameStarted'] == true) return true;
  final phase = (state['phase'] ?? 'idle').toString().toLowerCase();
  return phase.isNotEmpty && phase != 'idle';
}

DateTime _timeOf(dynamic ts) => ts is Timestamp ? ts.toDate() : DateTime.now();

/// One killer's submitted vote (target + quiz question).
class _KillerVote {
  final String voterId;
  final String? targetId;
  final Map<String, dynamic>? question;
  final DateTime time;

  const _KillerVote({
    required this.voterId,
    required this.targetId,
    required this.question,
    required this.time,
  });
}

class _QuestionBankParseResult {
  final List<Map<String, dynamic>> questions;
  final List<String> errors;

  const _QuestionBankParseResult(this.questions, this.errors);
}

/// Validates and normalises a pasted question bank.
/// Accepts either a JSON array or {"questions": [...]}.
_QuestionBankParseResult _parseQuestionBank(String raw) {
  dynamic decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (e) {
    return _QuestionBankParseResult(const [], ['Not valid JSON: $e']);
  }

  if (decoded is Map && decoded['questions'] is List) {
    decoded = decoded['questions'];
  }
  if (decoded is! List) {
    return const _QuestionBankParseResult(
      [],
      ['Expected a JSON array of questions (or {"questions": [...]}).'],
    );
  }
  if (decoded.isEmpty) {
    return const _QuestionBankParseResult([], ['The question list is empty.']);
  }

  final errors = <String>[];
  final questions = <Map<String, dynamic>>[];
  final seenIds = <String>{};

  for (var i = 0; i < decoded.length; i++) {
    final label = 'Question ${i + 1}';
    final item = decoded[i];
    if (item is! Map) {
      errors.add('$label: must be an object.');
      continue;
    }

    final errorsBefore = errors.length;
    final text = (item['question'] ?? item['text'] ?? '').toString().trim();
    final answer = (item['correctAnswer'] ?? item['answer'] ?? '').toString().trim();
    final id = (item['id'] ?? 'q${i + 1}').toString().trim();
    final rawOptions = item['options'];

    final options = rawOptions is List
        ? rawOptions
            .map((o) => o.toString().trim())
            .where((o) => o.isNotEmpty)
            .toList()
        : <String>[];

    if (text.isEmpty) errors.add('$label: "question" is missing.');
    if (options.length < 2) {
      errors.add('$label: needs at least 2 non-empty "options".');
    }

    String? matched;
    for (final o in options) {
      if (o.toLowerCase() == answer.toLowerCase()) {
        matched = o;
        break;
      }
    }
    if (answer.isEmpty) {
      errors.add('$label: "correctAnswer" is missing.');
    } else if (options.length >= 2 && matched == null) {
      errors.add('$label: "correctAnswer" must match one of the options.');
    }

    if (id.isEmpty) {
      errors.add('$label: "id" cannot be empty.');
    } else if (!seenIds.add(id)) {
      errors.add('$label: duplicate id "$id".');
    }

    if (errors.length == errorsBefore) {
      questions.add({
        'id': id,
        'question': text,
        'options': options,
        'correctAnswer': matched,
      });
    }
  }

  if (errors.isEmpty && jsonEncode(questions).length > 900000) {
    errors.add('The question bank is too large (limit is about 900 KB).');
  }

  return _QuestionBankParseResult(questions, errors);
}

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
  String? _timerKey; // "<phase>@<endsAtMs>" of the timer last started/resumed
  static const int _standardDuration = 30;
  int _townDiscussionDuration = 60;
  final TextEditingController _timerController = TextEditingController(text: '60');
  bool _busy = false;

  static const Map<String, String> _phaseLabels = {
    'idle': 'Idle',
    'killerPhase': 'Killer Phase',
    'awaitingHealerStart': 'Awaiting Healer Start',
    'healerPhase': 'Healer Phase',
    'awaitingDetectiveStart': 'Awaiting Detective Start',
    'detectivePhase': 'Detective Phase',
    'awaitingVillagersStart': 'Awaiting Day Start',
    'villagersPhase': 'Day / Villagers Phase',
    'roundCompleted': 'Round Completed',
  };

  DocumentReference<Map<String, dynamic>> get _stateRef =>
      FirebaseFirestore.instance.collection('game_state').doc('current');

  // ───────────────────────── Player helpers ─────────────────────────

  /// Players who can still act: alive and not blocked from the app.
  List<User> get _inPlay =>
      widget.playerList.where((p) => p.isAlive && !p.isTerminated).toList();

  List<User> get _livingKillers =>
      _inPlay.where((p) => p.identity.toLowerCase() == 'killer').toList();

  List<User> get _activeHealers =>
      _inPlay.where((p) => p.identity.toLowerCase() == 'healer').toList();

  bool get _isHealerAlive => _activeHealers.isNotEmpty;

  bool get _isDetectiveAlive =>
      _inPlay.any((p) => p.identity.toLowerCase() == 'detective');

  /// Before the very first round, every active player needs an identity.
  bool get _identitiesReady {
    final active = widget.playerList.where((p) => !p.isTerminated).toList();
    return active.isNotEmpty && active.every(GameEngineService.hasIdentity);
  }

  String? _startBlockedReason(Map<String, dynamic> state) {
    if (state['winner'] != null) {
      return 'The game is over. Use "End Game" to start a new one.';
    }
    if (!_isGameStarted(state) && !_identitiesReady) {
      return 'Allocate identities to all active players before starting.';
    }
    if (_livingKillers.isEmpty) return 'No living killers remain.';
    if (!_inPlay.any((p) => p.identity.toLowerCase() != 'killer')) {
      return 'No living innocent players remain.';
    }
    return null;
  }

  // ───────────────────────── Generic helpers ─────────────────────────

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  Future<Map<String, dynamic>> _readState() async =>
      (await _stateRef.get()).data() ?? {};

  /// Runs a moderator action once at a time and reports failures.
  Future<void> _guarded(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      _snack('Action failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String message, String confirmLabel) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result == true;
  }

  // ───────────────────────── Timer (resumable) ─────────────────────────
  //
  // Every timed phase stores `phaseEndsAt` (epoch ms) in Firestore. The
  // countdown is computed from that value, so a refreshed or second moderator
  // screen can pick the timer up again instead of leaving the phase stuck.

  Future<void> Function()? _handlerFor(String phase) {
    switch (phase) {
      case 'killerPhase':
        return _onKillerPhaseComplete;
      case 'healerPhase':
        return _resolveHealerPhase;
      case 'detectivePhase':
        return _resolveDetectivePhase;
      case 'villagersPhase':
        return _finalizeRound;
      default:
        return null;
    }
  }

  Map<String, dynamic> _timedFields(int seconds) => {
        'phaseDuration': seconds,
        'secondsRemaining': seconds,
        'phaseEndsAt': DateTime.now().millisecondsSinceEpoch + seconds * 1000,
      };

  void _runTimerUntil(String phase, int endsAtMs) {
    _phaseTimer?.cancel();
    final handler = _handlerFor(phase);
    if (handler == null) return;
    _timerKey = '$phase@$endsAtMs';

    _phaseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final left =
          ((endsAtMs - DateTime.now().millisecondsSinceEpoch) / 1000).ceil();
      if (left > 0) {
        _stateRef.update({'secondsRemaining': left}).catchError((_) {});
      } else {
        timer.cancel();
        _stateRef.update({'secondsRemaining': 0}).catchError((_) {});
        handler().catchError((e) {
          debugPrint('Phase timeout handler failed: $e');
        });
      }
    });
  }

  void _stopTimer() {
    _phaseTimer?.cancel();
  }

  /// Called after every state update; restarts the countdown if this screen
  /// has no timer running for the current timed phase.
  void _maybeResumeTimer(Map<String, dynamic> state) {
    if (_phaseTimer?.isActive == true) return;

    final phase = (state['phase'] ?? 'idle').toString();
    final handler = _handlerFor(phase);
    final endsAt = (state['phaseEndsAt'] as num?)?.toInt();
    if (handler == null || endsAt == null) return;

    final key = '$phase@$endsAt';
    if (_timerKey == key) return; // already running or already fired
    _timerKey = key;

    if (endsAt <= DateTime.now().millisecondsSinceEpoch) {
      handler().catchError((e) {
        debugPrint('Resumed phase handler failed: $e');
      });
    } else {
      _runTimerUntil(phase, endsAt);
    }
  }

  // ───────────────────────── Round data cleanup ─────────────────────────

  Future<void> _clearSubcollection(String name) async {
    final snap = await _stateRef.collection(name).get();
    if (snap.docs.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final d in snap.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }

  /// Votes, answers and investigations from a previous round must never leak
  /// into the next one.
  Future<void> _clearRoundData() async {
    for (final name in const [
      'killer_votes',
      'healer_answers',
      'day_votes',
      'detective_checks',
    ]) {
      await _clearSubcollection(name);
    }
  }

  // ───────────────────────── Round flow ─────────────────────────

  /// idle -> killerPhase
  /// The target and quiz question are NOT chosen here. One shared set of quiz
  /// options is published so every killer votes on the same choices; the
  /// killers then pick the target and question.
  Future<void> _startNewRound() async {
    final state = await _readState();
    final reason = _startBlockedReason(state);
    if (reason != null) throw reason;

    final usedIds = List<String>.from(state['usedQuestionIds'] ?? []);
    final options = GameEngineService.pickQuestionOptions(
      bank: widget.moderatorQuestionBank,
      usedQuestionIds: usedIds,
    );
    if (options.isEmpty) {
      throw 'The question bank is empty. Upload questions before the game starts.';
    }

    await _clearRoundData();

    final timed = _timedFields(_standardDuration);
    await JsonStorageService.updateGameState({
      'gameStarted': true,
      'roundToken': DateTime.now().millisecondsSinceEpoch,
      'phase': 'killerPhase',
      'isNight': true,
      'activeQuestion': null,
      'selectedQuestion': null,
      'targetedPlayerId': null,
      'targetedPlayerName': null,
      'nightOutcome': null,
      'killerQuestionOptions':
          options.map(GameEngineService.publicQuestion).toList(),
      ...timed,
      'announcement':
          'Night has fallen! Killers are choosing a victim and a quiz question.',
    });

    _runTimerUntil('killerPhase', timed['phaseEndsAt'] as int);
  }

  /// killerPhase -> awaitingHealerStart / awaitingDetectiveStart / awaitingVillagersStart
  /// Uses ONLY what the killers selected: the majority target and the majority
  /// quiz question (ties go to the earliest vote). If the killers submitted
  /// nothing, nobody is attacked.
  Future<void> _onKillerPhaseComplete() async {
    _stopTimer();

    final state = await _readState();
    if (state['phase'] != 'killerPhase') return; // already locked

    final usedIds = List<String>.from(state['usedQuestionIds'] ?? []);
    final killerIds = _livingKillers.map((p) => p.id).toSet();
    final validTargetIds = _inPlay
        .where((p) => p.identity.toLowerCase() != 'killer')
        .map((p) => p.id)
        .toSet();
    final offeredIds = ((state['killerQuestionOptions'] as List?) ?? [])
        .whereType<Map>()
        .map((q) => q['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    final snap = await _stateRef.collection('killer_votes').get();
    final votes = snap.docs
        .map((d) {
          final data = d.data();
          final q = data['selectedQuestion'];
          return _KillerVote(
            voterId: (data['voterId'] ?? d.id).toString(),
            targetId: data['targetUserId'] as String?,
            question: q is Map ? Map<String, dynamic>.from(q) : null,
            time: _timeOf(data['timestamp']),
          );
        })
        .where((v) => killerIds.contains(v.voterId))
        .toList();

    final targetId = GameEngineService.tally(
      votes
          .where((v) => v.targetId != null && validTargetIds.contains(v.targetId))
          .map((v) => MapEntry(v.targetId!, v.time)),
    ).winner;

    final questionVotes = votes
        .where((v) =>
            v.question != null && offeredIds.contains(v.question!['id']?.toString()))
        .toList();
    final questionId = GameEngineService.tally(
      questionVotes.map((v) => MapEntry(v.question!['id'].toString(), v.time)),
    ).winner;

    final User? target = targetId == null
        ? null
        : widget.playerList.where((p) => p.id == targetId).firstOrNull;

    // Votes only carry the public question (no answer key), so the full
    // question - with its correct answer - is looked up in the bank.
    Map<String, dynamic>? question;
    if (questionId != null) {
      final fromBank = widget.moderatorQuestionBank
          .where((q) => q['id']?.toString() == questionId)
          .firstOrNull;
      question = fromBank != null
          ? Map<String, dynamic>.from(fromBank)
          : questionVotes
              .firstWhere((v) => v.question!['id'].toString() == questionId)
              .question;
    }

    final bool hasAttack = target != null && question != null;
    if (hasAttack && !usedIds.contains(questionId)) usedIds.add(questionId!);

    // Healers only matter when there is an attack to defend against.
    final String nextPhase = (hasAttack && _isHealerAlive)
        ? 'awaitingHealerStart'
        : (_isDetectiveAlive ? 'awaitingDetectiveStart' : 'awaitingVillagersStart');

    await JsonStorageService.updateGameState({
      'phase': nextPhase,
      'targetedPlayerId': hasAttack ? target!.id : null,
      'targetedPlayerName': hasAttack ? target!.username : null,
      'selectedQuestion': hasAttack ? question : null,
      'usedQuestionIds': usedIds,
      'secondsRemaining': 0,
      'phaseEndsAt': null,
      'announcement': hasAttack
          ? 'The killers have made their choice. The night continues...'
          : 'The killers could not agree on a target tonight.',
    });
  }

  /// awaitingHealerStart -> healerPhase
  Future<void> _transferToHealer() async {
    final state = await _readState();
    if (state['phase'] != 'awaitingHealerStart') return;

    final question = state['selectedQuestion'];
    if (question == null) {
      // Nothing to answer, skip straight on.
      await _resolveHealerPhase();
      return;
    }

    await _clearSubcollection('healer_answers');

    final timed = _timedFields(_standardDuration);
    await JsonStorageService.updateGameState({
      'phase': 'healerPhase',
      'isNight': true,
      'activeQuestion': question,
      ...timed,
      'announcement':
          'Healers Active: Choose who to protect and solve the quiz picked by the Killers!',
    });

    _runTimerUntil('healerPhase', timed['phaseEndsAt'] as int);
  }

  /// healerPhase -> awaitingDetectiveStart / awaitingVillagersStart
  Future<void> _resolveHealerPhase() async {
    _stopTimer();

    final state = await _readState();
    final phase = state['phase'];
    if (phase != 'healerPhase' && phase != 'awaitingHealerStart') return;

    await JsonStorageService.updateGameState({
      'phase': _isDetectiveAlive ? 'awaitingDetectiveStart' : 'awaitingVillagersStart',
      'activeQuestion': null, // closes the quiz so late answers are impossible
      'secondsRemaining': 0,
      'phaseEndsAt': null,
    });
  }

  /// awaitingDetectiveStart -> detectivePhase
  Future<void> _transferToDetective() async {
    final state = await _readState();
    if (state['phase'] != 'awaitingDetectiveStart') return;

    final timed = _timedFields(_standardDuration);
    await JsonStorageService.updateGameState({
      'phase': 'detectivePhase',
      'isNight': true,
      'activeQuestion': null,
      ...timed,
      'announcement': 'Detective Action Active: Performing identity investigation.',
    });

    _runTimerUntil('detectivePhase', timed['phaseEndsAt'] as int);
  }

  /// detectivePhase -> awaitingVillagersStart
  Future<void> _resolveDetectivePhase() async {
    _stopTimer();

    final state = await _readState();
    if (state['phase'] != 'detectivePhase') return;

    await JsonStorageService.updateGameState({
      'phase': 'awaitingVillagersStart',
      'secondsRemaining': 0,
      'phaseEndsAt': null,
    });
  }

  /// awaitingVillagersStart -> villagersPhase
  /// The night is resolved here: the victim is eliminated (or saved) as the
  /// town wakes up, and the outcome is stored for the end-of-round summary.
  Future<void> _transferToVillagers() async {
    final state = await _readState();
    if (state['phase'] != 'awaitingVillagersStart') return;

    final targetId = state['targetedPlayerId'] as String?;
    final targetName = state['targetedPlayerName'] as String?;

    bool saved = false;
    if (targetId != null && _isHealerAlive) {
      final snap = await _stateRef.collection('healer_answers').get();
      final answers = {for (final d in snap.docs) d.id: d.data()};

      final allCorrect =
          _activeHealers.every((h) => answers[h.id]?['isCorrect'] == true);

      bool protectedRight = true;
      if (_requireProtectTargetMatch) {
        final picks = _activeHealers
            .where((h) => answers[h.id]?['targetUserId'] != null)
            .map((h) => MapEntry(
                  answers[h.id]!['targetUserId'].toString(),
                  _timeOf(answers[h.id]!['timestamp']),
                ));
        protectedRight = GameEngineService.tally(picks).winner == targetId;
      }

      saved = allCorrect && protectedRight;
    }

    String notice;
    if (targetId == null) {
      notice = 'The killers failed to strike tonight - everyone survived!';
    } else if (saved) {
      notice = 'GOOD NEWS: Everyone survived the night!';
    } else {
      final victim = widget.playerList.where((p) => p.id == targetId).firstOrNull;
      if (victim != null) {
        await JsonStorageService.updateUserIdentity(
          userId: victim.id,
          identity: victim.identity,
          isAlive: false,
        );
      }
      notice = 'ALERT: ${targetName ?? 'A player'} was TERMINATED during the night!';
    }

    final timed = _timedFields(_townDiscussionDuration);
    await JsonStorageService.updateGameState({
      'phase': 'villagersPhase',
      'isNight': false,
      'activeQuestion': null,
      'nightOutcome': targetId == null
          ? null
          : {'targetId': targetId, 'targetName': targetName, 'saved': saved},
      ...timed,
      'announcement': 'Everyone awakes! Day discussion & voting begins. $notice',
    });

    _runTimerUntil('villagersPhase', timed['phaseEndsAt'] as int);
  }

  /// villagersPhase -> roundCompleted
  /// Counts the day votes (plurality; a tie eliminates nobody), eliminates the
  /// accused player, then checks whether either side has won.
  Future<void> _finalizeRound() async {
    _stopTimer();

    final state = await _readState();
    if (state['phase'] != 'villagersPhase') return;

    // ── night summary ──
    final outcome = state['nightOutcome'];
    String nightMessage = 'No one was attacked tonight.';
    String? nightVictimId;
    if (outcome is Map && outcome['targetName'] != null) {
      final name = outcome['targetName'];
      if (outcome['saved'] == true) {
        nightMessage = 'Player $name was targeted but SAVED by Healers!';
      } else {
        nightMessage = 'Player $name was targeted and TERMINATED by Killers!';
        nightVictimId = outcome['targetId']?.toString();
      }
    }

    // ── day trial vote ──
    final living = _inPlay.where((p) => p.id != nightVictimId).toList();
    final livingIds = living.map((p) => p.id).toSet();

    final voteSnap = await _stateRef.collection('day_votes').get();
    final picks = <MapEntry<String, DateTime>>[];
    for (final d in voteSnap.docs) {
      final data = d.data();
      final voterId = (data['voterId'] ?? d.id).toString();
      final accusedId = data['accusedUserId']?.toString();
      if (accusedId == null || accusedId == voterId) continue;
      if (!livingIds.contains(voterId) || !livingIds.contains(accusedId)) continue;
      picks.add(MapEntry(accusedId, _timeOf(data['timestamp'])));
    }

    String dayMessage;
    String? votedOutId;
    final result = GameEngineService.tally(picks);
    if (picks.isEmpty) {
      dayMessage = 'Nobody voted, so the town eliminated no one.';
    } else if (result.isTie) {
      dayMessage = 'The town vote ended in a tie - nobody was eliminated.';
    } else {
      final accused = living.where((p) => p.id == result.winner).firstOrNull;
      if (accused != null) {
        votedOutId = accused.id;
        await JsonStorageService.updateUserIdentity(
          userId: accused.id,
          identity: accused.identity,
          isAlive: false,
        );
        dayMessage = 'The town voted out ${accused.username}.';
      } else {
        dayMessage = 'The town vote could not be resolved.';
      }
    }

    // ── win check on the post-round roster ──
    final afterRound = widget.playerList
        .map((p) => (p.id == nightVictimId || p.id == votedOutId)
            ? p.copyWith(isAlive: false)
            : p)
        .toList();
    final winner = GameEngineService.checkWinner(afterRound);
    final winnerMessage = winner == 'town'
        ? ' GAME OVER: The Town wins - every killer has been found!'
        : (winner == 'killers'
            ? ' GAME OVER: The Killers win - they now equal or outnumber the town!'
            : '');

    await JsonStorageService.updateGameState({
      'phase': 'roundCompleted',
      'isNight': false,
      'secondsRemaining': 0,
      'phaseEndsAt': null,
      'winner': winner,
      'announcement': '$nightMessage $dayMessage$winnerMessage',
    });
  }

  /// roundCompleted -> idle (next round number)
  Future<void> _resetForNextRound() async {
    final state = await _readState();
    final nextRound = ((state['round'] as num?)?.toInt() ?? 1) + 1;

    await JsonStorageService.updateGameState({
      'phase': 'idle',
      'isNight': false,
      'round': nextRound,
      'activeQuestion': null,
      'selectedQuestion': null,
      'killerQuestionOptions': null,
      'targetedPlayerId': null,
      'targetedPlayerName': null,
      'nightOutcome': null,
      'secondsRemaining': 0,
      'phaseEndsAt': null,
      'announcement': state['winner'] != null
          ? 'The game is over. Use "End Game" to start a new one.'
          : 'Round $nextRound is about to begin. Standby for the Moderator.',
    });
  }

  /// Ends the whole game: unlocks identity allocation and the question bank.
  Future<void> _endGame() async {
    final ok = await _confirm(
      'End the game?',
      'This resets the phase, round counter, used questions and all votes, and '
          'revives every player. Identities are kept until you re-allocate them.',
      'End Game',
    );
    if (!ok) return;

    _stopTimer();
    await _clearRoundData();

    for (final p in widget.playerList.where((p) => !p.isAlive)) {
      await JsonStorageService.updateUserIdentity(
        userId: p.id,
        identity: p.identity,
        isAlive: true,
      );
    }

    await JsonStorageService.updateGameState({
      'gameStarted': false,
      'roundToken': null,
      'phase': 'idle',
      'isNight': false,
      'round': 1,
      'winner': null,
      'activeQuestion': null,
      'selectedQuestion': null,
      'killerQuestionOptions': null,
      'targetedPlayerId': null,
      'targetedPlayerName': null,
      'nightOutcome': null,
      'usedQuestionIds': <String>[],
      'secondsRemaining': 0,
      'phaseEndsAt': null,
      'announcement': 'The game has ended. Standby for the next game.',
    });
  }

  // ───────────────────────── Question bank upload ─────────────────────────

  void _showQuestionBankUploadDialog() {
    final controller = TextEditingController();
    List<String> errors = [];
    bool uploading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> submit() async {
            final result = _parseQuestionBank(controller.text.trim());
            if (result.errors.isNotEmpty) {
              setDialogState(() => errors = result.errors);
              return;
            }

            setDialogState(() {
              errors = [];
              uploading = true;
            });

            try {
              final state = await _readState();
              if (_isGameStarted(state)) {
                setDialogState(() {
                  errors = ['The game has already started - the question bank is locked.'];
                  uploading = false;
                });
                return;
              }

              // set() WITHOUT merge replaces the whole document, so the new
              // bulk import completely overwrites the previous bank.
              await FirebaseFirestore.instance
                  .collection('game_state')
                  .doc('question_bank')
                  .set({
                'questions': result.questions,
                'count': result.questions.length,
                'updatedAt': FieldValue.serverTimestamp(),
              });
              await JsonStorageService.updateGameState({'usedQuestionIds': <String>[]});

              if (ctx.mounted) Navigator.of(ctx).pop();
              _snack(
                'Question bank replaced: ${result.questions.length} questions imported.',
              );
            } catch (e) {
              setDialogState(() {
                errors = ['Upload failed: $e'];
                uploading = false;
              });
            }
          }

          return AlertDialog(
            title: const Text('Import MCQ Question Bank (JSON)'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 18, color: Colors.orange),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'This REPLACES the entire existing question bank. '
                              'Only possible before the game starts.',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Paste a JSON array. "id" is optional (auto-numbered). '
                      '"correctAnswer" must match one of the options.',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: controller,
                      enabled: !uploading,
                      maxLines: 10,
                      decoration: const InputDecoration(
                        hintText:
                            '[\n  {\n    "id": "q1",\n    "question": "Sample?",\n    "options": ["A", "B", "C", "D"],\n    "correctAnswer": "A"\n  }\n]',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (errors.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final e in errors.take(6))
                              Text(
                                '• $e',
                                style: TextStyle(fontSize: 12, color: Colors.red.shade900),
                              ),
                            if (errors.length > 6)
                              Text(
                                '...and ${errors.length - 6} more issue(s).',
                                style: TextStyle(fontSize: 12, color: Colors.red.shade900),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: uploading ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: uploading ? null : submit,
                child: uploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Replace Question Bank'),
              ),
            ],
          );
        },
      ),
    ).whenComplete(controller.dispose);
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    _timerController.dispose();
    super.dispose();
  }

  // ───────────────────────── UI ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _stateRef.snapshots(),
      builder: (context, snapshot) {
        final gameState = snapshot.data?.data() ?? {};
        final currentPhase = gameState['phase'] as String? ?? 'idle';
        final secondsRemaining = (gameState['secondsRemaining'] as num?)?.toInt() ?? 0;
        final phaseDuration =
            (gameState['phaseDuration'] as num?)?.toInt() ?? _standardDuration;
        final round = (gameState['round'] as num?)?.toInt() ?? 1;
        final targetedPlayerName = gameState['targetedPlayerName'] as String? ?? 'None';
        final usedQuestionIds = List<String>.from(gameState['usedQuestionIds'] ?? []);
        final rawQuestion = gameState['selectedQuestion'];
        final Map<String, dynamic>? selectedQuestion =
            rawQuestion is Map ? Map<String, dynamic>.from(rawQuestion) : null;
        final String? winner = gameState['winner'] as String?;

        final bool gameStarted = _isGameStarted(gameState);
        final String? blockedReason = _startBlockedReason(gameState);
        final bool busy = _busy;

        // Pick the countdown back up after a refresh / on a second moderator screen.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _maybeResumeTimer(gameState);
        });

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
                  children: [
                    Expanded(
                      child: Text(
                        'Moderator Control Center',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple.shade900,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: gameStarted
                          ? 'Locked while a game is in progress'
                          : 'Replace the whole question bank',
                      child: OutlinedButton.icon(
                        icon: Icon(gameStarted ? Icons.lock : Icons.upload_file, size: 16),
                        label: const Text('Upload MCQ Bank', style: TextStyle(fontSize: 12)),
                        onPressed: (gameStarted || busy) ? null : _showQuestionBankUploadDialog,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: gameStarted ? Colors.deepOrange.shade100 : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        gameStarted ? 'Game in progress - Round $round' : 'Game not started',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: gameStarted ? Colors.deepOrange.shade900 : Colors.grey.shade700,
                        ),
                      ),
                    ),
                    if (winner != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          winner == 'town' ? 'Winner: Town' : 'Winner: Killers',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900,
                          ),
                        ),
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
                      Text(
                        'Targeted Player: $targetedPlayerName',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (selectedQuestion != null) ...[
                        Text(
                          'Selected MCQ: "${selectedQuestion['question']}"',
                          style: TextStyle(
                            color: Colors.deepPurple.shade800,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        Text(
                          'Options: ${(selectedQuestion['options'] as List?)?.join(' | ') ?? '-'}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          'Correct answer: ${selectedQuestion['correctAnswer'] ?? '-'}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ],
                      Text(
                        'Used Questions Count: ${usedQuestionIds.length}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      if (currentPhase == 'killerPhase')
                        _CountStatus(
                          label: 'Killer votes received',
                          collection: 'killer_votes',
                          allowedIds: _livingKillers.map((p) => p.id).toSet(),
                          color: Colors.red.shade800,
                        ),
                      if (currentPhase == 'healerPhase')
                        _CountStatus(
                          label: 'Healer answers received',
                          collection: 'healer_answers',
                          allowedIds: _activeHealers.map((p) => p.id).toSet(),
                          color: Colors.teal.shade800,
                        ),
                      if (currentPhase == 'detectivePhase')
                        _CountStatus(
                          label: 'Investigations done',
                          collection: 'detective_checks',
                          allowedIds: _inPlay
                              .where((p) => p.identity.toLowerCase() == 'detective')
                              .map((p) => p.id)
                              .toSet(),
                          color: Colors.indigo.shade800,
                        ),
                      if (currentPhase == 'villagersPhase')
                        _CountStatus(
                          label: 'Town votes cast',
                          collection: 'day_votes',
                          allowedIds: _inPlay.map((p) => p.id).toSet(),
                          color: Colors.orange.shade900,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                if (currentPhase != 'idle' && currentPhase != 'roundCompleted') ...[
                  LinearProgressIndicator(
                    value: (secondsRemaining / phaseDuration).clamp(0.0, 1.0),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'Phase: ${_phaseLabels[currentPhase] ?? currentPhase}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        '$secondsRemaining s',
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
                    if (currentPhase == 'idle')
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple.shade700,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.nights_stay),
                        label: Text(gameStarted ? 'Start Next Night Phase' : 'Start Night Phase'),
                        onPressed: (blockedReason == null && !busy)
                            ? () => _guarded(_startNewRound)
                            : null,
                      ),
                    if (currentPhase == 'killerPhase')
                      ElevatedButton.icon(
                        icon: const Icon(Icons.lock),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple.shade700,
                          foregroundColor: Colors.white,
                        ),
                        label: const Text('Lock Killer Selection'),
                        onPressed: busy ? null : () => _guarded(_onKillerPhaseComplete),
                      ),
                    if (currentPhase == 'awaitingHealerStart')
                      ElevatedButton.icon(
                        icon: const Icon(Icons.medical_services),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade700,
                          foregroundColor: Colors.white,
                        ),
                        label: const Text('Transfer Question to Healer'),
                        onPressed: busy ? null : () => _guarded(_transferToHealer),
                      ),
                    if (currentPhase == 'healerPhase')
                      ElevatedButton.icon(
                        icon: const Icon(Icons.arrow_forward),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade800,
                          foregroundColor: Colors.white,
                        ),
                        label: const Text('End Healer Phase Early'),
                        onPressed: busy ? null : () => _guarded(_resolveHealerPhase),
                      ),
                    if (currentPhase == 'awaitingDetectiveStart')
                      ElevatedButton.icon(
                        icon: const Icon(Icons.search),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo.shade700,
                          foregroundColor: Colors.white,
                        ),
                        label: const Text('Start Detective Phase'),
                        onPressed: busy ? null : () => _guarded(_transferToDetective),
                      ),
                    if (currentPhase == 'detectivePhase')
                      ElevatedButton.icon(
                        icon: const Icon(Icons.arrow_forward),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo.shade800,
                          foregroundColor: Colors.white,
                        ),
                        label: const Text('End Detective Phase Early'),
                        onPressed: busy ? null : () => _guarded(_resolveDetectivePhase),
                      ),
                    if (currentPhase == 'awaitingVillagersStart')
                      ElevatedButton.icon(
                        icon: const Icon(Icons.wb_sunny),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade800,
                          foregroundColor: Colors.white,
                        ),
                        label: const Text('Start Day / Villagers Phase'),
                        onPressed: busy ? null : () => _guarded(_transferToVillagers),
                      ),
                    if (currentPhase == 'villagersPhase')
                      ElevatedButton.icon(
                        icon: const Icon(Icons.flag),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                        ),
                        label: const Text('Finalize Round Early'),
                        onPressed: busy ? null : () => _guarded(_finalizeRound),
                      ),
                    if (currentPhase == 'roundCompleted')
                      ElevatedButton(
                        onPressed: busy ? null : () => _guarded(_resetForNextRound),
                        child: const Text('Reset for Next Round'),
                      ),
                  ],
                ),

                if (currentPhase == 'idle' && blockedReason != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    blockedReason,
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                  ),
                ],

                if (gameStarted) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700),
                    icon: const Icon(Icons.stop_circle_outlined, size: 18),
                    label: const Text('End Game'),
                    onPressed: busy ? null : () => _guarded(_endGame),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Live "x / y have acted" line for the current phase.
class _CountStatus extends StatelessWidget {
  final String label;
  final String collection;
  final Set<String> allowedIds;
  final Color color;

  const _CountStatus({
    required this.label,
    required this.collection,
    required this.allowedIds,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('game_state')
          .doc('current')
          .collection(collection)
          .snapshots(),
      builder: (context, snapshot) {
        final received =
            (snapshot.data?.docs ?? []).where((d) => allowedIds.contains(d.id)).length;
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '$label: $received / ${allowedIds.length}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        );
      },
    );
  }
}