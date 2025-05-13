// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v3/detalle_visita_screen.dart';
import 'package:v3/login_screen.dart';

class ProfesorScreen extends StatefulWidget {
  const ProfesorScreen({super.key});

  @override
  _ProfesorScreenState createState() => _ProfesorScreenState();
}

class _ProfesorScreenState extends State<ProfesorScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  String? profesorId;
  String? profesorNombre;
  List<Map<String, dynamic>> visitas = [];
  List<Map<String, dynamic>> _filteredVisitas = [];
  String _searchText = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarDatosProfesor();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosProfesor() async {
    try {
      setState(() => _isLoading = true);
      final prefs = await SharedPreferences.getInstance();
      profesorId = prefs.getString('user_id');
      profesorNombre = prefs.getString('user_name') ?? "Profesor";

      await _cargarVisitasAsignadas();
    } catch (e) {
      _mostrarError('Error al cargar datos: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarVisitasAsignadas() async {
    try {
      if (profesorNombre == null) return;

      final visitasSnapshot =
          await _firestore
              .collection('visitas_escolares')
              .where('profesor', isEqualTo: profesorNombre)
              .get();

      setState(() {
        visitas =
            visitasSnapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                'titulo': data['titulo'] ?? 'Sin título',
                'empresa': data['empresa'] ?? 'Sin empresa',
                'grupo': data['grupo'] ?? 'Sin grupo',
                'fecha_hora': (data['fecha_hora'] as Timestamp?)?.toDate(),
                'estado': data['estado'] ?? 'pendiente',
                'ubicacion': data['ubicacion'] ?? 'Ubicación no disponible',
              };
            }).toList();
        _filteredVisitas = List.from(visitas);
      });
    } catch (e) {
      _mostrarError('Error al cargar visitas: $e');
    }
  }

  void _filterVisitas(String query) {
    setState(() {
      _searchText = query.toLowerCase();
      if (_searchText.isEmpty) {
        _filteredVisitas = List.from(visitas);
      } else {
        _filteredVisitas =
            visitas.where((visita) {
              return visita['titulo'].toString().toLowerCase().contains(
                    _searchText,
                  ) ||
                  visita['empresa'].toString().toLowerCase().contains(
                    _searchText,
                  ) ||
                  visita['grupo'].toString().toLowerCase().contains(
                    _searchText,
                  ) ||
                  visita['estado'].toString().toLowerCase().contains(
                    _searchText,
                  );
            }).toList();
      }
    });
  }

  void _mostrarDetallesVisita(Map<String, dynamic> visita) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetalleVisitaScreen(visitaId: visita['id']),
      ),
    );
  }

  Future<void> _logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id');
      await prefs.remove('user_name');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } catch (e) {
      _mostrarError("Error al cerrar sesión");
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'Visitas Escolares',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              Icon(Icons.person, color: Colors.yellow[200]),
              const SizedBox(width: 5),
              Text(
                profesorNombre ?? "Profesor",
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: _logout,
          tooltip: 'Cerrar sesión',
          color: Colors.red[200],
        ),
      ],
      centerTitle: true,
      backgroundColor: Colors.blue,
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

    return InkWell(
      onTap: () => _mostrarDetallesVisita(visita),
      child: Card(
        elevation: 3,
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                visita['titulo'] as String? ?? 'Sin título',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[800],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.business, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    visita['empresa'] as String? ?? 'Sin empresa',
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.group, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    visita['grupo'] as String? ?? 'Sin grupo',
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
              if (fechaHora != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${fechaHora.day}/${fechaHora.month}/${fechaHora.year} - ${fechaHora.hour}:${fechaHora.minute.toString().padLeft(2, '0')}',
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _getEstadoColor(visita['estado'] as String?),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  (visita['estado'] as String? ?? 'pendiente').toUpperCase(),
                  style: GoogleFonts.roboto(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getEstadoColor(String? estado) {
    switch (estado) {
      case 'confirmado':
        return Colors.green;
      case 'cancelado':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    Text(
                      'Mis Visitas Asignadas',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Buscar visitas...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon:
                            _searchText.isNotEmpty
                                ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    _filterVisitas('');
                                  },
                                )
                                : null,
                      ),
                      onChanged: _filterVisitas,
                    ),
                    const SizedBox(height: 16),
                    if (_filteredVisitas.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          _searchText.isEmpty
                              ? 'No tienes visitas asignadas'
                              : 'No se encontraron resultados',
                          style: GoogleFonts.roboto(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ..._filteredVisitas.map(_buildVisitaCard),
                  ],
                ),
              ),
    );
  }
}
