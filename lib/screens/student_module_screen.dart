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
  final DateTime _fechaEmision = DateTime.now();
  String _nombreOperador = "Cargando...";
  String _cicloActivoNombre = "Sin ciclo activo";
  int? _activeCycleYear;

  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: const Color(0xff1a237e),
    exportBackgroundColor: Colors.white,
  );

  bool _isSearching = false;
  bool _hasSearched = false;
  bool _isExistingStudent = false;
  bool _isProcessing = false;
  String _tipoTramiteSugerido = "";
  DocumentSnapshot? _existingStudentDoc;

  List<String> _carreras = [];

  final Color primaryColor = const Color(0xff1a237e);
  final Color accentColor = const Color(0xff3f51b5);

  @override
  void initState() {
    super.initState();
    _cargarCarreras();
    _obtenerNombreOperador();
    _obtenerCicloActivo();
  }

  @override
  void dispose() {
    _signatureController.dispose();
    _searchController.dispose();
    _nombreController.dispose();
    _codigoController.dispose();
    super.dispose();
  }

  void _obtenerCicloActivo() async {
    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('ciclos')
          .where('activo', isEqualTo: true)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        var doc = snapshot.docs.first;
        setState(() {
          _cicloActivoNombre = doc.get('nombre') ?? "Sin ciclo activo";
          // Extraemos el año del ciclo activo para la lógica de "Primera Emisión del Año"
          if (doc.get('fechaInicio') is Timestamp) {
            _activeCycleYear = (doc.get('fechaInicio') as Timestamp).toDate().year;
          }
        });
      }
    } catch (e) {
      debugPrint("Error obteniendo ciclo activo: $e");
    }
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
      debugPrint("Error cargando carreras: $e");
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

          try {
            var data = _existingStudentDoc!.data() as Map<String, dynamic>?;
            if (data != null && data.containsKey('fechaEmision')) {
              Timestamp lastTimestamp = data['fechaEmision'];
              DateTime lastDate = lastTimestamp.toDate();
              
              // Usamos el año del ciclo activo si existe, de lo contrario el año actual
              int targetYear = _activeCycleYear ?? DateTime.now().year;

              if (lastDate.year < targetYear) {
                _tipoTramiteSugerido = "Primera Emisión del Año";
              } else {
                _tipoTramiteSugerido = "Reposición";
              }
            } else {
              _tipoTramiteSugerido = "Primera Emisión";
            }
          } catch (e) {
            _tipoTramiteSugerido = "Reposición";
          }
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error en la búsqueda: $e")));
    }
  }

  Future<void> _descontarInventario(int cantidad) async {
    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('inventario')
          .where('nombre', isEqualTo: 'Tarjetas PVC')
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        var doc = snapshot.docs.first;
        await doc.reference.update({'cantidad': (doc.get('cantidad') ?? 0) - cantidad});
      }
    } catch (e) {
      debugPrint("Error inventario: $e");
    }
  }

  void _procesarEmision() async {
    if (_formKey.currentState!.validate()) {
      if (_signatureController.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("La firma es obligatoria"), backgroundColor: Colors.orange),
        );
        return;
      }

      setState(() => _isProcessing = true);

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
          'ciclo': _cicloActivoNombre,
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

        _showSuccessDialog();
        _resetForm();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al procesar: $e"), backgroundColor: Colors.red),
        );
      } finally {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _resetForm() {
    _searchController.clear();
    _signatureController.clear();
    _nombreController.clear();
    _codigoController.clear();
    setState(() {
      _hasSearched = false;
      _carreraSeleccionada = null;
    });
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.green, size: 80),
            const SizedBox(height: 16),
            Text("¡Registro Exitoso!",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryColor)),
            const SizedBox(height: 8),
            Text("El carnet ha sido procesado para el $_cicloActivoNombre y el inventario actualizado.",
                textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("ENTENDIDO"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Emisión de Carnets", style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_hasSearched)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _resetForm,
              tooltip: "Nueva búsqueda",
            )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildSearchHeader(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _hasSearched ? _buildForm() : _buildWelcomeState(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Buscar Estudiante",
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _cicloActivoNombre,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))
              ],
            ),
            child: TextField(
              controller: _searchController,
              textCapitalization: TextCapitalization.characters,
              onSubmitted: (_) => _buscarEstudiante(),
              decoration: InputDecoration(
                hintText: "Ingrese el código (Ej: U2023...)",
                prefixIcon: Icon(Icons.badge_outlined, color: primaryColor),
                suffixIcon: _isSearching
                    ? const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : IconButton(
                  icon: const Icon(Icons.search_rounded),
                  onPressed: _buscarEstudiante,
                  color: primaryColor,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeState() {
    return Column(
      children: [
        const SizedBox(height: 60),
        Icon(Icons.contactless_outlined, size: 100, color: Colors.grey[300]),
        const SizedBox(height: 20),
        Text(
          "Listo para procesar",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.grey[600]),
        ),
        Text(
          "Busque un estudiante por código para comenzar",
          style: TextStyle(color: Colors.grey[400]),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoBadge(),
          const SizedBox(height: 20),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Datos del Estudiante",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(height: 30),
                  _buildField(_nombreController, "Nombre Completo", Icons.person_outline),
                  const SizedBox(height: 20),
                  _buildField(_codigoController, "Código Institucional", Icons.tag, enabled: false),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: _carreraSeleccionada,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: "Carrera Universitaria",
                      prefixIcon: const Icon(Icons.school_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    items: _carreras
                        .map((c) => DropdownMenuItem(
                        value: c, child: Text(c, style: const TextStyle(fontSize: 14))))
                        .toList(),
                    onChanged: (v) => setState(() => _carreraSeleccionada = v),
                    validator: (v) => v == null ? "Seleccione una carrera" : null,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Firma de Conformidad",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
                        onPressed: () => _signatureController.clear(),
                      )
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Signature(
                        controller: _signatureController,
                        height: 150,
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
          _isProcessing
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton(
            onPressed: _procesarEmision,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              elevation: 5,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 10),
                Text(
                  _tipoTramiteSugerido.toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildInfoBadge() {
    Color color = _isExistingStudent ? Colors.orange : Colors.green;
    IconData icon = _isExistingStudent ? Icons.history : Icons.person_add_alt_1;
    String label = _isExistingStudent ? "Estudiante Registrado" : "Nuevo Estudiante";

    if (_tipoTramiteSugerido == "Primera Emisión del Año") {
      color = Colors.indigo; // Color distintivo para trámite anual de alumno existente
      icon = Icons.calendar_month_outlined;
      label = "Trámite Anual Habilitado";
    } else if (_tipoTramiteSugerido == "Primera Emisión") {
        color = Colors.green;
        icon = Icons.person_add_alt_1;
        label = "Nuevo Registro";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                ),
                Text(
                  "Trámite: $_tipoTramiteSugerido • Ciclo: $_cicloActivoNombre",
                  style: TextStyle(fontSize: 12, color: color.withOpacity(0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, IconData icon, {bool enabled = true}) {
    return TextFormField(
      controller: ctrl,
      enabled: enabled,
      style: TextStyle(color: enabled ? Colors.black87 : Colors.black54),
      validator: (v) => (v == null || v.isEmpty) ? "Este campo es obligatorio" : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 22),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey[100],
      ),
    );
  }
}