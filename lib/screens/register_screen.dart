import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/otp_service.dart';
import 'app_theme.dart';
import 'email_otp_screen.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final fullNameController        = TextEditingController();
  final emailController           = TextEditingController();
  final passwordController        = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final AuthService _authService  = AuthService();
  bool isLoading        = false;
  bool obscurePassword  = true;
  bool obscureConfirm   = true;

  @override
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  // Validate form fields and send OTP, then open the OTP screen.
  Future<void> _sendVerificationCode() async {
    final fullName        = fullNameController.text.trim();
    final email           = emailController.text.trim();
    final password        = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (fullName.isEmpty || email.isEmpty || password.isEmpty) {
      _snack('Please fill in all fields.');
      return;
    }
    if (password != confirmPassword) {
      _snack('Passwords do not match.');
      return;
    }
    if (password.length < 6) {
      _snack('Password must be at least 6 characters.');
      return;
    }

    setState(() => isLoading = true);
    String generatedCode;
    try {
      generatedCode = await OtpService().sendOtp(email);
    } catch (e) {
      setState(() => isLoading = false);
      _snack('Failed to send verification code: $e');
      return;
    }
    if (!mounted) return;
    setState(() => isLoading = false);

    // Navigate to OTP screen; on success, create the Firebase account.
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmailOtpScreen(
          email:        email,
          expectedCode: generatedCode,
          onVerified: () async {
            final result =
                await _authService.register(email, password, fullName);
            if (!mounted) return;

            if (result == 'success') {
              _snack('Account created successfully!');
              Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
            } else if (result == 'account_reclaim_needed') {
              // Firebase Auth account still exists (admin deleted only the
              // Firestore record). Show recovery instructions then go to login.
              await showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF1a1a2e),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  title: const Text(
                    'Account Recovery',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  content: const Text(
                    'This email was previously registered and its account was '
                    'removed by an administrator.\n\n'
                    'We\'ve sent a password reset link to your email. '
                    'Click the link to set a new password, then sign in.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  actions: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.gold,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
              if (!mounted) return;
              Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
            } else {
              throw Exception(result ?? 'Registration failed. Please try again.');
            }
          },
        ),
      ),
    );
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

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
                          errorBuilder: (_, __, ___) => const Icon(
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
                      'Create a new account',
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
                          // Full Name
                          TextField(
                            controller: fullNameController,
                            style: const TextStyle(color: Colors.white),
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            decoration: AppTheme.inputDecoration(
                              'Full Name',
                              icon: Icons.person_outline,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Email
                          TextField(
                            controller: emailController,
                            style: const TextStyle(color: Colors.white),
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: AppTheme.inputDecoration(
                              'Email',
                              icon: Icons.email_outlined,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Password
                          TextField(
                            controller: passwordController,
                            obscureText: obscurePassword,
                            style: const TextStyle(color: Colors.white),
                            textInputAction: TextInputAction.next,
                            decoration: AppTheme.inputDecoration(
                              'Password',
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
                                    () => obscurePassword = !obscurePassword),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Confirm Password
                          TextField(
                            controller: confirmPasswordController,
                            obscureText: obscureConfirm,
                            style: const TextStyle(color: Colors.white),
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _sendVerificationCode(),
                            decoration: AppTheme.inputDecoration(
                              'Confirm Password',
                              icon: Icons.lock_outline,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  obscureConfirm
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.white54,
                                  size: 18,
                                ),
                                onPressed: () => setState(
                                    () => obscureConfirm = !obscureConfirm),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Send OTP button
                          ElevatedButton(
                            onPressed:
                                isLoading ? null : _sendVerificationCode,
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
                                : const Text('Send Verification Code'),
                          ),

                          const SizedBox(height: 20),

                          // Sign in link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Already have an account?',
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 13),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: const Text(
                                  'Sign In',
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
