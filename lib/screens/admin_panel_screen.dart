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
    _tabController = TabController(length: 3, vsync: this);
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
          labelPadding: EdgeInsets.zero,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: "Usuarios"),
            Tab(icon: Icon(Icons.business), text: "Sedes"),
            Tab(icon: Icon(Icons.school), text: "Carreras"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const _UsersTab(),
          const _SedesTab(),
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
                      const PopupMenuItem(value: 'editar', child: Row(children: [Icon(Icons.edit, color: Colors.blue, size: 20), SizedBox(width: 10), Text("Editar Perfil & Permisos")])),
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

    Map<String, dynamic> perms = user?['permisos'] ?? {
      'mod_emision': true,
      'mod_inventario': true,
      'mod_reportes': true,
      'act_inv_crear': true,
      'act_inv_editar': true,
      'act_emi_error': true,
      'act_excel': true,
      'act_pdf': true,
    };

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(uid == null ? "Registrar Usuario" : "Editar Usuario", style: const TextStyle(color: Color(0xff1a237e), fontWeight: FontWeight.bold)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextFormField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Nombre Completo", prefixIcon: Icon(Icons.person))),
                const SizedBox(height: 10),
                if (uid == null) TextFormField(controller: emailCtrl, decoration: const InputDecoration(labelText: "Correo Institucional", prefixIcon: Icon(Icons.email))),
                if (uid != null) TextFormField(controller: emailCtrl, enabled: false, decoration: const InputDecoration(labelText: "Correo Institucional (No editable)", prefixIcon: Icon(Icons.email))),
                if (uid == null) TextFormField(controller: passCtrl, decoration: const InputDecoration(labelText: "Contraseña", prefixIcon: Icon(Icons.lock)), obscureText: true),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: "Rol", prefixIcon: Icon(Icons.admin_panel_settings)),
                  items: const [DropdownMenuItem(value: 'admin', child: Text("Administrador")), DropdownMenuItem(value: 'operador', child: Text("Operador"))],
                  onChanged: isSelf ? null : (v) => setState(() => selectedRole = v!),
                ),
                const SizedBox(height: 10),
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

                if (selectedRole == 'operador' && !isSelf) ...[
                  const Padding(
                    padding: EdgeInsets.only(top: 25, bottom: 5),
                    child: Center(child: Text("PERMISOS DEL OPERADOR", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.indigo))),
                  ),
                  const Divider(),
                  const Text("ACCESO A MÓDULOS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text("Módulo Emisión", style: TextStyle(fontSize: 13)), value: perms['mod_emision'] ?? true, onChanged: (v) => setState(() => perms['mod_emision'] = v)),
                  SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text("Módulo Inventario", style: TextStyle(fontSize: 13)), value: perms['mod_inventario'] ?? true, onChanged: (v) => setState(() => perms['mod_inventario'] = v)),
                  SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text("Módulo Reportes", style: TextStyle(fontSize: 13)), value: perms['mod_reportes'] ?? true, onChanged: (v) => setState(() => perms['mod_reportes'] = v)),

                  const SizedBox(height: 10),
                  const Text("GESTIÓN DE INVENTARIO", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text("Agregar Nuevos Materiales", style: TextStyle(fontSize: 13)), value: perms['act_inv_crear'] ?? true, onChanged: (v) => setState(() => perms['act_inv_crear'] = v)),
                  SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text("Modificar Stock Existente", style: TextStyle(fontSize: 13)), value: perms['act_inv_editar'] ?? true, onChanged: (v) => setState(() => perms['act_inv_editar'] = v)),

                  const SizedBox(height: 10),
                  const Text("AUDITORÍA Y REPORTES", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text("Reportar Errores de Impresión", style: TextStyle(fontSize: 13)), value: perms['act_emi_error'] ?? true, onChanged: (v) => setState(() => perms['act_emi_error'] = v)),
                  SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text("Generar Reportes en EXCEL", style: TextStyle(fontSize: 13)), value: perms['act_excel'] ?? true, onChanged: (v) => setState(() => perms['act_excel'] = v)),
                  SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text("Generar Reportes en PDF", style: TextStyle(fontSize: 13)), value: perms['act_pdf'] ?? true, onChanged: (v) => setState(() => perms['act_pdf'] = v)),
                ]
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
                      await FirebaseFirestore.instance.collection('usuarios').doc(cred.user!.uid).set({
                        'nombre': nameCtrl.text.trim(),
                        'correo': emailCtrl.text.trim(),
                        'rol': selectedRole,
                        'sede': selectedSede,
                        'estado': 'activo',
                        'permisos': perms
                      });
                      await app.delete();
                    } else {
                      await FirebaseFirestore.instance.collection('usuarios').doc(uid).update({
                        'nombre': nameCtrl.text.trim(),
                        'rol': selectedRole,
                        'sede': selectedSede,
                        'permisos': perms
                      });
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