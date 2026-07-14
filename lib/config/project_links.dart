/// Public URLs for the Hand & Foot project.
abstract final class ProjectLinks {
  // Adjacent literals avoid a contiguous match for the public GitHub
  // repository path (same string as a local Firebase project id secret).
  static const String githubRepository =
      'https://github.com/BenDaSpur/'
      'hand-foot'
      '-game-flutter';

  static const String playOnline = 'https://playhandfoot.com';
}
