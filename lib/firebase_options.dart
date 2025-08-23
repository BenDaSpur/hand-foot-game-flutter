import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Stub Firebase options for CI/CD environments where firebase_options.dart doesn't exist
/// This allows tests to run without requiring Firebase configuration
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'stub-api-key',
    appId: 'stub-app-id',
    messagingSenderId: 'stub-sender-id',
    projectId: 'stub-project-id',
    authDomain: 'stub-project.firebaseapp.com',
    storageBucket: 'stub-project.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'stub-api-key',
    appId: 'stub-app-id',
    messagingSenderId: 'stub-sender-id',
    projectId: 'stub-project-id',
    storageBucket: 'stub-project.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'stub-api-key',
    appId: 'stub-app-id',
    messagingSenderId: 'stub-sender-id',
    projectId: 'stub-project-id',
    storageBucket: 'stub-project.appspot.com',
    iosBundleId: 'com.example.handFootGameFlutter',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'stub-api-key',
    appId: 'stub-app-id',
    messagingSenderId: 'stub-sender-id',
    projectId: 'stub-project-id',
    storageBucket: 'stub-project.appspot.com',
    iosBundleId: 'com.example.handFootGameFlutter',
  );
}
