import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/login_screen.dart'; // Crearemos esta pantalla en el paso 4

void main() async {
  // Asegura que los widgets de Flutter carguen antes de Firebase
  WidgetsFlutterBinding.ensureInitialized();
  // Inicializa el proyecto con los archivos de configuración (google-services.json)
  await Firebase.initializeApp();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sistema COC UNIVO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xff1a237e), // Azul institucional UNIVO
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const LoginScreen(), // Pantalla de inicio
    );
  }
}