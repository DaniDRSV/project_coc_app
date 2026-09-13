import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class UserAdminScreen extends StatefulWidget {
  const UserAdminScreen({super.key});

  @override
  State<UserAdminScreen> createState() => _UserAdminScreenState();
}

class _UserAdminScreenState extends State<UserAdminScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final _nameController = TextEditingController();
  String _rolSeleccionado = 'operador';
  String? _sedeSeleccionada;
  bool _isCreating = false;

  final Color primaryColor = const Color(0xff1a237e);

  @override
  void dispose() {
    _emailController.dispose();
    _passController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // Función avanzada para crear usuario sin cerrar la sesión del admin
  Future<void> _registrarUsuario() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isCreating = true);
      
      try {
        // 1. Creamos una instancia secundaria de Firebase para registrar al nuevo usuario
        // Esto evita que el Admin actual sea desconectado
        FirebaseApp secondaryApp = await Firebase.initializeApp(
          name: 'SecondaryApp',
          options: Firebase.app().options,
        );

        UserCredential userCredential = await FirebaseAuth.instanceFor(app: secondaryApp)
            .createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passController.text.trim(),
        );

        // 2. Guardamos el perfil en Firestore usando el UID generado, incluyendo sede y estado
        await FirebaseFirestore.instance.collection('usuarios').doc(userCredential.user!.uid).set({
          'nombre': _nameController.text.trim(),
          'correo': _emailController.text.trim(),
          'rol': _rolSeleccionado,
          'sede': _sedeSeleccionada ?? 'Sin sede',
          'fechaCreacion': FieldValue.serverTimestamp(),
          'estado': 'activo',
        });

        // 3. Cerramos la app secundaria
        await secondaryApp.delete();

        _emailController.clear();
        _passController.clear();
        _nameController.clear();

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Usuario creado con éxito"), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error al crear usuario: $e"), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isCreating = false);
      }
    }
  }

  void _showAddUserDialog() {
    _emailController.clear();
    _passController.clear();
    _nameController.clear();
    _rolSeleccionado = 'operador';
    _sedeSeleccionada = null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder( // Para manejar correctamente el estado de los Dropdowns dentro del diálogo
        builder: (context, setDialogState) => AlertDialog(
          title: Text("Registrar Nuevo Usuario", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: "Nombre Completo", 
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => v!.isEmpty ? "Campo requerido" : null,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: "Correo Institucional", 
                      prefixIcon: const Icon(Icons.email),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => v!.isEmpty ? "Campo requerido" : null,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _passController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: "Contraseña Inicial", 
                      prefixIcon: const Icon(Icons.lock),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => v!.length < 6 ? "Mínimo 6 caracteres" : null,
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    value: _rolSeleccionado,
                    decoration: InputDecoration(
                      labelText: "Asignar Rol",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'admin', child: Text("Administrador")),
                      DropdownMenuItem(value: 'operador', child: Text("Operador")),
                    ],
                    onChanged: (v) {
                      setDialogState(() {
                        _rolSeleccionado = v!;
                      });
                    },
                  ),
                  const SizedBox(height: 15),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('sedes').orderBy('nombre').snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData) return const LinearProgressIndicator();
                      return DropdownButtonFormField<String>(
                        value: _sedeSeleccionada,
                        decoration: InputDecoration(
                          labelText: "Sede de Trabajo",
                          prefixIcon: const Icon(Icons.business),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: snap.data!.docs.map((s) => DropdownMenuItem(value: s['nombre'].toString(), child: Text(s['nombre']))).toList(),
                        onChanged: (v) {
                          setDialogState(() {
                            _sedeSeleccionada = v;
                          });
                        },
                        validator: (v) => v == null ? "Seleccione una sede" : null,
                      );
                    }
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
            _isCreating 
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: CircularProgressIndicator(),
                )
              : ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _registrarUsuario, 
                  child: const Text("Registrar"),
                ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Gestión de Usuarios", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('usuarios').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              Map<String, dynamic> user = doc.data() as Map<String, dynamic>;
              bool isSelf = doc.id == currentUid;

              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: user['rol'] == 'admin' ? const Color(0xff1a237e) : Colors.blueGrey,
                      child: Text(
                        (user['nombre'] ?? 'U')[0].toUpperCase(), 
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                      ),
                    ),
                    title: Text(user['nombre'] ?? 'Sin nombre', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        "${user['correo']}\nSEDE: ${user['sede'] ?? 'Sin sede'} • ${user['rol'].toString().toUpperCase()}",
                        style: TextStyle(color: Colors.grey[600], height: 1.3),
                      ),
                    ),
                    isThreeLine: true,
                    trailing: isSelf || user['rol'] == 'admin' ? null : IconButton(
                      icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent, size: 28),
                      onPressed: () => _confirmDelete(doc),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddUserDialog,
        backgroundColor: primaryColor,
        icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
        label: const Text("Nuevo Usuario", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _confirmDelete(DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Eliminar Usuario"),
        content: Text("¿Está seguro de eliminar a ${doc['nombre']}? Esto quitará su perfil del sistema."),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              doc.reference.delete();
              Navigator.pop(context);
            }, 
            child: const Text("Eliminar")
          ),
        ],
      ),
    );
  }
}