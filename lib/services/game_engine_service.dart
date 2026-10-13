import 'dart:math';
import '../models/user_model.dart';

/// Result of counting votes. Ties are broken in favour of the option that
/// received its first vote earliest, but [isTie] still reports the tie so the
/// caller can decide whether a tie should count (e.g. no elimination).
class VoteResult {
  final String? winner;
  final bool isTie;
  final Map<String, int> counts;

  const VoteResult({
    required this.winner,
    required this.isTie,
    required this.counts,
  });
}

class GameEngineService {
  static final Random _random = Random();

  static const Set<String> validIdentities = {
    'killer',
    'healer',
    'detective',
    'villager',
  };

  /// True when the player holds a real in-game identity (case-insensitive,
  /// so both 'none' and legacy 'NONE' count as unassigned).
  static bool hasIdentity(User user) =>
      validIdentities.contains(user.identity.toLowerCase());

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

  /// 2. SHARED QUESTION OPTIONS
  /// Picks the quiz options ALL killers choose from this round. Unused
  /// questions come first; if fewer than [count] are left, already used ones
  /// top the list up so a small bank never runs dry. Questions without an id
  /// are skipped because votes refer to questions by id.
  static List<Map<String, dynamic>> pickQuestionOptions({
    required List<Map<String, dynamic>> bank,
    required List<String> usedQuestionIds,
    int count = 4,
  }) {
    final seen = <String>{};
    final pool = <Map<String, dynamic>>[];
    for (final q in bank) {
      final id = q['id']?.toString() ?? '';
      if (id.isEmpty || !seen.add(id)) continue;
      pool.add(q);
    }

    final unused = pool
        .where((q) => !usedQuestionIds.contains(q['id'].toString()))
        .toList()
      ..shuffle(_random);
    final used = pool
        .where((q) => usedQuestionIds.contains(q['id'].toString()))
        .toList()
      ..shuffle(_random);

    return [...unused, ...used].take(count).toList();
  }

  /// Copy of a question that is safe to show to killers (no answer key).
  static Map<String, dynamic> publicQuestion(Map<String, dynamic> question) {
    final copy = Map<String, dynamic>.from(question);
    copy.remove('correctAnswer');
    copy.remove('answer');
    return copy;
  }

  /// 3. VOTE TALLY (killer target/question, healer protection, day trial)
  static VoteResult tally(Iterable<MapEntry<String, DateTime>> picks) {
    final counts = <String, int>{};
    final firstVote = <String, DateTime>{};

    for (final pick in picks) {
      counts[pick.key] = (counts[pick.key] ?? 0) + 1;
      final earliest = firstVote[pick.key];
      if (earliest == null || pick.value.isBefore(earliest)) {
        firstVote[pick.key] = pick.value;
      }
    }

    if (counts.isEmpty) {
      return const VoteResult(winner: null, isTie: false, counts: {});
    }

    final top = counts.values.reduce(max);
    final leaders = counts.entries
        .where((e) => e.value == top)
        .map((e) => e.key)
        .toList()
      ..sort((a, b) => firstVote[a]!.compareTo(firstVote[b]!));

    return VoteResult(
      winner: leaders.first,
      isTie: leaders.length > 1,
      counts: counts,
    );
  }

  /// 4. WIN CONDITION
  /// Returns 'town' when every killer is gone, 'killers' when they equal or
  /// outnumber everyone else, otherwise null (game continues).
  static String? checkWinner(List<User> players) {
    final living = players
        .where((p) => p.isAlive && !p.isTerminated && hasIdentity(p))
        .toList();
    if (living.isEmpty) return null;

    final killers =
        living.where((p) => p.identity.toLowerCase() == 'killer').length;
    final others = living.length - killers;

    if (killers == 0) return 'town';
    if (killers >= others) return 'killers';
    return null;
  }
}