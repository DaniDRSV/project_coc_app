import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  final Color primaryBlue = const Color(0xff1a237e);
  String? _selectedCicloName;

  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
    end: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59),
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarCicloActivoInicial();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _cargarCicloActivoInicial() async {
    try {
      var snap = await FirebaseFirestore.instance
          .collection('ciclos')
          .where('activo', isEqualTo: true)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty && mounted) {
        var doc = snap.docs.first;
        setState(() {
          _selectedCicloName = doc['nombre'];
          _selectedDateRange = DateTimeRange(
            start: (doc['fechaInicio'] as Timestamp).toDate(),
            end: (doc['fechaFin'] as Timestamp).toDate(),
          );
        });
      }
    } catch (e) {
      debugPrint("Error cargando ciclo inicial: $e");
    }
  }

  void _applyQuickFilter(String filter) {
    DateTime now = DateTime.now();
    setState(() {
      _selectedCicloName = null; // Al elegir rango rápido, se limpia el ciclo predefinido
      if (filter == 'Hoy') {
        _selectedDateRange = DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      } else if (filter == 'Semana') {
        _selectedDateRange = DateTimeRange(
          start: now.subtract(const Duration(days: 7)),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      } else if (filter == 'Mes') {
        _selectedDateRange = DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Auditoría y Reportes", style: TextStyle(fontWeight: FontWeight.bold)),
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
            Tab(icon: Icon(Icons.badge), text: "Emisiones"),
            Tab(icon: Icon(Icons.error_outline), text: "Errores"),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildCycleDropdown(),
          _buildQuickFilters(),
          _buildSearchBar(),
          _buildFilterBanner(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildListView('emisiones_log', 'fechaRegistro'),
                _buildListView('errores_impresion', 'fecha'),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('usuarios').doc(FirebaseAuth.instance.currentUser?.uid).snapshots(),
          builder: (context, snapshotUser) {
            var userData = snapshotUser.data?.data() as Map<String, dynamic>? ?? {};
            String rol = userData['rol'] ?? 'operador';

            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('configuracion').doc('permisos').snapshots(),
              builder: (context, snapshotPermisos) {
                var permisosGlobales = snapshotPermisos.data?.data() as Map<String, dynamic>? ?? {};

                // Sincronización con las llaves globales correctas del panel de políticas
                bool canExcel = rol == 'admin' || (permisosGlobales['perm_act_excel'] ?? true);
                bool canPdf = rol == 'admin' || (permisosGlobales['perm_act_pdf'] ?? true);

                if (!canExcel && !canPdf) return const SizedBox.shrink();

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (canExcel)
                      FloatingActionButton.extended(
                        heroTag: "btn_ex",
                        onPressed: () => _showExportPreview("Excel"),
                        backgroundColor: Colors.green.shade800,
                        icon: const Icon(Icons.table_view, color: Colors.white),
                        label: const Text("EXCEL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    if (canExcel && canPdf) const SizedBox(height: 10),
                    if (canPdf)
                      FloatingActionButton.extended(
                        heroTag: "btn_pd",
                        onPressed: () => _showExportPreview("PDF"),
                        backgroundColor: Colors.red.shade800,
                        icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                        label: const Text("PDF", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                  ],
                );
              }
            );
          }
      ),
    );
  }

  Widget _buildCycleDropdown() {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 12, 15, 4),
      color: Colors.white,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('ciclos').orderBy('fechaInicio', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const LinearProgressIndicator();
          var docs = snapshot.data!.docs;

          return DropdownButtonFormField<String>(
            value: _selectedCicloName,
            decoration: InputDecoration(
              labelText: "Filtrar por Ciclo Académico",
              prefixIcon: const Icon(Icons.calendar_month, color: Color(0xff1a237e)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            hint: const Text("Seleccione un ciclo escolar"),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text("Rango de fecha libre / Personalizado"),
              ),
              ...docs.map((doc) {
                return DropdownMenuItem<String>(
                  value: doc['nombre'].toString(),
                  child: Text(doc['nombre'].toString()),
                );
              })
            ],
            onChanged: (value) {
              if (value == null) {
                setState(() {
                  _selectedCicloName = null;
                });
              } else {
                var selectedDoc = docs.firstWhere((d) => d['nombre'] == value);
                setState(() {
                  _selectedCicloName = value;
                  _selectedDateRange = DateTimeRange(
                    start: (selectedDoc['fechaInicio'] as Timestamp).toDate(),
                    end: (selectedDoc['fechaFin'] as Timestamp).toDate(),
                  );
                });
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildQuickFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _filterChip('Hoy'),
          _filterChip('Semana'),
          _filterChip('Mes'),
          IconButton(
            icon: Icon(Icons.date_range, color: primaryBlue),
            tooltip: "Seleccionar rango de fechas",
            onPressed: () async {
              final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2024),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: ColorScheme.light(primary: primaryBlue),
                      ),
                      child: child!,
                    );
                  }
              );
              if (picked != null) {
                setState(() {
                  _selectedCicloName = null; // Rango personalizado limpia selección de ciclo
                  _selectedDateRange = DateTimeRange(
                    start: picked.start,
                    end: DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
                  );
                });
              }
            },
          )
        ],
      ),
    );
  }

  Widget _filterChip(String label) {
    return ActionChip(
      label: Text(label),
      onPressed: () => _applyQuickFilter(label),
      backgroundColor: Colors.indigo.shade50,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      labelStyle: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold, fontSize: 13),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: TextField(
          controller: _searchController,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            hintText: "Filtrar por Código (ej: U2021...)",
            prefixIcon: Icon(Icons.search, color: primaryBlue),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onChanged: (value) => setState(() => _searchQuery = value.trim().toUpperCase()),
        ),
      ),
    );
  }

  Widget _buildFilterBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: primaryBlue,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.event_note, color: Colors.white70, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _selectedCicloName != null
                  ? "Ciclo: $_selectedCicloName (${DateFormat('dd/MM/yy').format(_selectedDateRange.start)} al ${DateFormat('dd/MM/yy').format(_selectedDateRange.end)})"
                  : "Periodo: ${DateFormat('dd/MM/yy').format(_selectedDateRange.start)} al ${DateFormat('dd/MM/yy').format(_selectedDateRange.end)}",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListView(String coll, String field) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(coll)
          .where(field, isGreaterThanOrEqualTo: _selectedDateRange.start)
          .where(field, isLessThanOrEqualTo: _selectedDateRange.end)
          .orderBy(field, descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        var docs = snapshot.data!.docs;
        if (_searchQuery.isNotEmpty) {
          docs = docs.where((doc) {
            var data = doc.data() as Map<String, dynamic>? ?? {};
            return (data['codigo'] ?? '').toString().toUpperCase().contains(_searchQuery);
          }).toList();
        }

        if (docs.isEmpty) return Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            Text("Sin registros en este periodo", style: TextStyle(color: Colors.grey.shade500)),
          ],
        ));

        return ListView.builder(
          itemCount: docs.length,
          padding: const EdgeInsets.only(top: 10, bottom: 80),
          itemBuilder: (context, index) {
            var doc = docs[index];
            var data = doc.data() as Map<String, dynamic>? ?? {};
            DateTime fecha = DateTime.now();
            if (data[field] is Timestamp) {
              fecha = (data[field] as Timestamp).toDate();
            }
            String? cicloReg = data['ciclo'];

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: coll == 'emisiones_log' ? Colors.green.shade50 : Colors.red.shade50,
                  child: Icon(
                    coll == 'emisiones_log' ? Icons.check_circle_outline : Icons.error_outline,
                    color: coll == 'emisiones_log' ? Colors.green : Colors.red,
                  ),
                ),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        data['codigo']?.toString() ?? 'S/C', 
                        style: const TextStyle(fontWeight: FontWeight.bold)
                      ),
                    ),
                    if (cicloReg != null)
                      Text(
                        cicloReg,
                        style: TextStyle(fontSize: 11, color: primaryBlue, fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(coll == 'emisiones_log' ? (data['nombre'] ?? '') : (data['motivo'] ?? '')),
                    if (coll == 'errores_impresion' && data['material_perdido'] != null)
                      Text(
                        "Material perdido: ${data['material_perdido']} PVC",
                        style: TextStyle(fontSize: 11, color: Colors.red.shade700, fontWeight: FontWeight.w500),
                      ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (coll == 'emisiones_log')
                      IconButton(
                        icon: const Icon(Icons.report_gmailerrorred_rounded, color: Colors.orange),
                        onPressed: () => _showReportErrorDialog(context, data),
                        tooltip: "Reportar Error",
                      ),
                    const SizedBox(width: 4),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(DateFormat('dd/MM').format(fecha), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        Text(DateFormat('HH:mm').format(fecha), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showReportErrorDialog(BuildContext context, Map<String, dynamic> emissionData) async {
    final motivoController = TextEditingController();
    final materialController = TextEditingController(text: "1");
    final currentUser = FirebaseAuth.instance.currentUser;
    
    String reporterName = "Operador";
    String reporterSede = "Sin sede";
    try {
      var userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(currentUser?.uid).get();
      if (userDoc.exists) {
        reporterName = userDoc.get('nombre') ?? "Operador";
        reporterSede = userDoc.get('sede') ?? "Sin sede";
      }
    } catch (_) {}

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.report_problem_rounded, color: Colors.orange),
            SizedBox(width: 10),
            Text("Reportar Incidencia", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Se registrará un error para el estudiante:", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(height: 4),
              Text("${emissionData['nombre']} (${emissionData['codigo']})", 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const Divider(height: 30),
              TextField(
                controller: motivoController,
                decoration: InputDecoration(
                  labelText: "Motivo del error",
                  hintText: "Ej: Fallo de impresión, Cinta rota...",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: materialController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Tarjetas PVC desperdiciadas",
                  helperText: "Cantidad de tarjetas que se perdieron",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              if (motivoController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Indique el motivo")));
                return;
              }
              
              int materialPerdido = int.tryParse(materialController.text) ?? 1;

              try {
                await FirebaseFirestore.instance.collection('errores_impresion').add({
                  'atendidoPorUid': currentUser?.uid,
                  'codigo': emissionData['codigo'],
                  'fecha': FieldValue.serverTimestamp(),
                  'material_perdido': materialPerdido,
                  'motivo': motivoController.text.trim(),
                  'reportadoPor': reporterName,
                  'sede': reporterSede,
                });

                await _descontarInventario(materialPerdido);

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Error registrado y stock actualizado (-$materialPerdido)"), 
                    backgroundColor: Colors.orange[800]
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al reportar: $e")));
              }
            },
            child: const Text("GUARDAR REPORTE"),
          ),
        ],
      ),
    );
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
        int stockActual = doc.get('cantidad') ?? 0;
        await doc.reference.update({'cantidad': stockActual - cantidad});
      }
    } catch (e) {
      debugPrint("Error descontando inventario en reporte de error: $e");
    }
  }

  void _showExportPreview(String format) async {
    var snapE = await FirebaseFirestore.instance.collection('emisiones_log')
        .where('fechaRegistro', isGreaterThanOrEqualTo: _selectedDateRange.start)
        .where('fechaRegistro', isLessThanOrEqualTo: _selectedDateRange.end).get();

    var snapErr = await FirebaseFirestore.instance.collection('errores_impresion')
        .where('fecha', isGreaterThanOrEqualTo: _selectedDateRange.start)
        .where('fecha', isLessThanOrEqualTo: _selectedDateRange.end).get();

    List<DocumentSnapshot> docsEmisiones = snapE.docs;
    List<DocumentSnapshot> docsErrores = snapErr.docs;

    if (_searchQuery.isNotEmpty) {
      docsEmisiones = docsEmisiones.where((doc) {
        var data = doc.data() as Map<String, dynamic>? ?? {};
        return (data['codigo'] ?? '').toString().toUpperCase().contains(_searchQuery);
      }).toList();
      docsErrores = docsErrores.where((doc) {
        var data = doc.data() as Map<String, dynamic>? ?? {};
        return (data['codigo'] ?? '').toString().toUpperCase().contains(_searchQuery);
      }).toList();
    }

    int materialPerdido = 0;
    for(var errorDoc in docsErrores) {
      var data = errorDoc.data() as Map<String, dynamic>? ?? {};
      materialPerdido += (data['material_perdido'] ?? 1) as int;
    }

    int totalMaterialUsado = docsEmisiones.length + materialPerdido;

    if (format == "Excel") {
      _showExcelPreview(docsEmisiones, totalMaterialUsado);
    } else {
      _showPdfConfirmDialog(docsEmisiones, docsErrores, totalMaterialUsado);
    }
  }

  void _showExcelPreview(List<DocumentSnapshot> docs, int totalMaterial) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Vista Previa Excel", style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Total registros a exportar: ${docs.length}"),
              if (_selectedCicloName != null) ...[
                const SizedBox(height: 4),
                Text("Ciclo Académico: $_selectedCicloName", style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.indigo)),
              ],
              const SizedBox(height: 10),
              Flexible(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Código')),
                        DataColumn(label: Text('Nombre')),
                        DataColumn(label: Text('Sede')),
                        DataColumn(label: Text('Operador')),
                      ],
                      rows: docs.take(10).map((doc) {
                        var data = doc.data() as Map<String, dynamic>? ?? {};
                        return DataRow(cells: [
                          DataCell(Text(data['codigo']?.toString() ?? '')),
                          DataCell(Text(data['nombre']?.toString() ?? '')),
                          DataCell(Text(data['sede']?.toString() ?? '')),
                          DataCell(Text(data['atendidoPor']?.toString() ?? '')),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
              ),
              if (docs.length > 10) Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text("... y ${docs.length - 10} registros más", style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
              ),
              const Divider(),
              Text("Consumo estimado: $totalMaterial PVC", style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade800),
            icon: const Icon(Icons.share, color: Colors.white),
            label: const Text("COMPARTIR EXCEL", style: TextStyle(color: Colors.white)),
            onPressed: () {
              Navigator.pop(context);
              _generateExcel(docs, totalMaterial);
            },
          ),
        ],
      ),
    );
  }

  void _showPdfConfirmDialog(List<DocumentSnapshot> emi, List<DocumentSnapshot> err, int total) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Generar Reporte PDF", style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Emisiones: ${emi.length}"),
            Text("Errores: ${err.length}"),
            Text("Total PVC usado: $total"),
            if (_selectedCicloName != null) ...[
              const SizedBox(height: 8),
              Text("Ciclo Académico Seleccionado: $_selectedCicloName", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
            ],
            const SizedBox(height: 10),
            const Text("El PDF se generará en formato horizontal para incluir las firmas."),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800),
            onPressed: () {
              Navigator.pop(context);
              _generatePdf(emi, total);
            },
            child: const Text("GENERAR PDF", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _generatePdf(List<DocumentSnapshot> emissions, int totalMaterial) async {
    final pdf = pw.Document();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape, // Orientación horizontal
      margin: const pw.EdgeInsets.all(32),
      build: (pw.Context context) => [
        pw.Header(level: 0, child: pw.Text("REPORTE OFICIAL COC UNIVO - AUDITORÍA DE MATERIALES")),
        pw.Text(_selectedCicloName != null 
            ? "Ciclo Académico Seleccionado: $_selectedCicloName" 
            : "Periodo: ${DateFormat('dd/MM/yy').format(_selectedDateRange.start)} al ${DateFormat('dd/MM/yy').format(_selectedDateRange.end)}"),
        pw.SizedBox(height: 15),
        pw.Text("RESUMEN DE CONSUMO:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.Bullet(text: "Total Tarjetas PVC Usadas: $totalMaterial"),
        pw.Bullet(text: "Emisiones Exitosas: ${emissions.length}"),
        pw.SizedBox(height: 15),

        pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FlexColumnWidth(1),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(2), // Carrera
              3: const pw.FlexColumnWidth(1.5), // Trámite
              4: const pw.FlexColumnWidth(1), // Sede
              5: const pw.FlexColumnWidth(1.5), // Operador
              6: const pw.FlexColumnWidth(1.2), // Fecha
              7: const pw.FlexColumnWidth(1.5), // Espacio para firma
            },
            children: [
              pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.indigo),
                  children: [
                    _pdfCell("Código", isHeader: true),
                    _pdfCell("Nombre", isHeader: true),
                    _pdfCell("Carrera", isHeader: true),
                    _pdfCell("Trámite", isHeader: true),
                    _pdfCell("Sede", isHeader: true),
                    _pdfCell("Operador", isHeader: true),
                    _pdfCell("Fecha", isHeader: true),
                    _pdfCell("Firma", isHeader: true),
                  ]
              ),
              ...emissions.map((doc) {
                var data = doc.data() as Map<String, dynamic>? ?? {};
                Uint8List? signatureBytes;
                if (data['firma'] != null) {
                  try {
                    signatureBytes = base64Decode(data['firma']);
                  } catch (_) {}
                }

                String formattedDate = '';
                if (data['fechaRegistro'] is Timestamp) {
                  formattedDate = DateFormat('dd/MM HH:mm').format((data['fechaRegistro'] as Timestamp).toDate());
                }

                return pw.TableRow(
                    verticalAlignment: pw.TableCellVerticalAlignment.middle,
                    children: [
                      _pdfCell(data['codigo']?.toString() ?? ''),
                      _pdfCell(data['nombre']?.toString() ?? ''),
                      _pdfCell(data['carrera']?.toString() ?? ''),
                      _pdfCell((data['typeTramite'] ?? data['tipoTramite'] ?? '').toString()),
                      _pdfCell(data['sede']?.toString() ?? ''),
                      _pdfCell(data['atendidoPor']?.toString() ?? ''),
                      _pdfCell(formattedDate),
                      signatureBytes != null
                          ? pw.Padding(
                          padding: const pw.EdgeInsets.all(2),
                          child: pw.Image(pw.MemoryImage(signatureBytes), height: 25)
                      )
                          : _pdfCell("Sin firma"),
                    ]
                );
              }).toList(),
            ]
        ),
      ],
    ));
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  pw.Widget _pdfCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          color: isHeader ? PdfColors.white : PdfColors.black,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  Future<void> _generateExcel(List<DocumentSnapshot> emissions, int totalMaterial) async {
    var excel = Excel.createExcel();
    Sheet sheet = excel['Auditoria'];
    excel.delete('Sheet1');

    sheet.appendRow([TextCellValue('REPORTE COC UNIVO - AUDITORÍA DE MATERIALES')]);
    if (_selectedCicloName != null) {
      sheet.appendRow([TextCellValue('Ciclo Académico Seleccionado: $_selectedCicloName')]);
    } else {
      sheet.appendRow([TextCellValue('Periodo: ${DateFormat('dd/MM/yy').format(_selectedDateRange.start)} al ${DateFormat('dd/MM/yy').format(_selectedDateRange.end)}')]);
    }
    sheet.appendRow([]);

    sheet.appendRow([
      TextCellValue('CÓDIGO'),
      TextCellValue('ESTUDIANTE'),
      TextCellValue('CARRERA'),
      TextCellValue('TRAMITE'),
      TextCellValue('SEDE'),
      TextCellValue('OPERADOR'),
      TextCellValue('FECHA'),
      TextCellValue('CICLO REGISTRADO')
    ]);

    for (var doc in emissions) {
      var data = doc.data() as Map<String, dynamic>? ?? {};
      String formattedDate = '';
      if (data['fechaRegistro'] is Timestamp) {
        formattedDate = DateFormat('dd/MM/yy HH:mm').format((data['fechaRegistro'] as Timestamp).toDate());
      }
      sheet.appendRow([
        TextCellValue(data['codigo']?.toString() ?? ''),
        TextCellValue(data['nombre']?.toString() ?? ''),
        TextCellValue(data['carrera']?.toString() ?? ''),
        TextCellValue((data['tipoTramite'] ?? data['typeTramite'] ?? '').toString()),
        TextCellValue(data['sede']?.toString() ?? ''),
        TextCellValue(data['atendidoPor']?.toString() ?? ''),
        TextCellValue(formattedDate),
        TextCellValue(data['ciclo']?.toString() ?? 'N/A'),
      ]);
    }

    sheet.appendRow([]);
    sheet.appendRow([TextCellValue('RESUMEN DE CONSUMO DE MATERIAL')]);
    sheet.appendRow([TextCellValue('Tarjetas PVC (Éxitos + Errores):'), TextCellValue(totalMaterial.toString())]);

    var fileBytes = excel.save();
    final directory = await getTemporaryDirectory();
    final filePath = "${directory.path}/Auditoria_COC_${DateTime.now().millisecondsSinceEpoch}.xlsx";
    File(filePath)..createSync(recursive: true)..writeAsBytesSync(fileBytes!);
    await Share.shareXFiles([XFile(filePath)], text: 'Reporte Excel COC');
  }
}