import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/json_storage_service.dart';

class PlayerAccessManagementScreen extends StatefulWidget {
  const PlayerAccessManagementScreen({super.key});

  @override
  State<PlayerAccessManagementScreen> createState() =>
      _PlayerAccessManagementScreenState();
}

class _PlayerAccessManagementScreenState
    extends State<PlayerAccessManagementScreen> {
  final Set<String> _loadingUserIds = {};

  // Helper method to style and capitalize identity badges
  Widget _buildIdentityChip(String rawIdentity) {
    final identity = rawIdentity.toLowerCase();
    Color chipColor;
    Color textColor = Colors.white;
    String label = rawIdentity.toUpperCase();

    switch (identity) {
      case 'killer':
        chipColor = Colors.red.shade800;
        break;
      case 'healer':
        chipColor = Colors.green.shade700;
        break;
      case 'detective':
        chipColor = Colors.blue.shade700;
        break;
      case 'villager':
        chipColor = Colors.orange.shade800;
        break;
      default:
        chipColor = Colors.grey.shade400;
        textColor = Colors.black87;
        label = 'UNASSIGNED';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _toggleAccess(User user) async {
    setState(() {
      _loadingUserIds.add(user.id);
    });

    try {
      if (user.isTerminated) {
        await JsonStorageService.reactivateUser(user.id);
      } else {
        await JsonStorageService.softDeleteUser(user.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Action failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingUserIds.remove(user.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Player Access Management'),
      ),
      body: StreamBuilder<List<User>>(
        stream: JsonStorageService.streamAllUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          // Show ONLY mafia players (Excludes SuperAdmin & Moderator accounts)
          final players = (snapshot.data ?? [])
              .where((u) => u.role == 'mafia')
              .toList();

          if (players.isEmpty) {
            return const Center(
              child: Text('No registered players found.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: players.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final user = players[index];
              final isLoading = _loadingUserIds.contains(user.id);

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                leading: CircleAvatar(
                  backgroundColor: user.isTerminated
                      ? Colors.red.shade100
                      : Colors.green.shade100,
                  child: Icon(
                    user.isTerminated ? Icons.block : Icons.check_circle_outline,
                    color: user.isTerminated ? Colors.red : Colors.green,
                  ),
                ),
                title: Row(
                  children: [
                    Text(
                      user.username,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildIdentityChip(user.identity),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    'Role: ${user.role.toUpperCase()} • Status: ${user.isTerminated ? "Revoked" : "Active"} • Life: ${user.isAlive ? "Alive" : "Eliminated"}',
                    style: TextStyle(
                      fontSize: 13,
                      color: user.isTerminated
                          ? Colors.red.shade800
                          : Colors.grey.shade800,
                    ),
                  ),
                ),
                trailing: isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: user.isTerminated
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _toggleAccess(user),
                        child: Text(
                          user.isTerminated ? 'Re-grant Access' : 'Revoke Access',
                        ),
                      ),
              );
            },
          );
        },
      ),
    );
  }
}