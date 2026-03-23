import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'config/app_config.dart';
import 'firebase_options.dart';
import 'router/app_router.dart';
import 'services/purchase_service.dart';
import 'core/utils/notifications.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

class HalideApp extends StatelessWidget {
  const HalideApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const AuthGate();
  }
}

/// A gate widget that shows a loading spinner while Firebase
/// resolves the initial auth state (avoids the router making
/// a blind decision before authStateChanges fires the first event).
class AuthGate extends StatelessWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Still waiting for the first auth event
        if (snapshot.connectionState == ConnectionState.waiting) {
          return MaterialApp(
            scaffoldMessengerKey: scaffoldMessengerKey,
            debugShowCheckedModeBanner: false,
            home: const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        // Auth resolved — let the router take over
        return MaterialApp.router(
          scaffoldMessengerKey: scaffoldMessengerKey,
          title: 'Halide',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            primarySwatch: Colors.blue,
            useMaterial3: true,
          ),
          routerConfig: appRouter,
        );
      },
    );
  }
}
