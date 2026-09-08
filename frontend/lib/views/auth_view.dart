import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart';
import 'package:firebase_ui_oauth_facebook/firebase_ui_oauth_facebook.dart';
import 'package:firebase_ui_oauth_apple/firebase_ui_oauth_apple.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/l10n/l10n_extension.dart';
import '../services/auth_service.dart';

class AuthView extends StatelessWidget {
  const AuthView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final providers = <AuthProvider>[
      EmailAuthProvider(),
      GoogleProvider(clientId: 'dummy-google-id'),
      FacebookProvider(clientId: 'dummy-facebook-id'),
      AppleProvider(),
    ];

    return SignInScreen(
      providers: providers,
      actions: [
        AuthStateChangeAction<SignedIn>((context, state) {
          final authService = AuthService();
          authService.syncWithBackend();
          context.go('/');
        }),
        AuthStateChangeAction<UserCreated>((context, state) {
          final authService = AuthService();
          authService.syncWithBackend();
          context.go('/');
        }),
      ],
      headerBuilder: (context, constraints, shrinkOffset) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: AspectRatio(
            aspectRatio: 1,
            child: Image.network('https://raw.githubusercontent.com/flutter/website/main/src/assets/images/shared/brand/flutter/logo/flutter-lockup.png'),
          ),
        );
      },
      subtitleBuilder: (context, action) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: action == AuthAction.signIn
              ? Text(l10n.welcomeSignIn)
              : Text(l10n.welcomeSignUp),
        );
      },
      footerBuilder: (context, action) {
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            l10n.signInTermsFooter,
            style: const TextStyle(color: Colors.grey),
          ),
        );
      },
      sideBuilder: (context, shrinkOffset) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: AspectRatio(
            aspectRatio: 1,
            child: Image.network('https://raw.githubusercontent.com/flutter/website/main/src/assets/images/shared/brand/flutter/logo/flutter-lockup.png'),
          ),
        );
      },
    );
  }
}
