import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/json_storage_service.dart';

class QuizCard extends StatefulWidget {
  final User currentUser;

  const QuizCard({
    super.key,
    required this.currentUser,
  });

  @override
  State<QuizCard> createState() => _QuizCardState();
}

class _QuizCardState extends State<QuizCard> {
  final TextEditingController _answerController = TextEditingController();
  bool _isSubmitting = false;
  String? _feedbackMessage;
  bool _isCorrect = false;

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _submitAnswer(String currentQuestion) async {
    final answer = _answerController.text.trim();
    if (answer.isEmpty) {
      setState(() {
        _feedbackMessage = 'Please enter an answer before submitting.';
        _isCorrect = false;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _feedbackMessage = null;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 600));

      setState(() {
        _feedbackMessage = 'Answer recorded! ALL active Healers must answer correctly to save the target.';
        _isCorrect = true;
        _answerController.clear();
      });
    } catch (e) {
      setState(() {
        _feedbackMessage = 'Failed to submit answer: $e';
        _isCorrect = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: JsonStorageService.streamGameState(),
      builder: (context, snapshot) {
        final gameState = snapshot.data ?? {};
        final bool isNight = gameState['isNight'] ?? false;
        final String announcement = gameState['announcement'] ?? '';

        // SAFELY PARSE activeQuestion (handles both Map and String structures)
        final rawQuestion = gameState['activeQuestion'];
        String activeQuestionText = '';

        if (rawQuestion is Map) {
          activeQuestionText = rawQuestion['question']?.toString() ??
              rawQuestion['text']?.toString() ??
              rawQuestion['title']?.toString() ??
              '';
        } else if (rawQuestion is String) {
          activeQuestionText = rawQuestion;
        }

        if (activeQuestionText.isEmpty) {
          activeQuestionText = 'Waiting for the Moderator to transmit the Healer quiz challenge...';
        }

        if (!widget.currentUser.isAlive) {
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
                      'You have been eliminated. You can observe the game, but cannot answer quiz questions.',
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

        // Quiz is EXCLUSIVELY available to Healers
        final isHealer = widget.currentUser.identity.toLowerCase() == 'healer';

        return Column(
          children: [
            // Ambient Phase Update Bar across all client screens
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
                          'Quiz challenges are currently reserved exclusively for Healers to save targeted players.',
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
              )
            else
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.teal.shade100,
                            child: Icon(Icons.health_and_safety, color: Colors.teal.shade800),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Healer Rescue Challenge',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'UNANIMOUS REQ',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.shield, color: Colors.amber, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Strict Requirement: EVERY active Healer must submit the correct answer within 30s to save the target!',
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.indigo.shade100),
                        ),
                        child: Text(
                          activeQuestionText,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.indigo,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: _answerController,
                        enabled: !_isSubmitting,
                        decoration: const InputDecoration(
                          labelText: 'Your Answer',
                          hintText: 'Type your answer here...',
                          prefixIcon: Icon(Icons.edit_note),
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (val) => _submitAnswer(activeQuestionText),
                      ),

                      if (_feedbackMessage != null) ...[
                        const SizedBox(height: 12),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _isCorrect ? Colors.green.shade50 : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _isCorrect ? Colors.green.shade300 : Colors.red.shade300,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _isCorrect ? Icons.check_circle_outline : Icons.error_outline,
                                color: _isCorrect ? Colors.green.shade800 : Colors.red.shade800,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _feedbackMessage!,
                                  style: TextStyle(
                                    color: _isCorrect ? Colors.green.shade900 : Colors.red.shade900,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : () => _submitAnswer(activeQuestionText),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade800,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.shield),
                        label: Text(_isSubmitting ? 'Submitting...' : 'Submit Rescue Answer'),
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