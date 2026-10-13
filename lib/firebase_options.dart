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
    apiKey: 'AIzaSyAZqrS2OqwZugXD0J1rt0OM1HG-ApKiVts',
    appId: '1:869400565061:web:497e315c3d3d245efada2c',
    messagingSenderId: '869400565061',
    projectId: 'scholarpath-e5d39',
    authDomain: 'scholarpath-e5d39.firebaseapp.com',
    storageBucket: 'scholarpath-e5d39.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyACo2hthzxfDSyvJPmqA59t9HIeFq0NXt8',
    appId: '1:869400565061:android:2502bd945910d3a4fada2c',
    messagingSenderId: '869400565061',
    projectId: 'scholarpath-e5d39',
    storageBucket: 'scholarpath-e5d39.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBuj4Q448-UrxovMLxWHCb2xk1pu5MzcVE',
    appId: '1:869400565061:ios:ece00e5bbb6ecdedfada2c',
    messagingSenderId: '869400565061',
    projectId: 'scholarpath-e5d39',
    storageBucket: 'scholarpath-e5d39.firebasestorage.app',
    androidClientId: '869400565061-j9as037t4p92he7oeisfhd3iguh0luis.apps.googleusercontent.com',
    iosClientId: '869400565061-6kegpkcqvvg0sgu723ub3sdtvkdtv710.apps.googleusercontent.com',
    iosBundleId: 'com.example.scholarPath',
  );
}
