import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/cart_manager.dart';
import 'app_theme.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text.trim();

    if (identifier.isEmpty || password.isEmpty) {
      _snack('Please enter your Email / ID and password.');
      return;
    }

    setState(() => _isLoading = true);

    String? result;
    try {
      result = await _authService.login(identifier, password);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _snack('An unexpected error occurred. Please try again.', isError: true);
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result == null) {
      _snack('Login failed. Please try again.', isError: true);
      return;
    }

    // must_change_password signal: "must_change_password:<role>"
    if (result.startsWith('must_change_password:')) {
      final role = result.split(':').last;
      Navigator.pushReplacementNamed(
        context,
        '/change-password',
        arguments: {'role': role},
      );
      return;
    }

    switch (result) {
      case 'customer':
        // Load the cart for this user now that we know they are authenticated.
        // FirebaseAuth.instance.currentUser is available immediately after
        // a successful signInWithEmailAndPassword call inside AuthService.login().
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          await CartManager.loadForUser(uid);
        }
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/customer');
        break;

      case 'employee':
        Navigator.pushReplacementNamed(context, '/employee');
        break;

      case 'admin':
        if (!kIsWeb) {
          _snack('Admin access is only available on the web.');
          await _authService.signOut();
          return;
        }
        Navigator.pushReplacementNamed(context, '/admin');
        break;

      default:
        // Any other string is an error message from AuthService
        _snack(result, isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        backgroundColor: isError ? const Color(0xFFB00020) : Colors.black87,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () => messenger.hideCurrentSnackBar(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.backgroundDecoration,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 600;
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isWide ? 24 : 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo / Brand
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.15),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/imprentalogo.jpg',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.local_print_shop,
                                color: Colors.white,
                                size: 18,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'IMPRENTA INC.',
                      style: TextStyle(
                        color: AppTheme.gold,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Sign in to your account',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),

                    const SizedBox(height: 32),

                    // Glass card
                    Container(
                      width: isWide ? 400 : double.infinity,
                      padding: EdgeInsets.all(isWide ? 28 : 20),
                      decoration: AppTheme.glassCard(opacity: 0.18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Identifier:
                          //   Customer  → email or CUS-xxx
                          //   Employee  → email or EMP-xxx
                          //   Admin     → email or ADM-xxx
                          TextField(
                            controller: _identifierController,
                            style: const TextStyle(color: Colors.white),
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: AppTheme.inputDecoration(
                              'Email or ID',
                              icon: Icons.person_outline,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Password
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(color: Colors.white),
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _handleLogin(),
                            decoration: AppTheme.inputDecoration(
                              'Password',
                              icon: Icons.lock_outline,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.white54,
                                  size: 18,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),
                          ),

                          // Forgot password
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => Navigator.pushNamed(
                                context,
                                '/forgot-password',
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                  horizontal: 0,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Forgot password?',
                                style: TextStyle(
                                  color: AppTheme.gold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Login button
                          ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: AppTheme.primaryButton(),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black,
                                    ),
                                  )
                                : const Text('Sign In'),
                          ),

                          const SizedBox(height: 20),

                          // Register link (customers only)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                "Don't have an account?",
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () =>
                                    Navigator.pushNamed(context, '/register'),
                                child: const Text(
                                  'Register',
                                  style: TextStyle(
                                    color: AppTheme.gold,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
