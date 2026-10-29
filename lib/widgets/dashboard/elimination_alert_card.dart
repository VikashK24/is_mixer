import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/sound_alert_service.dart';

/// Shows the sound-alert status and plays "<username> eliminated!" on this
/// player's device the moment their own account flips from alive to
/// eliminated (night kill or day vote). Other players' devices stay silent.
class EliminationAlertCard extends StatefulWidget {
  final User currentUser;

  const EliminationAlertCard({
    super.key,
    required this.currentUser,
  });

  @override
  State<EliminationAlertCard> createState() => _EliminationAlertCardState();
}

class _EliminationAlertCardState extends State<EliminationAlertCard> {
  bool _enabled = SoundAlertService.isEnabled;

  @override
  void didUpdateWidget(covariant EliminationAlertCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Only the alive -> eliminated transition counts. Loading the page while
    // already eliminated, or being revived by End Game, stays silent.
    if (oldWidget.currentUser.isAlive && !widget.currentUser.isAlive) {
      SoundAlertService.announceElimination(widget.currentUser.username);
    }
  }

  void _enable() {
    SoundAlertService.enable();
    setState(() => _enabled = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.volume_off, color: Colors.orange.shade800),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Sound alerts are off. Turn them on so your phone announces it if you are eliminated, and turn your volume up.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade900,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade800,
                foregroundColor: Colors.white,
              ),
              onPressed: _enable,
              child: const Text('Enable'),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.volume_up, color: Colors.green.shade800, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sound alerts on. Keep your volume up and silent mode off.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.green.shade900,
              ),
            ),
          ),
          TextButton(
            onPressed: () => SoundAlertService.test(widget.currentUser.username),
            child: const Text('Test'),
          ),
        ],
      ),
    );
  }
}