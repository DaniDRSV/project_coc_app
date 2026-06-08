import 'dart:convert';
import 'dart:io';
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

  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
    end: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59),
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _applyQuickFilter(String filter) {
    DateTime now = DateTime.now();
    setState(() {
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

  void _seleccionarAno(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text("Seleccionar Año", style: TextStyle(color: Color(0xff1a237e), fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 300,
            height: 300,
            child: YearPicker(
              firstDate: DateTime(2024),
              lastDate: DateTime(DateTime.now().year + 5),
              initialDate: DateTime.now(),
              selectedDate: _selectedDateRange.start,
              onChanged: (DateTime dateTime) {
                setState(() {
                  _selectedDateRange = DateTimeRange(
                    start: DateTime(dateTime.year, 1, 1),
                    end: DateTime(dateTime.year, 12, 31, 23, 59, 59),
                  );
                });
                Navigator.pop(context);
              },
            ),
          ),
        );
      },
    );
  }

  void _mostrarDialogoReporteError(DocumentSnapshot emisionDoc) async {
    var u = FirebaseAuth.instance.currentUser;
    var userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(u?.uid).get();
    String rol = userDoc.data()?['rol'] ?? 'operador';
    String nombreOp = userDoc.data()?['nombre'] ?? 'Operador';
    String sedeOp = userDoc.data()?['sede'] ?? 'Sin sede';

    var permDoc = await FirebaseFirestore.instance.collection('configuracion').doc('permisos').get();
    bool puedeReportar = rol == 'admin' || (permDoc.data()?['perm_act_emi_error'] ?? true);

    if (!puedeReportar) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No tienes permiso para reportar errores.", style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.orange));
      return;
    }

    final motivoCtrl = TextEditingController();
    final cantidadCtrl = TextEditingController(text: "1");

    // Extracción segura de datos
    var data = emisionDoc.data() as Map<String, dynamic>? ?? {};
    String codigoEmision = data['codigo'] ?? 'S/C';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text("Reportar Error\n($codigoEmision)", style: const TextStyle(color: Color(0xff1a237e), fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Por cada intento fallido, se descontará automáticamente 1 Tarjeta PVC del inventario. El ciclo de tinta gastado quedará registrado en la auditoría.", style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 15),
              TextField(controller: motivoCtrl, decoration: const InputDecoration(labelText: "Motivo del error", border: OutlineInputBorder())),
              const SizedBox(height: 15),
              TextField(controller: cantidadCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Cantidad de intentos fallidos", border: OutlineInputBorder(), prefixIcon: Icon(Icons.error_outline))),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800, foregroundColor: Colors.white),
            icon: const Icon(Icons.warning_amber),
            label: const Text("REPORTAR"),
            onPressed: () async {
              if (motivoCtrl.text.isNotEmpty) {
                int cantidad = int.tryParse(cantidadCtrl.text) ?? 0;

                if (cantidad > 0) {
                  await FirebaseFirestore.instance.collection('errores_impresion').add({
                    'codigo': codigoEmision,
                    'motivo': motivoCtrl.text.trim(),
                    'material_perdido': cantidad,
                    'fecha': FieldValue.serverTimestamp(),
                    'reportadoPor': nombreOp,
                    'atendidoPorUid': u?.uid,
                    'sede': sedeOp,
                  });

                  await _descontarInventarioParcial('PVC', cantidad);

                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error reportado y tarjeta PVC descontada", style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.green));
                  }
                }
              }
            },
          )
        ],
      ),
    );
  }

  Future<void> _descontarInventarioParcial(String terminoBusqueda, int cantidad) async {
    try {
      var snapshot = await FirebaseFirestore.instance.collection('inventario').get();
      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>? ?? {};
        String nombreMaterial = (data['nombre'] ?? '').toString().toUpperCase();
        if (nombreMaterial.contains(terminoBusqueda.toUpperCase())) {
          await doc.reference.update({'cantidad': FieldValue.increment(-cantidad)});
        }
      }
    } catch (e) {
      print("Error ajustando inventario: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Auditoría y Reportes"),
        backgroundColor: const Color(0xff1a237e),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [Tab(text: "Emisiones"), Tab(text: "Errores")],
        ),
      ),
      body: Column(
        children: [
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
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: "btn_ex",
            onPressed: () => _showExportPreview("Excel"),
            backgroundColor: Colors.green.shade800,
            icon: const Icon(Icons.table_view, color: Colors.white),
            label: const Text("EXCEL", style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: "btn_pd",
            onPressed: () => _showExportPreview("PDF"),
            backgroundColor: Colors.red.shade800,
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            label: const Text("PDF", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _filterChip('Hoy'),
          _filterChip('Semana'),
          _filterChip('Mes'),
          ActionChip(
            label: const Text('Año'),
            onPressed: () => _seleccionarAno(context),
            backgroundColor: Colors.indigo.shade50,
            labelStyle: const TextStyle(color: Color(0xff1a237e), fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.date_range, color: Color(0xff1a237e)),
            onPressed: () async {
              final picked = await showDateRangePicker(context: context, firstDate: DateTime(2024), lastDate: DateTime.now());
              if (picked != null) {
                setState(() {
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

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      child: TextField(
        controller: _searchController,
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(
          hintText: "Filtrar por Código de Estudiante",
          prefixIcon: const Icon(Icons.search, color: Color(0xff1a237e)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value.trim().toUpperCase();
          });
        },
      ),
    );
  }

  Widget _filterChip(String label) {
    return ActionChip(
      label: Text(label),
      onPressed: () => _applyQuickFilter(label),
      backgroundColor: Colors.indigo.shade50,
      labelStyle: const TextStyle(color: Color(0xff1a237e), fontWeight: FontWeight.bold),
    );
  }

  Widget _buildFilterBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: const Color(0xff1a237e),
      child: Text(
        "Rango: ${DateFormat('dd/MM/yy').format(_selectedDateRange.start)} al ${DateFormat('dd/MM/yy').format(_selectedDateRange.end)}",
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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

        if (docs.isEmpty) return const Center(child: Text("Sin datos en este rango o búsqueda"));

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var doc = docs[index];
            var data = doc.data() as Map<String, dynamic>? ?? {};
            DateTime fecha = data[field] != null ? (data[field] as Timestamp).toDate() : DateTime.now();

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              child: ListTile(
                title: Text(data['codigo']?.toString() ?? 'S/C', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("${data[coll == 'emisiones_log' ? 'nombre' : 'motivo'] ?? 'Dato no disponible'}"),
                trailing: Text(DateFormat('dd/MM HH:mm').format(fecha)),
                onTap: coll == 'emisiones_log' ? () => _mostrarDialogoReporteError(doc) : null,
              ),
            );
          },
        );
      },
    );
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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Resumen de Auditoría ($format)"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Filtro aplicado: ${_searchQuery.isEmpty ? 'Todos' : _searchQuery}", style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("Emisiones Exitosas: ${docsEmisiones.length}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            Text("Errores Registrados: ${docsErrores.length}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            const Divider(),
            const Text("CONSUMO REAL DE MATERIAL:", style: TextStyle(fontWeight: FontWeight.bold)),
            Text("- Total Tarjetas PVC: $totalMaterialUsado"),
            Text("- Total Ciclos Cinta: $totalMaterialUsado"),
            const SizedBox(height: 10),
            const Text("¿Generar archivo de reporte?", style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
          ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                format == "PDF"
                    ? _generatePdf(docsEmisiones, totalMaterialUsado)
                    : _generateExcel(docsEmisiones, totalMaterialUsado);
              },
              child: const Text("GENERAR")
          ),
        ],
      ),
    );
  }

  Future<void> _generatePdf(List<DocumentSnapshot> e, int totalMaterial) async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      build: (pw.Context context) => [
        pw.Header(level: 0, child: pw.Text("REPORTE COC UNIVO - AUDITORÍA")),
        pw.Text("Periodo: ${DateFormat('dd/MM/yy').format(_selectedDateRange.start)} - ${DateFormat('dd/MM/yy').format(_selectedDateRange.end)}"),
        if (_searchQuery.isNotEmpty) pw.Text("Filtro de búsqueda: $_searchQuery"),
        pw.SizedBox(height: 20),
        pw.Text("RESUMEN DE CONSUMO:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.Bullet(text: "Total Tarjetas PVC Usadas: $totalMaterial"),
        pw.Bullet(text: "Total Ciclos de Cinta Usados: $totalMaterial"),
        pw.Bullet(text: "Emisiones Exitosas: ${e.length}"),
        pw.SizedBox(height: 20),

        pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Código', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Nombre', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Operador', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Fecha', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Firma', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                ],
              ),
              ...e.map((doc) {
                var data = doc.data() as Map<String, dynamic>? ?? {};
                pw.Widget firmaWidget = pw.SizedBox();
                if (data['firma'] != null) {
                  try {
                    firmaWidget = pw.Image(pw.MemoryImage(base64Decode(data['firma'])), width: 40, height: 20);
                  } catch (_) {}
                }

                DateTime fecha = data['fechaRegistro'] != null ? (data['fechaRegistro'] as Timestamp).toDate() : DateTime.now();

                return pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(data['codigo']?.toString() ?? '', style: const pw.TextStyle(fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(data['nombre']?.toString() ?? '', style: const pw.TextStyle(fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(data['atendidoPor']?.toString() ?? '', style: const pw.TextStyle(fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(DateFormat('dd/MM/yyyy').format(fecha), style: const pw.TextStyle(fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Center(child: firmaWidget)),
                    ]
                );
              }).toList(),
            ]
        ),
      ],
    ));
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  Future<void> _generateExcel(List<DocumentSnapshot> e, int totalMaterial) async {
    var excel = Excel.createExcel();
    Sheet s = excel['Reporte Auditoria'];
    excel.delete('Sheet1');

    s.appendRow([TextCellValue('REPORTE COC UNIVO - AUDITORÍA DE MATERIALES')]);
    s.appendRow([TextCellValue('Periodo: ${DateFormat('dd/MM/yy').format(_selectedDateRange.start)} al ${DateFormat('dd/MM/yy').format(_selectedDateRange.end)}')]);
    if (_searchQuery.isNotEmpty) s.appendRow([TextCellValue('Filtro de búsqueda: $_searchQuery')]);
    s.appendRow([]);

    s.appendRow([TextCellValue('CÓDIGO'), TextCellValue('ESTUDIANTE'), TextCellValue('TRÁMITE'), TextCellValue('OPERADOR'), TextCellValue('FECHA')]);
    for (var doc in e) {
      var data = doc.data() as Map<String, dynamic>? ?? {};
      DateTime fecha = data['fechaRegistro'] != null ? (data['fechaRegistro'] as Timestamp).toDate() : DateTime.now();

      s.appendRow([
        TextCellValue(data['codigo']?.toString() ?? ''),
        TextCellValue(data['nombre']?.toString() ?? ''),
        TextCellValue(data['tipoTramite']?.toString() ?? ''),
        TextCellValue(data['atendidoPor']?.toString() ?? ''),
        TextCellValue(DateFormat('dd/MM/yy HH:mm').format(fecha)),
      ]);
    }

    s.appendRow([]);
    s.appendRow([TextCellValue('RESUMEN DE CONSUMO')]);
    s.appendRow([TextCellValue('Total Tarjetas PVC Usadas:'), TextCellValue(totalMaterial.toString())]);
    s.appendRow([TextCellValue('Total Ciclos Cinta Usados:'), TextCellValue(totalMaterial.toString())]);

    var bytes = excel.save();
    final dir = await getTemporaryDirectory();
    final path = "${dir.path}/Reporte_Auditoria.xlsx";
    File(path)..createSync(recursive: true)..writeAsBytesSync(bytes!);
    await Share.shareXFiles([XFile(path)], text: 'Reporte Excel COC');
  }
}