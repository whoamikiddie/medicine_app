import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'config/app_theme.dart';
import 'providers/medicine_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/user_provider.dart';
import 'screens/auth_wrapper.dart';
import 'services/notification_service.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  // Initialize local notifications and request permissions
  final notificationService = NotificationService();
  await notificationService.init();
  
  // Request permissions immediately on app start
  final hasPermissions = await notificationService.ensurePermissionsGranted();
  if (hasPermissions) {
    debugPrint('[App] ✓ Notification permissions granted');
  } else {
    debugPrint('[App] ⚠️ Notification permissions denied - reminders will not work');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProxyProvider<UserProvider, MedicineProvider>(
          create: (_) => MedicineProvider(),
          update: (_, userProvider, medicineProvider) {
            medicineProvider!.setUserId(
              userProvider.isLoggedIn ? userProvider.currentUser?.uid : null,
            );
            return medicineProvider;
          },
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'MediTrack',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const AuthWrapper(),
          );
        },
      ),
    );
  }
}