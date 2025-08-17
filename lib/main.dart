import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'auth_provider.dart';
import 'models/plant_provider.dart';
import 'models/history_provider.dart';
import 'models/experience_provider.dart';
import 'models/user_provider.dart'; // Tambahkan import ini
import 'splash_screen.dart';

Future<void> main() async {
  // Initialize packages and bindings
  WidgetsFlutterBinding.ensureInitialized();

  // Configure timeago
  timeago.setLocaleMessages('en_short', timeago.EnShortMessages());

  // Initialize shared preferences
  final sharedPreferences = await SharedPreferences.getInstance();

  runApp(
    MultiProvider(
      providers: [
        // Auth Provider (manages user authentication state)
        ChangeNotifierProvider(
          create: (_) => AuthProvider(sharedPreferences),
        ),

        // User Provider - Tambahkan ini
        ChangeNotifierProvider(
          create: (_) => UserProvider(),
        ),

        // Plant Provider (depends on auth)
        ChangeNotifierProvider(
          create: (context) => PlantProvider()
            ..updateUserProvider(
                Provider.of<UserProvider>(context, listen: false)),
        ),
        // History Provider (depends on auth)
        ChangeNotifierProxyProvider<AuthProvider, HistoryProvider>(
          create: (_) => HistoryProvider(),
          update: (_, authProvider, historyProvider) {
            historyProvider ??= HistoryProvider();
            historyProvider.updateAuthProvider(authProvider);
            return historyProvider;
          },
        ),

        // Experience Provider
        ChangeNotifierProvider(
          create: (_) => ExperienceProvider(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WeFarm',
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.green),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
