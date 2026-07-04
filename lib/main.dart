import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/home_page.dart';
import 'screens/signup_screen.dart';
import 'screens/login_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/verify_code_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/password_changed_screen.dart';
import 'screens/email_verification_screen.dart';
import 'widgets/auth_guard.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'app_localizations.dart';
import 'services/android_call_bridge_service.dart';
import 'services/preferences_service.dart';

void main() async {
  // Step 1: Initialize Flutter binding
  WidgetsFlutterBinding.ensureInitialized();

  // Step 2: Initialize Firebase. On Android the native SDK auto-creates the
  // "[DEFAULT]" app from google-services.json before Dart runs, so a second
  // initializeApp here throws [core/duplicate-app]; swallow that and reuse the
  // existing app. Any other error is rethrown.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
  }

  // Step 3: Start the Android call bridge when available. This must never block
  // app startup, so any native/platform-channel failure here is swallowed —
  // the bridge is optional and can be retried from its status screen.
  try {
    await AndroidCallBridgeService.instance.start();
  } catch (e) {
    debugPrint('Android call bridge start failed: $e');
  }

  // Step 4: Run the app
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp>  createState()  => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _prefs = PreferencesService();
  Locale? _locale;

  @override
  void initState() {
    super.initState();
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final locale = await _prefs.getLocale();
    if (locale != null) {
      setState(() => _locale = locale);
    }
  }

  void _onLocaleChanged(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // App-wide dark theme so system-drawn surfaces (dialogs, date pickers,
      // default buttons, text selection) match the app instead of falling back
      // to the light Material default (which rendered accent text purple).
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF020607),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE81218),
          brightness: Brightness.dark,
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Color(0xFFE81218),
        ),
      ),
      locale: _locale,
      supportedLocales: const [
        Locale('en'),
        Locale('it'),
        Locale('zh'),
        Locale('fr'),
        Locale('de'),
        Locale('es'),
        Locale('ru'),
        Locale('ar'),
        Locale('hi'),
        Locale('pt'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const SplashScreen(),
      routes: {
        'splash': (context) => const SplashScreen(),
        'home': (context) => AuthGuard.protect(
          child: HomePage(onLocaleChanged: _onLocaleChanged),
        ),
        'signup': (context) => const SignUpScreen(),
        'login': (context) => const LoginScreen(),
        'forgot-password': (context) => const ForgotPasswordScreen(),
        'verify-code': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is VerifyCodeArgs) {
            return VerifyCodeScreen(args: args);
          }
          return const LoginScreen();
        },
        'email-verification': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is EmailVerificationArgs) {
            return EmailVerificationScreen(args: args);
          }
          return const LoginScreen(); // Fallback
        },
        'reset-password': (context) {
          return const ResetPasswordScreen();
        },
        'password-changed': (context) => const PasswordChangedScreen(),
      },
    );
  }
}
