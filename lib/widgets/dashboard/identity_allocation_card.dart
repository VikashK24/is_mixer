import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/game_engine_service.dart';
import '../../services/json_storage_service.dart';

const Set<String> _validIdentities = {'killer', 'healer', 'detective', 'villager'};

bool _isAssigned(User p) => _validIdentities.contains(p.identity.toLowerCase());

/// The game counts as started once the first night phase has begun
/// (`gameStarted` flag) or whenever the phase is anything other than idle.
/// It is cleared again by "End Game" in the Moderator Control Center.
bool _isGameStarted(Map<String, dynamic> state) {
  if (state['gameStarted'] == true) return true;
  final phase = (state['phase'] ?? 'idle').toString().toLowerCase();
  return phase.isNotEmpty && phase != 'idle';
}

class IdentityAllocationCard extends StatefulWidget {
  final List<User> playerList;

  const IdentityAllocationCard({
    super.key,
    required this.playerList,
  });

  @override
  State<IdentityAllocationCard> createState() => _IdentityAllocationCardState();
}

class _IdentityAllocationCardState extends State<IdentityAllocationCard> {
  bool _isProcessing = false;

  void _snack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  /// Re-checks the live game state so a stale screen can never bypass the lock.
  Future<bool> _blockedByStartedGame() async {
    final state = await JsonStorageService.getGameState();
    if (_isGameStarted(state)) {
      _snack(
        'The game has already started. End the game first to change identities.',
        Colors.orange,
      );
      return true;
    }
    return false;
  }

  Future<void> _allocateIdentities() async {
    // Blocked accounts do not take part in the game.
    final eligible = widget.playerList.where((p) => !p.isTerminated).toList();

    if (eligible.length < 4) {
      _snack('Minimum 4 active players required to allocate identities.', Colors.orange);
      return;
    }

    setState(() => _isProcessing = true);
    try {
      if (await _blockedByStartedGame()) return;

      final updatedPlayers = GameEngineService.assignGameIdentities(eligible);
      await Future.wait(
        updatedPlayers.map(
          (player) => JsonStorageService.updateUserIdentity(
            userId: player.id,
            identity: player.identity,
            isAlive: true,
          ),
        ),
      );
      _snack('Identities successfully allocated!', Colors.green);
    } catch (e) {
      _snack('Allocation Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _resetIdentities() async {
    setState(() => _isProcessing = true);
    try {
      if (await _blockedByStartedGame()) return;

      await Future.wait(
        widget.playerList.map(
          (player) => JsonStorageService.updateUserIdentity(
            userId: player.id,
            identity: 'none',
            isAlive: true,
          ),
        ),
      );
      _snack('All player identities have been reset.', Colors.blueGrey);
    } catch (e) {
      _snack('Reset Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasAllocated = widget.playerList.any(_isAssigned);

    return StreamBuilder<Map<String, dynamic>>(
      stream: JsonStorageService.streamGameState(),
      builder: (context, snapshot) {
        final bool gameStarted = _isGameStarted(snapshot.data ?? {});
        final bool locked = gameStarted || _isProcessing;

        final String chipLabel = gameStarted
            ? 'Game In Progress'
            : (hasAllocated ? 'Identities Active' : 'Unallocated');
        final Color chipColor = gameStarted
            ? Colors.deepOrange
            : (hasAllocated ? Colors.green : Colors.orange);

        return Card(
          elevation: 2,
          color: Colors.indigo.shade50,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Identity Allocation Control',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo.shade900,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text(
                        chipLabel,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      backgroundColor: chipColor,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  gameStarted
                      ? 'Identities are locked while a game is in progress. Use "End Game" in the Moderator Control Center to allocate again.'
                      : 'Distribute roles (Killer, Healer, Detective, Villager) evenly based on current player count.',
                  style: TextStyle(
                    color: gameStarted ? Colors.deepOrange.shade800 : Colors.indigo.shade700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo.shade700,
                        foregroundColor: Colors.white,
                      ),
                      icon: _isProcessing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Icon(gameStarted ? Icons.lock : Icons.shuffle),
                      label: const Text('Allocate Identities'),
                      onPressed: locked ? null : _allocateIdentities,
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade300),
                      ),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset Identities'),
                      onPressed: locked ? null : _resetIdentities,
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