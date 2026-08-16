import 'dart:math';
import '../models/user_model.dart';

/// Represents a vote cast by a role (Killer, Healer, Detective) during a phase turn
class NightPhaseVote {
  final String userId;
  final String questionId;
  final DateTime timestamp;

  NightPhaseVote({
    required this.userId,
    required this.questionId,
    required this.timestamp,
  });
}

/// Payload returned after resolving the night phase outcome
class NightResolution {
  final User target;
  final bool isSaved;
  final String selectedQuestion;
  final String broadcastMessage;

  NightResolution({
    required this.target,
    required this.isSaved,
    required this.selectedQuestion,
    required this.broadcastMessage,
  });
}

class GameEngineService {
  static final Random _random = Random();

  /// 1. DYNAMIC IDENTITY ASSIGNMENT ALGORITHM
  static List<User> assignGameIdentities(List<User> playerUsers) {
    final int total = playerUsers.length;
    if (total < 4) {
      throw ArgumentError('Minimum 4 players required to assign identities.');
    }

    int killerCount = max(1, (total * 0.22).floor());
    int detectiveCount = total >= 5 ? (total >= 13 ? 2 : 1) : 0;
    int healerCount = total >= 6 ? (total >= 15 ? 2 : 1) : 0;
    int villagerCount = total - (killerCount + detectiveCount + healerCount);

    List<String> identityDeck = [
      ...List.generate(killerCount, (_) => 'killer'),
      ...List.generate(detectiveCount, (_) => 'detective'),
      ...List.generate(healerCount, (_) => 'healer'),
      ...List.generate(villagerCount, (_) => 'villager'),
    ];

    identityDeck.shuffle(_random);

    return List.generate(total, (i) {
      return playerUsers[i].copyWith(
        identity: identityDeck[i],
        isAlive: true,
      );
    });
  }

  /// 2. SECRET TARGET SELECTION
  static User selectSecretTarget(List<User> activePlayers) {
    final potentialTargets = activePlayers
        .where((p) => p.isAlive && p.identity != 'killer')
        .toList();

    if (potentialTargets.isEmpty) {
      throw StateError('No valid innocent targets remaining.');
    }

    return potentialTargets[_random.nextInt(potentialTargets.length)];
  }

  /// 3. QUESTION BANK SAMPLING
  static List<String> getAvailableOptions({
    required List<String> moderatorQuestionBank,
    required List<String> usedQuestionIds,
  }) {
    final unused = moderatorQuestionBank
        .where((q) => !usedQuestionIds.contains(q))
        .toList();
    unused.shuffle(_random);
    return unused.take(4).toList();
  }

  /// 4. VOTE RESOLUTION ENGINE (TIE-BREAKING BY TIMESTAMP)
  static String resolveWinningQuestion(List<NightPhaseVote> votes) {
    if (votes.isEmpty) return '';

    final Map<String, List<NightPhaseVote>> groupedVotes = {};
    for (var vote in votes) {
      groupedVotes.putIfAbsent(vote.questionId, () => []).add(vote);
    }

    String winningQuestionId = '';
    int maxCount = -1;
    DateTime earliestTime = DateTime.now().add(const Duration(days: 365));

    groupedVotes.forEach((questionId, voteList) {
      final int count = voteList.length;
      voteList.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final DateTime firstVoteTime = voteList.first.timestamp;

      if (count > maxCount) {
        maxCount = count;
        earliestTime = firstVoteTime;
        winningQuestionId = questionId;
      } else if (count == maxCount) {
        if (firstVoteTime.isBefore(earliestTime)) {
          earliestTime = firstVoteTime;
          winningQuestionId = questionId;
        }
      }
    });

    return winningQuestionId;
  }

  /// 5. DEFENSE RESOLUTION ENGINE
  static NightResolution resolveNightPhase({
    required User secretTarget,
    required String selectedQuestion,
    required bool healerSolved,
    required bool detectiveSolved,
    required bool hasActiveHealer,
    required bool hasActiveDetective,
  }) {
    bool isSaved = false;
    String savedByRole = 'None';

    if (hasActiveHealer && healerSolved) {
      isSaved = true;
      savedByRole = 'Healer';
    } else if (hasActiveDetective && detectiveSolved) {
      isSaved = true;
      savedByRole = 'Detective';
    }

    final message = isSaved
        ? 'ALERT TO VILLAGERS: ${secretTarget.username} was targeted by the Killer group, but was successfully SAVED by the $savedByRole!'
        : 'ALERT TO VILLAGERS: The defense team failed to solve the question. ${secretTarget.username} was TERMINATED!';

    return NightResolution(
      target: isSaved ? secretTarget : secretTarget.copyWith(isAlive: false),
      isSaved: isSaved,
      selectedQuestion: selectedQuestion,
      broadcastMessage: message,
    );
  }
}