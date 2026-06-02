import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/cart_manager.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/customer_homepage.dart';
import 'screens/employee_homepage.dart';
import 'screens/admin_homepage.dart';
import 'screens/role_guard.dart';
import 'screens/change_password_screen.dart';
import 'services/notification_service.dart';
import 'screens/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (kIsWeb) {
    await FirebaseAuth.instance.setPersistence(Persistence.SESSION);
  }
  await FirebaseAuth.instance.authStateChanges()
      .first
      .timeout(const Duration(seconds: 5), onTimeout: () => null);
  await NotificationService.initialize();

  String? resetOobCode;
  if (kIsWeb) {
    final uri = Uri.base;
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
            TargetPlatform.iOS: _SmoothPageTransitionsBuilder(),
            TargetPlatform.windows: _SmoothPageTransitionsBuilder(),
            TargetPlatform.macOS: _SmoothPageTransitionsBuilder(),
            TargetPlatform.linux: _SmoothPageTransitionsBuilder(),
          },
        ),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      ),
      // ── Global background applied once here — covers every screen ────────
      // builder wraps every route's widget tree with AppBackground,
      // so no individual screen needs to set its own background.
      builder: (context, child) => AppBackground(child: child!),
      initialRoute: resetOobCode != null ? '/reset-password' : '/',
      routes: {
        '/': (context) => LoginScreen(),
        '/register': (context) => RegisterScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/reset-password': (context) =>
            ResetPasswordScreen(oobCode: resetOobCode ?? ''),
        '/customer': (context) => const RoleGuard(requiredRole: 'customer', child: CustomerHomepage()),
        '/employee': (context) => const RoleGuard(requiredRole: 'employee', child: EmployeeHomepage()),
        '/admin':    (context) => const RoleGuard(requiredRole: 'admin',    child: AdminHomepage()),
        '/change-password': (context) {
          final args =
          ModalRoute.of(context)!.settings.arguments
          as Map<String, dynamic>;
          return ChangePasswordScreen(role: args['role'] as String);
        },
      },
    );
  }
}

// ── AppBackground ─────────────────────────────────────────────────────────────
// Sits below every screen. Picks landscape or portrait asset automatically.
// Individual screens should have transparent/no background scaffolds —
// remove any existing BoxDecoration background from your Scaffold/Container
// in each screen so this one shows through.
class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.backgroundDecoration(context),
      child: child,
    );
  }
}