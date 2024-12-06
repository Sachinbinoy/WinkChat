import 'package:chat_app/Screens/login_screen.dart';
import 'package:chat_app/constants.dart';
import 'package:flutter/material.dart';
import 'package:chat_app/Screens/home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate(); // Navigate after a delay
  }

  // Navigate based on the user's authentication status after a delay
  Future<void> _navigate() async {
    await Future.delayed(
        const Duration(seconds: 2)); // Delay for the splash effect

    // Check if a user is already signed in
    if (FirebaseAuth.instance.currentUser != null) {
      // User is already signed in, navigate to HomeScreen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else {
      // No user is signed in, navigate to AuthCheck or LoginScreen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String text = 'WingChat'; // The text for the splash screen

    return Scaffold(
      backgroundColor: SecondaryBlue,
      body: Center(
        child: Text(
          text,
          style: TextStyle(
            color: White,
            fontSize: 36,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
