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
        });

        if (visitaDetalles != null && visitaDetalles!['alumnos'] != null) {
          final alumnosIds = List<String>.from(visitaDetalles!['alumnos']);
          await _cargarNombresAlumnos(alumnosIds);
        }
      }
    } catch (e) {
      _mostrarError('Error al cargar los detalles de la visita');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarNombresAlumnos(List<String> alumnosIds) async {
    try {
      final nombres = <String>[];

      for (final alumnoId in alumnosIds) {
        final alumnoSnapshot =
            await _firestore.collection('usuarios').doc(alumnoId).get();
        if (alumnoSnapshot.exists) {
          nombres.add(alumnoSnapshot['nombre'] ?? 'Nombre no disponible');
        }
      }

      setState(() => nombresAlumnos = nombres);
    } catch (e) {
      _mostrarError('Error al cargar los nombres de los alumnos');
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

  Widget _buildAlumnosList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Alumnos Asignados',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.blue[800],
            ),
          ),
        ),
        if (nombresAlumnos.isEmpty)
          const Center(child: CircularProgressIndicator())
        else
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children:
                    nombresAlumnos
                        .map(
                          (nombre) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.person,
                                  size: 20,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  nombre,
                                  style: GoogleFonts.roboto(fontSize: 16),
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
                child: Text(
                  'No se encontraron detalles de la visita',
                  style: GoogleFonts.poppins(),
                ),
              )
              : SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 24,
                  vertical: 16,
                ),
                child: Column(
                  children: [
                    _buildInfoCard(
                      'Título',
                      visitaDetalles!['titulo'] ?? 'Sin título',
                      Icons.title,
                    ),
                    _buildInfoCard(
                      'Empresa',
                      visitaDetalles!['empresa'] ?? 'Desconocida',
                      Icons.business,
                    ),
                    _buildInfoCard(
                      'Profesor',
                      visitaDetalles!['profesor'] ?? 'No asignado',
                      Icons.school,
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
                      'Grupo',
                      visitaDetalles!['grupo'] ?? 'No asignado',
                      Icons.group,
                    ),
                    const SizedBox(height: 16),
                    _buildAlumnosList(),
                  ],
                ),
              ),
    );
  }
}
