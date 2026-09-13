import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
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
        stream: FirebaseFirestore.instance.collection('usuarios').doc(user?.uid).snapshots(),
        builder: (context, snapshotUser) {
          if (!snapshotUser.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));

          var userData = snapshotUser.data?.data() as Map<String, dynamic>? ?? {};
          String userRole = userData['rol'] ?? 'operador';
          String nombre = userData['nombre'] ?? 'Usuario';
          String sedeUsuario = userData['sede'] ?? 'Sin sede';

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('configuracion').doc('permisos').snapshots(),
            builder: (context, snapshotPermisos) {
              if (!snapshotPermisos.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
              var permisosGlobales = snapshotPermisos.data?.data() as Map<String, dynamic>? ?? {};

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('ciclos').where('activo', isEqualTo: true).limit(1).snapshots(),
                builder: (context, snapshotCiclo) {
                  String cicloActivo = "Buscando ciclo...";
                  if (snapshotCiclo.hasData && snapshotCiclo.data!.docs.isNotEmpty) {
                    cicloActivo = snapshotCiclo.data!.docs.first.get('nombre') ?? "Sin ciclo";
                  }

                  return Scaffold(
                    backgroundColor: const Color(0xfff5f7fb),
                    appBar: AppBar(
                      title: const Text("UNIVO COC", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                      backgroundColor: const Color(0xff1a237e),
                      elevation: 0,
                      centerTitle: true,
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.account_circle_outlined, color: Colors.white, size: 28),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())),
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout_rounded, color: Colors.white),
                          onPressed: () => _logout(context),
                        )
                      ],
                    ),
                    body: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildModernHeader(userRole, nombre, sedeUsuario, cicloActivo),
                          const Padding(
                            padding: EdgeInsets.fromLTRB(20, 25, 20, 10),
                            child: Text("Panel de Control", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xff1a237e))),
                          ),
                          _buildStatsSection(user?.uid, startOfDay, sedeUsuario),
                          const Padding(
                            padding: EdgeInsets.fromLTRB(20, 25, 20, 10),
                            child: Text("Acceso Rápido", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xff1a237e))),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 15),
                            child: GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 2,
                              mainAxisSpacing: 15,
                              crossAxisSpacing: 15,
                              childAspectRatio: 1.1,
                              children: _buildMenuItems(context, userRole, permisosGlobales, sedeUsuario),
                            ),
                          ),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  );
                }
              );
            }
          );
        }
    );
  }

  Widget _buildModernHeader(String rol, String nombre, String sede, String ciclo) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xff1a237e),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
      ),
      padding: const EdgeInsets.fromLTRB(25, 10, 25, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Hola, $nombre", style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 5),
          const Text("Bienvenido de nuevo", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 25),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _infoBadge(Icons.location_on, sede, Colors.blue.shade300),
              _infoBadge(Icons.calendar_today, ciclo, Colors.orange.shade300),
              _infoBadge(Icons.admin_panel_settings, rol.toUpperCase(), Colors.teal.shade300),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildStatsSection(String? uid, DateTime startOfDay, String sedeUsuario) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
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
                } catch (e) { return false; }
              }).length;
              return _statCard(
                "Emisiones Hoy", 
                sedeHoy.toString(), 
                "Total General: $totalHoy", 
                Icons.analytics_rounded, 
                Colors.indigo,
                isFullWidth: true
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
                    return _statCard("Mis Registros", count.toString(), "Histórico", Icons.person_pin_rounded, Colors.blue);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('emisiones_log').snapshots(),
                  builder: (context, snapshot) {
                    int count = snapshot.data?.docs.length ?? 0;
                    return _statCard("Total UNIVO", count.toString(), "Global", Icons.language_rounded, Colors.deepPurple);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, String subText, IconData icon, Color color, {bool isFullWidth = false}) {
    return Container(
      width: isFullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))],
        border: Border.all(color: color.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
                Text(subText, style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          if (isFullWidth) Icon(Icons.keyboard_arrow_right_rounded, color: Colors.grey.shade300),
        ],
      ),
    );
  }

  List<Widget> _buildMenuItems(BuildContext context, String rol, Map<String, dynamic> permisosGlobales, String sede) {
    List<Widget> items = [];
    if (rol == 'admin' || (permisosGlobales['perm_mod_emision'] ?? true)) {
      items.add(_menuCard(context, Icons.badge_outlined, "Emisión", "Registro Carnet", Colors.indigo, () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => StudentModuleScreen(rol: rol, sede: sede)));
      }));
    }
    if (rol == 'admin' || (permisosGlobales['perm_mod_inventario'] ?? true)) {
      items.add(_menuCard(context, Icons.inventory_2_outlined, "Inventario", "Insumos", Colors.orange, () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => InventoryScreen(rol: rol)));
      }));
    }
    if (rol == 'admin' || (permisosGlobales['perm_mod_reportes'] ?? true)) {
      items.add(_menuCard(context, Icons.analytics_outlined, "Reportes", "Auditoría", Colors.teal, () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const ReportsScreen()));
      }));
    }
    if (rol == 'admin') {
      items.add(_menuCard(context, Icons.admin_panel_settings_outlined, "Panel", "Configuración", Colors.red, () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminPanelScreen()));
      }));
    }
    return items;
  }

  Widget _menuCard(BuildContext context, IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: color.withOpacity(0.06), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(25),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(icon, size: 30, color: color),
                ),
                const SizedBox(height: 12),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xff1a237e))),
                const SizedBox(height: 2),
                Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}