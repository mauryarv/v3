// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v3/aprobar_archivos_screen.dart';
import 'package:v3/crear_visita_screen.dart';
import 'package:v3/login_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  _AdminScreenState createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _adminName = "Administrador";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _adminName = prefs.getString('user_name') ?? "Administrador";
        _isLoading = false;
      });
    } catch (e) {
      _mostrarError("Error al cargar datos del administrador");
      setState(() => _isLoading = false);
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

  Future<void> _eliminarVisita(String visitaId) async {
    try {
      await _firestore.collection("visitas_escolares").doc(visitaId).delete();
      _mostrarExito("Visita eliminada correctamente");
    } catch (e) {
      _mostrarError("Error al eliminar visita: $e");
    }
  }

  void _editarVisita(DocumentSnapshot visita) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CrearVisitaScreen(visita: visita),
      ),
    );
  }

  Future<List<String>> _obtenerNombresAlumnos(List<dynamic> alumnosIds) async {
    List<String> nombres = [];
    for (String id in alumnosIds) {
      var alumnoDoc = await _firestore.collection('usuarios').doc(id).get();
      if (alumnoDoc.exists) {
        nombres.add(alumnoDoc['nombre'] ?? 'Desconocido');
      }
    }
    return nombres;
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
      title: LayoutBuilder(
        builder: (context, constraints) {
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
                        _adminName,
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

  Widget _buildVisitaCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final titulo = data["titulo"] ?? "Sin título";
    final empresa = data["empresa"] ?? "Desconocida";
    final grupo = data["grupo"] ?? "No asignado";
    final profesor = data["profesor"] ?? "No asignado";
    final alumnos = data["alumnos"] ?? [];
    final timestamp = data["fecha_hora"] as Timestamp?;
    final fechaHoraTexto =
        timestamp != null
            ? DateFormat('dd/MM/yyyy - HH:mm').format(timestamp.toDate())
            : "No definida";

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: FutureBuilder<List<String>>(
        future: _obtenerNombresAlumnos(alumnos),
        builder: (context, snapshot) {
          final alumnosTexto =
              snapshot.hasData
                  ? snapshot.data!.join(', ')
                  : snapshot.connectionState == ConnectionState.waiting
                  ? "Cargando..."
                  : "No disponibles";

          return Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        titulo,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[800],
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.folder_open, color: Colors.orange),
                          onPressed:
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => AprobarArchivosScreen(
                                        visitaId: doc.id,
                                      ),
                                ),
                              ),
                          tooltip: 'Revisar Archivos',
                        ),
                        IconButton(
                          icon: Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _editarVisita(doc),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _eliminarVisita(doc.id),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.business, empresa),
                _buildInfoRow(Icons.people, "Grupo: $grupo"),
                _buildInfoRow(Icons.person, "Profesor: $profesor"),
                _buildInfoRow(Icons.calendar_today, fechaHoraTexto),
                const SizedBox(height: 4),
                Text(
                  "Alumnos:",
                  style: GoogleFonts.roboto(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  alumnosTexto,
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          );
        },
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No hay visitas creadas',
            style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey[600]),
          ),
        ],
      ),
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
              : Column(
                children: [
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      'Visitas creadas',
                      style: GoogleFonts.caveat(
                        fontSize: 30,
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream:
                          _firestore
                              .collection("visitas_escolares")
                              .orderBy("fecha_creacion", descending: true)
                              .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return _buildEmptyState();
                        }
                        return SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 8 : 24,
                            vertical: 16,
                          ),
                          child: Column(
                            children:
                                snapshot.data!.docs
                                    .map((doc) => _buildVisitaCard(doc))
                                    .toList(),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: FloatingActionButton.extended(
                      backgroundColor: Colors.blue,
                      icon: const Icon(Icons.add),
                      label: const Text('Crear visita'),
                      onPressed:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CrearVisitaScreen(),
                            ),
                          ),
                    ),
                  ),
                ],
              ),
    );
  }
}
