import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/json_storage_service.dart';

/// MODERATOR APPROVALS CARD (Navigatable)
class ApprovalQueueCardPreview extends StatelessWidget {
  final List<User> moderatorList;

  const ApprovalQueueCardPreview({
    super.key,
    required this.moderatorList,
  });

  void _openModeratorApprovalDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final pendingList = moderatorList.where((m) => !m.isApproved).toList();

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              height: MediaQuery.of(context).size.height * 0.6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Pending Moderator Approvals',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: pendingList.isEmpty
                        ? const Center(
                            child: Text(
                              'No pending moderator registration requests.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            itemCount: pendingList.length,
                            itemBuilder: (context, index) {
                              final mod = pendingList[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    child: Icon(Icons.person_add),
                                  ),
                                  title: Text(
                                    mod.username,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: const Text('Awaiting Super Admin Approval'),
                                  trailing: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                    icon: const Icon(Icons.check, size: 16),
                                    label: const Text('Approve'),
                                    onPressed: () async {
                                      await JsonStorageService.approveModerator(mod.id);
                                      if (context.mounted) {
                                        Navigator.of(context).pop();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Moderator ${mod.username} approved!'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = moderatorList.where((m) => !m.isApproved).length;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: () => _openModeratorApprovalDialog(context),
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Colors.orange.shade100,
          child: Icon(Icons.how_to_reg, color: Colors.orange.shade800),
        ),
        title: const Text(
          'Moderator Approvals',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          pendingCount > 0
              ? '$pendingCount pending moderator requests'
              : 'No pending approvals',
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: pendingCount > 0 ? Colors.orange : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$pendingCount',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

/// PLAYER ACCESS MANAGEMENT CARD (Navigatable)
class PlayerAccessCardPreview extends StatelessWidget {
  final List<User> playerList;

  const PlayerAccessCardPreview({
    super.key,
    required this.playerList,
  });

  void _openPlayerAccessDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Player Access & Status Management',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: playerList.isEmpty
                    ? const Center(
                        child: Text(
                          'No registered players found.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: playerList.length,
                        itemBuilder: (context, index) {
                          final player = playerList[index];
                          final isTerminated = player.isTerminated;

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isTerminated
                                    ? Colors.red.shade100
                                    : Colors.blue.shade100,
                                child: Icon(
                                  isTerminated ? Icons.block : Icons.person,
                                  color: isTerminated ? Colors.red : Colors.blue,
                                ),
                              ),
                              title: Text(
                                player.username,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                'Role: ${player.identity.toUpperCase()} | Status: ${isTerminated ? "TERMINATED / BLOCKED" : "ACTIVE"}',
                                style: TextStyle(
                                  color: isTerminated ? Colors.red : Colors.green.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              trailing: isTerminated
                                  ? ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white,
                                      ),
                                      icon: const Icon(Icons.refresh, size: 16),
                                      label: const Text('Reactivate'),
                                      onPressed: () async {
                                        await JsonStorageService.reactivateUser(player.id);
                                        if (context.mounted) {
                                          Navigator.of(context).pop();
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Access granted to ${player.username}'),
                                            ),
                                          );
                                        }
                                      },
                                    )
                                  : OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                      ),
                                      icon: const Icon(Icons.block, size: 16),
                                      label: const Text('Terminate'),
                                      onPressed: () async {
                                        await JsonStorageService.softDeleteUser(player.id);
                                        if (context.mounted) {
                                          Navigator.of(context).pop();
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Terminated ${player.username}'),
                                            ),
                                          );
                                        }
                                      },
                                    ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: () => _openPlayerAccessDialog(context),
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          child: Icon(Icons.people, color: Colors.blue.shade800),
        ),
        title: const Text(
          'Player Access Management',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('Total registered players: ${playerList.length}'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }
}

/// SUPER ADMIN EXCLUSIVE DANGER ZONE CARD
class SuperAdminDangerZoneCard extends StatefulWidget {
  final User currentUser;

  const SuperAdminDangerZoneCard({
    super.key,
    required this.currentUser,
  });

  @override
  State<SuperAdminDangerZoneCard> createState() => _SuperAdminDangerZoneCardState();
}

class _SuperAdminDangerZoneCardState extends State<SuperAdminDangerZoneCard> {
  bool _isClearing = false;

  Future<void> _confirmAndClearData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Reset Entire Game Data?'),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete ALL users, players, and moderators?\n\n'
          '• Question bank WILL NOT be deleted.\n'
          '• Current Super Admin account will remain active.\n'
          '• All game progress and active sessions will be reset.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('PURGE ALL USER DATA', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isClearing = true);

    try {
      await JsonStorageService.clearAllUserDataExceptQuestions(widget.currentUser.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All user data cleared successfully. Question bank preserved.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear user data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isClearing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentUser.role != 'superadmin') return const SizedBox.shrink();

    return Card(
      elevation: 2,
      color: Colors.red.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.red.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.shield_outlined, color: Colors.red),
                SizedBox(width: 8),
                Text(
                  'Super Admin Danger Zone',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Purge all players, moderators, and active game progress. Question bank data remains intact.',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isClearing ? null : _confirmAndClearData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: _isClearing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.delete_forever),
                label: Text(_isClearing ? 'Clearing...' : 'Clear All Users Data'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}