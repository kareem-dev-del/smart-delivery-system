import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shopease_mobile/core/dependency_injection/di.dart';
import 'firebase_options.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    AppBlocProviders.pushNotificationService.initialize();
  } catch (_) {
    // Firebase project config is supplied when the app is connected in Firebase.
  }
  runApp(const ShopEaseApp());
}
