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

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAnyVw59R9OjmI0iDPtPjFpcdO_6AVItSY',
    appId: '1:623468431015:android:56387acffe786354d4bd82',
    messagingSenderId: '623468431015',
    projectId: 'advmobileprog-firebase2627',
    storageBucket: 'advmobileprog-firebase2627.firebasestorage.app',
  );
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBpc5kNpGakNmyEhPiz73GKZDNFIWCKoQ4',
    appId: '1:623468431015:web:db76441ffec3f53cd4bd82',
    messagingSenderId: '623468431015',
    projectId: 'advmobileprog-firebase2627',
    authDomain: 'advmobileprog-firebase2627.firebaseapp.com',
    storageBucket: 'advmobileprog-firebase2627.firebasestorage.app',
    measurementId: 'G-SVS373W3MH',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyB-8EIUuds5yMoDOyeo_PyGN_11DkagWRs',
    appId: '1:623468431015:ios:2a6262c9b8a05488d4bd82',
    messagingSenderId: '623468431015',
    projectId: 'advmobileprog-firebase2627',
    storageBucket: 'advmobileprog-firebase2627.firebasestorage.app',
    iosBundleId: 'com.example.navarroAdvmobprog',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyB-8EIUuds5yMoDOyeo_PyGN_11DkagWRs',
    appId: '1:623468431015:ios:2a6262c9b8a05488d4bd82',
    messagingSenderId: '623468431015',
    projectId: 'advmobileprog-firebase2627',
    storageBucket: 'advmobileprog-firebase2627.firebasestorage.app',
    iosBundleId: 'com.example.navarroAdvmobprog',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBpc5kNpGakNmyEhPiz73GKZDNFIWCKoQ4',
    appId: '1:623468431015:web:fcc22e53fbe63f5ad4bd82',
    messagingSenderId: '623468431015',
    projectId: 'advmobileprog-firebase2627',
    authDomain: 'advmobileprog-firebase2627.firebaseapp.com',
    storageBucket: 'advmobileprog-firebase2627.firebasestorage.app',
    measurementId: 'G-412SLTL8HP',
  );
}
