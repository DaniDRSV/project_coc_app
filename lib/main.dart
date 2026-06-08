import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  Widget initialScreen = const LoginScreen();
  User? user = FirebaseAuth.instance.currentUser;

  // Si hay un usuario en Firebase, verificamos si pidió mantener la sesión
  if (user != null) {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool keepSession = prefs.getBool('keep_session') ?? false;

    if (keepSession) {
      try {
        DocumentSnapshot doc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
        if (doc.exists) {
          String rol = (doc.data() as Map<String, dynamic>)['rol'] ?? 'operador';
          initialScreen = HomeScreen(rol: rol);
        }
      } catch (e) {
        // En caso de error de red, cae al login
      }
    } else {
      // Si no marcó la casilla en su último inicio, cerramos la sesión residual
      await FirebaseAuth.instance.signOut();
    }
  }

  runApp(MyApp(initialScreen: initialScreen));
}

class MyApp extends StatelessWidget {
  final Widget initialScreen;
  const MyApp({super.key, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sistema COC UNIVO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xff1a237e),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: initialScreen, // Carga la pantalla calculada en el main
    );
  }
}