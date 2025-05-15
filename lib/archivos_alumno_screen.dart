// ignore_for_file: library_private_types_in_public_api, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';

class ArchivosAlumnoScreen extends StatefulWidget {
  final String visitaId;
  final String alumnoId;
  final String nombreAlumno;

  const ArchivosAlumnoScreen({
    super.key,
    required this.visitaId,
    required this.alumnoId,
    required this.nombreAlumno,
  });

  @override
  _ArchivosAlumnoScreenState createState() => _ArchivosAlumnoScreenState();
}

class _ArchivosAlumnoScreenState extends State<ArchivosAlumnoScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final List<String> _motivosRechazo = [
    'Documento ilegible',
    'Documento no coincide con el tipo requerido',
    'Documento vencido',
    'Falta información importante',
    'Documento no válido',
    'Otro motivo',
  ];

  Future<void> _actualizarEstadoArchivo(
    Map<String, dynamic> archivo,
    String nuevoEstado, {
    String? motivoRechazo,
  }) async {
    try {
      final visitaRef = _firestore
          .collection("visitas_escolares")
          .doc(widget.visitaId);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(visitaRef);
        if (!snapshot.exists) return;

        final archivosPendientes = List.from(
          snapshot.data()?['archivos_pendientes'] ?? [],
        );

        // Eliminar TODAS las versiones de este archivo del mismo tipo para el alumno
        archivosPendientes.removeWhere(
          (a) =>
              a['alumnoId'] == widget.alumnoId && a['tipo'] == archivo['tipo'],
        );

        // Agregar la nueva versión actualizada
        final nuevoArchivo = {
          ...archivo,
          'estado': nuevoEstado,
          'fechaSubida': Timestamp.now(),
          if (motivoRechazo != null) 'motivoRechazo': motivoRechazo,
        };

        archivosPendientes.add(nuevoArchivo);

        transaction.update(visitaRef, {
          'archivos_pendientes': archivosPendientes,
        });
      });

      _mostrarExito("Estado actualizado correctamente");
    } catch (e) {
      _mostrarError("Error al actualizar el estado del archivo: $e");
    } finally {
      if (mounted) {}
    }
  }

  Future<void> _mostrarDialogoMotivoRechazo(
    Map<String, dynamic> archivo,
  ) async {
    String? motivoSeleccionado;
    final otroMotivoController = TextEditingController();

    final confirmado = await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setState) {
              return Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.9,
                    maxHeight: MediaQuery.of(context).size.height * 0.7,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Motivo de rechazo',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.8,
                          ),
                          child: DropdownButtonFormField<String>(
                            value: motivoSeleccionado,
                            isExpanded:
                                true, // Hace que el dropdown ocupe todo el ancho disponible
                            items:
                                _motivosRechazo.map((motivo) {
                                  return DropdownMenuItem(
                                    value: motivo,
                                    child: Text(
                                      motivo,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.roboto(
                                        color: Colors.black,
                                      ),
                                    ),
                                  );
                                }).toList(),
                            onChanged:
                                (value) =>
                                    setState(() => motivoSeleccionado = value),
                            decoration: InputDecoration(
                              labelText: 'Seleccione motivo',
                              labelStyle: GoogleFonts.roboto(),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                            ),
                            style: GoogleFonts.roboto(),
                          ),
                        ),
                        if (motivoSeleccionado == 'Otro motivo') ...[
                          const SizedBox(height: 16),
                          TextField(
                            controller: otroMotivoController,
                            decoration: InputDecoration(
                              labelText: 'Especifique motivo',
                              labelStyle: GoogleFonts.roboto(),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                            ),
                            maxLines: 3,
                            maxLength: 200,
                            style: GoogleFonts.roboto(),
                          ),
                        ],
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(
                                'Cancelar',
                                style: GoogleFonts.roboto(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                              onPressed: () {
                                if (motivoSeleccionado == null ||
                                    (motivoSeleccionado == 'Otro motivo' &&
                                        otroMotivoController.text.isEmpty)) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Seleccione un motivo válido',
                                        style: GoogleFonts.roboto(),
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }
                                Navigator.pop(context, true);
                              },
                              child: Text(
                                'Confirmar',
                                style: GoogleFonts.roboto(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
    );

    if (confirmado == true && motivoSeleccionado != null) {
      final motivoFinal =
          motivoSeleccionado == 'Otro motivo'
              ? otroMotivoController.text
              : motivoSeleccionado!;

      await _actualizarEstadoArchivo(
        {...archivo, 'motivoRechazo': motivoFinal},
        "rechazado",
        motivoRechazo: motivoFinal,
      );
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
              if (estado == "rechazado" && archivo["motivoRechazo"] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "Motivo: ${archivo["motivoRechazo"]}",
                      style: GoogleFonts.roboto(
                        color: Colors.red[700],
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
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
                    onPressed: () => _mostrarDialogoMotivoRechazo(archivo),
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
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
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream:
                  _firestore
                      .collection("visitas_escolares")
                      .doc(widget.visitaId)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data == null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        "No hay datos de la visita",
                        style: GoogleFonts.roboto(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  );
                }

                final data = snapshot.data!.data() as Map<String, dynamic>?;
                final archivosPendientes = List.from(
                  data?['archivos_pendientes'] ?? [],
                );

                // Filtrar solo los archivos del alumno actual
                final archivosAlumno =
                    archivosPendientes
                        .where(
                          (archivo) => archivo['alumnoId'] == widget.alumnoId,
                        )
                        .toList();

                if (archivosAlumno.isEmpty) {
                  return Center(
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
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 8 : 24,
                    vertical: 16,
                  ),
                  itemCount: archivosAlumno.length,
                  itemBuilder: (context, index) {
                    return _buildArchivoCard(archivosAlumno[index]);
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
