import 'package:flutter/material.dart';
import '../../models/user_model.dart';

class UserProfileHeader extends StatelessWidget {
  final User user;

  const UserProfileHeader({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final isSuperAdmin = user.role == 'superadmin';
    final isModerator = user.role == 'moderator';

    final String displayIdentity = (isSuperAdmin || isModerator)
        ? 'GOD'
        : user.identity.toUpperCase();

    return Column(
      children: [
        Icon(
          isSuperAdmin
              ? Icons.admin_panel_settings
              : (isModerator ? Icons.security : Icons.sports_esports),
          size: 72,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 12),
        Text(
          'Welcome back, ${user.username}!',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        Text(
          'In-Game Identity: $displayIdentity',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple.shade700,
          ),
        ),
        const SizedBox(height: 8),
        if (user.role == 'mafia')
          const Chip(
            avatar: Icon(Icons.shield, color: Colors.green),
            label: Text('Anti-Cheat Active: Do not leave or switch tabs!'),
          ),
      ],
    );
  }
}