import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/site_nav_bar.dart';

/// One person on the People page.
/// To add a real photo later, set [imageUrl] (a link to the picture).
/// While it is null, a default icon is shown.
class _Person {
  final String name;
  final String description;
  final String? imageUrl;

  const _Person({
    required this.name,
    required this.description,
    this.imageUrl,
  });
}

const List<_Person> _people = [
  _Person(
    name: 'Alvin Antony',
    description:
        'A member of Computing Club and one of the hosts of this session, '
        'making sure the night runs smoothly and everyone gets to play.',
  ),
  _Person(
    name: 'Mannu Kumar',
    description:
        'A member of Computing Club and one of the hosts of this session, '
        'here to guide you from your first merge to the final vote.',
  ),
  _Person(
    name: 'Vikash Kumar',
    description:
        'A member of Computing Club and one of the hosts of this session, '
        'helping everyone through pull requests, deployment and the Mafia quiz game.',
  ),
];

class PeopleScreen extends StatelessWidget {
  const PeopleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SiteNavBar(current: NavTarget.people),
      body: NoirBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 36, 20, 56),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                children: [
                  const PageTitle(
                    eyebrow: 'THE FAMILY BEHIND THE NIGHT',
                    title: 'People',
                    subtitle:
                        'The Computing Club members who conducted this session.',
                  ),
                  Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    alignment: WrapAlignment.center,
                    children: _people.map((p) => _PersonCard(person: p)).toList(),
                  ),
                  const SizedBox(height: 36),
                  const Text(
                    'COMPUTING CLUB  ·  INFORMATION SCIENCES MIXER 2026',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: NoirColors.muted,
                      fontSize: 12,
                      letterSpacing: 3,
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

class _PersonCard extends StatelessWidget {
  final _Person person;

  const _PersonCard({required this.person});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: DossierCard(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: NoirColors.gold, width: 2),
              ),
              child: CircleAvatar(
                radius: 48,
                backgroundColor: NoirColors.paperInk,
                backgroundImage:
                    person.imageUrl != null ? NetworkImage(person.imageUrl!) : null,
                child: person.imageUrl == null
                    ? const Icon(Icons.person, size: 54, color: NoirColors.gold)
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              person.name,
              textAlign: TextAlign.center,
              style: noirHeading(size: 22, color: NoirColors.paperInk, spacing: 0.5),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: NoirColors.crimson,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'COMPUTING CLUB',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              person.description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: NoirColors.paperInk,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}