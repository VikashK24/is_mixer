import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/json_storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/mafia_logo.dart';
import '../widgets/site_nav_bar.dart';

class AuthScreen extends StatefulWidget {
  final Function(User) onLoginSuccess;

  const AuthScreen({super.key, required this.onLoginSuccess});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  String _role = 'mafia'; // 'mafia' = player, 'moderator'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SiteNavBar(current: NavTarget.home),
      body: NoirBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: NoirColors.panel,
                      border: Border.all(color: NoirColors.gold, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: NoirColors.crimson.withOpacity(0.35),
                          blurRadius: 34,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const FedoraLogo(size: 64, color: NoirColors.gold),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'MAFIA QUIZ',
                    textAlign: TextAlign.center,
                    style: noirHeading(size: 44, color: NoirColors.gold, spacing: 7),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'INFORMATION SCIENCES MIXER 2026',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: NoirColors.muted,
                      fontSize: 12,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: NoirColors.paper,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: NoirColors.gold.withOpacity(0.7)),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black87,
                          blurRadius: 28,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _SeatButton(
                                label: 'PLAYER',
                                icon: Icons.theater_comedy,
                                selected: _role == 'mafia',
                                onTap: () => setState(() => _role = 'mafia'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _SeatButton(
                                label: 'MODERATOR',
                                icon: Icons.gavel,
                                selected: _role == 'moderator',
                                onTap: () => setState(() => _role = 'moderator'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        LoginFormTab(
                          key: ValueKey(_role),
                          role: _role,
                          onLoginSuccess: widget.onLoginSuccess,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Trust no one. Answer everything.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: NoirColors.muted,
                      fontStyle: FontStyle.italic,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SeatButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SeatButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? NoirColors.crimson : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? NoirColors.crimson : NoirColors.paperInk.withOpacity(0.25),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: selected ? Colors.white : NoirColors.paperInk),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : NoirColors.paperInk,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LoginFormTab extends StatefulWidget {
  final String role;
  final Function(User) onLoginSuccess;

  const LoginFormTab({
    super.key,
    required this.role,
    required this.onLoginSuccess,
  });

  @override
  State<LoginFormTab> createState() => _LoginFormTabState();
}

class _LoginFormTabState extends State<LoginFormTab> {
  final TextEditingController _usernameController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a username.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await JsonStorageService.authenticateUser(
        username,
        widget.role,
      );
      widget.onLoginSuccess(user);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPlayer = widget.role == 'mafia';
    final isInfoMessage = _errorMessage != null &&
        _errorMessage!.contains('submitted successfully');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Who goes there?',
          textAlign: TextAlign.center,
          style: noirHeading(size: 24, color: NoirColors.paperInk, spacing: 0.5),
        ),
        const SizedBox(height: 6),
        Text(
          isPlayer
              ? 'Choose a username to take your seat at the table.'
              : 'Moderators need Super Admin approval before entering.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: NoirColors.paperInk.withOpacity(0.7),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _usernameController,
          textInputAction: TextInputAction.go,
          decoration: InputDecoration(
            labelText: "You'll be known as?",
            prefixIcon: const Icon(Icons.person_outline),
            filled: true,
            fillColor: Colors.white.withOpacity(0.7),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: NoirColors.crimson, width: 2),
            ),
          ),
          onSubmitted: (_) => _handleLogin(),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isInfoMessage ? Colors.orange.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isInfoMessage ? Colors.orange.shade300 : Colors.red.shade300,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isInfoMessage ? Icons.info_outline : Icons.error_outline,
                  color: isInfoMessage ? Colors.orange.shade800 : Colors.red.shade800,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: isInfoMessage ? Colors.orange.shade900 : Colors.red.shade900,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                    softWrap: true,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: NoirColors.crimson,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 17),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  isPlayer ? 'ENTER THE FAMILY' : 'ENTER AS MODERATOR',
                  style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2),
                ),
        ),
      ],
    );
  }
}