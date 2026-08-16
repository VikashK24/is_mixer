import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/json_storage_service.dart';

class AuthScreen extends StatefulWidget {
  final Function(User) onLoginSuccess;

  const AuthScreen({super.key, required this.onLoginSuccess});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Information Sciences Mixer 2026'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.sports_esports), text: 'Mafia'),
            Tab(icon: Icon(Icons.security), text: 'Moderator'),
          ],
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: SizedBox(
                height: 410, // Height increased to accommodate multi-line error messages nicely
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    LoginFormTab(
                      role: 'mafia',
                      onLoginSuccess: widget.onLoginSuccess,
                    ),
                    LoginFormTab(
                      role: 'moderator',
                      onLoginSuccess: widget.onLoginSuccess,
                    ),
                  ],
                ),
              ),
            ),
          ),
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
    final displayRole = widget.role == 'mafia' ? 'Mafia' : 'Moderator';
    final isInfoMessage = _errorMessage != null &&
        _errorMessage!.contains('submitted successfully');

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Please define your username to enter the Mafia Quiz Game',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Role: $displayRole',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade700,
                ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: "You'll be known as?",
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _handleLogin(),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isInfoMessage
                    ? Colors.orange.shade50
                    : Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isInfoMessage
                      ? Colors.orange.shade300
                      : Colors.red.shade300,
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
                        color: isInfoMessage
                            ? Colors.orange.shade900
                            : Colors.red.shade900,
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

          const Spacer(),
          ElevatedButton(
            onPressed: _isLoading ? null : _handleLogin,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('Enter Game as $displayRole'),
          ),
        ],
      ),
    );
  }
}