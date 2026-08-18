import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/json_storage_service.dart';

class PlayerStatusGrid extends StatelessWidget {
  final User currentUser;

  const PlayerStatusGrid({
    super.key,
    required this.currentUser,
  });

  Color _getIdentityColor(String rawIdentity) {
    switch (rawIdentity.toLowerCase()) {
      case 'killer':
        return Colors.red.shade700;
      case 'healer':
        return Colors.green.shade700;
      case 'detective':
        return Colors.blue.shade700;
      case 'villager':
        return Colors.orange.shade800;
      default:
        return Colors.grey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.teal,
                  child: Icon(Icons.people, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Town Roster & Status',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: Text(
                    'Real-time',
                    style: TextStyle(
                      color: Colors.teal.shade900,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            StreamBuilder<List<User>>(
              stream: JsonStorageService.streamAllUsers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final players = (snapshot.data ?? [])
                    .where((u) => u.role == 'mafia')
                    .toList();

                if (players.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No active town members.'),
                    ),
                  );
                }

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisExtent: 85,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: players.length,
                  itemBuilder: (context, index) {
                    final player = players[index];
                    final isSelf = player.id == currentUser.id;

                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: player.isAlive
                            ? (isSelf ? Colors.indigo.shade50 : Colors.grey.shade50)
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelf
                              ? Colors.indigo
                              : (player.isAlive ? Colors.grey.shade300 : Colors.red.shade200),
                          width: isSelf ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: player.isAlive
                                ? Colors.green.shade100
                                : Colors.red.shade100,
                            child: Icon(
                              player.isAlive ? Icons.person : Icons.close,
                              color: player.isAlive ? Colors.green.shade800 : Colors.red.shade800,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  player.username + (isSelf ? ' (You)' : ''),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: player.isAlive ? Colors.black87 : Colors.grey.shade600,
                                    decoration: player.isAlive
                                        ? TextDecoration.none
                                        : TextDecoration.lineThrough,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                if (isSelf)
                                  Text(
                                    currentUser.identity.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: _getIdentityColor(currentUser.identity),
                                    ),
                                  )
                                else
                                  Text(
                                    player.isAlive ? 'ALIVE' : 'ELIMINATED',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: player.isAlive
                                          ? Colors.green.shade700
                                          : Colors.red.shade700,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}