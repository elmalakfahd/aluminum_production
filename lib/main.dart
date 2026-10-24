import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'models.dart';
import 'services.dart';
import 'screens.dart';
import 'login_screen.dart';
import 'admin_users_screen.dart';
import 'app_localization.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('ar', null);
  await initializeDateFormatting('en', null);

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print('خطأ في تهيئة Firebase: $e');
  }

  await SharedPreferences.getInstance();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AbstractFirebaseService>(
          create: (_) => FirebaseServiceImpl(),
        ),
        ChangeNotifierProvider<ShiftProvider>(
          create: (context) => ShiftProvider(
            context.read<AbstractFirebaseService>(),
          ),
        ),
        ChangeNotifierProvider<LocaleProvider>(
          create: (_) => LocaleProvider(),
        ),
      ],
      child: Consumer<LocaleProvider>(
        builder: (context, localeProvider, _) {
          return MaterialApp(
            title: AppStrings.of(context, 'app_title'),
            theme: ThemeData(
              primarySwatch: Colors.blue,
              useMaterial3: true,
            ),
            locale: localeProvider.locale,
            supportedLocales: const [
              Locale('ar', 'SA'),
              Locale('en', 'US'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Scaffold(
                    body: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(context.tr('loading_app')),
                        ],
                      ),
                    ),
                  );
                }
                if (snapshot.hasData) {
                  return const HomeScreen();
                }
                return const LoginScreen();
              },
            ),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}

// 🔥 إعدادات Firebase
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
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
        return linux;
      default:
        throw UnsupportedError('Platform not supported');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyDO3SNh4Yl6clhcCt4c7vdGH8ypZr787iU",
    authDomain: "aluminum-production.firebaseapp.com",
    databaseURL: "https://aluminum-production-default-rtdb.europe-west1.firebasedatabase.app",
    projectId: "aluminum-production",
    storageBucket: "aluminum-production.firebasestorage.app",
    messagingSenderId: "233627030140",
    appId: "1:233627030140:web:9dfdecda67fcd126acaff9",
    measurementId: "G-0NZ73WF57Q",
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: "AIzaSyDO3SNh4Yl6clhcCt4c7vdGH8ypZr787iU",
    authDomain: "aluminum-production.firebaseapp.com",
    databaseURL: "https://aluminum-production-default-rtdb.europe-west1.firebasedatabase.app",
    projectId: "aluminum-production",
    storageBucket: "aluminum-production.firebasestorage.app",
    messagingSenderId: "233627030140",
    appId: "1:233627030140:android:your-android-app-id",
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: "AIzaSyDO3SNh4Yl6clhcCt4c7vdGH8ypZr787iU",
    authDomain: "aluminum-production.firebaseapp.com",
    databaseURL: "https://aluminum-production-default-rtdb.europe-west1.firebasedatabase.app",
    projectId: "aluminum-production",
    storageBucket: "aluminum-production.firebasestorage.app",
    messagingSenderId: "233627030140",
    appId: "1:233627030140:ios:your-ios-app-id",
    iosBundleId: "com.example.aluminum_production",
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: "AIzaSyDO3SNh4Yl6clhcCt4c7vdGH8ypZr787iU",
    authDomain: "aluminum-production.firebaseapp.com",
    databaseURL: "https://aluminum-production-default-rtdb.europe-west1.firebasedatabase.app",
    projectId: "aluminum-production",
    storageBucket: "aluminum-production.firebasestorage.app",
    messagingSenderId: "233627030140",
    appId: "1:233627030140:ios:your-macos-app-id",
    iosBundleId: "com.example.aluminum_production",
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: "AIzaSyDO3SNh4Yl6clhcCt4c7vdGH8ypZr787iU",
    authDomain: "aluminum-production.firebaseapp.com",
    databaseURL: "https://aluminum-production-default-rtdb.europe-west1.firebasedatabase.app",
    projectId: "aluminum-production",
    storageBucket: "aluminum-production.firebasestorage.app",
    messagingSenderId: "233627030140",
    appId: "1:233627030140:web:9dfdecda67fcd126acaff9",
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: "AIzaSyDO3SNh4Yl6clhcCt4c7vdGH8ypZr787iU",
    authDomain: "aluminum-production.firebaseapp.com",
    databaseURL: "https://aluminum-production-default-rtdb.europe-west1.firebasedatabase.app",
    projectId: "aluminum-production",
    storageBucket: "aluminum-production.firebasestorage.app",
    messagingSenderId: "233627030140",
    appId: "1:233627030140:web:9dfdecda67fcd126acaff9",
  );
}