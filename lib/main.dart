import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:q_officer_barantin/surat_tugas/surat_tugas.dart';

import 'services/notification_service.dart';
import 'services/notif_history_screen.dart';
import 'services/notification_provider.dart';
import 'services/notif_detail_screen.dart';
import 'services/auth_provider.dart';

import 'login_screen.dart';
import 'splash_screen.dart';
import 'beranda/home_screen.dart';


final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> initFirebaseOnce() async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await initFirebaseOnce();
  debugPrint("📨 [Background] ${message.notification?.title}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initFirebaseOnce();
  await initializeDateFormatting('id_ID', null);

  // Setup background notification
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..checkLoginStatus()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const Color karantinaBrown = Color(0xFF522E2E);
  static const Color softBackground = Color(0xFFF9F6F1);
  static const Color accentGold = Color(0xFFD2B48C);

  @override
  Widget build(BuildContext context) {
    // Inisialisasi notifikasi setelah frame build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.navigatorKey = navigatorKey;
      NotificationService.initialize(context);
    });

    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Q-Officer App',
      theme: ThemeData(
        primaryColor: karantinaBrown,
        scaffoldBackgroundColor: softBackground,
        fontFamily: 'Inter',
        appBarTheme: const AppBarTheme(
          backgroundColor: karantinaBrown,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: karantinaBrown,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.black87),
          bodyMedium: TextStyle(color: Colors.black87),
        ),
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.brown,
        ).copyWith(
          primary: karantinaBrown,
          secondary: accentGold,
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('id', 'ID'), // Tambahkan lokal Bahasa Indonesia
      ],
      locale: const Locale('id', 'ID'),
      home: const SplashScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/notif-detail': (context) => const NotifDetailScreen(),
        '/notif-history': (context) => const NotifHistoryScreen(),
        '/surat-tugas': (context) => SuratTugasPage(),
      },
    );
  }
}
