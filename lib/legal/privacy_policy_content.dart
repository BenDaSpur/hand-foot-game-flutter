import '../config/project_links.dart';

/// Canonical privacy policy copy shown in-app and mirrored at
/// https://playhandfoot.com/privacy.html
abstract final class PrivacyPolicyContent {
  static const String title = 'Privacy Policy';
  static const String lastUpdated = 'August 17, 2026';
  static const String website = 'https://playhandfoot.com';
  static const String publicUrl = '$website/privacy.html';

  static const String intro =
      'This Privacy Policy describes how the Hand & Foot card game at '
      'playhandfoot.com (the "Game", "we", "us") collects, uses, and shares '
      'information when you play in a browser, install the progressive web app, '
      'or use a downloaded build. Solo play works without creating an account.';

  static const List<PrivacyPolicySection> sections = [
    PrivacyPolicySection(
      title: 'Who we are',
      body:
          'The Game is an open-source Flutter project hosted at playhandfoot.com. '
          'Source code is published on GitHub. We are not a large commercial '
          'platform, but we still collect some technical and gameplay data so the '
          'Game can run, stay available, and improve — especially bot AI.',
    ),
    PrivacyPolicySection(
      title: 'Information you provide',
      body:
          'Multiplayer: you choose a display name when you create or join a game. '
          'That name is stored with the game and shown to other players in the same '
          'match. We do not ask for an email address, phone number, or password.\n\n'
          'You may also save game settings (for example bot count or sound '
          'preferences) on your device.',
    ),
    PrivacyPolicySection(
      title: 'Information collected automatically',
      body:
          'When Firebase is configured (as it is on playhandfoot.com), the Game '
          'collects:\n\n'
          '• A locally generated device identifier (a random ID stored on your '
          'device, not your advertising ID or phone serial number).\n'
          '• An anonymous Firebase Authentication ID used for multiplayer security '
          'rules. This is not tied to your name, email, or Google account.\n'
          '• Gameplay analytics: session duration, player counts, scores, rounds, '
          'app version, bot AI version, game seed, bot personalities, and whether '
          'bots reached their foot pile.\n'
          '• Detailed bot-decision logs used to improve AI (turn context, chosen '
          'moves, and related game-state details). These logs may include in-game '
          'display names such as "You" or a multiplayer name you chose.\n'
          '• Firebase Analytics events (for example app start, game created, game '
          'joined). Google may process device and network metadata such as '
          'approximate location derived from IP address, browser type, and similar '
          'technical data as described in Google’s privacy policy.\n\n'
          'If Firebase is not configured (typical for a local development build), '
          'these network analytics are not sent.',
    ),
    PrivacyPolicySection(
      title: 'Information stored on your device',
      body:
          'The Game stores data locally in your browser or app storage, including '
          'saved solo games, settings, a device identifier, your last multiplayer '
          'display name, and resume information for an in-progress online match. '
          'Clearing site data or uninstalling the app removes this local copy. '
          'Server-side analytics and multiplayer records are not deleted just '
          'because you cleared local storage.',
    ),
    PrivacyPolicySection(
      title: 'How we use information',
      body:
          'We use this information to:\n\n'
          '• Operate solo and multiplayer play, including reconnecting you to a '
          'match.\n'
          '• Enforce rate limits and security rules so lobbies are not abused.\n'
          '• Understand how games unfold and how bots behave, so we can fix bugs '
          'and improve AI.\n'
          '• Measure basic usage (for example that the site loaded) and keep the '
          'service reliable.\n\n'
          'We do not use this data to show third-party advertising, and we do not '
          'sell personal information.',
    ),
    PrivacyPolicySection(
      title: 'Cookies, local storage, and similar technologies',
      body:
          'The Game is a web app. It uses browser local storage and similar '
          'technologies for settings and saved games. Firebase Authentication and '
          'Firebase Analytics (Google) may set cookies or equivalent storage on '
          'playhandfoot.com. We do not use a separate advertising cookie or a '
          'marketing pixel.\n\n'
          'You can block cookies or clear site data in your browser. Doing so may '
          'sign you out of anonymous multiplayer, forget local settings, or limit '
          'analytics. The Game will still offer solo play.',
    ),
    PrivacyPolicySection(
      title: 'Third-party services',
      body:
          'We rely on these processors to run the website and Game:\n\n'
          '• Google Firebase (Authentication, Cloud Firestore, and Analytics) — '
          'game state, anonymous auth, and analytics. See Google’s privacy policy.\n'
          '• Vercel — website hosting. Vercel may process request logs such as IP '
          'address, user agent, and timestamps. See Vercel’s privacy policy.\n'
          '• Google Fonts — the Game may load fonts from Google, which can receive '
          'your IP address and user agent.\n\n'
          'These providers act on our behalf to host and operate the Game. They '
          'have their own privacy policies that govern how they process data.',
    ),
    PrivacyPolicySection(
      title: 'When we share information',
      body:
          'Other players in your multiplayer match can see your display name and '
          'public game actions (melds, discards, scores). Hidden cards in your '
          'hand are not shown to opponents.\n\n'
          'We share data with the processors listed above to operate the Game. We '
          'may also disclose information if required by law, or if needed to '
          'protect the Game, players, or the public.\n\n'
          'Gameplay analytics from completed games may be reviewed by maintainers '
          'to improve bot AI. We do not sell or rent your information.',
    ),
    PrivacyPolicySection(
      title: 'How long we keep information',
      body:
          'Local device data stays until you clear it or uninstall the app.\n\n'
          'Multiplayer games in a waiting lobby are removed if they expire without '
          'starting (about 30 minutes). Finished or cancelled matches are cleaned '
          'up after a short delay (about one hour).\n\n'
          'Anonymous Firebase Auth IDs persist in your browser until you clear '
          'site data.\n\n'
          'Gameplay analytics (session summaries, bot decisions, turn summaries) '
          'are kept so we can improve the Game and AI. We do not currently offer '
          'an automatic timed purge of those analytics collections. You can ask us '
          'to delete analytics associated with a device ID or session as described '
          'below.',
    ),
    PrivacyPolicySection(
      title: 'Your choices and rights',
      body:
          'You can play solo without joining multiplayer and without choosing a '
          'display name.\n\n'
          'You can clear cookies and site data in your browser, or uninstall a '
          'downloaded build, to remove local identifiers and saves.\n\n'
          'Depending on where you live (for example the EEA, UK, or California), '
          'you may have rights to request access, correction, deletion, or a copy '
          'of personal information, or to object to certain processing. We do not '
          'currently provide an in-app analytics opt-out. To make a request, '
          'contact us privately using the email address or GitHub Security '
          'Advisories form listed in the project Security Policy. Do not open a '
          'public GitHub issue or post identifiers in public discussion. Include '
          'any device ID, display name, or approximate play time you can share so '
          'we can find matching records. We may not be able to identify you if '
          'you only played solo and never set a unique name.\n\n'
          'We do not sell personal information or share it for cross-context '
          'behavioral advertising.',
    ),
    PrivacyPolicySection(
      title: 'Children',
      body:
          'The Game is a general-audience card game. It is not directed at '
          'children under 13, and we do not knowingly collect personal information '
          'from children under 13. If you believe a child provided information, '
          'contact us privately using the methods in the project Security Policy '
          'and we will delete it when we can identify the records.',
    ),
    PrivacyPolicySection(
      title: 'International processing',
      body:
          'playhandfoot.com is hosted on infrastructure that may process data in '
          'the United States and other countries (including Google Firebase and '
          'Vercel). If you play from outside the United States, your information '
          'may be transferred to and stored in those locations.',
    ),
    PrivacyPolicySection(
      title: 'Security',
      body:
          'We transmit data over HTTPS. Multiplayer access is limited by Firebase '
          'security rules and anonymous authentication. No method of transmission '
          'or storage is 100% secure. Do not put secrets, real names you want kept '
          'private, or sensitive data in a multiplayer display name.',
    ),
    PrivacyPolicySection(
      title: 'Changes to this policy',
      body:
          'We may update this Privacy Policy when the Game or our practices '
          'change. The "Last updated" date at the top will change when we do. The '
          'current version is always available in the Game and at '
          'https://playhandfoot.com/privacy.html.',
    ),
    PrivacyPolicySection(
      title: 'Contact',
      body:
          'Questions or privacy requests: contact us privately using the email '
          'address or GitHub Security Advisories form listed in the project '
          'Security Policy at ${ProjectLinks.securityPolicy}. Do not open a '
          'public GitHub issue or post identifiers in public discussion.',
    ),
  ];
}

class PrivacyPolicySection {
  final String title;
  final String body;

  const PrivacyPolicySection({required this.title, required this.body});
}
