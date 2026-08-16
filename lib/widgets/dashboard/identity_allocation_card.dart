import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/game_engine_service.dart';
import '../../services/json_storage_service.dart';

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

  Future<void> _allocateIdentities() async {
    if (widget.playerList.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimum 4 players required to allocate identities.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final updatedPlayers = GameEngineService.assignGameIdentities(widget.playerList);
      for (var player in updatedPlayers) {
        await JsonStorageService.updateUserIdentity(
          userId: player.id,
          identity: player.identity,
          isAlive: true,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Identities successfully allocated!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Allocation Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _resetIdentities() async {
    setState(() => _isProcessing = true);
    try {
      for (var player in widget.playerList) {
        await JsonStorageService.updateUserIdentity(
          userId: player.id,
          identity: 'NONE',
          isAlive: true,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All player identities have been reset.'),
            backgroundColor: Colors.blueGrey,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasAllocated = widget.playerList.any((p) => p.identity != 'NONE');

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
                Text(
                  'Identity Allocation Control',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo.shade900,
                      ),
                ),
                Chip(
                  label: Text(
                    hasAllocated ? 'Identities Active' : 'Unallocated',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  backgroundColor: hasAllocated ? Colors.green : Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Distribute roles (Killer, Healer, Detective, Villager) evenly based on current player count.',
              style: TextStyle(color: Colors.indigo.shade700, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Row(
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
                      : const Icon(Icons.shuffle),
                  label: const Text('Allocate Identities'),
                  onPressed: _isProcessing ? null : _allocateIdentities,
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade300),
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset Identities'),
                  onPressed: _isProcessing ? null : _resetIdentities,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}