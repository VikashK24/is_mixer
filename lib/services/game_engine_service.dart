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
  /// Role distribution:
  /// - Killers: ~13%
  /// - Healers: ~30% (Higher proportion for team quiz consensus)
  /// - Detectives: ~7%
  /// - Villagers: ~50% (Remaining pool)
  static List<User> assignGameIdentities(List<User> playerUsers) {
    final int total = playerUsers.length;
    if (total < 4) {
      throw ArgumentError('Minimum 4 players required to assign identities.');
    }

    int killerCount = max(1, (total * 0.13).round());
    int healerCount = max(1, (total * 0.30).round());
    int detectiveCount = max(1, (total * 0.07).round());

    // Scale down if role totals exceed eligible players
    while (killerCount + healerCount + detectiveCount >= total && total > 0) {
      if (detectiveCount > 1) {
        detectiveCount--;
      } else if (healerCount > 1) {
        healerCount--;
      } else if (killerCount > 1) {
        killerCount--;
      } else {
        break;
      }
    }

    int villagerCount = total - (killerCount + healerCount + detectiveCount);
    if (villagerCount < 0) villagerCount = 0;

    List<String> identityDeck = [
      ...List.generate(killerCount, (_) => 'killer'),
      ...List.generate(healerCount, (_) => 'healer'),
      ...List.generate(detectiveCount, (_) => 'detective'),
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
        .where((p) => p.isAlive && p.identity.toLowerCase() != 'killer')
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
        ? 'ALERT TO VILLAGERS: ${secretTarget.username} was targeted by the Killer group, but was successfully SAVED by $savedByRole team consensus!'
        : 'ALERT TO VILLAGERS: The rescue attempt failed. ${secretTarget.username} was TERMINATED!';

    return NightResolution(
      target: isSaved ? secretTarget : secretTarget.copyWith(isAlive: false),
      isSaved: isSaved,
      selectedQuestion: selectedQuestion,
      broadcastMessage: message,
    );
  }
}