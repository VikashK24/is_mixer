import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/json_storage_service.dart';

class ModeratorApprovalQueueScreen extends StatefulWidget {
  const ModeratorApprovalQueueScreen({super.key});

  @override
  State<ModeratorApprovalQueueScreen> createState() =>
      _ModeratorApprovalQueueScreenState();
}

class _ModeratorApprovalQueueScreenState
    extends State<ModeratorApprovalQueueScreen> {
  final Set<String> _loadingUserIds = {};

  Future<void> _toggleModeratorApproval(User user) async {
    setState(() {
      _loadingUserIds.add(user.id);
    });

    try {
      if (!user.isApproved || user.isTerminated) {
        await JsonStorageService.approveModerator(user.id);
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
        title: const Text('Moderator Approvals & Access'),
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

          // Fetch all moderators (excluding superadmin and mafia players)
          final moderators = (snapshot.data ?? [])
              .where((u) => u.role == 'moderator')
              .toList();

          if (moderators.isEmpty) {
            return const Center(
              child: Text('No registered moderators found.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: moderators.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final user = moderators[index];
              final isLoading = _loadingUserIds.contains(user.id);
              final bool isActive = user.isApproved && !user.isTerminated;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      isActive ? Colors.green.shade100 : Colors.amber.shade100,
                  child: Icon(
                    isActive ? Icons.verified_user : Icons.security,
                    color: isActive ? Colors.green : Colors.amber.shade900,
                  ),
                ),
                title: Text(
                  user.username,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Role: MODERATOR • Status: ${isActive ? "Active / Approved" : "Pending / Revoked"}',
                ),
                trailing: isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isActive
                              ? Colors.red.shade700
                              : Colors.green.shade700,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _toggleModeratorApproval(user),
                        child: Text(
                          isActive ? 'Revoke Access' : 'Approve Access',
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