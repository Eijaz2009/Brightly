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
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCXOnRGXoa7LM5xiultKPgQ5fa--7EZPmA',
    appId: '1:333990211250:web:brightly',
    messagingSenderId: '333990211250',
    projectId: 'brightly-a864b',
    authDomain: 'brightly-a864b.firebaseapp.com',
    storageBucket: 'brightly-a864b.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCXOnRGXoa7LM5xiultKPgQ5fa--7EZPmA',
    appId: '1:333990211250:android:3438cef958c265d80063ab',
    messagingSenderId: '333990211250',
    projectId: 'brightly-a864b',
    storageBucket: 'brightly-a864b.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCXOnRGXoa7LM5xiultKPgQ5fa--7EZPmA',
    appId: '1:333990211250:ios:brightly',
    messagingSenderId: '333990211250',
    projectId: 'brightly-a864b',
    storageBucket: 'brightly-a864b.firebasestorage.app',
    androidClientId: '333990211250-85l7f0ia2l248c64pt1e9si4f076l36j.apps.googleusercontent.com',
    iosClientId: '333990211250-85l7f0ia2l248c64pt1e9si4f076l36j.apps.googleusercontent.com',
    iosBundleId: 'com.example.scholarPath',
  );
}
