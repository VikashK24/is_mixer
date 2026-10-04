import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/json_storage_service.dart';

class HealerActionCard extends StatefulWidget {
  final User currentUser;
  final List<User> players;

  const HealerActionCard({
    super.key,
    required this.currentUser,
    required this.players,
  });

  @override
  State<HealerActionCard> createState() => _HealerActionCardState();
}

class _HealerActionCardState extends State<HealerActionCard> {
  String? _selectedOption;
  String? _selectedTargetId;
  bool _isSubmitting = false;
  String? _feedbackMessage;
  bool _isSuccess = false;

  List<User> get _validTargets {
    return widget.players.where((p) => p.isAlive && !p.isTerminated).toList();
  }

  Future<void> _submitAnswer(String correctAnswer) async {
    if (_selectedOption == null) {
      setState(() {
        _feedbackMessage = 'Please select an option first.';
        _isSuccess = false;
      });
      return;
    }

    if (_selectedTargetId == null) {
      setState(() {
        _feedbackMessage = 'Please select a target player to protect.';
        _isSuccess = false;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _feedbackMessage = null;
    });

    try {
      final bool isCorrect =
          _selectedOption!.trim().toLowerCase() == correctAnswer.trim().toLowerCase();

      // Store response into Firestore for Moderator evaluation
      await FirebaseFirestore.instance
          .collection('game_state')
          .doc('current')
          .collection('healer_answers')
          .doc(widget.currentUser.id)
          .set({
        'healerId': widget.currentUser.id,
        'healerName': widget.currentUser.username,
        'targetUserId': _selectedTargetId,
        'selectedOption': _selectedOption,
        'isCorrect': isCorrect,
        'timestamp': FieldValue.serverTimestamp(),
      });

      setState(() {
        _isSuccess = isCorrect;
        _feedbackMessage = isCorrect
            ? 'Correct answer! Your rescue submission has been recorded in Firebase.'
            : 'Incorrect answer. Protection failed for this round!';
      });
    } catch (e) {
      setState(() {
        _isSuccess = false;
        _feedbackMessage = 'Error submitting answer to Firebase: $e';
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

        dynamic rawQuestion = gameState['activeQuestion'];
        String questionText = '';
        String correctAnswer = '';
        List<String> options = [];

        if (rawQuestion is Map) {
          questionText = rawQuestion['question']?.toString() ??
              rawQuestion['text']?.toString() ??
              rawQuestion['question_text']?.toString() ??
              '';
          correctAnswer = rawQuestion['correctAnswer']?.toString() ??
              rawQuestion['answer']?.toString() ??
              '';
          if (rawQuestion['options'] is List) {
            options = List<String>.from(rawQuestion['options']);
          }
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
                            'Healer Action: Save Target',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          Text(
                            'Select player to save and answer the quiz correctly.',
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
                        'Waiting for the Killer to choose a question in Firebase...',
                        style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ),
                ] else ...[
                  const Text('1. Select Player to Protect:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(fillColor: Colors.white, filled: true, border: OutlineInputBorder()),
                    hint: const Text('Select player to save...'),
                    value: _selectedTargetId,
                    items: _validTargets.map((user) => DropdownMenuItem(value: user.id, child: Text(user.username))).toList(),
                    onChanged: (val) => setState(() => _selectedTargetId = val),
                  ),
                  const SizedBox(height: 16),

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
                          'ACTIVE FIREBASE QUESTION:',
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
                  const SizedBox(height: 12),

                  if (options.isNotEmpty) ...[
                    const Text('2. Select Answer Option:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: options.map((opt) {
                          return RadioListTile<String>(
                            dense: true,
                            title: Text(opt, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                            value: opt,
                            groupValue: _selectedOption,
                            activeColor: primaryColor,
                            onChanged: (val) => setState(() => _selectedOption = val),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

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
                    label: Text(_isSubmitting ? 'Verifying...' : 'Submit Answer & Protect Target'),
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