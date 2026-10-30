import 'package:flutter/material.dart';
import '../screens/about_screen.dart';
import '../screens/people_screen.dart';
import '../theme/app_theme.dart';
import 'mafia_logo.dart';

enum NavTarget { home, about, people }

/// Top navigation: Home (login or game), About and People.
/// Pass [onLogout] on the game dashboard to show a logout button.
class SiteNavBar extends StatelessWidget implements PreferredSizeWidget {
  final NavTarget current;
  final String? roleLabel;
  final VoidCallback? onLogout;

  const SiteNavBar({
    super.key,
    required this.current,
    this.roleLabel,
    this.onLogout,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  void _go(BuildContext context, NavTarget target) {
    if (target == current) return;
    final nav = Navigator.of(context);

    if (target == NavTarget.home) {
      nav.popUntil((route) => route.isFirst);
      return;
    }

    final route = MaterialPageRoute<void>(
      builder: (_) =>
          target == NavTarget.about ? const AboutScreen() : const PeopleScreen(),
    );
    if (current == NavTarget.home) {
      nav.push(route);
    } else {
      nav.pushReplacement(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 640;

    return Material(
      color: NoirColors.ink,
      child: Container(
        height: 64,
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 24),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: NoirColors.gold.withOpacity(0.4)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  const SizedBox(width: 4),
                  const FedoraLogo(size: 30, color: NoirColors.gold),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'MAFIA QUIZ',
                      overflow: TextOverflow.ellipsis,
                      style: noirHeading(
                        size: compact ? 15 : 20,
                        color: NoirColors.gold,
                        spacing: 3,
                      ),
                    ),
                  ),
                  if (roleLabel != null && !compact) ...[
                    const SizedBox(width: 14),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: NoirColors.crimson,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        roleLabel!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _NavItem(
              label: current == NavTarget.home ? 'Game' : 'Home',
              icon: Icons.home_outlined,
              active: current == NavTarget.home,
              compact: compact,
              onTap: () => _go(context, NavTarget.home),
            ),
            _NavItem(
              label: 'About',
              icon: Icons.menu_book_outlined,
              active: current == NavTarget.about,
              compact: compact,
              onTap: () => _go(context, NavTarget.about),
            ),
            _NavItem(
              label: 'People',
              icon: Icons.groups_outlined,
              active: current == NavTarget.people,
              compact: compact,
              onTap: () => _go(context, NavTarget.people),
            ),
            if (onLogout != null)
              IconButton(
                tooltip: 'Logout',
                icon: const Icon(Icons.logout, color: NoirColors.goldSoft),
                onPressed: onLogout,
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final bool compact;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.active,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? NoirColors.gold : NoirColors.cream.withOpacity(0.75);

    if (compact) {
      return IconButton(
        tooltip: label,
        icon: Icon(icon, color: color),
        onPressed: onTap,
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              height: 2,
              width: 22,
              color: active ? NoirColors.gold : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }
}