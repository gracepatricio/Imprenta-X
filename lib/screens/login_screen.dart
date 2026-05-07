import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'app_theme.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool isLoading = false;
  bool obscurePassword = true;

  void handleLogin() async {
    setState(() => isLoading = true);
    String? result = await _authService.login(
      emailController.text.trim(),
      passwordController.text.trim(),
    );
    setState(() => isLoading = false);

    if (result == "customer") {
      Navigator.pushReplacementNamed(context, '/customer');
    } else if (result == "employee") {
      Navigator.pushReplacementNamed(context, '/employee');
    } else if (result == "admin") {
      if (!kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Admin access is only available on the web."),
          ),
        );
        return;
      }
      Navigator.pushReplacementNamed(context, '/admin');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result ?? "Login failed")),
      );
    }
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
                      "IMPRENTA INC.",
                      style: TextStyle(
                        color: AppTheme.gold,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Sign in to your account",
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
                          // Email
                          TextField(
                            controller: emailController,
                            style: const TextStyle(color: Colors.white),
                            keyboardType: TextInputType.emailAddress,
                            decoration: AppTheme.inputDecoration(
                              "Email",
                              icon: Icons.email_outlined,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Password
                          TextField(
                            controller: passwordController,
                            obscureText: obscurePassword,
                            style: const TextStyle(color: Colors.white),
                            decoration: AppTheme.inputDecoration(
                              "Password",
                              icon: Icons.lock_outline,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.white54,
                                  size: 18,
                                ),
                                onPressed: () => setState(
                                  () => obscurePassword = !obscurePassword,
                                ),
                              ),
                            ),
                          ),

                          // Forgot password
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => Navigator.pushNamed(
                                  context, '/forgot-password'),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 4, horizontal: 0),
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
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
                            onPressed: isLoading ? null : handleLogin,
                            style: AppTheme.primaryButton(),
                            child: isLoading
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black,
                                    ),
                                  )
                                : const Text("Sign In"),
                          ),

                          const SizedBox(height: 20),

                          // Register link
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
                                onTap: () => Navigator.pushNamed(
                                    context, '/register'),
                                child: const Text(
                                  "Register",
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
