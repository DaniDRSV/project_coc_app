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
  final Color primaryBlue = const Color(0xff1a237e);

  @override
  void dispose() {
    _newPassCtrl.dispose();
    _oldPassCtrl.dispose();
    _newEmailCtrl.dispose();
    super.dispose();
  }

  void _showMsg(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(15),
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
    if (_oldPassCtrl.text.isEmpty) {
      _showMsg("Debe ingresar su contraseña actual", Colors.orange);
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _updateEmail() async {
    if (!_newEmailCtrl.text.contains("@")) {
      _showMsg("Ingrese un correo válido", Colors.orange);
      return;
    }
    setState(() => _isLoading = true);
    try {
      // Firebase requiere reautenticación para cambios sensibles
      _showMsg("Por favor, asegúrese de haber iniciado sesión recientemente", Colors.blue);
      await _auth.currentUser!.verifyBeforeUpdateEmail(_newEmailCtrl.text.trim());
      await FirebaseFirestore.instance.collection('usuarios').doc(_auth.currentUser!.uid).update({
        'correo': _newEmailCtrl.text.trim(),
      });
      _showMsg("Se ha enviado un correo de verificación a la nueva dirección.", Colors.blue);
      _newEmailCtrl.clear();
    } catch (e) {
      _showMsg("Error al actualizar correo: $e", Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Configuración de Perfil", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('usuarios').doc(user?.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          var userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          String nombre = userData['nombre'] ?? 'Usuario';
          String sede = userData['sede'] ?? 'Sin sede';
          String rol = userData['rol'] ?? 'operador';

          return Stack(
            children: [
              SingleChildScrollView(
                child: Column(
                  children: [
                    _buildHeader(nombre, user?.email ?? '', sede, rol),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _buildSectionCard(
                            title: "Información de la Cuenta",
                            icon: Icons.alternate_email,
                            children: [
                              const Text("Actualizar correo institucional:", style: TextStyle(fontSize: 13, color: Colors.grey)),
                              const SizedBox(height: 15),
                              _buildTextField(_newEmailCtrl, "Nuevo Correo", Icons.email_outlined),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade700,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 2,
                                  ),
                                  onPressed: _updateEmail, 
                                  child: const Text("ACTUALIZAR CORREO", style: TextStyle(fontWeight: FontWeight.bold))
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 25),
                          _buildSectionCard(
                            title: "Seguridad y Contraseña",
                            icon: Icons.lock_outline,
                            children: [
                              const Text("Cambiar contraseña de acceso:", style: TextStyle(fontSize: 13, color: Colors.grey)),
                              const SizedBox(height: 15),
                              _buildTextField(_oldPassCtrl, "Contraseña Actual", Icons.key, isPassword: true),
                              const SizedBox(height: 15),
                              _buildTextField(_newPassCtrl, "Nueva Contraseña", Icons.lock_reset, isPassword: true),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryBlue,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 2,
                                  ),
                                  onPressed: _updatePassword, 
                                  child: const Text("CAMBIAR CONTRASEÑA", style: TextStyle(fontWeight: FontWeight.bold))
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 40),
                          const Text(
                            "Sistema COC UNIVO v1.0.0",
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_isLoading)
                Container(
                  color: Colors.black26,
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(String nombre, String email, String sede, String rol) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 35, left: 20, right: 20),
      decoration: BoxDecoration(
        color: primaryBlue,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(35),
          bottomRight: Radius.circular(35),
        ),
      ),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 50,
            backgroundColor: Colors.white24,
            child: Icon(Icons.person, size: 60, color: Colors.white),
          ),
          const SizedBox(height: 15),
          Text(
            nombre,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          Text(
            email,
            style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.7)),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            alignment: WrapAlignment.center,
            children: [
              _buildBadge(Icons.business, sede),
              _buildBadge(Icons.admin_panel_settings, rol.toUpperCase()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required List<Widget> children}) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: primaryBlue, size: 24),
                const SizedBox(width: 12),
                Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: primaryBlue)),
              ],
            ),
            const Divider(height: 30, thickness: 1),
            ...children
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {bool isPassword = false}) {
    return TextField(
      controller: ctrl,
      obscureText: isPassword,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 22, color: primaryBlue),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: primaryBlue, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }
}
