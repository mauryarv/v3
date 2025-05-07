// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v3/aprobar_archivos_screen.dart';
import 'package:v3/crear_visita_screen.dart';
import 'package:v3/detalle_visita_screen.dart';
import 'package:v3/login_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  _AdminScreenState createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  // Pagination and search variables
  int _limit = 10;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  List<DocumentSnapshot> _loadedDocuments = [];
  String _searchText = '';
  List<DocumentSnapshot> _filteredDocuments = [];

  // Admin data
  String _adminName = "Administrador";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _loadAdminData();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ========== SEARCH METHODS ==========
  void _filterVisitas(String query) {
    setState(() {
      _searchText = query.toLowerCase();
      if (_searchText.isEmpty) {
        _filteredDocuments = List.from(_loadedDocuments);
      } else {
        _filteredDocuments =
            _loadedDocuments.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['titulo'].toString().toLowerCase().contains(
                    _searchText,
                  ) ||
                  data['empresa'].toString().toLowerCase().contains(
                    _searchText,
                  ) ||
                  data['grupo'].toString().toLowerCase().contains(
                    _searchText,
                  ) ||
                  data['profesor'].toString().toLowerCase().contains(
                    _searchText,
                  );
            }).toList();
      }
    });
  }

  // ========== PAGINATION METHODS ==========
  void _scrollListener() {
    if (_scrollController.offset >=
            _scrollController.position.maxScrollExtent &&
        !_scrollController.position.outOfRange) {
      if (!_isLoadingMore && _hasMore && _searchText.isEmpty) {
        _loadMoreVisitas();
      }
    }
  }

  Future<void> _loadMoreVisitas() async {
    if (!_hasMore || _isLoadingMore) return;

    setState(() => _isLoadingMore = true);

    try {
      setState(() => _limit += 10);
    } catch (e) {
      _mostrarError("Error al cargar más visitas: $e");
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  // ========== CORE FUNCTIONALITY ==========
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
    final confirm = await _showConfirmationDialog(
      title: "Eliminar visita",
      content: "Esta acción no se puede deshacer. ¿Deseas continuar?",
      confirmText: "Eliminar",
    );

    if (confirm) {
      try {
        await _firestore.collection("visitas_escolares").doc(visitaId).delete();
        _mostrarExito("Visita eliminada correctamente");
      } catch (e) {
        _mostrarError("Error al eliminar visita: $e");
      }
    }
  }

  Future<void> _editarVisita(DocumentSnapshot visita) async {
    final confirm = await _showConfirmationDialog(
      title: "Editar visita",
      content: "¿Deseas editar esta visita?",
      confirmText: "Editar",
      confirmColor: Colors.blue,
    );

    if (confirm) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CrearVisitaScreen(visita: visita),
        ),
      ).then((_) {
        // Recargar datos después de editar
        _loadAdminData();
      });
    }
  }

  void _mostrarDetallesVisita(DocumentSnapshot doc) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetalleVisitaScreen(visitaId: doc.id),
      ),
    );
  }

  // ========== HELPER METHODS ==========
  Future<bool> _showConfirmationDialog({
    required String title,
    required String content,
    String confirmText = "Confirmar",
    Color confirmColor = Colors.red,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancelar"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(confirmText, style: TextStyle(color: confirmColor)),
              ),
            ],
          ),
    );
    return result ?? false;
  }

  Future<void> _confirmLogout() async {
    final confirm = await _showConfirmationDialog(
      title: "Cerrar sesión",
      content: "¿Estás seguro de que deseas salir de la aplicación?",
      confirmText: "Salir",
    );

    if (confirm) {
      await _logout();
    }
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

  Future<void> _confirmOpenFiles(String visitaId) async {
    final confirm = await _showConfirmationDialog(
      title: "Revisar archivos",
      content: "¿Deseas revisar los archivos de esta visita?",
      confirmText: "Abrir",
      confirmColor: Colors.orange,
    );

    if (confirm) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AprobarArchivosScreen(visitaId: visitaId),
        ),
      );
    }
  }

  // ========== UI COMPONENTS ==========
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 400) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.school, color: Colors.white, size: 24),
                const SizedBox(width: 8),
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
                    const SizedBox(width: 4),
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
          icon: const Icon(Icons.logout, size: 22),
          onPressed: _confirmLogout,
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

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Buscar visitas...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
    );
  }

  Widget _buildVisitaCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final titulo = data["titulo"] ?? "Sin título";
    final empresa = data["empresa"] ?? "Desconocida";
    final ubicacion = data["ubicacion"] ?? "Ubicación no disponible";
    final grupo = data["grupo"] ?? "No asignado";
    final profesor = data["profesor"] ?? "No asignado";
    final alumnos = data["alumnos"] ?? [];
    final timestamp = data["fecha_hora"] as Timestamp?;
    final fechaHoraTexto =
        timestamp != null
            ? DateFormat('dd/MM/yyyy - HH:mm').format(timestamp.toDate())
            : "No definida";

    return InkWell(
      onTap: () => _mostrarDetallesVisita(doc),
      child: Card(
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
                            onPressed: () => _confirmOpenFiles(doc.id),
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
                  _buildInfoRow(Icons.location_on, "Ubicación: $ubicacion"),
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
            _searchText.isEmpty
                ? 'No hay visitas creadas'
                : 'No se encontraron resultados',
            style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginatedVisitasList() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          _firestore
              .collection("visitas_escolares")
              .orderBy("fecha_creacion", descending: true)
              .limit(_limit)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            _loadedDocuments.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        _loadedDocuments = snapshot.data!.docs;
        _filteredDocuments =
            _searchText.isEmpty
                ? List.from(_loadedDocuments)
                : _loadedDocuments.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['titulo'].toString().toLowerCase().contains(
                        _searchText,
                      ) ||
                      data['empresa'].toString().toLowerCase().contains(
                        _searchText,
                      ) ||
                      data['grupo'].toString().toLowerCase().contains(
                        _searchText,
                      ) ||
                      data['profesor'].toString().toLowerCase().contains(
                        _searchText,
                      );
                }).toList();

        if (snapshot.data!.docs.length < _limit) {
          _hasMore = false;
        }

        return Column(
          children: [
            _buildSearchField(),
            if (_filteredDocuments.isEmpty)
              _buildEmptyState()
            else
              ..._filteredDocuments.map((doc) => _buildVisitaCard(doc)),
            if (_isLoadingMore)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            if (!_hasMore &&
                _filteredDocuments.isNotEmpty &&
                _searchText.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'No hay más visitas para mostrar',
                  style: GoogleFonts.roboto(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: _buildPaginatedVisitasList(),
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
