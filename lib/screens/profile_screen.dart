import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _newPassCtrl = TextEditingController();
  final _oldPassCtrl = TextEditingController();
  final _newEmailCtrl = TextEditingController();
  bool _isLoading = false;

  void _showMsg(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _reauthenticate(String password) async {
    User? user = _auth.currentUser;
    AuthCredential credential = EmailAuthProvider.credential(email: user!.email!, password: password);
    await user.reauthenticateWithCredential(credential);
  }

  void _updatePassword() async {
    if (_newPassCtrl.text.length < 6) {
      _showMsg("La contraseña debe tener al menos 6 caracteres", Colors.orange);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _reauthenticate(_oldPassCtrl.text);
      await _auth.currentUser!.updatePassword(_newPassCtrl.text);
      _showMsg("Contraseña actualizada con éxito", Colors.green);
      _newPassCtrl.clear();
      _oldPassCtrl.clear();
    } catch (e) {
      _showMsg("Error: Verifique su contraseña actual", Colors.redAccent);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _updateEmail() async {
    if (!_newEmailCtrl.text.contains("@")) {
      _showMsg("Ingrese un correo válido", Colors.orange);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _auth.currentUser!.verifyBeforeUpdateEmail(_newEmailCtrl.text.trim());
      await FirebaseFirestore.instance.collection('usuarios').doc(_auth.currentUser!.uid).update({
        'correo': _newEmailCtrl.text.trim(),
      });
      _showMsg("Se ha enviado un correo de verificación a la nueva dirección.", Colors.blue);
    } catch (e) {
      _showMsg("Error al actualizar correo: $e", Colors.redAccent);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mi Perfil"),
        backgroundColor: const Color(0xff1a237e),
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(25),
            child: Column(
              children: [
                _buildSection("Actualizar Correo", [
                  TextField(controller: _newEmailCtrl, decoration: const InputDecoration(labelText: "Nuevo Correo Institucional", prefixIcon: Icon(Icons.email))),
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(onPressed: _updateEmail, child: const Text("CAMBIAR CORREO")),
                  ),
                ]),
                const SizedBox(height: 30),
                _buildSection("Cambiar Contraseña", [
                  TextField(controller: _oldPassCtrl, decoration: const InputDecoration(labelText: "Contraseña Actual"), obscureText: true),
                  const SizedBox(height: 10),
                  TextField(controller: _newPassCtrl, decoration: const InputDecoration(labelText: "Nueva Contraseña"), obscureText: true),
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff1a237e), foregroundColor: Colors.white),
                      onPressed: _updatePassword, 
                      child: const Text("ACTUALIZAR CONTRASEÑA")
                    ),
                  ),
                ]),
              ],
            ),
          ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xff1a237e))),
            const Divider(),
            const SizedBox(height: 10),
            ...children
          ],
        ),
      ),
    );
  }
}
