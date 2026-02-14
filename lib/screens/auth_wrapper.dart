import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'doctor_dashboard.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, _) {
        // Show loading while checking auth state
        if (userProvider.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Not logged in → Login Screen
        if (!userProvider.isLoggedIn) {
          return const LoginScreen();
        }

        //Logged in → Route by role
        if (userProvider.isDoctor) {
          return const DoctorDashboard();
        } else {
          return const HomeScreen(); // Patient dashboard
        }
      },
    );
  }
}
