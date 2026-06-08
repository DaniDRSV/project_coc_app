import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Control Maestro COC", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xff1a237e),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 4,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelPadding: EdgeInsets.zero, // Centra las pestañas en pantallas alargadas
          tabs: const [
            Tab(icon: Icon(Icons.people), text: "Usuarios"),
            Tab(icon: Icon(Icons.business), text: "Sedes"),
            Tab(icon: Icon(Icons.security), text: "Permisos"),
            Tab(icon: Icon(Icons.school), text: "Carreras"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const _UsersTab(),
          const _SedesTab(),
          const _PermissionsTab(),
          const _CareersTab(),
        ],
      ),
    );
  }
}

class _UsersTab extends StatelessWidget {
  const _UsersTab();

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('usuarios').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            padding: const EdgeInsets.all(10),
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              Map<String, dynamic> user = doc.data() as Map<String, dynamic>;
              bool isSelf = doc.id == currentUid;
              bool isActive = (user['estado'] ?? 'activo') != 'inactivo';

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: user['rol'] == 'admin' ? Colors.indigo : Colors.blueGrey,
                    child: Text(user['nombre'][0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                  ),
                  title: Text(user['nombre'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("${user['correo']}\nSEDE: ${user['sede'] ?? 'Sin sede'} • ${user['rol'].toString().toUpperCase()}"),
                  trailing: isSelf
                      ? IconButton(
                    icon: const Icon(Icons.edit, color: Color(0xff1a237e)),
                    onPressed: () => _showUserDialog(context, doc.id, user, isSelf),
                    tooltip: "Editar mi perfil",
                  )
                      : PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Color(0xff1a237e)),
                    onSelected: (value) {
                      if (value == 'editar') {
                        _showUserDialog(context, doc.id, user, isSelf);
                      } else if (value == 'bloquear') {
                        doc.reference.update({'estado': isActive ? 'inactivo' : 'activo'});
                      } else if (value == 'eliminar') {
                        _confirmDeleteUser(context, doc.reference, user['nombre']);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'editar', child: Row(children: [Icon(Icons.edit, color: Colors.blue, size: 20), SizedBox(width: 10), Text("Editar")])),
                      PopupMenuItem(
                          value: 'bloquear',
                          child: Row(children: [
                            Icon(isActive ? Icons.block : Icons.check_circle, color: isActive ? Colors.orange : Colors.green, size: 20),
                            const SizedBox(width: 10),
                            Text(isActive ? "Bloquear Acceso" : "Permitir Acceso")
                          ])
                      ),
                      const PopupMenuItem(value: 'eliminar', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 20), SizedBox(width: 10), Text("Eliminar Registro")])),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showUserDialog(context, null, null, false),
        backgroundColor: const Color(0xff1a237e),
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text("Nuevo Usuario", style: TextStyle(color: Colors.white)),
      ),
    );
  }

  void _showUserDialog(BuildContext context, String? uid, Map<String, dynamic>? user, bool isSelf) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: user?['nombre'] ?? '');
    final emailCtrl = TextEditingController(text: user?['correo'] ?? '');
    final passCtrl = TextEditingController();
    String selectedRole = user?['rol'] ?? 'operador';
    String? selectedSede = user?['sede'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(uid == null ? "Registrar Usuario" : "Editar Usuario", style: const TextStyle(color: Color(0xff1a237e), fontWeight: FontWeight.bold)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Nombre Completo", prefixIcon: Icon(Icons.person))),
                if (uid == null) TextFormField(controller: emailCtrl, decoration: const InputDecoration(labelText: "Correo Institucional", prefixIcon: Icon(Icons.email))),
                if (uid == null) TextFormField(controller: passCtrl, decoration: const InputDecoration(labelText: "Contraseña", prefixIcon: Icon(Icons.lock)), obscureText: true),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: "Rol", prefixIcon: Icon(Icons.admin_panel_settings)),
                  items: const [DropdownMenuItem(value: 'admin', child: Text("Administrador")), DropdownMenuItem(value: 'operador', child: Text("Operador"))],
                  onChanged: isSelf ? null : (v) => setState(() => selectedRole = v!),
                ),
                StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('sedes').snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData) return const LinearProgressIndicator();
                      return DropdownButtonFormField<String>(
                        value: selectedSede,
                        decoration: const InputDecoration(labelText: "Sede de Trabajo", prefixIcon: Icon(Icons.business)),
                        items: snap.data!.docs.map((s) => DropdownMenuItem(value: s['nombre'].toString(), child: Text(s['nombre']))).toList(),
                        onChanged: (v) => setState(() => selectedSede = v),
                        validator: (v) => v == null ? "Seleccione una sede" : null,
                      );
                    }
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff1a237e), foregroundColor: Colors.white),
              icon: const Icon(Icons.save, color: Colors.white),
              label: Text(uid == null ? "REGISTRAR" : "GUARDAR", style: const TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    if (uid == null) {
                      FirebaseApp app = await Firebase.initializeApp(name: 'Temp', options: Firebase.app().options);
                      UserCredential cred = await FirebaseAuth.instanceFor(app: app).createUserWithEmailAndPassword(email: emailCtrl.text.trim(), password: passCtrl.text.trim());
                      await FirebaseFirestore.instance.collection('usuarios').doc(cred.user!.uid).set({'nombre': nameCtrl.text.trim(), 'correo': emailCtrl.text.trim(), 'rol': selectedRole, 'sede': selectedSede, 'estado': 'activo'});
                      await app.delete();
                    } else {
                      await FirebaseFirestore.instance.collection('usuarios').doc(uid).update({'nombre': nameCtrl.text.trim(), 'rol': selectedRole, 'sede': selectedSede});
                    }
                    Navigator.pop(context);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteUser(BuildContext context, DocumentReference docRef, String userName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Eliminar Usuario", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text("¿Estás seguro de que deseas eliminar permanentemente a $userName?\n\nAl eliminarlo, se revocará su acceso al sistema de forma definitiva."),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                await docRef.delete();
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text("ELIMINAR", style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );
  }
}

class _SedesTab extends StatelessWidget {
  const _SedesTab();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('sedes').orderBy('nombre').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              return ListTile(
                leading: const Icon(Icons.location_on, color: Color(0xff1a237e)),
                title: Text(doc['nombre'], style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => doc.reference.delete()),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addSede(context),
        backgroundColor: const Color(0xff1a237e),
        icon: const Icon(Icons.add_location, color: Colors.white),
        label: const Text("Nueva Sede", style: TextStyle(color: Colors.white)),
      ),
    );
  }

  void _addSede(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
            title: const Text("Nueva Sede Institucional"),
            content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: "Nombre de la Sede")),
            actions: [
              ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff1a237e), foregroundColor: Colors.white),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text("AÑADIR"),
                  onPressed: () {
                    if (ctrl.text.isNotEmpty) {
                      FirebaseFirestore.instance.collection('sedes').add({'nombre': ctrl.text.trim()});
                      Navigator.pop(context);
                    }
                  }
              )
            ]
        )
    );
  }
}

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
          padding: const EdgeInsets.all(20),
          children: [
            const Text("CONFIGURACIÓN PARA OPERADORES", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xff1a237e))),
            const Text("Define qué módulos y funciones tiene permitidos el personal operativo.", style: TextStyle(fontSize: 12, color: Colors.grey)),
            const Divider(height: 30),
            _sectionHeader("ACCESO A MÓDULOS"),
            _pSwitch("Habilitar Módulo Emisión", "perm_mod_emision", data),
            _pSwitch("Habilitar Módulo Inventario", "perm_mod_inventario", data),
            _pSwitch("Habilitar Módulo Reportes", "perm_mod_reportes", data),
            const SizedBox(height: 20),
            _sectionHeader("ACCIONES Y AUDITORÍA"),
            _pSwitch("Permitir Generar Reportes en EXCEL", "perm_act_excel", data),
            _pSwitch("Permitir Generar Reportes en PDF", "perm_act_pdf", data),
            _pSwitch("Permitir Reportar Errores de Impresión", "perm_act_emi_error", data),
            const SizedBox(height: 20),
            _sectionHeader("GESTIÓN DE INVENTARIO"),
            _pSwitch("Permitir Agregar Nuevos Materiales", "perm_act_inv_crear", data),
            _pSwitch("Permitir Editar Stock Existente", "perm_act_inv_editar", data),
          ],
        );
      },
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 5),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo)),
    );
  }

  Widget _pSwitch(String label, String key, Map<String, dynamic> data) {
    bool val = data[key] ?? true;
    return SwitchListTile(
      title: Text(label, style: const TextStyle(fontSize: 14)),
      value: val,
      activeColor: const Color(0xff1a237e),
      onChanged: (bool nv) => FirebaseFirestore.instance.collection('configuracion').doc('permisos').set({key: nv}, SetOptions(merge: true)),
    );
  }
}

class _CareersTab extends StatelessWidget {
  const _CareersTab();
  @override
  Widget build(BuildContext context) {
    final ctrl = TextEditingController();
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('carreras').orderBy('nombre').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              return ListTile(
                  leading: const Icon(Icons.school, color: Color(0xff1a237e)),
                  title: Text(doc['nombre']),
                  trailing: IconButton(icon: const Icon(Icons.delete), onPressed: () => doc.reference.delete())
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xff1a237e),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Añadir Carrera", style: TextStyle(color: Colors.white)),
        onPressed: () {
          showDialog(context: context, builder: (context) => AlertDialog(
              title: const Text("Nueva Carrera Universitaria"),
              content: TextField(controller: ctrl),
              actions: [
                ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff1a237e), foregroundColor: Colors.white),
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text("AÑADIR"),
                    onPressed: () {
                      if (ctrl.text.isNotEmpty) {
                        FirebaseFirestore.instance.collection('carreras').add({'nombre': ctrl.text.trim()});
                        Navigator.pop(context);
                      }
                    }
                )
              ]
          ));
        },
      ),
    );
  }
}