// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:universal_html/html.dart' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';

import 'package:v3/archivos_alumno_screen.dart';

class AprobarArchivosScreen extends StatefulWidget {
  final String visitaId;

  const AprobarArchivosScreen({super.key, required this.visitaId});

  @override
  _AprobarArchivosScreenState createState() => _AprobarArchivosScreenState();
}

class _AprobarArchivosScreenState extends State<AprobarArchivosScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final bool _isLoading = false;
  bool _generandoReporte = false;

  Future<String> _obtenerNombreAlumno(String alumnoId) async {
    try {
      DocumentSnapshot alumnoDoc =
          await _firestore.collection("usuarios").doc(alumnoId).get();
      if (alumnoDoc.exists) {
        return alumnoDoc["nombre"] ?? "Alumno desconocido";
      }
    } catch (e) {
      _mostrarError("Error al obtener nombre del alumno: $e");
    }
    return "Alumno desconocido";
  }

  String _determinarEstadoArchivos(List<Map<String, dynamic>> archivos) {
    bool todosAprobados = archivos.every(
      (archivo) => archivo["estado"] == "aprobado",
    );
    bool todosRechazados = archivos.every(
      (archivo) => archivo["estado"] == "rechazado",
    );

    if (todosAprobados) return "aprobado";
    if (todosRechazados) return "rechazado";
    return "pendiente";
  }

  Future<pw.Document> _generatePdf(
    Map<String, List<Map<String, dynamic>>> archivosPorAlumno,
  ) async {
    final pdf = pw.Document();
    final alumnos = archivosPorAlumno.entries.toList();

    final nombresAlumnos = <String, String>{};
    for (var entry in alumnos) {
      nombresAlumnos[entry.key] = await _obtenerNombreAlumno(entry.key);
    }

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text(
                  'Reporte de Archivos - Visita Escolar',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Visita ID: ${widget.visitaId}',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.Text(
                'Fecha de reporte: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 30),
              pw.Text(
                'Total de alumnos: ${archivosPorAlumno.length}',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              for (var entry in alumnos)
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Alumno: ${nombresAlumnos[entry.key]}',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'ID: ${entry.key}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Table(
                      border: pw.TableBorder.all(),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(2),
                        1: const pw.FlexColumnWidth(1.5),
                        2: const pw.FlexColumnWidth(2),
                      },
                      children: [
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.grey200,
                          ),
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                'Tipo de Archivo',
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                'Estado',
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                'Fecha Subida',
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        for (var archivo in entry.value)
                          pw.TableRow(
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text(
                                  archivo['tipo']?.toString() ?? 'Sin tipo',
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text(
                                  archivo['estado']?.toString().toUpperCase() ??
                                      'PENDIENTE',
                                  style: pw.TextStyle(
                                    color:
                                        archivo['estado'] == 'aprobado'
                                            ? PdfColors.green
                                            : archivo['estado'] == 'rechazado'
                                            ? PdfColors.red
                                            : PdfColors.orange,
                                  ),
                                ),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Text(
                                  archivo['fechaSubida'] != null
                                      ? DateFormat('dd/MM/yyyy HH:mm').format(
                                        (archivo['fechaSubida'] as Timestamp)
                                            .toDate(),
                                      )
                                      : 'No disponible',
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    pw.SizedBox(height: 20),
                  ],
                ),
              pw.Footer(
                title: pw.Text(
                  'Generado por Visitas Escolares App - ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  Future<void> _guardarReporte() async {
    try {
      setState(() => _generandoReporte = true);

      final snapshot =
          await _firestore
              .collection("visitas_escolares")
              .doc(widget.visitaId)
              .get();

      if (!snapshot.exists) {
        _mostrarError("No se encontraron datos de la visita");
        return;
      }

      Map<String, dynamic>? data = snapshot.data();
      List<dynamic> archivosPendientes = data?["archivos_pendientes"] ?? [];

      if (archivosPendientes.isEmpty) {
        _mostrarError("No hay archivos para generar el reporte");
        return;
      }

      // Agrupar archivos por alumno
      Map<String, List<Map<String, dynamic>>> archivosPorAlumno = {};
      for (var archivo in archivosPendientes) {
        String alumnoId = archivo["alumnoId"] ?? "sin_alumno";
        if (!archivosPorAlumno.containsKey(alumnoId)) {
          archivosPorAlumno[alumnoId] = [];
        }
        archivosPorAlumno[alumnoId]!.add(archivo);
      }

      // Generar PDF
      final pdf = await _generatePdf(archivosPorAlumno);
      final bytes = await pdf.save();

      if (kIsWeb) {
        // Implementación para web
        final blob = html.Blob([bytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final fecha = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final anchor =
            html.document.createElement('a') as html.AnchorElement
              ..href = url
              ..style.display = 'none'
              ..download = 'reporte_visita_${widget.visitaId}_$fecha.pdf';

        html.document.body?.children.add(anchor);
        anchor.click();

        Future.delayed(const Duration(milliseconds: 500), () {
          html.document.body?.children.remove(anchor);
          html.Url.revokeObjectUrl(url);
        });
      } else {
        // Implementación para móvil/desktop - Versión mejorada
        try {
          // Usar el directorio de documentos de la aplicación
          final directory = await getApplicationDocumentsDirectory();
          final saveDir = Directory('${directory.path}/ReportesVisitas');

          // Crear directorio si no existe
          if (!await saveDir.exists()) {
            await saveDir.create(recursive: true);
          }

          // Generar nombre de archivo
          final fecha = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
          final fileName = 'reporte_visita_${widget.visitaId}_$fecha.pdf';
          final filePath = '${saveDir.path}/$fileName';

          // Guardar archivo
          final file = File(filePath);
          await file.writeAsBytes(bytes);

          _mostrarExito('Reporte generado exitosamente');

          // Intentar abrir el archivo
          try {
            await OpenFile.open(filePath);
          } catch (e) {
            debugPrint('Error al abrir el archivo: $e');
            _mostrarExito('Reporte guardado en: ${file.path}');
          }
        } catch (e) {
          _mostrarError('Error al guardar el reporte: $e');
          debugPrint('Error detallado: $e');
        }
      }
    } catch (e) {
      _mostrarError('Error al generar el reporte: $e');
      debugPrint('Error detallado: $e');
    } finally {
      if (mounted) {
        setState(() => _generandoReporte = false);
      }
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _mostrarExito(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        "Revisión de Archivos",
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      centerTitle: true,
      backgroundColor: Colors.blue,
      elevation: 4,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4C60AF), Color.fromARGB(255, 37, 195, 248)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      actions: <Widget>[
        if (_generandoReporte)
          const Padding(
            padding: EdgeInsets.all(12.0),
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 2,
            ),
          )
        else
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            onPressed: _guardarReporte,
            tooltip: 'Generar reporte PDF',
          ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: (value) {
            if (value == 'about') {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text(
                      'Acerca de la aplicación',
                      style: GoogleFonts.poppins(),
                    ),
                    content: Text(
                      'Esta aplicación fue desarrollada para facilitar la gestión de visitas escolares del CECyT 3. '
                      'Su objetivo es proporcionar una herramienta eficiente para administradores, profesores y alumnos.',
                      style: GoogleFonts.roboto(),
                    ),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cerrar'),
                      ),
                    ],
                  );
                },
              );
            } else if (value == 'credits') {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text('Créditos', style: GoogleFonts.poppins()),
                    content: Text(
                      'Aplicación desarrollada por Reyes Vaca Mauricio Alberto.\n'
                      '© 2025 Todos los derechos reservados.',
                      style: GoogleFonts.roboto(),
                    ),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cerrar'),
                      ),
                    ],
                  );
                },
              );
            }
          },
          itemBuilder:
              (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'about',
                  child: Text('Acerca de la aplicación'),
                ),
                const PopupMenuItem<String>(
                  value: 'credits',
                  child: Text('Créditos'),
                ),
              ],
        ),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Text(
          message,
          style: GoogleFonts.roboto(fontSize: 16, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildAlumnoCard({
    required String nombreAlumno,
    required String estadoArchivos,
    required VoidCallback onPressed,
  }) {
    IconData icon;
    Color iconColor;

    switch (estadoArchivos) {
      case "aprobado":
        icon = Icons.check_circle;
        iconColor = Colors.green;
        break;
      case "rechazado":
        icon = Icons.cancel;
        iconColor = Colors.red;
        break;
      default:
        icon = Icons.warning;
        iconColor = Colors.orange;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  nombreAlumno,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(icon, color: iconColor, size: 28),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: Colors.grey[600]),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Text(
              "Verificación de Documentos",
              style: GoogleFonts.caveat(
                fontSize: 30,
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child:
                _isLoading
                    ? _buildLoadingIndicator()
                    : StreamBuilder<DocumentSnapshot>(
                      stream:
                          _firestore
                              .collection("visitas_escolares")
                              .doc(widget.visitaId)
                              .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return _buildLoadingIndicator();
                        }

                        if (!snapshot.hasData || snapshot.data == null) {
                          return _buildEmptyState(
                            "No se encontraron datos de la visita",
                          );
                        }

                        Map<String, dynamic>? data =
                            snapshot.data!.data() as Map<String, dynamic>?;
                        List<dynamic> archivosPendientes =
                            data?["archivos_pendientes"] ?? [];

                        if (archivosPendientes.isEmpty) {
                          return _buildEmptyState(
                            "No hay archivos pendientes de revisión",
                          );
                        }

                        // Agrupar archivos por alumnoId
                        Map<String, List<Map<String, dynamic>>>
                        archivosPorAlumno = {};
                        for (var archivo in archivosPendientes) {
                          String alumnoId = archivo["alumnoId"] ?? "sin_alumno";
                          if (!archivosPorAlumno.containsKey(alumnoId)) {
                            archivosPorAlumno[alumnoId] = [];
                          }
                          archivosPorAlumno[alumnoId]!.add(archivo);
                        }

                        return ListView.builder(
                          padding: EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: isMobile ? 8 : 24,
                          ),
                          itemCount: archivosPorAlumno.length,
                          itemBuilder: (context, index) {
                            String alumnoId = archivosPorAlumno.keys.elementAt(
                              index,
                            );
                            List<Map<String, dynamic>> archivosAlumno =
                                archivosPorAlumno[alumnoId]!;

                            return FutureBuilder<String>(
                              future: _obtenerNombreAlumno(alumnoId),
                              builder: (context, nombreSnapshot) {
                                if (nombreSnapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return _buildLoadingIndicator();
                                }

                                String nombreAlumno =
                                    nombreSnapshot.data ?? "Alumno desconocido";
                                String estadoArchivos =
                                    _determinarEstadoArchivos(archivosAlumno);

                                return _buildAlumnoCard(
                                  nombreAlumno: nombreAlumno,
                                  estadoArchivos: estadoArchivos,
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => ArchivosAlumnoScreen(
                                              visitaId: widget.visitaId,
                                              alumnoId: alumnoId,
                                              nombreAlumno: nombreAlumno,
                                            ),
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
