import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        var user = await _authService.signInWithEmail(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );

        if (user != null) {
          DocumentSnapshot userDoc = await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(user.uid)
              .get();

          if (userDoc.exists) {
            final data = userDoc.data() as Map<String, dynamic>?;
            String estado = data?['estado'] ?? 'activo'; 
            
            if (estado == 'inactivo') {
              await _authService.signOut();
              if (mounted) {
                setState(() => _isLoading = false);
                _showFeedback('Esta cuenta ha sido desactivada.', Colors.orange, Icons.block);
              }
              return;
            }

            String rol = data?['rol'] ?? 'operador';
            if (mounted) {
              setState(() => _isLoading = false);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => HomeScreen(rol: rol)),
              );
            }
          } else {
            if (mounted) {
              setState(() => _isLoading = false);
              _showFeedback('No se encontró el perfil del usuario.', Colors.redAccent, Icons.error_outline);
            }
          }
        } else {
          if (mounted) {
            setState(() => _isLoading = false);
            _showFeedback('Correo o contraseña incorrectos.', Colors.redAccent, Icons.lock_outline);
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showFeedback('Error de acceso al servidor.', Colors.redAccent, Icons.cloud_off);
        }
      }
    }
  }

  void _forgotPassword() {
    if (_emailController.text.isEmpty) {
      _showFeedback('Ingrese su correo para enviarle el enlace.', Colors.blueAccent, Icons.info_outline);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Recuperar Contraseña", style: TextStyle(color: Color(0xff1a237e), fontWeight: FontWeight.bold)),
        content: Text("¿Desea enviar un enlace de recuperación al correo:\n${_emailController.text.trim()}?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff1a237e)),
            onPressed: () async {
              try {
                await _authService.sendPasswordResetEmail(_emailController.text.trim());
                if (mounted) {
                  Navigator.pop(context);
                  _showFeedback("Enlace enviado con éxito.", Colors.green, Icons.send);
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  _showFeedback("Error al enviar el enlace.", Colors.redAccent, Icons.error);
                }
              }
            },
            child: const Text("ENVIAR", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showFeedback(String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(15),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff1a237e),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(30.0),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.school, size: 80, color: Color(0xff1a237e)),
                  const SizedBox(height: 10),
                  const Text("SISTEMA COC - UNIVO", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xff1a237e))),
                  const SizedBox(height: 25),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Correo Institucional', prefixIcon: Icon(Icons.email), border: OutlineInputBorder()),
                    validator: (value) => value!.isEmpty ? 'Ingrese su correo' : null,
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Contraseña', prefixIcon: Icon(Icons.lock), border: OutlineInputBorder()),
                    validator: (value) => value!.isEmpty ? 'Ingrese su contraseña' : null,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _forgotPassword,
                      child: const Text("¿Olvidó su contraseña?", style: TextStyle(color: Color(0xff1a237e), decoration: TextDecoration.underline)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: _handleLogin,
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff1a237e), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            child: const Text("Iniciar Sesión", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
