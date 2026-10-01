// packages
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

// screens
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/sigin_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/splash_screen.dart';

// providers
import 'providers/theme_provider.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]).then(
    (_) async {
      await dotenv.load(fileName: 'assets/.env');
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      runApp(const NavarroAdvMobProg());
    },
  );
}

class NavarroAdvMobProg extends StatelessWidget {
  const NavarroAdvMobProg({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: ScreenUtilInit(
        designSize: const Size(412, 715),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (build, child) {
          final themeModel = build.watch<ThemeProvider>();
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: themeModel.lightTheme,
            darkTheme: themeModel.darkTheme,
            themeMode: themeModel.isDark ? ThemeMode.dark : ThemeMode.light,
            title: 'E-Commerce App',
            // app now boots into the login screen; SplashScreen is shown
            // as a brief loading transition after a successful (or
            // already persisted) login, right before landing on /home.
            initialRoute: '/login',
            routes: {
              '/splash': (context) => const SplashScreen(),
              '/login': (context) => const SiginScreen(),
              '/signup': (context) => const SignupScreen(),
              '/home': (context) {
                final args = ModalRoute.of(context)?.settings.arguments;
                final username =
                    args is Map ? args['username'] as String? : null;
                return HomeScreen(username: username);
              },
              '/settings': (context) => const SettingsScreen(),
            },
          );
        },
      ),
    );
  }
}