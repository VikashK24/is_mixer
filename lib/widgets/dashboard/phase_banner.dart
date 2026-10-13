import 'package:flutter/material.dart';
import '../../services/json_storage_service.dart';

class PhaseBanner extends StatelessWidget {
  const PhaseBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      // Streams the global game state document from Firestore
      stream: JsonStorageService.streamGameState(),
      builder: (context, snapshot) {
        final gameState = snapshot.data ?? {};
        final phase = (gameState['phase'] as String? ?? 'idle');
        final round = (gameState['round'] as num?)?.toInt() ?? 1;
        final seconds = (gameState['secondsRemaining'] as num?)?.toInt() ?? 0;
        final announcement =
            gameState['announcement'] as String? ?? 'Awaiting moderator updates...';

        // Styling based on the real phase names written by the moderator controls
        Color bannerColor;
        IconData phaseIcon;
        String phaseTitle;

        switch (phase) {
          case 'killerPhase':
          case 'awaitingHealerStart':
          case 'healerPhase':
          case 'awaitingDetectiveStart':
          case 'detectivePhase':
          case 'awaitingVillagersStart':
          case 'night': // legacy value
            bannerColor = Colors.indigo.shade900;
            phaseIcon = Icons.nights_stay;
            phaseTitle = 'NIGHT PHASE (Round $round)';
            break;
          case 'villagersPhase':
          case 'voting': // legacy value
          case 'day': // legacy value
            bannerColor = Colors.amber.shade900;
            phaseIcon = Icons.wb_sunny;
            phaseTitle = 'DAY PHASE (Round $round)';
            break;
          case 'roundCompleted':
            bannerColor = Colors.teal.shade800;
            phaseIcon = Icons.flag;
            phaseTitle = 'ROUND $round COMPLETE';
            break;
          case 'idle':
          default:
            bannerColor = Colors.blueGrey.shade700;
            phaseIcon = Icons.hourglass_empty;
            phaseTitle = 'WAITING FOR NEXT PHASE (Round $round)';
            break;
        }

        final bool showTimer = seconds > 0 && phase != 'idle' && phase != 'roundCompleted';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bannerColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: bannerColor.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(phaseIcon, color: Colors.white, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      phaseTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      showTimer ? '${seconds}s' : 'LIVE',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.campaign, color: Colors.white70, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        announcement,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
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
  }
}