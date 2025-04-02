// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
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

  // Cambiamos el tipo de retorno a PreferredSizeWidget
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        "Visitas Escolares V3",
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
                PopupMenuItem<String>(
                  value: 'about',
                  child: Text(
                    'Acerca de la aplicación',
                    style: GoogleFonts.roboto(),
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'credits',
                  child: Text('Créditos', style: GoogleFonts.roboto()),
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
        crossAxisAlignment: CrossAxisAlignment.center, // Cambiado a center
        children: [
          SizedBox(height: 10),
          Center(
            // Widget Center añadido
            child: Text(
              "Verificación",
              style: GoogleFonts.caveat(
                fontSize: 30,
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Contenido principal (lista de archivos)
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
                                              archivos: archivosAlumno,
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
