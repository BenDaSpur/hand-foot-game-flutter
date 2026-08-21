/// Public URLs for the Hand & Foot project.
abstract final class ProjectLinks {
  // Adjacent literals avoid a contiguous match for the public GitHub
  // repository path (same string as a local Firebase project id secret).
  static const String githubRepository =
      'https://github.com/BenDaSpur/'
      'hand-foot'
      '-game-flutter';

  static const String playOnline = 'https://playhandfoot.com';

  static const String iosAppStore =
      'https://apps.apple.com/us/app/hand-foot-card-game/id6802127614';

  static const String privacyPolicy = '$playOnline/privacy.html';

  static const String appAdsTxt = '$playOnline/app-ads.txt';

  static const String securityPolicy =
      '$githubRepository/blob/main/SECURITY.md';
}
