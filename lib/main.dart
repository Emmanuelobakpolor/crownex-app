import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'screens/splash_screen.dart';
import 'services/session_guard.dart';
import 'services/user_session.dart';
import 'theme/app_theme.dart';

/// Lets any screen re-run work when it becomes visible again after a
/// pushed route pops back to it (e.g. HomeScreen refreshing the balance
/// after an airtime/data/electricity/crypto purchase completes).
final RouteObserver<PageRoute<void>> routeObserver =
    RouteObserver<PageRoute<void>>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final darkMode = await UserSession.loadDarkModePreference();
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: darkMode ? Brightness.light : Brightness.dark,
      statusBarBrightness: darkMode ? Brightness.dark : Brightness.light,
    ),
  );
  runApp(CrownexApp(darkMode: darkMode));
}

class CrownexApp extends StatelessWidget {
  const CrownexApp({super.key, this.darkMode = false});

  final bool darkMode;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final session = UserSession(darkMode: darkMode);
        SessionGuard.instance.attach(session);
        return session;
      },
      child: Consumer<UserSession>(
        builder: (context, session, child) {
          return MaterialApp(
            title: 'Crownex',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: session.themeMode,
            // Screens read AppColors directly and switch instantly, so
            // animating the Theme would leave the two out of step.
            themeAnimationDuration: Duration.zero,
            navigatorKey: SessionGuard.instance.navigatorKey,
            navigatorObservers: [routeObserver],
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
