import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/user_model.dart';

class ModeratorApprovalQueuePage extends StatefulWidget {
  const ModeratorApprovalQueuePage({super.key});

  @override
  State<ModeratorApprovalQueuePage> createState() => _ModeratorApprovalQueuePageState();
}

class _ModeratorApprovalQueuePageState extends State<ModeratorApprovalQueuePage> {
  Future<void> _updateUserApproval(String userId, bool isApproved) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'isApproved': isApproved,
        'approvedAt': isApproved ? FieldValue.serverTimestamp() : null,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isApproved ? 'Player approved!' : 'Player approval revoked.'),
            backgroundColor: isApproved ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moderator Approval Queue'),
        backgroundColor: Colors.indigo.shade800,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error loading users: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];
          final allUsers = docs.map((d) => User.fromJson(d.data())).toList();

          // Split users into pending and approved queues
          final pendingUsers = allUsers.where((u) => !u.isApproved && u.role.toLowerCase() != 'moderator').toList();
          final approvedUsers = allUsers.where((u) => u.isApproved && u.role.toLowerCase() != 'moderator').toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. PENDING APPROVALS SECTION
                Row(
                  children: [
                    Icon(Icons.pending_actions, color: Colors.orange.shade800),
                    const SizedBox(width: 8),
                    Text(
                      'Pending Approvals (${pendingUsers.length})',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (pendingUsers.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(
                        child: Text(
                          'No pending player approvals at this time.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: pendingUsers.length,
                    itemBuilder: (context, index) {
                      final user = pendingUsers[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.orange.shade100,
                            child: Icon(Icons.person, color: Colors.orange.shade900),
                          ),
                          title: Text(user.username, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Identity: ${user.identity.toUpperCase()} | Role: ${user.role}'),
                          trailing: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Approve'),
                            onPressed: () => _updateUserApproval(user.id, true),
                          ),
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),

                // 2. APPROVED PLAYERS QUEUE SECTION
                Row(
                  children: [
                    Icon(Icons.verified_user, color: Colors.green.shade800),
                    const SizedBox(width: 8),
                    Text(
                      'Approved Players Queue (${approvedUsers.length})',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (approvedUsers.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(
                        child: Text(
                          'No approved players found in this queue yet.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: approvedUsers.length,
                    itemBuilder: (context, index) {
                      final user = approvedUsers[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: Colors.green.shade50,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.green.shade100,
                            child: Icon(Icons.check_circle, color: Colors.green.shade800),
                          ),
                          title: Text(user.username, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Identity: ${user.identity.toUpperCase()} | Status: Approved'),
                          trailing: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                            ),
                            icon: const Icon(Icons.block, size: 18),
                            label: const Text('Revoke'),
                            onPressed: () => _updateUserApproval(user.id, false),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}