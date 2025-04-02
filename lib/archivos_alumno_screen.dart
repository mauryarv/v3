// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';

class ArchivosAlumnoScreen extends StatefulWidget {
  final String visitaId;
  final String alumnoId;
  final String nombreAlumno;
  final List<Map<String, dynamic>> archivos;

  const ArchivosAlumnoScreen({
    super.key,
    required this.visitaId,
    required this.alumnoId,
    required this.nombreAlumno,
    required this.archivos,
  });

  @override
  _ArchivosAlumnoScreenState createState() => _ArchivosAlumnoScreenState();
}

class _ArchivosAlumnoScreenState extends State<ArchivosAlumnoScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;

  Future<void> _actualizarEstadoArchivo(
    Map<String, dynamic> archivo,
    String nuevoEstado,
  ) async {
    try {
      setState(() {
        _isLoading = true;
      });

      DocumentReference visitaRef = _firestore
          .collection("visitas_escolares")
          .doc(widget.visitaId);

      await visitaRef.update({
        "archivos_pendientes": FieldValue.arrayRemove([archivo]),
      });

      archivo["estado"] = nuevoEstado;
      await visitaRef.update({
        "archivos_pendientes": FieldValue.arrayUnion([archivo]),
      });

      _mostrarExito("Estado actualizado correctamente");
    } catch (e) {
      _mostrarError("Error al actualizar el estado del archivo: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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

  Widget _buildArchivoCard(Map<String, dynamic> archivo) {
    String nombre = archivo["nombre"] ?? "Sin nombre";
    String url = archivo["archivoUrl"] ?? "";
    String estado = archivo["estado"] ?? "pendiente";
    Color estadoColor;

    switch (estado) {
      case "aprobado":
        estadoColor = Colors.green;
        break;
      case "rechazado":
        estadoColor = Colors.red;
        break;
      default:
        estadoColor = Colors.orange;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          if (await canLaunchUrl(Uri.parse(url))) {
            await launchUrl(Uri.parse(url));
          } else {
            _mostrarError("No se pudo abrir el archivo");
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      nombre,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: estadoColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      estado.toUpperCase(),
                      style: GoogleFonts.roboto(
                        color: estadoColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildActionButton(
                    icon: Icons.check,
                    color: Colors.green,
                    onPressed:
                        () => _actualizarEstadoArchivo(archivo, "aprobado"),
                    tooltip: "Aprobar archivo",
                  ),
                  const SizedBox(width: 8),
                  _buildActionButton(
                    icon: Icons.close,
                    color: Colors.red,
                    onPressed:
                        () => _actualizarEstadoArchivo(archivo, "rechazado"),
                    tooltip: "Rechazar archivo",
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: Icon(icon, color: color),
          onPressed: onPressed,
          splashRadius: 24,
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
          // Título personalizado debajo del AppBar - ahora centrado
          Center(
            // Widget Center añadido
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 8.0, // Mantenemos solo padding vertical
              ),
              child: Text(
                widget.nombreAlumno,
                style: GoogleFonts.caveat(
                  fontSize: 30,
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // Contenido principal (lista de archivos)
          Expanded(
            child:
                _isLoading
                    ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                    )
                    : widget.archivos.isEmpty
                    ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text(
                          "No hay archivos para mostrar",
                          style: GoogleFonts.roboto(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    )
                    : ListView.builder(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 8 : 24,
                        vertical: 16,
                      ),
                      itemCount: widget.archivos.length,
                      itemBuilder: (context, index) {
                        return _buildArchivoCard(widget.archivos[index]);
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
