// Placeholder values. Run `flutterfire configure` to generate this file
// for your own Firebase project. The real file is not published.
//
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
     show defaultTargetPlatform, kIsWeb, TargetPlatform;

 class DefaultFirebaseOptions {
   static FirebaseOptions get currentPlatform {
     if (kIsWeb) {
       throw UnsupportedError(
         'DefaultFirebaseOptions are not supported for web.',
       );
     }
     switch (defaultTargetPlatform) {
       case TargetPlatform.android:
         return android;
       default:
         throw UnsupportedError(
           'DefaultFirebaseOptions are not supported for this platform.',
         );
     }
   }

   static const FirebaseOptions android = FirebaseOptions(
     apiKey: 'YOUR_ANDROID_API_KEY',
     appId: 'YOUR_ANDROID_APP_ID',
     messagingSenderId: 'YOUR_SENDER_ID',
     projectId: 'your-firebase-project-id',
   );
 }
