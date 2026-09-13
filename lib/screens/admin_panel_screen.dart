import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Color primaryBlue = const Color(0xff1a237e);
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _currentTabIndex = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff8f9fa),
      appBar: AppBar(
        title: const Text("Panel Administrativo", 
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, letterSpacing: 0.5)),
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // CABECERA MODERNA CON TABBAR CENTRADO
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: primaryBlue,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(35),
                bottomRight: Radius.circular(35),
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))
              ],
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.amber,
              indicatorWeight: 4,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withOpacity(0.5),
              isScrollable: true,
              tabAlignment: TabAlignment.center, // ESTO CENTRA LOS ICONOS
              padding: const EdgeInsets.only(bottom: 15, top: 5),
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              tabs: const [
                Tab(icon: Icon(Icons.people_outline_rounded, size: 24), text: "Usuarios"),
                Tab(icon: Icon(Icons.location_city_rounded, size: 24), text: "Sedes"),
                Tab(icon: Icon(Icons.gpp_good_rounded, size: 24), text: "Permisos"),
                Tab(icon: Icon(Icons.auto_stories_rounded, size: 24), text: "Carreras"),
                Tab(icon: Icon(Icons.event_note_rounded, size: 24), text: "Ciclos"),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                const _UsersTab(),
                const _SedesTab(),
                const _PermissionsTab(),
                const _CareersTab(),
                const _CyclesTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget? _buildFab() {
    switch (_currentTabIndex) {
      case 0:
        return FloatingActionButton.extended(
          heroTag: "fab_user",
          onPressed: () => _AdminHelper.showUserDialog(context, null, null, false),
          backgroundColor: primaryBlue,
          icon: const Icon(Icons.person_add_rounded, color: Colors.white),
          label: const Text("NUEVO USUARIO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        );
      case 1:
        return FloatingActionButton.extended(
          heroTag: "fab_sede",
          onPressed: () => _AdminHelper.showSimpleAddDialog(context, "Sede", "sedes"),
          backgroundColor: primaryBlue,
          icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white),
          label: const Text("NUEVA SEDE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        );
      case 3:
        return FloatingActionButton.extended(
          heroTag: "fab_carrera",
          onPressed: () => _AdminHelper.showSimpleAddDialog(context, "Carrera", "carreras"),
          backgroundColor: primaryBlue,
          icon: const Icon(Icons.add_chart_rounded, color: Colors.white),
          label: const Text("NUEVA CARRERA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        );
      case 4:
        return FloatingActionButton.extended(
          heroTag: "fab_ciclo",
          onPressed: () => _AdminHelper.showAddCycleDialog(context),
          backgroundColor: primaryBlue,
          label: const Text("NUEVO CICLO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        );
      default:
        return null;
    }
  }
}

// --- PESTAÑA: USUARIOS ---
class _UsersTab extends StatefulWidget {
  const _UsersTab();
  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  String _searchFilter = "";
  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    return Column(
      children: [
        _AdminHelper.buildSearchBar((v) => setState(() => _searchFilter = v)),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('usuarios').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              var docs = snapshot.data!.docs;
              if (_searchFilter.isNotEmpty) {
                docs = docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  return data['nombre'].toString().toLowerCase().contains(_searchFilter.toLowerCase()) ||
                         data['correo'].toString().toLowerCase().contains(_searchFilter.toLowerCase());
                }).toList();
              }
              if (docs.isEmpty) return _AdminHelper.buildEmptyState(Icons.person_search_rounded, "No hay usuarios matching");

              return ListView.builder(
                itemCount: docs.length,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemBuilder: (context, index) {
                  var doc = docs[index];
                  Map<String, dynamic> user = doc.data() as Map<String, dynamic>;
                  bool isSelf = doc.id == currentUid;
                  bool isAdmin = user['rol'] == 'admin';

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey[200]!)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: CircleAvatar(
                        radius: 26,
                        backgroundColor: isAdmin ? const Color(0xff1a237e) : Colors.blueGrey[50],
                        child: Text((user['nombre'] ?? "U")[0].toUpperCase(), style: TextStyle(color: isAdmin ? Colors.white : const Color(0xff1a237e), fontWeight: FontWeight.bold)),
                      ),
                      title: Text(user['nombre'] ?? "Usuario", style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("${user['correo']}\nSEDE: ${user['sede'] ?? 'S/S'} • ${user['rol']?.toUpperCase()}", 
                        style: TextStyle(fontSize: 12, height: 1.4, color: Colors.grey[600])),
                      isThreeLine: true,
                      trailing: IconButton(
                        icon: const Icon(Icons.settings_suggest_rounded, color: Color(0xff1a237e)), 
                        onPressed: () => _AdminHelper.showUserDialog(context, doc.id, user, isSelf)
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// --- PESTAÑA: SEDES ---
class _SedesTab extends StatelessWidget {
  const _SedesTab();
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('sedes').orderBy('nombre').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var docs = snapshot.data!.docs;
        if (docs.isEmpty) return _AdminHelper.buildEmptyState(Icons.add_location_alt_rounded, "No hay sedes");

        return GridView.builder(
          padding: const EdgeInsets.all(20),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.1, crossAxisSpacing: 16, mainAxisSpacing: 16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var doc = docs[index];
            return Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey[200]!)),
              child: InkWell(
                onLongPress: () => _AdminHelper.confirmDelete(context, doc, "sede"),
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xff1a237e).withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.business_rounded, color: Color(0xff1a237e), size: 30),
                    ),
                    const SizedBox(height: 12),
                    Text(doc['nombre'], textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// --- PESTAÑA: PERMISOS ---
class _PermissionsTab extends StatelessWidget {
  const _PermissionsTab();
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('configuracion').doc('permisos').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _AdminHelper.buildPermissionGroup("ACCESO A MÓDULOS", [
              _AdminHelper.pSwitch("Habilitar Emisión", "perm_mod_emision", data),
              _AdminHelper.pSwitch("Habilitar Inventario", "perm_mod_inventario", data),
              _AdminHelper.pSwitch("Habilitar Reportes", "perm_mod_reportes", data),
            ]),
            const SizedBox(height: 16),
            _AdminHelper.buildPermissionGroup("EXPORTACIÓN Y STOCK", [
              _AdminHelper.pSwitch("Permitir Excel", "perm_act_excel", data),
              _AdminHelper.pSwitch("Permitir PDF", "perm_act_pdf", data),
              _AdminHelper.pSwitch("Ajustar Inventario", "perm_act_inv_editar", data),
            ]),
          ],
        );
      },
    );
  }
}

// --- PESTAÑA: CARRERAS ---
class _CareersTab extends StatelessWidget {
  const _CareersTab();
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('carreras').orderBy('nombre').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var docs = snapshot.data!.docs;
        if (docs.isEmpty) return _AdminHelper.buildEmptyState(Icons.school_outlined, "No hay carreras");
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var doc = docs[index];
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey[200]!)),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.indigo.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.book_rounded, color: Colors.indigo, size: 20),
                ),
                title: Text(doc['nombre'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                trailing: IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent), onPressed: () => _AdminHelper.confirmDelete(context, doc, "carrera")),
              ),
            );
          },
        );
      },
    );
  }
}

// --- PESTAÑA: CICLOS ---
class _CyclesTab extends StatelessWidget {
  const _CyclesTab();
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('ciclos').orderBy('fechaInicio', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var docs = snapshot.data!.docs;
        if (docs.isEmpty) return _AdminHelper.buildEmptyState(Icons.calendar_today_rounded, "No hay ciclos registrados");
        return ListView.builder(
          itemCount: docs.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            var doc = docs[index];
            var data = doc.data() as Map<String, dynamic>;
            bool isActivo = data['activo'] ?? false;
            String fInicio = DateFormat('dd/MM/yy').format((data['fechaInicio'] as Timestamp).toDate());
            String fFin = DateFormat('dd/MM/yy').format((data['fechaFin'] as Timestamp).toDate());

            return Card(
              elevation: isActivo ? 2 : 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isActivo ? Colors.green : Colors.grey[200]!)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isActivo ? Colors.green[50] : Colors.grey[50], 
                  child: Icon(Icons.event_repeat_rounded, color: isActivo ? Colors.green : Colors.grey)
                ),
                title: Text(data['nombre'], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Vigencia: $fInicio - $fFin", style: const TextStyle(fontSize: 12)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isActivo) TextButton(onPressed: () => _AdminHelper.activarCiclo(doc.id, docs), child: const Text("ACTIVAR", style: TextStyle(fontWeight: FontWeight.bold))),
                    IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent), onPressed: () => _AdminHelper.confirmDelete(context, doc, "ciclo")),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// --- CLASE AUXILIAR DE LÓGICA Y UI ---
class _AdminHelper {
  static Widget buildSearchBar(Function(String) onChanged) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: "Buscar por nombre o correo...",
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          filled: true,
          fillColor: const Color(0xfff1f3f8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  static Widget buildEmptyState(IconData icon, String msg) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 70, color: Colors.grey[200]), const SizedBox(height: 15), Text(msg, style: TextStyle(color: Colors.grey[400], fontSize: 16))]));
  }

  static Widget buildPermissionGroup(String title, List<Widget> children) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey[200]!)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xff1a237e), fontSize: 12, letterSpacing: 1))),
        const Divider(height: 1),
        ...children,
      ]),
    );
  }

  static Widget pSwitch(String label, String key, Map<String, dynamic> data) {
    return SwitchListTile(
      title: Text(label, style: const TextStyle(fontSize: 14)),
      value: data[key] ?? true,
      activeColor: const Color(0xff1a237e),
      onChanged: (nv) => FirebaseFirestore.instance.collection('configuracion').doc('permisos').set({key: nv}, SetOptions(merge: true)),
    );
  }

  static void showSimpleAddDialog(BuildContext context, String title, String coll) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Añadir $title"),
        content: TextField(controller: ctrl, decoration: InputDecoration(labelText: "Nombre del registro", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff1a237e), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () { if (ctrl.text.isNotEmpty) { FirebaseFirestore.instance.collection(coll).add({'nombre': ctrl.text.trim()}); Navigator.pop(context); } }, 
            child: const Text("GUARDAR")
          ),
        ],
      ),
    );
  }

  static void confirmDelete(BuildContext context, DocumentSnapshot doc, String type) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¿Eliminar?"),
        content: Text("Se borrará este registro de $type permanentemente."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
          TextButton(onPressed: () { doc.reference.delete(); Navigator.pop(context); }, child: const Text("ELIMINAR", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  static void activarCiclo(String targetId, List<DocumentSnapshot> allDocs) async {
    var batch = FirebaseFirestore.instance.batch();
    for (var doc in allDocs) { batch.update(doc.reference, {'activo': doc.id == targetId}); }
    await batch.commit();
  }

  static void showAddCycleDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    DateTime? s, e;
    showDialog(context: context, builder: (context) => StatefulBuilder(builder: (context, setS) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text("Nuevo Ciclo Escolar"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Nombre del Ciclo (Ej: Ciclo 01-2027)")),
        ListTile(title: Text(s == null ? "Fecha Inicio" : DateFormat('dd/MM/yyyy').format(s!)), leading: const Icon(Icons.calendar_today_rounded), onTap: () async { var r = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2024), lastDate: DateTime(2035)); if (r != null) setS(() => s = r); }),
        ListTile(title: Text(e == null ? "Fecha Fin" : DateFormat('dd/MM/yyyy').format(e!)), leading: const Icon(Icons.calendar_today_rounded), onTap: () async { var r = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 30)), firstDate: DateTime(2024), lastDate: DateTime(2035)); if (r != null) setS(() => e = r); }),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff1a237e), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: () { if (nameCtrl.text.isNotEmpty && s != null && e != null) { FirebaseFirestore.instance.collection('ciclos').add({'nombre': nameCtrl.text.trim(), 'fechaInicio': Timestamp.fromDate(s!), 'fechaFin': Timestamp.fromDate(e!), 'activo': false}); Navigator.pop(context); } }, 
          child: const Text("CREAR")
        ),
      ],
    )));
  }

  static void showUserDialog(BuildContext context, String? uid, Map<String, dynamic>? user, bool isSelf) {
    final name = TextEditingController(text: user?['nombre'] ?? '');
    final email = TextEditingController(text: user?['correo'] ?? '');
    final pass = TextEditingController();
    String role = user?['rol'] ?? 'operador';
    String? sede = user?['sede'];

    showDialog(context: context, builder: (context) => StatefulBuilder(builder: (context, setS) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(uid == null ? "Nuevo Usuario" : "Configurar Usuario"),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: "Nombre Completo")),
        if (uid == null) TextField(controller: email, decoration: const InputDecoration(labelText: "Correo Institucional")),
        if (uid == null) TextField(controller: pass, decoration: const InputDecoration(labelText: "Contraseña"), obscureText: true),
        DropdownButtonFormField<String>(value: role, decoration: const InputDecoration(labelText: "Rol"), items: const [DropdownMenuItem(value: 'admin', child: Text("Administrador")), DropdownMenuItem(value: 'operador', child: Text("Operador"))], onChanged: isSelf ? null : (v) => setS(() => role = v!)),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('sedes').snapshots(), builder: (context, snap) {
          if (!snap.hasData) return const LinearProgressIndicator();
          return DropdownButtonFormField<String>(value: sede, decoration: const InputDecoration(labelText: "Sede"), items: snap.data!.docs.map((s) => DropdownMenuItem(value: s['nombre'].toString(), child: Text(s['nombre']))).toList(), onChanged: (v) => setS(() => sede = v));
        }),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff1a237e), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: () async {
            if (uid == null) {
              FirebaseApp app = await Firebase.initializeApp(name: 'TempApp', options: Firebase.app().options);
              UserCredential cred = await FirebaseAuth.instanceFor(app: app).createUserWithEmailAndPassword(email: email.text.trim(), password: pass.text.trim());
              await FirebaseFirestore.instance.collection('usuarios').doc(cred.user!.uid).set({'nombre': name.text.trim(), 'correo': email.text.trim(), 'rol': role, 'sede': sede, 'estado': 'activo'});
              await app.delete();
            } else {
              await FirebaseFirestore.instance.collection('usuarios').doc(uid).update({'nombre': name.text.trim(), 'rol': role, 'sede': sede});
            }
            if (context.mounted) Navigator.pop(context);
          }, 
          child: const Text("GUARDAR")
        ),
      ],
    )));
  }
}