import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/json_storage_service.dart';

/// Status panel shown to every player below their role card.
///
/// Healers answer the rescue quiz in the Healer card (multiple choice), so this
/// card no longer contains an answer box and never writes answers itself.
class QuizCard extends StatelessWidget {
  final User currentUser;

  const QuizCard({
    super.key,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: JsonStorageService.streamGameState(),
      builder: (context, snapshot) {
        final gameState = snapshot.data ?? {};
        final bool isNight = gameState['isNight'] ?? false;
        final String announcement = gameState['announcement'] ?? '';

        if (!currentUser.isAlive) {
          return Card(
            color: Colors.grey.shade200,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: const Padding(
              padding: EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Icon(Icons.sentiment_very_dissatisfied, color: Colors.grey, size: 32),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'You have been eliminated. You can observe the game, but cannot take any more actions.',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final isHealer = currentUser.identity.toLowerCase() == 'healer';

        return Column(
          children: [
            if (announcement.isNotEmpty)
              Card(
                color: isNight ? Colors.indigo.shade900 : Colors.amber.shade100,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        isNight ? Icons.nights_stay : Icons.wb_sunny,
                        color: isNight ? Colors.amber : Colors.orange.shade900,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          announcement,
                          style: TextStyle(
                            color: isNight ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),

            // Healers use their own card; everyone else gets this notice.
            if (!isHealer)
              Card(
                elevation: 2,
                color: Colors.indigo.shade50,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.indigo.shade100,
                        child: Icon(Icons.lock_clock, color: Colors.indigo.shade800),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Quiz challenges are reserved exclusively for Healers to save targeted players.',
                          style: TextStyle(
                            color: Colors.indigo,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}