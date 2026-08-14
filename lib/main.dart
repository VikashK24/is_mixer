import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

void main() {
  // Removes '#' from browser URL
  usePathUrlStrategy();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Information Sciences Collaboration Celebration',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const WelcomeScreen(),
    );
  }
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final TextEditingController _usernameController = TextEditingController();
  
  // Simulated JSON registered database (In-memory / Local Session)
  // Tip: Connect this list to Firebase / Supabase or a JSON backend endpoint later!
  final List<String> _registeredUsernames = [
    'admin',
    'researcher1',
    'alice',
    'bob'
  ];

  String? _errorMessage;
  String? _registeredName;

  void _registerUser() {
    final inputName = _usernameController.text.trim();

    setState(() {
      if (inputName.isEmpty) {
        _errorMessage = 'Please enter a name or username.';
        return;
      }

      // Check if username already exists in our registered JSON database (Case-Insensitive)
      bool nameExists = _registeredUsernames.any(
        (name) => name.toLowerCase() == inputName.toLowerCase(),
      );

      if (nameExists) {
        _errorMessage = 'The name "$inputName" is already taken. Please choose a unique username!';
      } else {
        // Successfully register the new user into the JSON registry
        _registeredUsernames.add(inputName);
        _errorMessage = null;
        _registeredName = inputName;
        _usernameController.clear();
      }
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IS Celebration'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 550),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Heading
                    Text(
                      'Welcome to the Information Sciences Mixer 2026!',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                    const SizedBox(height: 32),

                    if (_registeredName != null) ...[
                      // Success Message State
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: Text(
                          '🎉 Registration successful! Welcome aboard, $_registeredName.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.green.shade900,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _registeredName = null;
                          });
                        },
                        child: const Text('Register Another Name'),
                      ),
                    ] else ...[
                      // 2. Input Label & Textfield
                      const Text(
                        "You'll be known as?",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          hintText: 'Enter your name/username',
                          errorText: _errorMessage,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.person),
                        ),
                        onSubmitted: (_) => _registerUser(),
                      ),
                      const SizedBox(height: 20),

                      // 3. Register Action Button
                      ElevatedButton.icon(
                        onPressed: _registerUser,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text(
                          'Register Username',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
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