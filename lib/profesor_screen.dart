// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:v3/login_screen.dart';

class ProfesorScreen extends StatefulWidget {
  const ProfesorScreen({super.key});

  @override
  _ProfesorScreenState createState() => _ProfesorScreenState();
}

class _ProfesorScreenState extends State<ProfesorScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String? profesorId;
  String? profesorNombre;
  List<Map<String, dynamic>> visitas = [];
  bool _isLoading = true;

  File? _archivo;
  String? _tipoSeleccionado;
  bool _cargandoSubida = false;
  final List<String> _tiposDocumentos = [
    'CURP',
    'INE',
    'Constancia_Medica',
    'Comprobante_Domicilio',
  ];
  Map<String, String> _documentosSubidos = {};

  @override
  void initState() {
    super.initState();
    _cargarDatosProfesor();
  }

  Future<void> _cargarDatosProfesor() async {
    try {
      setState(() => _isLoading = true);
      final prefs = await SharedPreferences.getInstance();
      profesorId = prefs.getString('user_id');
      profesorNombre = prefs.getString('user_name') ?? "Profesor";

      await Future.wait([
        _cargarVisitasAsignadas(),
        _cargarDocumentosProfesor(),
      ]);
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
                'fecha_hora': (data['fecha_hora'] as Timestamp?)?.toDate(),
                'estado': data['estado'] ?? 'pendiente',
              };
            }).toList();
      });
    } catch (e) {
      _mostrarError('Error al cargar visitas: $e');
    }
  }

  Future<void> _cargarDocumentosProfesor() async {
    try {
      if (profesorId == null) return;

      final snapshot =
          await _firestore.collection('usuarios').doc(profesorId).get();

      if (snapshot.exists) {
        final docs =
            snapshot.data()?['documentos'] as Map<String, dynamic>? ?? {};
        setState(() {
          _documentosSubidos = Map<String, String>.from(docs);
        });
      }
    } catch (e) {
      _mostrarError('Error al cargar documentos: $e');
    }
  }

  Future<void> _seleccionarArchivo() async {
    if (_tipoSeleccionado == null) {
      _mostrarMensaje('Selecciona un tipo de documento', Colors.orange);
      return;
    }

    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (resultado != null) {
      final archivo = File(resultado.files.single.path!);
      if (archivo.lengthSync() > 2 * 1024 * 1024) {
        _mostrarMensaje('El archivo no debe exceder 2MB', Colors.red);
        return;
      }
      setState(() => _archivo = archivo);
    }
  }

  Future<void> _subirDocumento() async {
    if (_tipoSeleccionado == null || _archivo == null || profesorId == null) {
      return;
    }

    setState(() => _cargandoSubida = true);
    try {
      final nombreArchivo =
          '${_tipoSeleccionado}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final rutaStorage = 'profesores/$profesorId/$nombreArchivo';
      final referencia = _storage.ref().child(rutaStorage);
      await referencia.putFile(_archivo!);
      final url = await referencia.getDownloadURL();

      if (_documentosSubidos.containsKey(_tipoSeleccionado!)) {
        final urlAnterior = _documentosSubidos[_tipoSeleccionado!]!;
        await _storage.refFromURL(urlAnterior).delete();
      }

      await _firestore.collection('usuarios').doc(profesorId).set({
        'documentos': {..._documentosSubidos, _tipoSeleccionado!: url},
      }, SetOptions(merge: true));

      await _cargarDocumentosProfesor();

      _mostrarMensaje('Documento subido con éxito', Colors.green);
      setState(() {
        _archivo = null;
      });
    } catch (e) {
      _mostrarMensaje('Error al subir documento: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _cargandoSubida = false);
    }
  }

  Future<void> _eliminarDocumento(String tipoDocumento) async {
    if (profesorId == null || !_documentosSubidos.containsKey(tipoDocumento)) {
      return;
    }

    try {
      setState(() => _isLoading = true);

      // Eliminar de Firebase Storage
      final url = _documentosSubidos[tipoDocumento]!;
      await _storage.refFromURL(url).delete();

      // Eliminar de Firestore
      final nuevosDocumentos = Map<String, String>.from(_documentosSubidos);
      nuevosDocumentos.remove(tipoDocumento);

      await _firestore.collection('usuarios').doc(profesorId).update({
        'documentos': nuevosDocumentos,
      });

      // Actualizar estado local
      await _cargarDocumentosProfesor();

      _mostrarMensaje('Documento eliminado con éxito', Colors.green);
    } catch (e) {
      _mostrarError('Error al eliminar documento: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarDialogoConfirmacionEliminar(String tipoDocumento) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Eliminar documento'),
            content: Text(
              '¿Estás seguro de que quieres eliminar ${_getNombreLegible(tipoDocumento)}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _eliminarDocumento(tipoDocumento);
                },
                child: const Text(
                  'Eliminar',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
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

  void _mostrarMensaje(String texto, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
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

  String _getNombreLegible(String tipo) {
    switch (tipo) {
      case 'CURP':
        return 'CURP';
      case 'INE':
        return 'INE';
      case 'Constancia_Medica':
        return 'Constancia Médica';
      case 'Comprobante_Domicilio':
        return 'Comprobante de Domicilio';
      default:
        return tipo.replaceAll('_', ' ');
    }
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'Visitas Escolares - Profesor',
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

    return Card(
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
            if (fechaHora != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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

  Widget _buildDocumentosSection() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        title: Text(
          'Documentos del Profesor',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
        ),
        initiallyExpanded: true,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _tipoSeleccionado,
                  hint: Text(
                    'Selecciona un documento',
                    style: GoogleFonts.roboto(),
                  ),
                  items:
                      _tiposDocumentos.map((tipo) {
                        final subido = _documentosSubidos.containsKey(tipo);
                        return DropdownMenuItem(
                          value: tipo,
                          child: Text(
                            '${_getNombreLegible(tipo)}${subido ? ' (subido)' : ''}',
                            style: GoogleFonts.roboto(),
                          ),
                        );
                      }).toList(),
                  onChanged:
                      (value) => setState(() {
                        _tipoSeleccionado = value;
                        _archivo = null;
                      }),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
                const SizedBox(height: 16),
                if (_tipoSeleccionado != null) ...[
                  OutlinedButton.icon(
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Seleccionar archivo PDF'),
                    onPressed: _seleccionarArchivo,
                  ),
                  if (_archivo != null) ...[
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(
                        Icons.picture_as_pdf,
                        color: Colors.red,
                      ),
                      title: Text(_archivo!.path.split('/').last),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _archivo = null),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _subirDocumento,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child:
                          _cargandoSubida
                              ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                              : const Text('Subir Documento'),
                    ),
                  ],
                ],
                const SizedBox(height: 16),
                if (_documentosSubidos.isNotEmpty) ...[
                  const Divider(),
                  Text(
                    'Documentos subidos:',
                    style: GoogleFonts.roboto(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  ..._documentosSubidos.entries.map(
                    (entry) => ListTile(
                      leading: const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                      ),
                      title: Text(_getNombreLegible(entry.key)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.visibility,
                              color: Colors.blue,
                            ),
                            onPressed: () async {
                              final url = entry.value;
                              if (await canLaunchUrl(Uri.parse(url))) {
                                await launchUrl(
                                  Uri.parse(url),
                                  mode: LaunchMode.externalApplication,
                                );
                              } else {
                                _mostrarMensaje(
                                  'No se pudo abrir el documento',
                                  Colors.red,
                                );
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed:
                                () => _mostrarDialogoConfirmacionEliminar(
                                  entry.key,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
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
                    _buildDocumentosSection(),
                    const SizedBox(height: 24),
                    Text(
                      'Mis Visitas Asignadas',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (visitas.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'No tienes visitas asignadas',
                          style: GoogleFonts.roboto(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ...visitas.map(_buildVisitaCard),
                  ],
                ),
              ),
    );
  }
}
