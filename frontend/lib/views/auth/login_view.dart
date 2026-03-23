import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/widgets/halide_dialog.dart';
import '../../providers/auth_provider.dart';

class LoginView extends ConsumerStatefulWidget {
  const LoginView({Key? key}) : super(key: key);

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  
  bool _isLoading = false;
  bool _showOTPField = false;
  String? _verificationId;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _handleAuthAction(Future<void> Function() action) async {
    setState(() => _isLoading = true);
    try {
      await action();
      // Sync with backend to ensure user record exists
      await ref.read(authServiceProvider).syncWithBackend();
      // On success, GoRouter will handle redirection via AuthNotifier
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithEmail() async {
    await _handleAuthAction(() async {
      await ref.read(authServiceProvider).signInWithEmailAndPassword(
            _emailController.text.trim(),
            _passwordController.text.trim(),
          );
    });
  }

  Future<void> _loginWithGoogle() async {
    await _handleAuthAction(() async {
      await ref.read(authServiceProvider).signInWithGoogle();
    });
  }

  Future<void> _loginWithApple() async {
    await _handleAuthAction(() async {
      await ref.read(authServiceProvider).signInWithApple();
    });
  }

  Future<void> _verifyPhone() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authServiceProvider).verifyPhoneNumber(
        phoneNumber: _phoneController.text.trim(),
        verificationCompleted: (credential) async {
          await ref.read(authServiceProvider).signInWithCredential(credential);
          await ref.read(authServiceProvider).syncWithBackend();
        },
        verificationFailed: (e) => _showError(e.message ?? 'Phone verification failed'),
        codeSent: (verificationId, resendToken) {
          setState(() {
            _verificationId = verificationId;
            _showOTPField = true;
            _isLoading = false;
          });
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      if (mounted) {
        _showError(e.toString());
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithOTP() async {
    if (_verificationId == null) return;
    await _handleAuthAction(() async {
      await ref.read(authServiceProvider).signInWithPhoneNumber(
        _verificationId!,
        _otpController.text.trim(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Local background image for premium aesthetic
          Positioned.fill(
            child: Image.asset(
              'assets/images/login_bg.png',
              fit: BoxFit.cover,
              height: double.infinity,
              width: double.infinity,
            ),
          ),
          // Gradient Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.4),
                    Colors.black.withOpacity(0.85),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    _buildLogoHeader(),
                    const SizedBox(height: 32),
                    _buildGlassCard(),
                    const SizedBox(height: 24),
                    _buildFooter(),
                  ],
                ),
              ),
            ),
          ),

          if (_isLoading)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  color: Colors.black26,
                  child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLogoHeader() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
                color: Colors.white.withOpacity(0.05),
              ),
            ),
            const Icon(Icons.camera_rounded, color: Colors.white, size: 48),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'Halide',
          style: TextStyle(
            color: Colors.white,
            fontSize: 42,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        const Text(
          'Film Photography',
          style: TextStyle(color: Colors.white54, fontSize: 14, letterSpacing: 1),
        ),
      ],
    );
  }

  Widget _buildGlassCard() {
    final width = MediaQuery.of(context).size.width;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              width: width * 0.9,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white.withOpacity(0.15)),
              ),
              child: Column(
                children: [
                  const Text(
                    'Sign in to Halide',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Start capturing analog moments again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white60, fontSize: 14),
                  ),
                  const SizedBox(height: 40),

                  if (!_showOTPField) ...[
                    _buildContinueButton('Continue with Email', Icons.email_outlined, _showEmailDialog),
                    const SizedBox(height: 16),
                    _buildContinueButton('Continue with Phone', Icons.phone_android_outlined, _showPhoneInput),
                    const SizedBox(height: 16),
                    _buildContinueButton('Continue with Google', Icons.g_mobiledata_rounded, _loginWithGoogle),
                    const SizedBox(height: 16),
                    _buildContinueButton('Continue with Apple', Icons.apple_rounded, _loginWithApple),
                  ] else ...[
                    HalideTextField(
                      controller: _otpController,
                      label: 'Verification Code',
                      prefixIcon: Icons.sms_outlined,
                    ),
                    const SizedBox(height: 24),
                    HalideActionButton(
                      text: 'Verify & Login',
                      onPressed: _signInWithOTP,
                    ),
                    TextButton(
                      onPressed: () => setState(() => _showOTPField = false),
                      child: const Text('Back to options', style: TextStyle(color: Colors.white60)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContinueButton(String text, IconData icon, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.white.withOpacity(0.2)),
          shape: const StadiumBorder(),
          backgroundColor: Colors.white.withOpacity(0.02),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 24),
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    text,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Don\'t have an account? ', style: TextStyle(color: Colors.white38)),
            GestureDetector(
              onTap: () => context.push('/register'),
              child: const Text('Sign Up', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Forgot password?', style: TextStyle(color: Colors.white24, fontSize: 13)),
      ],
    );
  }

  void _showEmailDialog() {
    showHalideDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: HalideModalContainer(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Email Sign In',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.left,
                ),
                const SizedBox(height: 16),
                HalideTextField(
                  controller: _emailController,
                  label: 'Email',
                  prefixIcon: Icons.email_outlined,
                ),
                const SizedBox(height: 16),
                HalideTextField(
                  controller: _passwordController,
                  label: 'Password',
                  prefixIcon: Icons.lock_outline,
                  obscureText: true,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                    ),
                    const SizedBox(width: 8),
                    HalideActionButton(
                      text: 'Login',
                      width: 100,
                      height: 40,
                      onPressed: () {
                        Navigator.pop(context);
                        _loginWithEmail();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPhoneInput() {
    showHalideDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: HalideModalContainer(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Continue with Phone',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.left,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'We will send a code to your number',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  HalideTextField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 24),
                  HalideActionButton(
                    text: 'Send Verification Code',
                    onPressed: () {
                      Navigator.pop(context);
                      _verifyPhone();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
