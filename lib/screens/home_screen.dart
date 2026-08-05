import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'student_module_screen.dart';
import 'inventory_screen.dart';
import 'reports_screen.dart';
import 'admin_panel_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatelessWidget {
  final String? rol;
  final AuthService _authService = AuthService();

  HomeScreen({super.key, this.rol});

  void _logout(BuildContext context) async {
    await _authService.signOut();
    if (context.mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    DateTime now = DateTime.now();
    DateTime startOfDay = DateTime(now.year, now.month, now.day);

    return StreamBuilder<DocumentSnapshot>(
      // Este es el ÚNICO StreamBuilder que necesitamos ahora
        stream: FirebaseFirestore.instance.collection('usuarios').doc(user?.uid).snapshots(),
        builder: (context, snapshotUser) {
          if (!snapshotUser.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));

          var userData = snapshotUser.data?.data() as Map<String, dynamic>? ?? {};
          String userRole = userData['rol'] ?? 'operador';
          String nombre = userData['nombre'] ?? 'Usuario';
          String sedeUsuario = userData['sede'] ?? 'Sin sede';

          // AQUÍ extraemos los permisos individuales del usuario
          Map<String, dynamic> permisosPersonales = userData['permisos'] ?? {};

          return Scaffold(
            appBar: AppBar(
              title: const Text("SISTEMA COC - UNIVO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              backgroundColor: const Color(0xff1a237e),
              actions: [
                IconButton(
                  icon: const Icon(Icons.account_circle, color: Colors.white),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())),
                  tooltip: "Mi Perfil",
                ),
                IconButton(icon: const Icon(Icons.logout, color: Colors.white), onPressed: () => _logout(context))
              ],
            ),
            body: Column(
              children: [
                _buildHeader(userRole, nombre, sedeUsuario),
                _buildStatsSection(user?.uid, startOfDay, sedeUsuario),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: MediaQuery.of(context).size.width > 800 ? 3 : 2,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    mainAxisSpacing: 15,
                    crossAxisSpacing: 15,
                    // Le pasamos los permisos individuales extraídos arriba
                    children: _buildMenuItems(context, userRole, permisosPersonales, sedeUsuario),
                  ),
                ),
              ],
            ),
          );
        }
    );
  }

  Widget _buildHeader(String rol, String nombre, String sede) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: const BoxDecoration(
          color: Color(0xff1a237e),
          borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30))
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Bienvenido, $nombre", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text("Sede: $sede | Rol: ${rol.toUpperCase()}", style: const TextStyle(color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildStatsSection(String? uid, DateTime startOfDay, String sedeUsuario) {
    return Padding(
      padding: const EdgeInsets.all(15.0),
      child: Column(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('emisiones_log').where('fechaRegistro', isGreaterThanOrEqualTo: startOfDay).snapshots(),
            builder: (context, snapshot) {
              var docs = snapshot.data?.docs ?? [];
              int totalHoy = docs.length;
              int sedeHoy = docs.where((d) {
                try {
                  return (d.data() as Map<String, dynamic>)['sede'] == sedeUsuario;
                } catch (e) {
                  return false;
                }
              }).length;
              return _counterCard(
                "Emisiones de Hoy",
                totalHoy.toString(),
                Colors.orange,
                "Emitidos en $sedeUsuario: $sedeHoy",
                fullWidth: true,
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('emisiones_log').where('atendidoPorUid', isEqualTo: uid).snapshots(),
                  builder: (context, snapshot) {
                    int count = snapshot.data?.docs.length ?? 0;
                    return _counterCard("Mis Emisiones", count.toString(), Colors.blue, "Total Personal");
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('emisiones_log').snapshots(),
                  builder: (context, snapshot) {
                    int count = snapshot.data?.docs.length ?? 0;
                    return _counterCard("Total UNIVO", count.toString(), Colors.indigo, "Todas las Sedes");
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _counterCard(String title, String value, Color color, String? subtext, {bool fullWidth = false}) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        border: Border(top: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 5),
          Text(value, style: TextStyle(fontSize: fullWidth ? 30 : 22, fontWeight: FontWeight.bold, color: color)),
          if (subtext != null) ...[
            const SizedBox(height: 5),
            Text(subtext, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          ]
        ],
      ),
    );
  }

  List<Widget> _buildMenuItems(BuildContext context, String rol, Map<String, dynamic> permisosPersonales, String sede) {
    List<Widget> items = [];

    if (rol == 'admin' || (permisosPersonales['mod_emision'] ?? true)) {
      items.add(_menuCard(context, Icons.badge, "Emisión", "Registro de Carnet", Colors.indigo, () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => StudentModuleScreen(rol: rol, sede: sede)));
      }));
    }
    if (rol == 'admin' || (permisosPersonales['mod_inventario'] ?? true)) {
      items.add(_menuCard(context, Icons.inventory_2, "Inventario", "Suministros", Colors.orange, () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => InventoryScreen(rol: rol)));
      }));
    }
    if (rol == 'admin' || (permisosPersonales['mod_reportes'] ?? true)) {
      items.add(_menuCard(context, Icons.analytics, "Reportes", "Auditoría", Colors.teal, () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const ReportsScreen()));
      }));
    }
    if (rol == 'admin') {
      items.add(_menuCard(context, Icons.admin_panel_settings, "Administración", "Control Total", Colors.red, () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminPanelScreen()));
      }));
    }
    return items;
  }

  Widget _menuCard(BuildContext context, IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 35, color: color),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}