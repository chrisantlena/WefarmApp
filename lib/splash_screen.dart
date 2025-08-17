import 'package:flutter/material.dart';
import 'package:wefarm/login_screen.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(Duration(seconds: 5), () {
      // Pindah ke HomeScreen setelah 5 detik
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, // Warna dominan di atas
            end: Alignment.bottomCenter, // Warna penuh di bawah
            colors: [
              Color(0xFFF4E2BC), // Warna atas (1%)
              Color(0xFFB89955), // Warna bawah (100%)
            ],
          ),
        ),
        child: Center(
          child: Image.asset(
            'assets/logo_wefarm.png', // Ganti dengan path logo kamu
            width: 200, // Sesuaikan ukuran logo
            height: 200,
          ),
        ),
      ),
    );
  }
}
