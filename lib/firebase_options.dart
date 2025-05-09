// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
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
        return windows;
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
    apiKey: 'AIzaSyAXtVhxtjbHxMe87gUbilTrdLSVI8umT2o',
    appId: '1:300075626097:web:72b6bf80067ad744df75d0',
    messagingSenderId: '300075626097',
    projectId: 'cecyt3-11636',
    authDomain: 'cecyt3-11636.firebaseapp.com',
    storageBucket: 'cecyt3-11636.firebasestorage.app',
    measurementId: 'G-VM27BEL13D',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDKm4gy3PQOhaj32ucE7z6h2tIk49ePt_E',
    appId: '1:300075626097:android:f1759edfe6604751df75d0',
    messagingSenderId: '300075626097',
    projectId: 'cecyt3-11636',
    storageBucket: 'cecyt3-11636.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA8k0nxdIAsjlStnoWOmg0C-emSnB79Coo',
    appId: '1:300075626097:ios:994c110dae7e4a23df75d0',
    messagingSenderId: '300075626097',
    projectId: 'cecyt3-11636',
    storageBucket: 'cecyt3-11636.firebasestorage.app',
    iosBundleId: 'com.example.v3',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyA8k0nxdIAsjlStnoWOmg0C-emSnB79Coo',
    appId: '1:300075626097:ios:994c110dae7e4a23df75d0',
    messagingSenderId: '300075626097',
    projectId: 'cecyt3-11636',
    storageBucket: 'cecyt3-11636.firebasestorage.app',
    iosBundleId: 'com.example.v3',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAXtVhxtjbHxMe87gUbilTrdLSVI8umT2o',
    appId: '1:300075626097:web:2f77f4f6f5369343df75d0',
    messagingSenderId: '300075626097',
    projectId: 'cecyt3-11636',
    authDomain: 'cecyt3-11636.firebaseapp.com',
    storageBucket: 'cecyt3-11636.firebasestorage.app',
    measurementId: 'G-L05R2DW8YD',
  );
}
