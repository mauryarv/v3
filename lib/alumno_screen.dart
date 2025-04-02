// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v3/detalle_visita_screen.dart';
import 'package:v3/login_screen.dart';
import 'package:v3/subir_archivo_screen.dart';
import 'package:intl/intl.dart';

class AlumnoScreen extends StatefulWidget {
  final String alumnoId;

  const AlumnoScreen({super.key, required this.alumnoId});

  @override
  _AlumnoScreenState createState() => _AlumnoScreenState();
}

class _AlumnoScreenState extends State<AlumnoScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> visitas = [];
  String? alumnoNombre;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      setState(() => _isLoading = true);
      await Future.wait([_cargarNombreAlumno(), _cargarVisitas()]);
    } catch (e) {
      _mostrarError('Error al cargar datos: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } catch (e) {
      _mostrarError("Error al cerrar sesión");
    }
  }

  Future<void> _cargarNombreAlumno() async {
    final snapshot =
        await _firestore.collection('usuarios').doc(widget.alumnoId).get();
    if (snapshot.exists && mounted) {
      setState(() => alumnoNombre = snapshot['nombre']);
    }
  }

  Future<void> _cargarVisitas() async {
    final visitasSnapshot =
        await _firestore
            .collection('visitas_escolares')
            .where('alumnos', arrayContains: widget.alumnoId)
            .get();

    final visitasList =
        visitasSnapshot.docs.map((doc) {
          final data = doc.data();
          final archivosPendientes =
              (data['archivos_pendientes'] ?? [])
                  .where((archivo) => archivo['alumnoId'] == widget.alumnoId)
                  .toList();

          return {
            'id': doc.id,
            'titulo': data['titulo'],
            'empresa': data['empresa'],
            'fecha_hora': data['fecha_hora']?.toDate(),
            'profesor': data['profesor'],
            'archivos_pendientes': archivosPendientes,
          };
        }).toList();

    if (mounted) setState(() => visitas = visitasList);
  }

  void _navegarASubirArchivo(String visitaId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => SubirArchivoScreen(
              visitaId: visitaId,
              alumnoId: widget.alumnoId,
              onArchivoSubido: _cargarDatos,
            ),
      ),
    );
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
      title: LayoutBuilder(
        builder: (context, constraints) {
          // Mostrar solo el icono y nombre en pantallas pequeñas
          if (constraints.maxWidth < 400) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.school, color: Colors.white, size: 24),
                SizedBox(width: 8),
                Text(
                  'Visitas',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
              ],
            );
          }
          // Mostrar título completo en pantallas más grandes
          return Text(
            'Visitas Escolares',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 20,
            ),
          );
        },
      ),
      actions: [
        // Nombre del usuario con diseño adaptable
        LayoutBuilder(
          builder: (context, constraints) {
            final showFullName = constraints.maxWidth > 350;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person, color: Colors.amber[200], size: 20),
                  if (showFullName) ...[
                    SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        alumnoNombre ?? "Alumno",
                        style: GoogleFonts.roboto(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
        IconButton(
          icon: Icon(Icons.logout, size: 22),
          onPressed: _logout,
          tooltip: 'Cerrar sesión',
          color: Colors.white,
        ),
      ],
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

  Widget _buildVisitaCard(Map<String, dynamic> visita) {
    final fechaHora = visita['fecha_hora'] as DateTime?;
    final archivosPendientes = visita['archivos_pendientes'] as List<dynamic>;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DetalleVisitaScreen(visitaId: visita['id']),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      visita['titulo'] ?? 'Sin título',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[800],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (archivosPendientes.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${archivosPendientes.length} archivo(s)',
                        style: GoogleFonts.roboto(
                          color: Colors.orange[800],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.business, visita['empresa'] ?? 'Sin empresa'),
              _buildInfoRow(
                Icons.person,
                'Profesor: ${visita['profesor'] ?? 'No asignado'}',
              ),
              if (fechaHora != null)
                _buildInfoRow(
                  Icons.calendar_today,
                  DateFormat('dd/MM/yyyy - HH:mm').format(fechaHora),
                ),
              const SizedBox(height: 12),
              if (archivosPendientes.isNotEmpty) ...[
                Text(
                  'Archivos pendientes:',
                  style: GoogleFonts.roboto(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                ...archivosPendientes.map<Widget>((archivo) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.insert_drive_file,
                          size: 16,
                          color: _getEstadoColor(archivo['estado']),
                        ),
                        Expanded(
                          child: Text(
                            archivo['nombre'] ?? 'Sin nombre',
                            style: GoogleFonts.roboto(
                              fontSize: 14,
                              color: Colors.grey[800],
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getEstadoColor(
                              archivo['estado'],
                            ).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            archivo['estado'] ?? 'pendiente',
                            style: GoogleFonts.roboto(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _getEstadoColor(archivo['estado']),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _navegarASubirArchivo(visita['id']),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Subir archivo',
                    style: GoogleFonts.roboto(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.roboto(fontSize: 14, color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }

  Color _getEstadoColor(String? estado) {
    switch (estado) {
      case 'aprobado':
        return Colors.green;
      case 'rechazado':
        return Colors.red;
      default:
        return Colors.orange;
    }
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
              : visitas.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.assignment, size: 60, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No tienes visitas asignadas',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              )
              : SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 24,
                  vertical: 16,
                ),
                child: Column(children: visitas.map(_buildVisitaCard).toList()),
              ),
    );
  }
}
