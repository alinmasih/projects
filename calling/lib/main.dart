import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/config.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/agora_service.dart';
import 'services/auth_service.dart';
import 'services/call_service.dart';
import 'services/fcm_service.dart';

/// Handles FCM messages when the application runs in the background or is killed.
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      name: 'background',
      options: AppConfig.firebaseOptions,
    );
  } on FirebaseException catch (error) {
    if (error.code != 'duplicate-app') {
      rethrow;
    }
  }

  await FcmService.handleBackgroundMessage(message);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: AppConfig.firebaseOptions);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  final authService = AuthService();
  final agoraService = AgoraService();
  final fcmService = FcmService();
  final callService = CallService(
    authService: authService,
    agoraService: agoraService,
    fcmService: fcmService,
  );

  await Future.wait([
    agoraService.initialize(),
    fcmService.initialize(authService: authService, callService: callService),
  ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: authService),
        Provider<AgoraService>.value(value: agoraService),
        ChangeNotifierProvider<CallService>.value(value: callService),
        ChangeNotifierProvider<FcmService>.value(value: fcmService),
      ],
      child: const WiFiVoiceApp(),
    ),
  );
}

class WiFiVoiceApp extends StatelessWidget {
  const WiFiVoiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      colorSchemeSeed: Colors.blueGrey,
      useMaterial3: true,
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: AppConfig.appName,
      theme: theme,
      home: Consumer<AuthService>(
        builder: (context, authService, _) {
          if (authService.isInitializing) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator.adaptive()),
            );
          }

          return authService.isAuthenticated
              ? const HomeScreen()
              : const LoginScreen();
        },
      ),
      routes: {
        HomeScreen.routeName: (_) => const HomeScreen(),
        LoginScreen.routeName: (_) => const LoginScreen(),
      },
    );
  }
}
