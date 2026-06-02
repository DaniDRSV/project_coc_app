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
  bool _isCreating = false;

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

        // 2. Guardamos el perfil en Firestore usando el UID generado
        await FirebaseFirestore.instance.collection('usuarios').doc(userCredential.user!.uid).set({
          'nombre': _nameController.text.trim(),
          'correo': _emailController.text.trim(),
          'rol': _rolSeleccionado,
          'fechaCreacion': FieldValue.serverTimestamp(),
          'estado': 'activo',
        });

        // 3. Cerramos la app secundaria
        await secondaryApp.delete();

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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder( // Para manejar el estado dentro del dialog
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Registrar Nuevo Usuario"),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: "Nombre Completo", prefixIcon: Icon(Icons.person)),
                    validator: (v) => v!.isEmpty ? "Campo requerido" : null,
                  ),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: "Correo Institucional", prefixIcon: Icon(Icons.email)),
                    validator: (v) => v!.isEmpty ? "Campo requerido" : null,
                  ),
                  TextFormField(
                    controller: _passController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: "Contraseña Inicial", prefixIcon: Icon(Icons.lock)),
                    validator: (v) => v!.length < 6 ? "Mínimo 6 caracteres" : null,
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    value: _rolSeleccionado,
                    decoration: const InputDecoration(labelText: "Asignar Rol"),
                    items: const [
                      DropdownMenuItem(value: 'admin', child: Text("Administrador")),
                      DropdownMenuItem(value: 'operador', child: Text("Operador")),
                    ],
                    onChanged: (v) => setState(() => _rolSeleccionado = v!),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
            _isCreating 
              ? const CircularProgressIndicator()
              : ElevatedButton(onPressed: _registrarUsuario, child: const Text("Registrar")),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestión de Usuarios"),
        backgroundColor: const Color(0xff1a237e),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('usuarios').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            padding: const EdgeInsets.all(10),
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              return Card(
                elevation: 2,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: doc['rol'] == 'admin' ? Colors.indigo.shade100 : Colors.blue.shade100,
                    child: Icon(
                      doc['rol'] == 'admin' ? Icons.security : Icons.person,
                      color: doc['rol'] == 'admin' ? Colors.indigo : Colors.blue,
                    ),
                  ),
                  title: Text(doc['nombre']),
                  subtitle: Text("${doc['correo']}\nRol: ${doc['rol']}"),
                  isThreeLine: true,
                  trailing: doc['rol'] == 'admin' ? null : IconButton(
                    icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
                    onPressed: () => _confirmDelete(doc),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddUserDialog,
        backgroundColor: const Color(0xff1a237e),
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
    );
  }

  void _confirmDelete(DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Eliminar Usuario"),
        content: Text("¿Está seguro de eliminar a ${doc['nombre']}? Esto solo quitará su perfil de la lista."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              doc.reference.delete();
              Navigator.pop(context);
            }, 
            child: const Text("Eliminar", style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );
  }
}
