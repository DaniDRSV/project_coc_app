import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryScreen extends StatelessWidget {
  final String rol;
  const InventoryScreen({super.key, required this.rol});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('configuracion').doc('permisos').snapshots(),
      builder: (context, snapshotPermisos) {
        var permisos = snapshotPermisos.data?.data() as Map<String, dynamic>? ?? {};
        
        // El administrador ignora las restricciones. El operador depende de los toggles del Admin Panel.
        bool puedeCrear = rol == 'admin' || (permisos['perm_inv_crear'] ?? true);
        bool puedeEditar = rol == 'admin' || (permisos['perm_inv_editar'] ?? true);

        return Scaffold(
          appBar: AppBar(
            title: const Text("Inventario de Suministros"),
            backgroundColor: const Color(0xff1a237e),
            foregroundColor: Colors.white,
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('inventario').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No hay suministros registrados."));

              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text("Stock en Bodega", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xff1a237e))),
                  const SizedBox(height: 10),
                  if (rol != 'admin' && !puedeEditar) 
                    const Text("⚠️ Solo lectura: No tienes permiso para editar existencias.", style: TextStyle(fontSize: 12, color: Colors.orange)),
                  const SizedBox(height: 20),
                  ...snapshot.data!.docs.map((doc) => _buildInventoryCard(context, doc, puedeEditar)),
                ],
              );
            },
          ),
          floatingActionButton: puedeCrear ? FloatingActionButton.extended(
            onPressed: () => _showAddMaterialDialog(context),
            backgroundColor: const Color(0xff1a237e),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text("Nuevo Material", style: TextStyle(color: Colors.white)),
          ) : null,
        );
      }
    );
  }

  Widget _buildInventoryCard(BuildContext context, DocumentSnapshot doc, bool puedeEditar) {
    final data = doc.data() as Map<String, dynamic>;
    int cantidad = data['cantidad'] ?? 0;
    String nombre = data['nombre'] ?? 'Sin nombre';
    bool lowStock = cantidad < 50; 

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: lowStock ? Colors.red.shade100 : const Color(0xff1a237e).withOpacity(0.1),
          child: Icon(Icons.inventory_2, color: lowStock ? Colors.red : const Color(0xff1a237e)),
        ),
        title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("Stock actual: $cantidad unidades"),
        trailing: puedeEditar ? IconButton(
          icon: const Icon(Icons.edit, color: Color(0xff1a237e)),
          onPressed: () => _showUpdateStockDialog(context, doc),
        ) : null,
      ),
    );
  }

  void _showUpdateStockDialog(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final controller = TextEditingController(text: data['cantidad'].toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Actualizar ${data['nombre']}"),
        content: TextField(controller: controller, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Cantidad")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
          ElevatedButton(
            onPressed: () async {
              int? nuevaCant = int.tryParse(controller.text);
              if (nuevaCant != null) {
                await doc.reference.update({'cantidad': nuevaCant});
                Navigator.pop(context);
              }
            },
            child: const Text("GUARDAR"),
          ),
        ],
      ),
    );
  }

  void _showAddMaterialDialog(BuildContext context) {
    final nameController = TextEditingController();
    final quantityController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Agregar Suministro"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameController, decoration: const InputDecoration(labelText: "Nombre del material")),
          TextField(controller: quantityController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Stock inicial")),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                await FirebaseFirestore.instance.collection('inventario').add({
                  'nombre': nameController.text.trim(),
                  'cantidad': int.tryParse(quantityController.text) ?? 0,
                });
                Navigator.pop(context);
              }
            },
            child: const Text("REGISTRAR"),
          ),
        ],
      ),
    );
  }
}
