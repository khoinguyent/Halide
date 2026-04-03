import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/widgets/halide_dialog.dart';
import '../../core/providers/notification_provider.dart';
import '../../core/models/notification_model.dart';
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

  String _cleanErrorMessage(String raw) {
    // Strip [firebase_auth/xxx] prefix
    final regex = RegExp(r'\[firebase_auth/[^\]]+\]\s*');
    var cleaned = raw.replaceAll(regex, '').trim();
    // Strip leading "Exception: " if present
    if (cleaned.startsWith('Exception: ')) {
      cleaned = cleaned.substring('Exception: '.length);
    }
    // Capitalize first letter
    if (cleaned.isNotEmpty) {
      cleaned = cleaned[0].toUpperCase() + cleaned.substring(1);
    }
    // Remove trailing period if not present
    if (cleaned.isNotEmpty && !cleaned.endsWith('.')) {
      cleaned = '$cleaned.';
    }
    return cleaned;
  }

  void _showError(String message) {
    ref.read(notificationProvider.notifier).show(
      _cleanErrorMessage(message),
      type: NotificationType.error,
    );
  }

  Future<void> _handleAuthAction(Future<void> Function() action) async {
    setState(() => _isLoading = true);
    try {
      await action();
      await ref.read(authServiceProvider).syncWithBackend();
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
          Positioned.fill(
            child: Image.asset(
              'assets/images/login_bg.png',
              fit: BoxFit.cover,
            ),
          ),
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
                    const SizedBox(height: 48),
                    if (!_showOTPField) ...[
                      _buildAuthButton('Login with Email', Icons.email_outlined, _showEmailDialog),
                      const SizedBox(height: 16),
                      _buildAuthButton('Login with Phone', Icons.phone_android_outlined, _showPhoneInput),
                      const SizedBox(height: 16),
                      _buildAuthButton('Login with Google', Icons.g_mobiledata_rounded, _loginWithGoogle),
                      const SizedBox(height: 16),
                      _buildAuthButton('Login with Apple', Icons.apple_rounded, _loginWithApple),
                    ] else ...[
                      _buildOTPView(),
                    ],
                    const SizedBox(height: 32),
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
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
            'assets/images/app_icon.jpg',
            width: 80,
            height: 80,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'HALIDE',
          style: TextStyle(
            color: Colors.white,
            fontSize: 48,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
          ),
        ),
        Text(
          'FILM PHOTOGRAPHY'.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withOpacity(0.5), 
            fontSize: 12, 
            letterSpacing: 3,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildAuthButton(String text, IconData icon, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.white.withOpacity(0.15)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white.withOpacity(0.05),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 24),
            Expanded(
              child: Center(
                child: Text(
                  text.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
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

  Widget _buildOTPView() {
    return HalideModalContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'VERIFY PHONE',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 2),
          ),
          const SizedBox(height: 32),
          HalideTextField(
            controller: _otpController,
            label: 'VERIFICATION CODE',
            prefixIcon: Icons.sms_outlined,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 32),
          HalideActionButton(
            text: 'VERIFY & LOGIN',
            onPressed: _signInWithOTP,
          ),
          TextButton(
            onPressed: () => setState(() => _showOTPField = false),
            child: Text(
              'BACK TO OPTIONS'.toUpperCase(), 
              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('NEW HERE? '.toUpperCase(), style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11, fontWeight: FontWeight.bold)),
        GestureDetector(
          onTap: () => context.push('/register'),
          child: Text(
            'CREATE ACCOUNT'.toUpperCase(), 
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1),
          ),
        ),
      ],
    );
  }

  void _showEmailDialog() {
    showHalideDialog(
      context: context,
      builder: (context) => HalideModalContainer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'EMAIL SIGN IN',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            HalideTextField(
              controller: _emailController,
              label: 'EMAIL',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            HalideTextField(
              controller: _passwordController,
              label: 'PASSWORD',
              prefixIcon: Icons.lock_outline,
              obscureText: true,
            ),
            const SizedBox(height: 40),
            HalideActionButton(
              text: 'LOGIN',
              onPressed: () {
                Navigator.pop(context);
                _loginWithEmail();
              },
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'CANCEL'.toUpperCase(), 
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPhoneInput() {
    showHalideDialog(
      context: context,
      builder: (context) => HalideModalContainer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'PHONE SIGN IN',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'WE WILL SEND A CODE TO YOUR NUMBER'.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              const SizedBox(height: 32),
              HalideTextField(
                controller: _phoneController,
                label: 'PHONE NUMBER',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 40),
              HalideActionButton(
                text: 'SEND CODE',
                onPressed: () {
                  Navigator.pop(context);
                  _verifyPhone();
                },
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'CANCEL'.toUpperCase(), 
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
