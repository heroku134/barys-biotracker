// File generated for KALKAN SPORT (watch-ba720)
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
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
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD19yDU1QGZpLRTTc2dfunyprwr67yzgsE',
    appId: '1:718180799511:android:41ddb5b639f5cb67de3852',
    messagingSenderId: '718180799511',
    projectId: 'watch-ba720',
    storageBucket: 'watch-ba720.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyC5HivOL6MFCqn6r1E5JiIEqYg2mC6eXMg',
    appId: '1:718180799511:ios:45ef25542bddf89bde3852',
    messagingSenderId: '718180799511',
    projectId: 'watch-ba720',
    storageBucket: 'watch-ba720.firebasestorage.app',
    iosBundleId: 'kalkan.comp',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD19yDU1QGZpLRTTc2dfunyprwr67yzgsE',
    appId: '1:718180799511:android:41ddb5b639f5cb67de3852',
    messagingSenderId: '718180799511',
    projectId: 'watch-ba720',
    storageBucket: 'watch-ba720.firebasestorage.app',
  );
}
