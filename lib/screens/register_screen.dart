import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'app_theme.dart';
import 'email_otp_screen.dart';

const _cyan = Color(0xFF00B4D8);
const _magenta = Color(0xFFFF006E);
const _yellow = Color(0xFFFFDE89);
const _green = Color(0xFF80B918);

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  final fullNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirm = true;

  late AnimationController _pulseCtrl;
  late AnimationController _dotCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    _pulseCtrl.dispose();
    _dotCtrl.dispose();
    super.dispose();
  }

  String? _validatePassword(String password) {
    if (password.length < 8) return 'Password must be at least 8 characters.';
    if (!RegExp(r'[A-Z]').hasMatch(password))
      return 'Password must contain at least one uppercase letter.';
    if (!RegExp(r'[a-z]').hasMatch(password))
      return 'Password must contain at least one lowercase letter.';
    if (!RegExp(r'[0-9]').hasMatch(password))
      return 'Password must contain at least one number.';
    if (!RegExp(
      r'[!@#$%^&*()\-_=+\[\]{};:,.<>?/\\|`~'
      "'\"]",
    ).hasMatch(password))
      return 'Password must contain at least one special character.';
    return null;
  }

  Future<void> _createAccount() async {
    final fullName = fullNameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (fullName.isEmpty || email.isEmpty || password.isEmpty) {
      _snack('Please fill in all fields.');
      return;
    }
    if (password != confirmPassword) {
      _snack('Passwords do not match.');
      return;
    }
    final pwError = _validatePassword(password);
    if (pwError != null) {
      _snack(pwError);
      return;
    }

    setState(() => isLoading = true);
    final result = await _authService.createAccount(email, password, fullName);
    if (!mounted) return;
    setState(() => isLoading = false);

    if (result.error != null) {
      _snack(result.error!);
      return;
    }

    final user = result.user!;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmailVerificationScreen(
          email: email,
          onVerified: () async {
            final err = await _authService.finalizeRegistration(
              user.uid,
              email,
              fullName,
            );
            if (!mounted) return;
            if (err == 'success') {
              _snack('Account created successfully!');
              Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
            } else {
              throw Exception(err ?? 'Registration failed. Please try again.');
            }
          },
        ),
      ),
    );
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    final m = ScaffoldMessenger.of(context);
    m.clearSnackBars();
    m.showSnackBar(
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
          onPressed: () => m.hideCurrentSnackBar(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
decoration: AppTheme.backgroundDecoration(context),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 600;
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isWide ? 24 : 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildBrand(),
                    const SizedBox(height: 28),
                    _buildCard(isWide),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBrand() {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (_, child) => Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.07),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _cyan.withValues(alpha: _pulseCtrl.value * 0.15),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: child,
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/imprentalogo.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.local_print_shop, color: _yellow, size: 24),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'IMPRENTA INC.',
          style: TextStyle(
            color: _yellow,
            fontWeight: FontWeight.w600,
            fontSize: 18,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'Create a new account',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 11,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildCard(bool isWide) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: isWide ? 400 : double.infinity),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Glass body
          Container(
            padding: EdgeInsets.fromLTRB(
              isWide ? 28 : 20,
              32,
              isWide ? 28 : 20,
              24,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Full Name
                _FocusField(
                  label: 'Full Name',
                  controller: fullNameController,
                  icon: Icons.person_outline_rounded,
                  keyboardType: TextInputType.name,
                  textInputAction: TextInputAction.next,
                  hint: 'Enter your full name',
                ),
                const SizedBox(height: 14),

                // Email
                _FocusField(
                  label: 'Email',
                  controller: emailController,
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  hint: 'Enter your email',
                ),
                const SizedBox(height: 14),

                // Password
                _FocusField(
                  label: 'Password',
                  controller: passwordController,
                  icon: Icons.lock_outline_rounded,
                  obscureText: obscurePassword,
                  textInputAction: TextInputAction.next,
                  hint: 'Create a password',
                  suffix: IconButton(
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.white.withValues(alpha: 0.3),
                      size: 18,
                    ),
                    onPressed: () =>
                        setState(() => obscurePassword = !obscurePassword),
                    splashRadius: 16,
                  ),
                ),
                const SizedBox(height: 5),
                Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Text(
                    'Min. 8 chars · uppercase · lowercase · number · special character',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.25),
                      fontSize: 10,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Confirm Password
                _FocusField(
                  label: 'Confirm Password',
                  controller: confirmPasswordController,
                  icon: Icons.lock_outline_rounded,
                  obscureText: obscureConfirm,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _createAccount(),
                  hint: 'Repeat your password',
                  suffix: IconButton(
                    icon: Icon(
                      obscureConfirm
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.white.withValues(alpha: 0.3),
                      size: 18,
                    ),
                    onPressed: () =>
                        setState(() => obscureConfirm = !obscureConfirm),
                    splashRadius: 16,
                  ),
                ),
                const SizedBox(height: 22),

                // Create Account button
                ElevatedButton(
                  onPressed: isLoading ? null : _createAccount,
                  style:
                      ElevatedButton.styleFrom(
                        backgroundColor: _yellow,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: _yellow.withValues(alpha: 0.5),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        shadowColor: _yellow.withValues(alpha: 0.3),
                      ).copyWith(
                        elevation: WidgetStateProperty.resolveWith(
                          (s) => s.contains(WidgetState.hovered) ? 6 : 0,
                        ),
                      ),
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          'Create Account',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                ),

                const SizedBox(height: 20),

                // Divider
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: Colors.white.withValues(alpha: 0.08),
                        thickness: 1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'or',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.2),
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: Colors.white.withValues(alpha: 0.08),
                        thickness: 1,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Sign in link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account?',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.32),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text(
                        'Sign In',
                        style: TextStyle(
                          color: _yellow,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // CMYK dots
                _CmykDots(controller: _dotCtrl),
              ],
            ),
          ),

          // CMYK top accent bar
          Positioned(
            top: 0,
            left: 40,
            right: 40,
            child: Container(
              height: 2,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(4)),
                gradient: LinearGradient(
                  colors: [_cyan, _magenta, _yellow, _green],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Focus-animated field ───────────────────────────────────────────────────────

class _FocusField extends StatefulWidget {
  const _FocusField({
    required this.label,
    required this.controller,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.suffix,
    this.hint,
  });

  final String label;
  final TextEditingController controller;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;
  final String? hint;

  @override
  State<_FocusField> createState() => _FocusFieldState();
}

class _FocusFieldState extends State<_FocusField> {
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            color: _focused
                ? _yellow.withValues(alpha: 0.9)
                : Colors.white.withValues(alpha: 0.38),
            fontSize: 10,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w500,
          ),
          child: Text(widget.label.toUpperCase()),
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.white.withValues(alpha: 0.05),
            border: Border.all(
              color: _focused
                  ? _yellow.withValues(alpha: 0.45)
                  : Colors.white.withValues(alpha: 0.10),
              width: 1,
            ),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: _yellow.withValues(alpha: 0.08),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focus,
            obscureText: widget.obscureText,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            onSubmitted: widget.onSubmitted,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.2),
                fontSize: 13,
              ),
              prefixIcon: Icon(
                widget.icon,
                color: _focused
                    ? _yellow.withValues(alpha: 0.8)
                    : Colors.white.withValues(alpha: 0.28),
                size: 18,
              ),
              suffixIcon: widget.suffix,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── CMYK dots ─────────────────────────────────────────────────────────────────

class _CmykDots extends StatelessWidget {
  const _CmykDots({required this.controller});
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    final colors = [_cyan, _magenta, _yellow, _green];
    final delays = [0.0, 0.2, 0.4, 0.6];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        final anim = Tween<double>(begin: 0.25, end: 0.9).animate(
          CurvedAnimation(
            parent: controller,
            curve: Interval(
              delays[i],
              (delays[i] + 0.4).clamp(0, 1),
              curve: Curves.easeInOut,
            ),
          ),
        );
        return AnimatedBuilder(
          animation: anim,
          builder: (_, __) => Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors[i].withValues(alpha: anim.value),
            ),
          ),
        );
      }),
    );
  }
}
