import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
    end: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59),
  );
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
          end: now,
        );
      } else if (filter == 'Mes') {
        _selectedDateRange = DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: now,
        );
      }
    });
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
          IconButton(
            icon: const Icon(Icons.date_range, color: Color(0xff1a237e)),
            onPressed: () async {
              final picked = await showDateRangePicker(context: context, firstDate: DateTime(2024), lastDate: DateTime.now());
              if (picked != null) setState(() => _selectedDateRange = picked);
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
        if (snapshot.data!.docs.isEmpty) return const Center(child: Text("Sin datos en este rango"));

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            DateTime fecha = (doc[field] as Timestamp).toDate();
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              child: ListTile(
                title: Text(doc['codigo'] ?? 'S/C', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("${doc[coll == 'emisiones_log' ? 'nombre' : 'motivo']}"),
                trailing: Text(DateFormat('dd/MM HH:mm').format(fecha)),
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

    int totalTarjetas = snapE.docs.length + snapErr.docs.length;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Resumen de Auditoría ($format)"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Emisiones Exitosas: ${snapE.docs.length}"),
            Text("Errores (Material Perdido): ${snapErr.docs.length}"),
            const Divider(),
            const Text("CONSUMO DE MATERIAL:", style: TextStyle(fontWeight: FontWeight.bold)),
            Text("- Tarjetas PVC: $totalTarjetas"),
            Text("- Ciclos de Cinta: $totalTarjetas"),
            const SizedBox(height: 10),
            const Text("¿Generar archivo de reporte?", style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              format == "PDF" ? _generatePdf(snapE, snapErr) : _generateExcel(snapE, snapErr);
            }, 
            child: const Text("GENERAR")
          ),
        ],
      ),
    );
  }

  Future<void> _generatePdf(QuerySnapshot e, QuerySnapshot err) async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      build: (pw.Context context) => [
        pw.Header(level: 0, child: pw.Text("REPORTE COC UNIVO - AUDITORÍA")),
        pw.Text("Periodo: ${DateFormat('dd/MM/yy').format(_selectedDateRange.start)} - ${DateFormat('dd/MM/yy').format(_selectedDateRange.end)}"),
        pw.SizedBox(height: 20),
        pw.Text("RESUMEN DE CONSUMO:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.Bullet(text: "Total Tarjetas Usadas: ${e.docs.length + err.docs.length}"),
        pw.Bullet(text: "Emisiones Exitosas: ${e.docs.length}"),
        pw.SizedBox(height: 20),
        pw.Table.fromTextArray(
          headers: ['Código', 'Nombre', 'Operador', 'Fecha'],
          data: e.docs.map((doc) => [doc['codigo'], doc['nombre'], doc['atendidoPor'], DateFormat('dd/MM').format((doc['fechaRegistro'] as Timestamp).toDate())]).toList(),
        ),
        pw.SizedBox(height: 30),
        pw.Text("DETALLE DE FIRMAS:"),
        pw.Wrap(
          spacing: 10, runSpacing: 10,
          children: e.docs.map((doc) {
            if (doc['firma'] == null) return pw.SizedBox();
            return pw.Column(children: [
              pw.Image(pw.MemoryImage(base64Decode(doc['firma'])), width: 80, height: 40),
              pw.Text(doc['codigo'], style: const pw.TextStyle(fontSize: 8)),
            ]);
          }).toList(),
        ),
      ],
    ));
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  Future<void> _generateExcel(QuerySnapshot e, QuerySnapshot err) async {
    var excel = Excel.createExcel();
    Sheet s = excel['Reporte Auditoria'];
    excel.delete('Sheet1');

    s.appendRow([TextCellValue('REPORTE COC UNIVO - AUDITORÍA DE MATERIALES')]);
    s.appendRow([TextCellValue('Periodo: ${DateFormat('dd/MM/yy').format(_selectedDateRange.start)} al ${DateFormat('dd/MM/yy').format(_selectedDateRange.end)}')]);
    s.appendRow([]);

    s.appendRow([TextCellValue('CÓDIGO'), TextCellValue('ESTUDIANTE'), TextCellValue('TRÁMITE'), TextCellValue('OPERADOR'), TextCellValue('FECHA')]);
    for (var doc in e.docs) {
      s.appendRow([
        TextCellValue(doc['codigo'] ?? ''),
        TextCellValue(doc['nombre'] ?? ''),
        TextCellValue(doc['tipoTramite'] ?? ''),
        TextCellValue(doc['atendidoPor'] ?? ''),
        TextCellValue(DateFormat('dd/MM/yy HH:mm').format((doc['fechaRegistro'] as Timestamp).toDate())),
      ]);
    }
    
    s.appendRow([]);
    s.appendRow([TextCellValue('RESUMEN DE CONSUMO')]);
    s.appendRow([TextCellValue('Total Tarjetas PVC:'), TextCellValue((e.docs.length + err.docs.length).toString())]);

    var bytes = excel.save();
    final dir = await getTemporaryDirectory();
    final path = "${dir.path}/Reporte_Auditoria.xlsx";
    File(path)..createSync(recursive: true)..writeAsBytesSync(bytes!);
    await Share.shareXFiles([XFile(path)], text: 'Reporte Excel COC');
  }
}
