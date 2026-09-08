import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'config/app_config.dart';
import 'config/env_loader.dart';
import 'core/l10n/locale_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/theme/halide_theme.dart';
import 'firebase_options.dart';
import 'router/app_router.dart';
import 'services/purchase_service.dart';
import 'core/utils/notifications.dart';
import 'core/widgets/halide_notification.dart';
import 'core/widgets/dismiss_notification_on_interaction.dart';
import 'providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadHalideEnv();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize RevenueCat
  await PurchaseService().init();

  debugPrint('[Halide] Backend: ${AppConfig.baseUrl} | API: ${AppConfig.apiUrl}');
  runApp(
    const ProviderScope(
      child: HalideApp(),
    ),
  );
}

class HalideApp extends ConsumerWidget {
  const HalideApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize global subscription sync listener
    ref.watch(entitlementListenerProvider);
    
    return const AuthGate();
  }
}

/// A gate widget that shows a loading spinner while Firebase
/// resolves the initial auth state (avoids the router making
/// a blind decision before authStateChanges fires the first event).
class AuthGate extends ConsumerWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = HalideTheme.fromColors(ref.watch(halideColorsProvider));
    final userLocale = ref.watch(localeProvider);
    final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
    final locale = resolveAppLocale(userLocale, deviceLocale);

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final localizations = AppLocalizations.localizationsDelegates;
        final supported = AppLocalizations.supportedLocales;

        // Still waiting for the first auth event
        if (snapshot.connectionState == ConnectionState.waiting) {
          return MaterialApp(
            scaffoldMessengerKey: scaffoldMessengerKey,
            debugShowCheckedModeBanner: false,
            theme: theme,
            locale: locale,
            localizationsDelegates: localizations,
            supportedLocales: supported,
            home: const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        // Auth resolved — let the router take over
        Widget app = MaterialApp.router(
          scaffoldMessengerKey: scaffoldMessengerKey,
          title: 'AgXel',
          locale: locale,
          localizationsDelegates: localizations,
          supportedLocales: supported,
          builder: (context, child) {
            Widget result = child!;
            if (AppConfig.flavor != AppFlavor.prod) {
              result = Banner(
                message: AppConfig.flavor.name.toUpperCase(),
                location: BannerLocation.topEnd,
                color: AppConfig.flavor == AppFlavor.staging 
                    ? Colors.orange.withOpacity(0.8) 
                    : Colors.red.withOpacity(0.8),
                child: result,
              );
            }
            return Stack(
              children: [
                DismissNotificationOnInteraction(child: result),
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: HalideNotification(),
                ),
              ],
            );
          },
          debugShowCheckedModeBanner: false,
          theme: theme,
          routerConfig: appRouter,
        );
        return app;
      },
    );
  }
}
