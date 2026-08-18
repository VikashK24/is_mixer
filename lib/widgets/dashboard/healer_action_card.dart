import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/json_storage_service.dart';

class HealerActionCard extends StatefulWidget {
  final User currentUser;

  const HealerActionCard({
    super.key,
    required this.currentUser,
  });

  @override
  State<HealerActionCard> createState() => _HealerActionCardState();
}

class _HealerActionCardState extends State<HealerActionCard> {
  final TextEditingController _answerController = TextEditingController();
  bool _isSubmitting = false;
  String? _feedbackMessage;
  bool _isSuccess = false;

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _submitAnswer(String correctAnswer) async {
    final input = _answerController.text.trim();
    if (input.isEmpty) {
      setState(() {
        _feedbackMessage = 'Please enter an answer.';
        _isSuccess = false;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _feedbackMessage = null;
    });

    try {
      if (input.toLowerCase() == correctAnswer.toLowerCase()) {
        setState(() {
          _isSuccess = true;
          _feedbackMessage = 'Correct answer! You saved the victim!';
        });
      } else {
        setState(() {
          _isSuccess = false;
          _feedbackMessage = 'Incorrect answer. Try again!';
        });
      }
    } catch (e) {
      setState(() {
        _isSuccess = false;
        _feedbackMessage = 'Error submitting answer: $e';
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
    const primaryColor = Colors.teal;

    return StreamBuilder<Map<String, dynamic>>(
      stream: JsonStorageService.streamGameState(),
      builder: (context, snapshot) {
        final gameState = snapshot.data ?? {};

        // Safely extract activeQuestion whether it is stored as a Map or String
        dynamic rawQuestion = gameState['activeQuestion'];
        String questionText = '';
        String correctAnswer = '';

        if (rawQuestion is Map) {
          questionText = rawQuestion['text']?.toString() ??
              rawQuestion['question']?.toString() ??
              rawQuestion['title']?.toString() ??
              '';
          correctAnswer = rawQuestion['answer']?.toString() ?? '';
        } else if (rawQuestion is String) {
          questionText = rawQuestion;
        }

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: primaryColor.withOpacity(0.15),
                      child: const Icon(Icons.medical_services, color: primaryColor),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Healer Action: Save Victim',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          Text(
                            'Solve the question to protect the target player.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),

                if (questionText.isEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.0),
                    child: Center(
                      child: Text(
                        'Waiting for the Killer to choose a question...',
                        style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: primaryColor.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ACTIVE QUESTION:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          questionText,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _answerController,
                    decoration: const InputDecoration(
                      labelText: 'Your Answer',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_feedbackMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _isSuccess ? Colors.green.shade50 : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _isSuccess ? Colors.green.shade300 : Colors.red.shade300,
                        ),
                      ),
                      child: Text(
                        _feedbackMessage!,
                        style: TextStyle(
                          color: _isSuccess ? Colors.green.shade900 : Colors.red.shade900,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _isSubmitting ? null : () => _submitAnswer(correctAnswer),
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.healing),
                    label: Text(_isSubmitting ? 'Verifying...' : 'Submit Answer'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}