// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
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

  // Variables de paginación y búsqueda
  int _limit = 10;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  List<DocumentSnapshot> _loadedDocuments = [];
  String _searchText = '';
  List<DocumentSnapshot> _filteredDocuments = [];

  // Datos del administrador
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

  // ========== MÉTODOS OPTIMIZADOS PARA CARGA DESDE EXCEL ==========

  Future<void> _cargarAlumnosDesdeExcel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;

      if (bytes == null || bytes.isEmpty) {
        _mostrarError("No se pudo leer el archivo o está vacío");
        return;
      }

      // Configurar diálogo de progreso
      bool isDialogOpen = true;
      int totalAlumnos = 0;
      int gruposProcesados = 0;
      final progressDialog = showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  title: const Text("Procesando archivo..."),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(value: totalAlumnos / 5000),
                      const SizedBox(height: 16),
                      Text("Alumnos procesados: $totalAlumnos"),
                      Text("Grupos procesados: $gruposProcesados"),
                    ],
                  ),
                );
              },
            ),
      );

      final excel = Excel.decodeBytes(bytes);
      List<String> errores = [];
      WriteBatch batch = _firestore.batch();
      const batchSize = 400;

      // Procesar cada hoja
      for (var sheetName in excel.tables.keys) {
        final sheet = excel.tables[sheetName]!;

        // Validar estructura
        if (sheet.maxColumns < 2 ||
            sheet.row(0)[0]?.value.toString().toLowerCase() != "boleta" ||
            sheet.row(0)[1]?.value.toString().toLowerCase() != "nombre") {
          errores.add("Formato incorrecto en hoja '$sheetName'");
          continue;
        }

        // Procesar filas
        for (var row in sheet.rows.skip(1)) {
          try {
            dynamic boletaValue = row[0]?.value;
            String boleta = boletaValue?.toString() ?? '';

            if (boletaValue is num) {
              boleta = boletaValue.toStringAsFixed(0);
            }

            // Validar boleta
            if (boleta.length != 10 || !RegExp(r'^[0-9]+$').hasMatch(boleta)) {
              errores.add("Boleta inválida en hoja $sheetName: $boleta");
              continue;
            }

            final nombre = row[1]?.value?.toString().trim() ?? '';
            if (nombre.isEmpty) {
              errores.add("Nombre vacío para boleta $boleta");
              continue;
            }

            // Agregar al batch
            final alumnoRef = _firestore.collection('usuarios').doc(boleta);
            batch.set(alumnoRef, {
              'nombre': nombre,
              'rol': 'alumno',
              'grupo': sheetName,
              'fecha_registro': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

            totalAlumnos++;

            // Commit parcial
            if (totalAlumnos % batchSize == 0) {
              await batch.commit();
              batch = _firestore.batch();
              if (isDialogOpen) {
                Navigator.pop(context);
                progressDialog.then((_) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder:
                        (context) => AlertDialog(
                          title: const Text("Procesando archivo..."),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                value: totalAlumnos / 5000,
                              ),
                              const SizedBox(height: 16),
                              Text("Alumnos procesados: $totalAlumnos"),
                              Text(
                                "Grupos procesados: ${gruposProcesados + 1}",
                              ),
                            ],
                          ),
                        ),
                  );
                });
              }
            }
          } catch (e) {
            errores.add("Error en hoja $sheetName: ${e.toString()}");
          }
        }
        gruposProcesados++;
      }

      // Commit final
      if (totalAlumnos % batchSize != 0) {
        await batch.commit();
      }

      // Cerrar diálogo
      if (isDialogOpen) Navigator.pop(context);

      // Mostrar resultados
      if (errores.isEmpty) {
        _mostrarExito(
          "$totalAlumnos alumnos cargados en $gruposProcesados grupos",
        );
      } else {
        String mensaje =
            "$totalAlumnos alumnos cargados, pero con ${errores.length} errores";
        _mostrarError(mensaje);
      }
    } catch (e) {
      Navigator.pop(context);
      _mostrarError("Error al procesar archivo: ${e.toString()}");
    }
  }

  Future<void> _cargarProfesoresDesdeExcel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;

      if (bytes == null || bytes.isEmpty) {
        _mostrarError("No se pudo leer el archivo o está vacío");
        return;
      }

      // Mostrar diálogo de progreso
      bool isDialogOpen = true;
      int totalProfesores = 0;
      final progressDialog = showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  title: const Text("Procesando archivo..."),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(value: totalProfesores / 1000),
                      const SizedBox(height: 16),
                      Text("Profesores procesados: $totalProfesores"),
                    ],
                  ),
                );
              },
            ),
      );

      // Procesamiento en batches
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel.tables[excel.tables.keys.first]!;
      List<String> errores = [];
      WriteBatch batch = _firestore.batch();
      const batchSize = 400;

      // Validar estructura
      if (sheet.maxColumns < 2 ||
          sheet.row(0)[0]?.value.toString().toLowerCase() != "numero" ||
          sheet.row(0)[1]?.value.toString().toLowerCase() != "nombre") {
        Navigator.pop(context);
        _mostrarError(
          "Formato incorrecto. Se requieren columnas: Número, Nombre",
        );
        return;
      }

      // Procesar filas
      for (var row in sheet.rows.skip(1)) {
        try {
          final numeroEmpleado = row[0]?.value?.toString().trim() ?? '';
          final nombre = row[1]?.value?.toString().trim() ?? '';

          if (numeroEmpleado.isEmpty || nombre.isEmpty) continue;

          final profesorRef = _firestore
              .collection('usuarios')
              .doc(numeroEmpleado);
          batch.set(profesorRef, {
            'numero_empleado': numeroEmpleado,
            'nombre': nombre,
            'rol': 'profesor',
            'fecha_registro': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          totalProfesores++;

          // Commit parcial cada batchSize
          if (totalProfesores % batchSize == 0) {
            await batch.commit();
            batch = _firestore.batch();
            if (isDialogOpen) {
              // Actualizar diálogo
              Navigator.pop(context);
              progressDialog.then((_) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder:
                      (context) => AlertDialog(
                        title: const Text("Procesando archivo..."),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              value: totalProfesores / 1000,
                            ),
                            const SizedBox(height: 16),
                            Text("Profesores procesados: $totalProfesores"),
                          ],
                        ),
                      ),
                );
              });
            }
          }
        } catch (e) {
          errores.add(
            "Error en fila ${row.indexOf(row as Data?)}: ${e.toString()}",
          );
        }
      }

      // Commit final si quedan operaciones pendientes
      if (totalProfesores % batchSize != 0) {
        await batch.commit();
      }

      // Cerrar diálogo
      if (isDialogOpen) Navigator.pop(context);

      // Mostrar resultados
      if (errores.isEmpty) {
        _mostrarExito("$totalProfesores profesores cargados exitosamente");
      } else {
        String mensaje =
            "$totalProfesores profesores cargados, pero con ${errores.length} errores";
        _mostrarError(mensaje);
      }
    } catch (e) {
      Navigator.pop(context);
      _mostrarError("Error al procesar archivo: ${e.toString()}");
    }
  }

  // ========== MÉTODOS AUXILIARES OPTIMIZADOS ==========

  Future<List<String>> _obtenerNombresAlumnos(List<dynamic> alumnosIds) async {
    if (alumnosIds.isEmpty) return [];

    try {
      // Usar consulta batch para reducir lecturas
      final query = _firestore
          .collection('usuarios')
          .where(FieldPath.documentId, whereIn: alumnosIds.take(10).toList())
          .limit(10);

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => doc['nombre']?.toString() ?? 'Desconocido')
          .toList();
    } catch (e) {
      print('Error al obtener nombres: $e');
      return List.filled(alumnosIds.length, 'Desconocido');
    }
  }

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
    final alumnos = data["alumnos"] as List<dynamic>? ?? [];
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
                  // Botones para cargar desde Excel
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Cargar alumnos'),
                          onPressed: _cargarAlumnosDesdeExcel,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Cargar profesores'),
                          onPressed: _cargarProfesoresDesdeExcel,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
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
