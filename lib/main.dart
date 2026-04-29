import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/customer_homepage.dart';
import 'screens/employee_homepage.dart';
import 'screens/admin_homepage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // On web, Firebase redirects the user back here after they click the reset
  // link, appending ?mode=resetPassword&oobCode=XXX to the URL.
  String? resetOobCode;
  if (kIsWeb) {
    final uri  = Uri.base;
    final mode = uri.queryParameters['mode'];
    final code = uri.queryParameters['oobCode'];
    if (mode == 'resetPassword' && code != null && code.isNotEmpty) {
      resetOobCode = code;
    }
  }

  runApp(MyApp(resetOobCode: resetOobCode));
}

class _SmoothPageTransitionsBuilder extends PageTransitionsBuilder {
  const _SmoothPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  final String? resetOobCode;
  const MyApp({super.key, this.resetOobCode});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Imprenta X System',
      theme: ThemeData(
        fontFamily: 'Spartan',
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: _SmoothPageTransitionsBuilder(),
            TargetPlatform.iOS:     _SmoothPageTransitionsBuilder(),
            TargetPlatform.windows: _SmoothPageTransitionsBuilder(),
            TargetPlatform.macOS:   _SmoothPageTransitionsBuilder(),
            TargetPlatform.linux:   _SmoothPageTransitionsBuilder(),
          },
        ),
        splashFactory:  NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      ),
      initialRoute: resetOobCode != null ? '/reset-password' : '/',
      routes: {
        '/':                (context) => LoginScreen(),
        '/register':        (context) => RegisterScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/reset-password':  (context) =>
            ResetPasswordScreen(oobCode: resetOobCode ?? ''),
        '/customer':        (context) => const CustomerHomepage(),
        '/employee':        (context) => EmployeeHomepage(),
        '/admin':           (context) => AdminHomepage(),
      },
    );
  }
}
