import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class InventoryScreen extends StatefulWidget {
  final String rol;

  const InventoryScreen({super.key, required this.rol});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Color primaryBlue = const Color(0xff1a237e);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('usuarios').doc(uid).snapshots(),
      builder: (context, snapshotUser) {
        if (!snapshotUser.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        
        var userData = snapshotUser.data?.data() as Map<String, dynamic>? ?? {};
        String userRole = userData['rol'] ?? widget.rol;
        String usuarioNombre = userData['nombre'] ?? 'Operador';

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('configuracion').doc('permisos').snapshots(),
          builder: (context, snapshotPermisos) {
            if (!snapshotPermisos.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
            
            var permisosGlobales = snapshotPermisos.data?.data() as Map<String, dynamic>? ?? {};

            // Validación alineada con las llaves globales correctas del panel de administración
            bool puedeCrear = userRole == 'admin' || (permisosGlobales['perm_act_inv_crear'] ?? true);
            bool puedeEditar = userRole == 'admin' || (permisosGlobales['perm_act_inv_editar'] ?? true);

            return Scaffold(
              backgroundColor: Colors.grey.shade50,
              appBar: AppBar(
                title: const Text("Gestión de Suministros", style: TextStyle(fontWeight: FontWeight.bold)),
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                bottom: TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.white,
                  indicatorWeight: 4,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  tabs: const [
                    Tab(icon: Icon(Icons.inventory_2_outlined), text: "Existencias"),
                    Tab(icon: Icon(Icons.history_toggle_off_rounded), text: "Movimientos"),
                  ],
                ),
              ),
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildStockTab(puedeEditar, usuarioNombre),
                  _buildHistoryTab(),
                ],
              ),
              floatingActionButton: puedeCrear
                  ? FloatingActionButton.extended(
                      onPressed: () => _showAddMaterialDialog(context, usuarioNombre),
                      backgroundColor: primaryBlue,
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text("NUEVO MATERIAL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    )
                  : null,
            );
          }
        );
      },
    );
  }

  // --- PESTAÑA 1: STOCK ACTUAL ---
  Widget _buildStockTab(bool puedeEditar, String usuarioNombre) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('inventario').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined, size: 70, color: Colors.grey[300]),
                const SizedBox(height: 15),
                Text("No hay materiales registrados", style: TextStyle(color: Colors.grey[500], fontSize: 16)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var doc = docs[index];
            var data = doc.data() as Map<String, dynamic>;
            int cantidad = data['cantidad'] ?? 0;
            String nombre = data['nombre'] ?? 'S/N';
            bool isRibbon = nombre.toLowerCase().contains('cinta');

            // Determinar color de estado según nivel de stock
            Color statusColor = Colors.green;
            String statusText = "Stock Saludable";
            if (cantidad < 30) {
              statusColor = Colors.red;
              statusText = "Stock Crítico";
            } else if (cantidad < 100) {
              statusColor = Colors.orange;
              statusText = "Stock Bajo";
            }

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: puedeEditar ? () => _showUpdateStockDialog(context, doc, usuarioNombre) : null,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Icon(
                              isRibbon ? Icons.layers_outlined : Icons.credit_card_rounded,
                              color: statusColor,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nombre,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    statusText.toUpperCase(),
                                    style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                "$cantidad",
                                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: statusColor),
                              ),
                              const Text("unidades", style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          )
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (puedeEditar)
                            TextButton.icon(
                              onPressed: () => _showUpdateStockDialog(context, doc, usuarioNombre),
                              icon: Icon(Icons.add_moderator_outlined, size: 18, color: primaryBlue),
                              label: Text("Ajustar Stock", style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w600)),
                            ),
                          if (widget.rol == 'admin') ...[
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () => _confirmDeleteMaterial(context, doc, nombre),
                              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                              label: const Text("Eliminar", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                            ),
                          ]
                        ],
                      ),
                      if (isRibbon) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey[50],
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.green,
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () => _registrarUsoCinta(doc, "inicio", usuarioNombre),
                                icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
                                label: const Text("COLOCAR NUEVA", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.orange.shade800,
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () => _registrarUsoCinta(doc, "fin", usuarioNombre),
                                icon: const Icon(Icons.stop_circle_outlined, size: 18),
                                label: const Text("TERMINAR CINTA", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ],
                          ),
                        )
                      ]
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- PESTAÑA 2: HISTORIAL ---
  Widget _buildHistoryTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('inventario_logs').orderBy('fecha', descending: true).limit(40).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var logs = snapshot.data!.docs;

        if (logs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_toggle_off_rounded, size: 70, color: Colors.grey[300]),
                const SizedBox(height: 15),
                Text("No hay movimientos registrados", style: TextStyle(color: Colors.grey[500], fontSize: 16)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: logs.length,
          itemBuilder: (context, index) {
            var log = logs[index];
            var data = log.data() as Map<String, dynamic>? ?? {};
            int cantidadLog = data['cantidad'] ?? 0;
            DateTime fecha = (data['fecha'] as Timestamp? ?? Timestamp.now()).toDate();
            bool isPositive = cantidadLog > 0;

            return Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isPositive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPositive ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded,
                    color: isPositive ? Colors.green : Colors.red,
                    size: 24,
                  ),
                ),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        data['material'] ?? 'Material',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPositive ? Colors.green[50] : Colors.red[50],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "${isPositive ? '+' : ''}$cantidadLog",
                        style: TextStyle(
                          color: isPositive ? Colors.green[800] : Colors.red[800],
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Motivo: ${data['motivo'] ?? 'Ajuste manual'}", style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(
                        "Por: ${data['usuario']} • ${DateFormat('dd/MM/yy HH:mm').format(fecha)}",
                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- DIÁLOGOS Y LÓGICA MEJORADA ---

  void _showUpdateStockDialog(BuildContext context, DocumentSnapshot doc, String usuario) {
    final controller = TextEditingController();
    String tipoOperacion = "SUMAR"; // Estado local del diálogo: SUMAR o RESTAR
    final formKeyDialog = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Ajustar Inventario", style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 4),
              Text(doc['nombre'], style: const TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.normal)),
            ],
          ),
          content: Form(
            key: formKeyDialog,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Selector intuitivo de tipo de operación
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text("AGREGAR (+)", style: TextStyle(fontWeight: FontWeight.bold))),
                        selected: tipoOperacion == "SUMAR",
                        selectedColor: Colors.green.shade100,
                        labelStyle: TextStyle(color: tipoOperacion == "SUMAR" ? Colors.green.shade900 : Colors.black54),
                        onSelected: (selected) {
                          if (selected) setDialogState(() => tipoOperacion = "SUMAR");
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text("RETIRAR (-)", style: TextStyle(fontWeight: FontWeight.bold))),
                        selected: tipoOperacion == "RESTAR",
                        selectedColor: Colors.red.shade100,
                        labelStyle: TextStyle(color: tipoOperacion == "RESTAR" ? Colors.red.shade900 : Colors.black54),
                        onSelected: (selected) {
                          if (selected) setDialogState(() => tipoOperacion = "RESTAR");
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: tipoOperacion == "SUMAR" ? "Cantidad a ingresar" : "Cantidad a retirar",
                    prefixIcon: Icon(tipoOperacion == "SUMAR" ? Icons.add_circle_outline : Icons.remove_circle_outline, 
                        color: tipoOperacion == "SUMAR" ? Colors.green : Colors.red),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return "Ingrese un valor";
                    int? parsed = int.tryParse(v);
                    if (parsed == null || parsed <= 0) return "Ingrese un número entero positivo";
                    if (tipoOperacion == "RESTAR" && parsed > (doc['cantidad'] ?? 0)) {
                      return "No puedes retirar más de las unidades disponibles";
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: tipoOperacion == "SUMAR" ? Colors.green.shade700 : Colors.red.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                if (formKeyDialog.currentState!.validate()) {
                  int val = int.parse(controller.text);
                  // Si la operación es retirar, el valor se vuelve negativo
                  int delta = tipoOperacion == "SUMAR" ? val : -val;

                  await doc.reference.update({'cantidad': FieldValue.increment(delta)});
                  _registrarLog(
                    doc['nombre'], 
                    delta, 
                    usuario, 
                    tipoOperacion == "SUMAR" ? 'Ingreso de stock manual' : 'Retiro de stock manual'
                  );
                  
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Inventario actualizado correctamente"), 
                        backgroundColor: tipoOperacion == "SUMAR" ? Colors.green : Colors.orange
                      ),
                    );
                  }
                }
              },
              child: const Text("GUARDAR", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteMaterial(BuildContext context, DocumentSnapshot doc, String nombre) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("¿Eliminar material?"),
        content: Text("Esta acción eliminará '$nombre' del inventario permanentemente."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              doc.reference.delete();
              Navigator.pop(context);
            },
            child: const Text("ELIMINAR", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddMaterialDialog(BuildContext context, String usuario) {
    final nameCtrl = TextEditingController();
    final cantCtrl = TextEditingController();
    final formKeyAdd = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Nuevo Suministro", style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold)),
        content: Form(
          key: formKeyAdd,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: "Nombre del material",
                  prefixIcon: const Icon(Icons.label_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => v == null || v.isEmpty ? "Campo requerido" : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: cantCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Stock Inicial",
                  prefixIcon: const Icon(Icons.numbers),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return "Campo requerido";
                  if (int.tryParse(v) == null || int.parse(v) < 0) return "Ingrese un número válido";
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              if (formKeyAdd.currentState!.validate()) {
                int cant = int.parse(cantCtrl.text);
                await FirebaseFirestore.instance.collection('inventario').add({
                  'nombre': nameCtrl.text.trim(),
                  'cantidad': cant,
                  'fechaRegistro': FieldValue.serverTimestamp(),
                });
                _registrarLog(nameCtrl.text.trim(), cant, usuario, 'Registro inicial de material');
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text("REGISTRAR", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _registrarUsoCinta(DocumentSnapshot doc, String fase, String usuario) async {
    var emisiones = await FirebaseFirestore.instance.collection('emisiones_log').get();
    int conteoActual = emisiones.docs.length;
    if (fase == "inicio") {
      await FirebaseFirestore.instance.collection('uso_cintas').add({
        'material': doc['nombre'],
        'fechaInicio': FieldValue.serverTimestamp(),
        'carnetsAlInicio': conteoActual,
        'usuario': usuario,
        'estado': 'activa'
      });
      await doc.reference.update({'cantidad': FieldValue.increment(-1)});
      _registrarLog(doc['nombre'], -1, usuario, 'Cinta puesta en uso');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Se ha descontado 1 cinta y colocado en uso activo"), backgroundColor: Colors.green),
        );
      }
    } else {
      var activa = await FirebaseFirestore.instance
          .collection('uso_cintas')
          .where('material', isEqualTo: doc['nombre'])
          .where('estado', isEqualTo: 'activa')
          .limit(1)
          .get();
      if (activa.docs.isNotEmpty) {
        int inicio = activa.docs.first['carnetsAlInicio'];
        int rendimiento = conteoActual - inicio;
        await activa.docs.first.reference.update({
          'fechaFin': FieldValue.serverTimestamp(),
          'carnetsAlFin': conteoActual,
          'totalRendimiento': rendimiento,
          'estado': 'terminada'
        });
        _showRendimientoDialog(rendimiento);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No se encontró ninguna cinta marcada en uso activo"), backgroundColor: Colors.orange),
          );
        }
      }
    }
  }

  void _showRendimientoDialog(int total) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.analytics_outlined, color: Colors.blue),
            SizedBox(width: 8),
            Text("Rendimiento de Cinta"),
          ],
        ),
        content: Text("Esta cinta finalizó su ciclo con un total de **$total** carnets impresos exitosamente desde su instalación."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ACEPTAR"))
        ],
      ),
    );
  }

  void _registrarLog(String material, int cant, String usuario, String motivo) async {
    await FirebaseFirestore.instance.collection('inventario_logs').add({
      'material': material,
      'cantidad': cant,
      'usuario': usuario,
      'motivo': motivo,
      'fecha': FieldValue.serverTimestamp(),
    });
  }
}