import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:signature/signature.dart';

class StudentModuleScreen extends StatefulWidget {
  final String rol;
  final String sede;

  const StudentModuleScreen({super.key, required this.rol, required this.sede});

  @override
  State<StudentModuleScreen> createState() => _StudentModuleScreenState();
}

class _StudentModuleScreenState extends State<StudentModuleScreen> {
  final TextEditingController _searchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _codigoController = TextEditingController();
  String? _carreraSeleccionada;
  DateTime _fechaEmision = DateTime.now();
  String _nombreOperador = "Cargando...";

  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  bool _isSearching = false;
  bool _hasSearched = false;
  bool _isExistingStudent = false;
  String _tipoTramiteSugerido = "";
  DocumentSnapshot? _existingStudentDoc;

  List<String> _carreras = [];

  @override
  void initState() {
    super.initState();
    _cargarCarreras();
    _obtenerNombreOperador();
  }

  @override
  void dispose() {
    _signatureController.dispose();
    _searchController.dispose();
    _nombreController.dispose();
    _codigoController.dispose();
    super.dispose();
  }

  void _obtenerNombreOperador() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        var doc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
        if (doc.exists) {
          setState(() => _nombreOperador = doc.get('nombre') ?? "Operador");
        }
      } catch (e) {
        setState(() => _nombreOperador = "Operador");
      }
    }
  }

  void _cargarCarreras() async {
    try {
      var snapshot = await FirebaseFirestore.instance.collection('carreras').orderBy('nombre').get();
      setState(() {
        _carreras = snapshot.docs.map((doc) => doc.get('nombre').toString()).toList();
      });
    } catch (e) {
      print("Error cargando carreras: $e");
    }
  }

  void _buscarEstudiante() async {
    String codigo = _searchController.text.trim().toUpperCase();
    if (codigo.isEmpty) return;

    setState(() {
      _isSearching = true;
      _hasSearched = false;
      _signatureController.clear();
    });

    try {
      var result = await FirebaseFirestore.instance
          .collection('estudiantes')
          .where('codigo', isEqualTo: codigo)
          .limit(1)
          .get();

      setState(() {
        _isSearching = false;
        _hasSearched = true;
        if (result.docs.isNotEmpty) {
          _isExistingStudent = true;
          _existingStudentDoc = result.docs.first;
          _nombreController.text = _existingStudentDoc!.get('nombre');
          _codigoController.text = _existingStudentDoc!.get('codigo');
          String carreraDb = _existingStudentDoc!.get('carrera');
          if (_carreras.contains(carreraDb)) _carreraSeleccionada = carreraDb;

          Timestamp lastTimestamp = _existingStudentDoc!.get('fechaEmision');
          _tipoTramiteSugerido = (lastTimestamp.toDate().year < DateTime.now().year) ? "Primera Emisión del Año" : "Reposición";
        } else {
          _isExistingStudent = false;
          _existingStudentDoc = null;
          _tipoTramiteSugerido = "Primera Emisión";
          _nombreController.clear();
          _codigoController.text = codigo;
          _carreraSeleccionada = null;
        }
      });
    } catch (e) {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _descontarInventario(int cantidad) async {
    try {
      var snapshot = await FirebaseFirestore.instance.collection('inventario').where('nombre', isEqualTo: 'Tarjetas PVC').limit(1).get();
      if (snapshot.docs.isNotEmpty) {
        var doc = snapshot.docs.first;
        await doc.reference.update({'cantidad': doc.get('cantidad') - cantidad});
      }
    } catch (e) {
      print("Error inventario: $e");
    }
  }

  void _procesarEmision() async {
    if (_formKey.currentState!.validate()) {
      if (_signatureController.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Firma requerida"), backgroundColor: Colors.orange));
        return;
      }

      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        final signatureBytes = await _signatureController.toPngBytes();
        final signatureBase64 = base64Encode(signatureBytes!);

        Map<String, dynamic> data = {
          'nombre': _nombreController.text.trim(),
          'codigo': _codigoController.text.trim().toUpperCase(),
          'carrera': _carreraSeleccionada,
          'fechaEmision': Timestamp.fromDate(_fechaEmision),
          'tipoTramite': _tipoTramiteSugerido,
          'atendidoPor': _nombreOperador,
          'atendidoPorUid': currentUser?.uid,
          'sede': widget.sede,
          'firma': signatureBase64,
        };

        if (_isExistingStudent) {
          await _existingStudentDoc!.reference.update(data);
        } else {
          await FirebaseFirestore.instance.collection('estudiantes').add(data);
        }

        await FirebaseFirestore.instance.collection('emisiones_log').add({
          ...data,
          'fechaRegistro': FieldValue.serverTimestamp(),
        });

        await _descontarInventario(1);

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Emisión completada"), backgroundColor: Colors.green));
        _searchController.clear();
        _signatureController.clear();
        setState(() => _hasSearched = false);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  void _mostrarReporteError() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reportar Error"),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: "Motivo...")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")),
          ElevatedButton(
              onPressed: () async {
                if (ctrl.text.isNotEmpty) {
                  await FirebaseFirestore.instance.collection('errores_impresion').add({
                    'codigo': _codigoController.text,
                    'motivo': ctrl.text.trim(),
                    'material_perdido': 1, // Descuenta 1 PVC por defecto al reportar desde aquí
                    'fecha': FieldValue.serverTimestamp(),
                    'reportadoPor': _nombreOperador,
                    'atendidoPorUid': FirebaseAuth.instance.currentUser?.uid,
                    'sede': widget.sede,
                  });
                  await _descontarInventario(1);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error reportado")));
                }
              },
              child: const Text("ENVIAR")
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<DocumentSnapshot>(
      // AHORA LEE DEL USUARIO DIRECTAMENTE
        stream: FirebaseFirestore.instance.collection('usuarios').doc(uid).snapshots(),
        builder: (context, snapshotUser) {
          var userData = snapshotUser.data?.data() as Map<String, dynamic>? ?? {};
          var permisos = userData['permisos'] as Map<String, dynamic>? ?? {};

          bool puedeReportarError = widget.rol == 'admin' || (permisos['act_emi_error'] ?? true);

          return Scaffold(
            appBar: AppBar(title: const Text("Módulo de Emisión"), backgroundColor: const Color(0xff1a237e), foregroundColor: Colors.white),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(hintText: "Código Estudiante", border: InputBorder.none),
                              onSubmitted: (_) => _buscarEstudiante(),
                            ),
                          ),
                          _isSearching ? const CircularProgressIndicator() : IconButton(icon: const Icon(Icons.search), onPressed: _buscarEstudiante),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_hasSearched) ...[
                    _buildStatusIndicator(),
                    const SizedBox(height: 20),
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildField(_nombreController, "Nombre Completo", Icons.person),
                          const SizedBox(height: 15),
                          _buildField(_codigoController, "Código", Icons.tag, enabled: false),
                          const SizedBox(height: 15),
                          DropdownButtonFormField<String>(
                            value: _carreraSeleccionada,
                            isExpanded: true,
                            decoration: InputDecoration(labelText: "Carrera", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                            items: _carreras.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                            onChanged: (v) => setState(() => _carreraSeleccionada = v),
                          ),
                          const SizedBox(height: 20),
                          const Text("Firma Estudiante:", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xff1a237e))),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(12)),
                            child: Signature(controller: _signatureController, height: 150, backgroundColor: Colors.grey.shade100),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.undo, color: Color(0xff1a237e)),
                                    onPressed: () => _signatureController.undo(),
                                    tooltip: "Deshacer último trazo",
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.redo, color: Color(0xff1a237e)),
                                    onPressed: () => _signatureController.redo(),
                                    tooltip: "Rehacer",
                                  ),
                                ],
                              ),
                              TextButton.icon(
                                onPressed: () => _signatureController.clear(),
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                label: const Text("Borrar todo", style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                          ElevatedButton(
                            onPressed: _procesarEmision,
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff1a237e), minimumSize: const Size(double.infinity, 55)),
                            child: Text(_tipoTramiteSugerido.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                          if (puedeReportarError) ...[
                            const SizedBox(height: 15),
                            Center(
                              child: TextButton.icon(
                                onPressed: _mostrarReporteError,
                                icon: const Icon(Icons.error_outline, color: Colors.red),
                                label: const Text("¿Hubo un error de impresión?", style: TextStyle(color: Colors.red)),
                              ),
                            ),
                          ]
                        ],
                      ),
                    ),
                  ]
                ],
              ),
            ),
          );
        }
    );
  }

  Widget _buildStatusIndicator() {
    Color color = _tipoTramiteSugerido.contains("Año") ? Colors.blue : (_isExistingStudent ? Colors.orange : Colors.green);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: color)),
      child: Text(_tipoTramiteSugerido.toUpperCase(), textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, IconData icon, {bool enabled = true}) {
    return TextFormField(
      controller: ctrl,
      enabled: enabled,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: !enabled, fillColor: enabled ? null : Colors.grey.shade100),
      validator: (v) => (v == null || v.isEmpty) ? "Requerido" : null,
    );
  }
}