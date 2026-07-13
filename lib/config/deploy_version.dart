/// Compile-time deploy identifier injected by CI/Vercel builds.
abstract final class DeployVersion {
  static const String buildNumber = String.fromEnvironment(
    'BUILD_NUMBER',
    defaultValue: '',
  );
}
