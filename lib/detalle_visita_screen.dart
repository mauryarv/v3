// ignore_for_file: library_private_types_in_public_api

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class DetalleVisitaScreen extends StatefulWidget {
  final String visitaId;

  const DetalleVisitaScreen({super.key, required this.visitaId});

  @override
  _DetalleVisitaScreenState createState() => _DetalleVisitaScreenState();
}

class _DetalleVisitaScreenState extends State<DetalleVisitaScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? visitaDetalles;
  List<String> nombresAlumnos = [];
  List<String> nombresProfesores = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarDetallesVisita();
  }

  Future<void> _cargarDetallesVisita() async {
    try {
      setState(() => _isLoading = true);

      final visitaSnapshot =
          await _firestore
              .collection('visitas_escolares')
              .doc(widget.visitaId)
              .get();

      if (visitaSnapshot.exists) {
        setState(() {
          visitaDetalles = visitaSnapshot.data() as Map<String, dynamic>;
          // Los profesores ya están como nombres en el documento
          nombresProfesores =
              visitaDetalles!['profesores'] != null
                  ? List<String>.from(visitaDetalles!['profesores'])
                  : [];
        });

        if (visitaDetalles != null && visitaDetalles!['alumnos'] != null) {
          await _cargarNombresAlumnos(
            (visitaDetalles!['alumnos'] as List)
                .map((e) => e.toString())
                .toList(),
          );
        }
      }
    } catch (e) {
      _mostrarError('Error al cargar los detalles de la visita: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarNombresAlumnos(List<String> alumnosIds) async {
    try {
      if (alumnosIds.isEmpty) {
        setState(() => nombresAlumnos = []);
        return;
      }

      final query = _firestore
          .collection('usuarios')
          .where(FieldPath.documentId, whereIn: alumnosIds);

      final snapshot = await query.get();
      final nombres =
          snapshot.docs
              .map((doc) => doc['nombre']?.toString() ?? 'Nombre no disponible')
              .toList();

      setState(() => nombresAlumnos = nombres);
    } catch (e) {
      _mostrarError('Error al cargar los nombres de los alumnos: $e');
      setState(() => nombresAlumnos = ['Error al cargar nombres']);
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

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        'Detalles de la Visita',
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.w600,
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

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: Colors.blue),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.roboto(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListaPersonas({
    required String titulo,
    required List<String> nombres,
    required IconData icono,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            titulo,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.blue[800],
            ),
          ),
        ),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                nombres.isEmpty
                    ? Text(
                      'No hay $titulo',
                      style: GoogleFonts.roboto(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    )
                    : Column(
                      children:
                          nombres
                              .map(
                                (nombre) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        icono,
                                        size: 20,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Text(
                                          nombre,
                                          style: GoogleFonts.roboto(
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                    ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    return Scaffold(
      appBar: _buildAppBar(),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              )
              : visitaDetalles == null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 50,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No se encontraron detalles de la visita',
                      style: GoogleFonts.poppins(fontSize: 18),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _cargarDetallesVisita,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              )
              : RefreshIndicator(
                onRefresh: _cargarDetallesVisita,
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 24,
                    vertical: 16,
                  ),
                  child: Column(
                    children: [
                      _buildInfoCard(
                        'Ubicación',
                        visitaDetalles!['ubicacion']?.toString() ??
                            'Ubicación no disponible',
                        Icons.location_on,
                      ),
                      _buildInfoCard(
                        'Grupo',
                        visitaDetalles!['grupo']?.toString() ?? 'No asignado',
                        Icons.group,
                      ),
                      _buildInfoCard(
                        'Fecha y Hora',
                        visitaDetalles!['fecha_hora'] != null
                            ? DateFormat('dd/MM/yyyy - HH:mm').format(
                              (visitaDetalles!['fecha_hora'] as Timestamp)
                                  .toDate(),
                            )
                            : 'No definida',
                        Icons.calendar_today,
                      ),
                      _buildInfoCard(
                        'Observaciones',
                        visitaDetalles!['observaciones']?.toString() ??
                            'Sin observaciones',
                        Icons.note,
                      ),
                      const SizedBox(height: 16),
                      _buildListaPersonas(
                        titulo: 'Profesores Asignados',
                        nombres: nombresProfesores,
                        icono: Icons.school,
                      ),
                      const SizedBox(height: 16),
                      _buildListaPersonas(
                        titulo: 'Alumnos Asignados',
                        nombres: nombresAlumnos,
                        icono: Icons.person,
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}
