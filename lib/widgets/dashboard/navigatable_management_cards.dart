import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/json_storage_service.dart';

// ════════════════════════════════════════════════════════════════════
// SHARED HELPERS
// ════════════════════════════════════════════════════════════════════

bool _isStaff(User u) => u.role == 'moderator' || u.role == 'superadmin';

/// A moderator who registered but has not been approved yet (and is not blocked).
bool _isPendingModerator(User u) =>
    u.role == 'moderator' && !u.isApproved && !u.isTerminated;

Color _identityColor(String rawIdentity) {
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

String _identityLabel(String rawIdentity) {
  final id = rawIdentity.toLowerCase();
  const known = ['killer', 'healer', 'detective', 'villager'];
  return known.contains(id) ? id.toUpperCase() : 'UNASSIGNED';
}

/// Small rounded badge used for quick stats and status labels.
Widget _pill({
  required String label,
  required Color color,
  IconData? icon,
  bool filled = false,
}) {
  final Color fg = filled ? Colors.white : color;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: filled ? color : color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(8),
      border: filled ? null : Border.all(color: color.withOpacity(0.35)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      ],
    ),
  );
}

Widget _sectionHeader(String text, IconData icon, Color color) {
  return Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 6),
    child: Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    ),
  );
}

Widget _errorBanner(String message) {
  return Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.red.shade50,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.red.shade300),
    ),
    child: Row(
      children: [
        Icon(Icons.error_outline, color: Colors.red.shade800, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: TextStyle(color: Colors.red.shade900, fontSize: 13),
          ),
        ),
      ],
    ),
  );
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result == true;
}

const RoundedRectangleBorder _sheetShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
);

// ════════════════════════════════════════════════════════════════════
// STATS
// ════════════════════════════════════════════════════════════════════

/// Quick numbers for moderators + god (super admin) accounts.
class _StaffStats {
  final int moderators;
  final int gods;
  final int pending;
  final int active;
  final int terminated;

  const _StaffStats({
    required this.moderators,
    required this.gods,
    required this.pending,
    required this.active,
    required this.terminated,
  });

  factory _StaffStats.from(List<User> users) {
    final staff = users.where(_isStaff).toList();
    return _StaffStats(
      moderators: staff.where((u) => u.role == 'moderator').length,
      gods: staff.where((u) => u.role == 'superadmin').length,
      pending: staff.where(_isPendingModerator).length,
      active: staff
          .where((u) => !u.isTerminated && !_isPendingModerator(u))
          .length,
      terminated: staff.where((u) => u.isTerminated).length,
    );
  }

  List<Widget> pills() => [
        _pill(
          label: '$moderators Moderator${moderators == 1 ? '' : 's'}',
          color: Colors.indigo,
          icon: Icons.security,
        ),
        _pill(
          label: '$gods God',
          color: Colors.deepPurple,
          icon: Icons.admin_panel_settings,
        ),
        _pill(
          label: '$active Active',
          color: Colors.green.shade700,
          icon: Icons.check_circle_outline,
        ),
        _pill(
          label: '$terminated Terminated',
          color: Colors.red.shade700,
          icon: Icons.block,
        ),
        if (pending > 0)
          _pill(
            label: '$pending Pending',
            color: Colors.orange.shade800,
            icon: Icons.hourglass_top,
            filled: true,
          ),
      ];
}

/// Quick numbers for in-game players only (role == 'mafia').
class _PlayerStats {
  final int total;
  final int active;
  final int terminated;
  final int alive;
  final int eliminated;
  final int killers;
  final int healers;
  final int detectives;
  final int villagers;
  final int unassigned;

  const _PlayerStats({
    required this.total,
    required this.active,
    required this.terminated,
    required this.alive,
    required this.eliminated,
    required this.killers,
    required this.healers,
    required this.detectives,
    required this.villagers,
    required this.unassigned,
  });

  factory _PlayerStats.from(List<User> users) {
    final players = users.where((u) => u.role == 'mafia').toList();
    int count(String id) =>
        players.where((u) => u.identity.toLowerCase() == id).length;

    final k = count('killer');
    final h = count('healer');
    final d = count('detective');
    final v = count('villager');

    return _PlayerStats(
      total: players.length,
      active: players.where((u) => !u.isTerminated).length,
      terminated: players.where((u) => u.isTerminated).length,
      alive: players.where((u) => u.isAlive).length,
      eliminated: players.where((u) => !u.isAlive).length,
      killers: k,
      healers: h,
      detectives: d,
      villagers: v,
      unassigned: players.length - (k + h + d + v),
    );
  }

  bool get hasRoles => (killers + healers + detectives + villagers) > 0;

  List<Widget> statusPills() => [
        _pill(
          label: '$active Active',
          color: Colors.green.shade700,
          icon: Icons.check_circle_outline,
        ),
        _pill(
          label: '$terminated Terminated',
          color: Colors.red.shade700,
          icon: Icons.block,
        ),
      ];

  List<Widget> lifePills() => [
        _pill(
          label: '$alive Alive',
          color: Colors.teal.shade700,
          icon: Icons.favorite_outline,
        ),
        _pill(
          label: '$eliminated Eliminated',
          color: Colors.grey.shade700,
          icon: Icons.close,
        ),
      ];

  List<Widget> rolePills() {
    if (!hasRoles) {
      return [
        _pill(
          label: 'Roles not allocated yet',
          color: Colors.grey.shade700,
          icon: Icons.help_outline,
        ),
      ];
    }
    return [
      _pill(label: '$killers Killer${killers == 1 ? '' : 's'}', color: _identityColor('killer')),
      _pill(label: '$healers Healer${healers == 1 ? '' : 's'}', color: _identityColor('healer')),
      _pill(label: '$detectives Detective${detectives == 1 ? '' : 's'}', color: _identityColor('detective')),
      _pill(label: '$villagers Villager${villagers == 1 ? '' : 's'}', color: _identityColor('villager')),
      if (unassigned > 0)
        _pill(label: '$unassigned Unassigned', color: _identityColor('none')),
    ];
  }
}

// ════════════════════════════════════════════════════════════════════
// MODERATOR & GOD MANAGEMENT CARD (includes the approval queue)
// ════════════════════════════════════════════════════════════════════

class ModeratorManagementCard extends StatelessWidget {
  /// Users with role 'moderator' or 'superadmin'. Anyone else is ignored.
  final List<User> staffList;

  const ModeratorManagementCard({
    super.key,
    required this.staffList,
  });

  void _openSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: _sheetShape,
      builder: (_) => const _StaffSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = _StaffStats.from(staffList);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openSheet(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.indigo.shade100,
                    child: Icon(Icons.manage_accounts,
                        color: Colors.indigo.shade800),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Moderator & God Management',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          stats.pending > 0
                              ? '${stats.pending} approval${stats.pending == 1 ? '' : 's'} waiting for you'
                              : 'Approvals, roles & access',
                          style: TextStyle(
                            fontSize: 13,
                            color: stats.pending > 0
                                ? Colors.orange.shade900
                                : Colors.grey.shade700,
                            fontWeight: stats.pending > 0
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 6, runSpacing: 6, children: stats.pills()),
            ],
          ),
        ),
      ),
    );
  }
}

class _StaffSheet extends StatefulWidget {
  const _StaffSheet();

  @override
  State<_StaffSheet> createState() => _StaffSheetState();
}

class _StaffSheetState extends State<_StaffSheet> {
  final Set<String> _busy = {};
  String? _error;

  Future<void> _run(String userId, Future<void> Function() action) async {
    setState(() {
      _busy.add(userId);
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = 'Action failed: $e');
    } finally {
      if (mounted) setState(() => _busy.remove(userId));
    }
  }

  Future<void> _approve(User u) =>
      _run(u.id, () => JsonStorageService.approveModerator(u.id));

  Future<void> _reactivate(User u) =>
      _run(u.id, () => JsonStorageService.reactivateUser(u.id));

  Future<void> _forceLogout(User u) =>
      _run(u.id, () => JsonStorageService.forceLogOutUser(u.id));

  Future<void> _terminate(User u) async {
    final ok = await _confirm(
      context,
      title: 'Terminate ${u.username}?',
      message:
          'This moderator will be blocked and logged out. You can re-grant access later.',
      confirmLabel: 'TERMINATE',
    );
    if (!ok || !mounted) return;
    await _run(u.id, () => JsonStorageService.softDeleteUser(u.id));
  }

  Widget _pendingCard(User u) {
    final busy = _busy.contains(u.id);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.orange.shade100,
              child: Icon(Icons.person_add, color: Colors.orange.shade900),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    u.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Awaiting Super Admin approval',
                    style:
                        TextStyle(fontSize: 12, color: Colors.orange.shade900),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Approve'),
                    onPressed: () => _approve(u),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _staffCard(User u) {
    final isGod = u.role == 'superadmin';
    final busy = _busy.contains(u.id);
    final Color accent = isGod ? Colors.deepPurple : Colors.indigo;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: accent.withOpacity(0.12),
                  child: Icon(
                    isGod ? Icons.admin_panel_settings : Icons.security,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        u.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _pill(
                            label: isGod ? 'GOD' : 'MODERATOR',
                            color: accent,
                            filled: true,
                          ),
                          u.isTerminated
                              ? _pill(
                                  label: 'TERMINATED',
                                  color: Colors.red.shade700,
                                  icon: Icons.block,
                                )
                              : _pill(
                                  label: 'ACTIVE',
                                  color: Colors.green.shade700,
                                  icon: Icons.check_circle_outline,
                                ),
                          if (u.isLoggedIn)
                            _pill(
                              label: 'ONLINE',
                              color: Colors.teal.shade700,
                              icon: Icons.circle,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!isGod) ...[
              const SizedBox(height: 10),
              if (busy)
                const LinearProgressIndicator()
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (u.isTerminated)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Reactivate'),
                        onPressed: () => _reactivate(u),
                      )
                    else ...[
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red),
                        icon: const Icon(Icons.block, size: 16),
                        label: const Text('Terminate'),
                        onPressed: () => _terminate(u),
                      ),
                      if (u.isLoggedIn)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.logout, size: 16),
                          label: const Text('Log out'),
                          onPressed: () => _forceLogout(u),
                        ),
                    ],
                  ],
                ),
            ] else ...[
              const SizedBox(height: 6),
              Text(
                'Protected account - cannot be modified here.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Moderator & God Management',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: StreamBuilder<List<User>>(
                  stream: JsonStorageService.streamAllUsers(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final staff =
                        snapshot.data!.where(_isStaff).toList();
                    final stats = _StaffStats.from(staff);
                    final pending =
                        staff.where(_isPendingModerator).toList();
                    final others = staff
                        .where((u) => !_isPendingModerator(u))
                        .toList()
                      ..sort((a, b) {
                        if (a.role != b.role) {
                          return a.role == 'superadmin' ? -1 : 1;
                        }
                        return a.username
                            .toLowerCase()
                            .compareTo(b.username.toLowerCase());
                      });

                    return ListView(
                      children: [
                        Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: stats.pills()),
                        if (_error != null) _errorBanner(_error!),
                        _sectionHeader(
                          'Pending Approvals (${pending.length})',
                          Icons.pending_actions,
                          Colors.orange.shade800,
                        ),
                        if (pending.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'No pending moderator registration requests.',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          )
                        else
                          ...pending.map(_pendingCard),
                        _sectionHeader(
                          'Moderators & God (${others.length})',
                          Icons.verified_user,
                          Colors.indigo.shade800,
                        ),
                        ...others.map(_staffCard),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// PLAYER ACCESS MANAGEMENT CARD (in-game players only)
// ════════════════════════════════════════════════════════════════════

class PlayerAccessCardPreview extends StatelessWidget {
  /// Only users with role 'mafia' are shown; moderators and god are ignored.
  final List<User> playerList;

  const PlayerAccessCardPreview({
    super.key,
    required this.playerList,
  });

  void _openSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: _sheetShape,
      builder: (_) => const _PlayerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = _PlayerStats.from(playerList);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openSheet(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: Icon(Icons.people, color: Colors.blue.shade800),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Player Access Management',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Total players: ${stats.total}',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 6, runSpacing: 6, children: stats.statusPills()),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: stats.rolePills()),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerSheet extends StatefulWidget {
  const _PlayerSheet();

  @override
  State<_PlayerSheet> createState() => _PlayerSheetState();
}

class _PlayerSheetState extends State<_PlayerSheet> {
  final Set<String> _busy = {};
  String? _error;
  String _filter = 'all'; // all | active | terminated

  Future<void> _run(String userId, Future<void> Function() action) async {
    setState(() {
      _busy.add(userId);
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = 'Action failed: $e');
    } finally {
      if (mounted) setState(() => _busy.remove(userId));
    }
  }

  Future<void> _reactivate(User u) =>
      _run(u.id, () => JsonStorageService.reactivateUser(u.id));

  Future<void> _forceLogout(User u) =>
      _run(u.id, () => JsonStorageService.forceLogOutUser(u.id));

  Future<void> _terminate(User u) async {
    final ok = await _confirm(
      context,
      title: 'Terminate ${u.username}?',
      message:
          'This player will be blocked and logged out until you re-grant access.',
      confirmLabel: 'TERMINATE',
    );
    if (!ok || !mounted) return;
    await _run(u.id, () => JsonStorageService.softDeleteUser(u.id));
  }

  List<User> _applyFilter(List<User> players) {
    switch (_filter) {
      case 'active':
        return players.where((p) => !p.isTerminated).toList();
      case 'terminated':
        return players.where((p) => p.isTerminated).toList();
      default:
        return players;
    }
  }

  Widget _playerCard(User p) {
    final busy = _busy.contains(p.id);
    final Color avatarColor = p.isTerminated
        ? Colors.red
        : (p.isAlive ? Colors.blue : Colors.grey);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: avatarColor.withOpacity(0.12),
                  child: Icon(
                    p.isTerminated
                        ? Icons.block
                        : (p.isAlive ? Icons.person : Icons.close),
                    color: avatarColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _pill(
                            label: _identityLabel(p.identity),
                            color: _identityColor(p.identity),
                            filled: true,
                          ),
                          p.isTerminated
                              ? _pill(
                                  label: 'TERMINATED',
                                  color: Colors.red.shade700,
                                  icon: Icons.block,
                                )
                              : _pill(
                                  label: 'ACTIVE',
                                  color: Colors.green.shade700,
                                  icon: Icons.check_circle_outline,
                                ),
                          _pill(
                            label: p.isAlive ? 'ALIVE' : 'ELIMINATED',
                            color: p.isAlive
                                ? Colors.teal.shade700
                                : Colors.grey.shade700,
                          ),
                          if (p.isLoggedIn)
                            _pill(
                              label: 'ONLINE',
                              color: Colors.teal.shade700,
                              icon: Icons.circle,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (busy)
              const LinearProgressIndicator()
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (p.isTerminated)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Reactivate'),
                      onPressed: () => _reactivate(p),
                    )
                  else ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red),
                      icon: const Icon(Icons.block, size: 16),
                      label: const Text('Terminate'),
                      onPressed: () => _terminate(p),
                    ),
                    if (p.isLoggedIn)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.logout, size: 16),
                        label: const Text('Log out'),
                        onPressed: () => _forceLogout(p),
                      ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Player Access & Status Management',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: StreamBuilder<List<User>>(
                  stream: JsonStorageService.streamAllUsers(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final players = snapshot.data!
                        .where((u) => u.role == 'mafia')
                        .toList()
                      ..sort((a, b) => a.username
                          .toLowerCase()
                          .compareTo(b.username.toLowerCase()));
                    final stats = _PlayerStats.from(players);
                    final visible = _applyFilter(players);

                    return ListView(
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _pill(
                              label: '${stats.total} Total',
                              color: Colors.blue.shade800,
                              icon: Icons.people,
                            ),
                            ...stats.statusPills(),
                            ...stats.lifePills(),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: stats.rolePills()),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final f in const [
                              ['all', 'All'],
                              ['active', 'Active'],
                              ['terminated', 'Terminated'],
                            ])
                              ChoiceChip(
                                label: Text(f[1]),
                                selected: _filter == f[0],
                                onSelected: (_) =>
                                    setState(() => _filter = f[0]),
                              ),
                          ],
                        ),
                        if (_error != null) _errorBanner(_error!),
                        const SizedBox(height: 8),
                        if (visible.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text(
                                players.isEmpty
                                    ? 'No registered players found.'
                                    : 'No players match this filter.',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ),
                          )
                        else
                          ...visible.map(_playerCard),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// SUPER ADMIN EXCLUSIVE DANGER ZONE CARD (unchanged)
// ════════════════════════════════════════════════════════════════════

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