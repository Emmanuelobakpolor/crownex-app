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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );
  runApp(const CrownexApp());
}

class CrownexApp extends StatelessWidget {
  const CrownexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final session = UserSession();
        SessionGuard.instance.attach(session);
        return session;
      },
      child: MaterialApp(
        title: 'Crownex',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        navigatorKey: SessionGuard.instance.navigatorKey,
        navigatorObservers: [routeObserver],
        home: const SplashScreen(),
      ),
    );
  }
}
