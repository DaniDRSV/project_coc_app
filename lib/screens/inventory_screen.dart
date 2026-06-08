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

          bool puedeCrear = rol == 'admin' || (permisos['perm_act_inv_crear'] ?? true);
          bool puedeEditar = rol == 'admin' || (permisos['perm_act_inv_editar'] ?? true);

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
                      const Text("⚠️ Solo lectura: No tienes permiso para modificar existencias.", style: TextStyle(fontSize: 12, color: Colors.orange)),
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
          icon: const Icon(Icons.edit_square, color: Color(0xff1a237e)),
          onPressed: () => _showUpdateStockDialog(context, doc),
          tooltip: "Ajustar cantidad",
        ) : null,
      ),
    );
  }

  // --- INTERFAZ DEL DIÁLOGO MEJORADA (SIN OVERFLOW) ---
  void _showUpdateStockDialog(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    int stockActual = data['cantidad'] ?? 0;
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text("Ajustar: ${data['nombre']}", style: const TextStyle(color: Color(0xff1a237e), fontWeight: FontWeight.bold)),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Stock Actual: $stockActual unidades", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 20),
              TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: "Cantidad a modificar",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calculate)
                  )
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                      icon: const Icon(Icons.remove, size: 18),
                      label: const Text("RESTAR"),
                      onPressed: () async {
                        int? cant = int.tryParse(controller.text);
                        if (cant != null && cant > 0) {
                          await doc.reference.update({'cantidad': FieldValue.increment(-cant)});
                          if(context.mounted) Navigator.pop(context);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text("SUMAR"),
                      onPressed: () async {
                        int? cant = int.tryParse(controller.text);
                        if (cant != null && cant > 0) {
                          await doc.reference.update({'cantidad': FieldValue.increment(cant)});
                          if(context.mounted) Navigator.pop(context);
                        }
                      },
                    ),
                  ),
                ],
              )
            ]
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff1a237e), foregroundColor: Colors.white),
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