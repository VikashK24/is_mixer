import 'dart:ui';
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import 'moderator_approval_queue.dart';
import 'player_access_management.dart';

// Custom Dotted Red Border Painter
class DottedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;

  DottedBorderPainter({
    this.color = Colors.red,
    this.strokeWidth = 2,
    this.gap = 4,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final Path path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(12),
      ));

    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + gap),
          paint,
        );
        distance += gap * 2;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// 1. APPROVAL QUEUE CARD PREVIEW (SUPER ADMIN ONLY)
class ApprovalQueueCardPreview extends StatelessWidget {
  final List<User> moderatorList;

  const ApprovalQueueCardPreview({super.key, required this.moderatorList});

  @override
  Widget build(BuildContext context) {
    final pendingCount = moderatorList.where((m) => !m.isApproved).length;
    final bool hasActionRequired = pendingCount > 0;

    return CustomPaint(
      painter: hasActionRequired ? DottedBorderPainter() : null,
      child: Card(
        elevation: 2,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ModeratorApprovalQueueScreen(),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      hasActionRequired ? Colors.red.shade100 : Colors.blue.shade100,
                  child: Icon(
                    Icons.how_to_reg,
                    color: hasActionRequired ? Colors.red : Colors.blue.shade800,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Moderator Approval Queue',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasActionRequired
                            ? 'Action Required: $pendingCount moderator(s) pending approval'
                            : 'All moderators approved',
                        style: TextStyle(
                          color:
                              hasActionRequired ? Colors.red.shade700 : Colors.grey.shade700,
                          fontWeight:
                              hasActionRequired ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 2. PLAYER ACCESS MANAGEMENT CARD PREVIEW
class PlayerAccessCardPreview extends StatelessWidget {
  final List<User> playerList;

  const PlayerAccessCardPreview({super.key, required this.playerList});

  @override
  Widget build(BuildContext context) {
    final total = playerList.length;
    final killers = playerList.where((p) => p.identity == 'killer').length;
    final healers = playerList.where((p) => p.identity == 'healer').length;
    final detectives = playerList.where((p) => p.identity == 'detective').length;
    final villagers = playerList.where((p) => p.identity == 'villager').length;

    // Trigger red dotted alert if players are terminated or unassigned
    final hasActionRequired =
        playerList.any((p) => p.isTerminated || p.identity == 'none' || p.identity == 'NONE');

    return CustomPaint(
      painter: hasActionRequired ? DottedBorderPainter() : null,
      child: Card(
        elevation: 2,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PlayerAccessManagementScreen(),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      hasActionRequired ? Colors.red.shade100 : Colors.green.shade100,
                  child: Icon(
                    Icons.manage_accounts,
                    color: hasActionRequired ? Colors.red : Colors.green.shade800,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Player Access Management',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Total: $total | Killer: $killers | Healer: $healers | Detective: $detectives | Villager: $villagers',
                        style: const TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}