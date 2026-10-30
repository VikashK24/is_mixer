import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';

class UserProfileHeader extends StatelessWidget {
  final User user;

  const UserProfileHeader({super.key, required this.user});

  static const Set<String> _identities = {'killer', 'healer', 'detective', 'villager'};

  Color _identityColor(String identity) {
    switch (identity) {
      case 'killer':
        return const Color(0xFFE5484D);
      case 'healer':
        return const Color(0xFF4ADE80);
      case 'detective':
        return const Color(0xFF60A5FA);
      case 'villager':
        return const Color(0xFFFBBF24);
      default:
        return NoirColors.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSuperAdmin = user.role == 'superadmin';
    final isModerator = user.role == 'moderator';
    final isStaff = isSuperAdmin || isModerator;

    final identity = user.identity.toLowerCase();
    final String displayIdentity = isStaff
        ? 'GOD'
        : (_identities.contains(identity) ? identity.toUpperCase() : 'NOT ASSIGNED YET');
    final Color identityColor = isStaff
        ? NoirColors.gold
        : _identityColor(_identities.contains(identity) ? identity : '');

    final IconData avatarIcon = isSuperAdmin
        ? Icons.admin_panel_settings
        : (isModerator ? Icons.gavel : Icons.theater_comedy);

    return Column(
      children: [
        Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: NoirColors.panel,
            border: Border.all(color: NoirColors.gold, width: 2),
            boxShadow: [
              BoxShadow(
                color: NoirColors.crimson.withOpacity(0.3),
                blurRadius: 24,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(avatarIcon, size: 44, color: NoirColors.gold),
        ),
        const SizedBox(height: 14),
        const Text(
          'WELCOME BACK',
          style: TextStyle(
            color: NoirColors.muted,
            fontSize: 12,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          user.username,
          textAlign: TextAlign.center,
          style: noirHeading(size: 34),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: identityColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: identityColor),
              ),
              child: Text(
                'IDENTITY  ·  $displayIdentity',
                style: TextStyle(
                  color: identityColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                  letterSpacing: 2,
                ),
              ),
            ),
            if (!isStaff && !user.isAlive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: NoirColors.crimson,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'ELIMINATED',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                    letterSpacing: 2,
                  ),
                ),
              ),
          ],
        ),
        if (user.role == 'mafia') ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: NoirColors.gold.withOpacity(0.35)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined, size: 16, color: NoirColors.gold),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Anti-cheat active: do not leave or switch tabs!',
                    style: TextStyle(color: NoirColors.goldSoft, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}