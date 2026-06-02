import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Iniciar sesión con Correo y Contraseña
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      print("Error de Firebase: ${e.message}");
      return null;
    }
  }

  // Función para cerrar sesión
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Función para enviar correo de recuperación de contraseña
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      print("Error al enviar correo de recuperación: $e");
      rethrow;
    }
  }
}
