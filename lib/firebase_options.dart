import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for iOS.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macOS.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCqnHFGaz8YvX1eLiZ9XVrump8W0um89Ec',
    appId: '1:555056909258:android:a39d3c9db1e6c0895c1d33',
    messagingSenderId: '555056909258',
    projectId: 'gridwar-9a1b0',
    storageBucket: 'gridwar-9a1b0.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCqnHFGaz8YvX1eLiZ9XVrump8W0um89Ec',
    appId: '1:555056909258:android:a39d3c9db1e6c0895c1d33',
    messagingSenderId: '555056909258',
    projectId: 'gridwar-9a1b0',
    storageBucket: 'gridwar-9a1b0.firebasestorage.app',
  );
}
