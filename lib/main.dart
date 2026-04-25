import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
// IMPORTANT: this is required for web + correct Firebase setup
import 'firebase_options.dart';
// Import your screens
import 'screens/login_screen.dart';
import 'screens/customer_homepage.dart';
import 'screens/employee_homepage.dart';
import 'screens/admin_homepage.dart';
import 'screens/register_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(MyApp());
}

// Custom smooth fade + slight upward slide transition (iOS-feel)
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
    // Smooth cubic ease curve
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    // Subtle slide up from 4% below + fade in
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
            TargetPlatform.iOS: _SmoothPageTransitionsBuilder(),
            TargetPlatform.windows: _SmoothPageTransitionsBuilder(),
            TargetPlatform.macOS: _SmoothPageTransitionsBuilder(),
            TargetPlatform.linux: _SmoothPageTransitionsBuilder(),
          },
        ),
        // Remove Android ink ripple on taps
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      ),
      // Start at login
      initialRoute: '/',
      routes: {
        '/': (context) => LoginScreen(),
        '/register': (context) => RegisterScreen(),
        '/customer': (context) => CustomerHomepage(),
        '/employee': (context) => EmployeeHomepage(),
        '/admin': (context) => AdminHomepage(),
      },
    );
  }
}
