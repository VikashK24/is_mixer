import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/site_nav_bar.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const TextStyle _body = TextStyle(
    color: NoirColors.paperInk,
    fontSize: 15,
    height: 1.55,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SiteNavBar(current: NavTarget.about),
      body: NoirBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 36, 20, 56),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const PageTitle(
                    eyebrow: 'THE RULES OF THE FAMILY',
                    title: 'About the Game',
                    subtitle:
                        'A night of secrets, suspicion and quiz questions. Read this once and you will know exactly how to play.',
                  ),
                  DossierCard(
                    title: 'The Story',
                    icon: Icons.auto_stories,
                    child: const Text(
                      'A quiet town hides a few killers among its people. Every night they choose a victim. '
                      'Every day the town argues and votes. What makes this Mafia different is that quiz '
                      'questions decide who survives: the killers pick a question, and the healers must '
                      'answer it correctly to save their target.',
                      style: _body,
                    ),
                  ),
                  const SizedBox(height: 18),
                  DossierCard(
                    title: 'The Roles',
                    icon: Icons.theater_comedy,
                    child: Column(
                      children: const [
                        _RoleTile(
                          name: 'Killer',
                          color: Color(0xFFB3202B),
                          icon: Icons.dangerous_outlined,
                          text:
                              'Each night, vote on a victim and on the quiz question the healers will face. The majority decides.',
                        ),
                        _RoleTile(
                          name: 'Healer',
                          color: Color(0xFF2E7D32),
                          icon: Icons.medical_services_outlined,
                          text:
                              'Pick one player to protect and answer the quiz. Every healer must answer correctly and protect the right person to save the victim.',
                        ),
                        _RoleTile(
                          name: 'Detective',
                          color: Color(0xFF1565C0),
                          icon: Icons.search,
                          text:
                              'Investigate one player each night and learn whether they are a killer. Use it wisely.',
                        ),
                        _RoleTile(
                          name: 'Villager',
                          color: Color(0xFFB7791F),
                          icon: Icons.home_outlined,
                          text:
                              'No night power. Watch, discuss and vote during the day. Your voice is your weapon.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  DossierCard(
                    title: 'How a Round Works',
                    icon: Icons.nights_stay_outlined,
                    child: Column(
                      children: const [
                        _Step(1, 'Killers choose', 'Night begins. Killers vote on a victim and a quiz question.'),
                        _Step(2, 'Healers answer', 'Healers protect a player and answer the question on their screen.'),
                        _Step(3, 'Detective investigates', 'The detective checks one player.'),
                        _Step(4, 'Dawn', 'The result is revealed: someone is saved, or someone is eliminated.'),
                        _Step(5, 'Day discussion', 'Everyone talks. Accuse, defend, bluff.'),
                        _Step(6, 'The vote', 'Every living player votes. The most accused player is eliminated. A tie eliminates nobody.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  DossierCard(
                    title: 'How to Win',
                    icon: Icons.emoji_events_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('The Town wins when every killer has been eliminated.', style: _body),
                        SizedBox(height: 8),
                        Text('The Killers win when they equal or outnumber everyone else.', style: _body),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  DossierCard(
                    title: 'Using the Game App',
                    icon: Icons.phone_iphone,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        _Bullet('Log in with a username. One device per player.'),
                        _Bullet('Follow the banner at the top: it shows the phase, the timer and announcements.'),
                        _Bullet('Act in your role card. It only unlocks during your phase.'),
                        _Bullet('Tap "Enable sound alerts" and keep your volume up. If you are eliminated, your phone announces it out loud so everyone knows where you are.'),
                        _Bullet('Eliminated players can keep watching, but cannot act or vote.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  DossierCard(
                    title: 'Fair Play',
                    icon: Icons.gavel,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        _Bullet('Do not leave the tab or switch apps during the game. The anti-cheat locks your account.'),
                        _Bullet('Locked out? Ask a moderator to restore your access.'),
                        _Bullet('Never show your screen to anyone. Your role is your secret.'),
                        _Bullet('The moderator (God) runs the phases and has the final word.'),
                      ],
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

class _RoleTile extends StatelessWidget {
  final String name;
  final Color color;
  final IconData icon;
  final String text;

  const _RoleTile({
    required this.name,
    required this.color,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: color.withOpacity(0.14),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(text, style: AboutScreen._body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int number;
  final String title;
  final String text;

  const _Step(this.number, this.title, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: NoirColors.crimson,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: NoirColors.paperInk,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                Text(text, style: AboutScreen._body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;

  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 7),
            child: Icon(Icons.diamond, size: 9, color: NoirColors.gold),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: AboutScreen._body)),
        ],
      ),
    );
  }
}