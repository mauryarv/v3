// ignore_for_file: library_private_types_in_public_api

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SubirArchivoScreen extends StatefulWidget {
  final String visitaId;
  final String alumnoId;
  final VoidCallback onArchivoSubido;

  const SubirArchivoScreen({
    super.key,
    required this.visitaId,
    required this.alumnoId,
    required this.onArchivoSubido,
  });

  @override
  _SubirArchivoScreenState createState() => _SubirArchivoScreenState();
}

class _SubirArchivoScreenState extends State<SubirArchivoScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  File? _archivo;
  String? _tipoSeleccionado;
  bool _cargando = false;
  final Map<String, Map<String, dynamic>> _estadoDocumentos = {
    'CURP': {'subido': false, 'estado': '', 'url': '', 'fecha': null},
    'INE_Tutor': {'subido': false, 'estado': '', 'url': '', 'fecha': null},
    'Constancia_Medica': {
      'subido': false,
      'estado': '',
      'url': '',
      'fecha': null,
    },
  };

  @override
  void initState() {
    super.initState();
    _verificarDocumentos();
  }

  Future<void> _verificarDocumentos() async {
    try {
      final snapshot =
          await _firestore
              .collection('visitas_escolares')
              .doc(widget.visitaId)
              .get();
      if (snapshot.exists) {
        final archivos =
            (snapshot.data()?['archivos_pendientes'] as List? ?? [])
                .where((a) => a['alumnoId'] == widget.alumnoId)
                .toList();

        // Conservar solo el más reciente por tipo
        final Map<String, dynamic> archivosUnicos = {};
        for (var archivo in archivos) {
          final tipo = archivo['tipo'] as String;
          final fecha = archivo['fechaSubida'] as Timestamp?;
          if (!archivosUnicos.containsKey(tipo) ||
              (fecha != null &&
                  (archivosUnicos[tipo]['fechaSubida'] as Timestamp).compareTo(
                        fecha,
                      ) <
                      0)) {
            archivosUnicos[tipo] = archivo;
          }
        }

        // Actualizar estado local
        for (var tipo in _estadoDocumentos.keys) {
          if (archivosUnicos.containsKey(tipo)) {
            final archivo = archivosUnicos[tipo];
            _estadoDocumentos[tipo] = {
              'subido': true,
              'estado': archivo['estado'] ?? '',
              'url': archivo['archivoUrl'] ?? '',
              'fecha': archivo['fechaSubida'],
            };
          }
        }
        setState(() {});
      }
    } catch (e) {
      _mostrarMensaje('Error al verificar documentos: $e', Colors.red);
    }
  }

  Future<void> _seleccionarArchivo() async {
    if (_tipoSeleccionado == null) {
      _mostrarMensaje('Selecciona un tipo de documento', Colors.orange);
      return;
    }

    final docInfo = _estadoDocumentos[_tipoSeleccionado]!;
    if (docInfo['subido'] == true && docInfo['estado'] == 'aprobado') {
      _mostrarMensaje(
        'Este documento ya fue aprobado y no puede ser modificado',
        Colors.orange,
      );
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

  Future<void> _eliminarArchivoStorage(String url) async {
    try {
      if (url.isNotEmpty) {
        final ref = _storage.refFromURL(url);
        await ref.delete();
      }
    } catch (e) {
      debugPrint('Error al eliminar archivo de Storage: $e');
    }
  }

  Future<void> _subirDocumento() async {
    if (_tipoSeleccionado == null || _archivo == null) return;

    setState(() => _cargando = true);
    try {
      final nombreArchivo = _generarNombreArchivo(_tipoSeleccionado!);
      final rutaStorage =
          'visitas/${widget.visitaId}/${widget.alumnoId}/$nombreArchivo';
      final referencia = _storage.ref().child(rutaStorage);
      await referencia.putFile(_archivo!);
      final url = await referencia.getDownloadURL();

      // Obtener la URL del archivo anterior para eliminarlo
      final urlAnterior =
          _estadoDocumentos[_tipoSeleccionado]?['url'] as String? ?? '';

      // Actualizar Firestore
      await _reemplazarDocumentoExistente(url, nombreArchivo);

      // Eliminar el archivo anterior si existe
      if (urlAnterior.isNotEmpty) {
        await _eliminarArchivoStorage(urlAnterior);
      }

      _mostrarMensaje('Documento subido con éxito', Colors.green);
      widget.onArchivoSubido();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _mostrarMensaje('Error al subir documento: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _reemplazarDocumentoExistente(
    String url,
    String nombreArchivo,
  ) async {
    final visitaRef = _firestore
        .collection('visitas_escolares')
        .doc(widget.visitaId);
    final visitaSnapshot = await visitaRef.get();

    if (visitaSnapshot.exists) {
      final archivosPendientes = List.from(
        visitaSnapshot.data()?['archivos_pendientes'] ?? [],
      );

      // Eliminar cualquier versión anterior del mismo tipo para este alumno
      archivosPendientes.removeWhere(
        (archivo) =>
            archivo['alumnoId'] == widget.alumnoId &&
            archivo['tipo'] == _tipoSeleccionado,
      );

      // Agregar el nuevo documento
      archivosPendientes.add({
        'alumnoId': widget.alumnoId,
        'archivoUrl': url,
        'tipo': _tipoSeleccionado,
        'nombre': _getNombreLegible(_tipoSeleccionado!),
        'nombreArchivo': nombreArchivo,
        'estado': 'pendiente',
        'fechaSubida': Timestamp.now(),
      });

      // Actualizar Firestore
      await visitaRef.update({'archivos_pendientes': archivosPendientes});
    }
  }

  String _generarNombreArchivo(String tipo) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${tipo}_${widget.alumnoId}_$timestamp.pdf';
  }

  String _getNombreLegible(String tipo) {
    switch (tipo) {
      case 'CURP':
        return 'CURP';
      case 'INE_Tutor':
        return 'INE del Tutor';
      case 'Constancia_Medica':
        return 'Constancia Médica';
      default:
        return tipo.replaceAll('_', ' ');
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

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        'Subir Documentos',
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
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

  Widget _buildTipoDocumento() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tipo de Documento',
          style: GoogleFonts.roboto(fontSize: 14, color: Colors.grey[600]),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _tipoSeleccionado,
          items:
              _estadoDocumentos.entries
                  .where(
                    (entry) =>
                        !entry.value['subido'] ||
                        entry.value['estado'] == 'rechazado',
                  )
                  .map((entry) {
                    final tipo = entry.key;
                    final nombre = _getNombreLegible(tipo);
                    final estado =
                        entry.value['subido']
                            ? ' (${entry.value['estado']})'
                            : '';
                    return DropdownMenuItem(
                      value: tipo,
                      child: Text(
                        '$nombre$estado',
                        style: GoogleFonts.roboto(),
                      ),
                    );
                  })
                  .toList(),
          onChanged:
              (value) => setState(() {
                _tipoSeleccionado = value;
                _archivo = null;
              }),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentosCompletados() {
    final completados = _estadoDocumentos.entries.where(
      (e) => e.value['subido'] == true && e.value['estado'] == 'aprobado',
    );
    if (completados.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          'Documentos aprobados:',
          style: GoogleFonts.roboto(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        ...completados.map(
          (doc) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Text(_getNombreLegible(doc.key), style: GoogleFonts.roboto()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body:
          _cargando
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Sube los documentos requeridos para la visita escolar',
                      style: GoogleFonts.poppins(fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    _buildTipoDocumento(),
                    const SizedBox(height: 16),
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
                        child: const Text('Subir Documento'),
                      ),
                    ],
                    _buildDocumentosCompletados(),
                  ],
                ),
              ),
    );
  }
}
