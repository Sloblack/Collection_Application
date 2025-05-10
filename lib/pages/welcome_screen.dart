//import 'dart:io';
import 'package:flutter/material.dart';
//import 'package:recollection_application/auth/auth_service.dart';
import 'package:recollection_application/pages/login_screen.dart';
import 'package:recollection_application/pages/main_wrapper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<bool> _checkSession() async {

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    //final authService = AuthService();
    //final isValid = await authService.validateToken();

    if(token != null){// && isValid) {
      return true;
    } else {
      return false;
    }
  }

  void abrirLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  void abrirWrapper() {
    Navigator.of(context).pushReplacement(
    MaterialPageRoute(builder: (context) => MainWrapper()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.recycling, size: 250, color: Colors.teal),
            SizedBox(height: 30),
            Text('Bienvenido', style:
            TextStyle(fontSize: 36)
            ),
            SizedBox(height: 20),
            Text('Aplicación de recolección de residuos', style: TextStyle(fontSize: 20),),
            SizedBox(height: 24.0 ),
            ElevatedButton(
              onPressed: () async {
                bool session = await _checkSession();
                if (session) {
                  abrirWrapper();
                }
                else {
                  abrirLogin();
                }
                CircularProgressIndicator(
                color: Colors.white,
              );
              },
              style:ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 102.0, vertical: 10.0),
              ),
              child: Text('Iniciar', style: TextStyle(fontSize: 26.0),),
              ),
          ],
        ),
      )
    );
  }
}