import 'package:flutter/material.dart';
import '../../services/json_storage_service.dart';

class PhaseBanner extends StatelessWidget {
  const PhaseBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      // Streams the global game state document from Firestore/Storage
      stream: JsonStorageService.streamGameState(),
      builder: (context, snapshot) {
        final gameState = snapshot.data ?? {};
        final phase = (gameState['phase'] as String? ?? 'day').toLowerCase();
        final round = gameState['round'] as int? ?? 1;
        final announcement = gameState['announcement'] as String? ?? 'Awaiting moderator updates...';

        // Styling based on phase
        Color bannerColor;
        IconData phaseIcon;
        String phaseTitle;

        switch (phase) {
          case 'night':
            bannerColor = Colors.indigo.shade900;
            phaseIcon = Icons.nights_stay;
            phaseTitle = 'NIGHT PHASE (Round $round)';
            break;
          case 'voting':
            bannerColor = Colors.deepOrange.shade800;
            phaseIcon = Icons.how_to_vote;
            phaseTitle = 'VOTING PHASE (Round $round)';
            break;
          case 'day':
          default:
            bannerColor = Colors.amber.shade900;
            phaseIcon = Icons.wb_sunny;
            phaseTitle = 'DAY PHASE (Round $round)';
            break;
        }

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
                  Text(
                    phaseTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
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