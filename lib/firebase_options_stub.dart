// Stub file for environments where Firebase options are not available
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
      'Firebase options not available in this environment',
    );
  }
}
