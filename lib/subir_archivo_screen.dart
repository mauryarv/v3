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

        for (var archivo in archivos) {
          final tipo = archivo['tipo'] as String;
          if (_estadoDocumentos.containsKey(tipo)) {
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
      actions: [],
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

  Future<void> _seleccionarArchivo() async {
    if (_tipoSeleccionado == null) {
      _mostrarMensaje('Selecciona un tipo de documento', Colors.orange);
      return;
    }

    final docInfo = _estadoDocumentos[_tipoSeleccionado]!;
    if (docInfo['subido'] == true && docInfo['estado'] != 'rechazado') {
      _mostrarMensaje(
        'Este documento ya fue subido y está ${docInfo['estado']}',
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

  Future<void> _subirDocumento() async {
    if (_tipoSeleccionado == null || _archivo == null) return;

    setState(() => _cargando = true);

    try {
      // 1. Subir a Storage
      final referencia = FirebaseStorage.instance.ref().child(
        'visitas/${widget.visitaId}/${widget.alumnoId}/$_tipoSeleccionado.pdf',
      );

      await referencia.putFile(_archivo!);
      final url = await referencia.getDownloadURL();

      // 2. Eliminar documento existente si es rechazado
      final docInfo = _estadoDocumentos[_tipoSeleccionado]!;
      if (docInfo['subido'] == true && docInfo['estado'] == 'rechazado') {
        await _firestore
            .collection('visitas_escolares')
            .doc(widget.visitaId)
            .update({
              'archivos_pendientes': FieldValue.arrayRemove([
                {
                  'alumnoId': widget.alumnoId,
                  'archivoUrl': docInfo['url'],
                  'tipo': _tipoSeleccionado,
                  'estado': 'rechazado',
                  'fechaSubida': docInfo['fecha'],
                },
              ]),
            });
      }

      // 3. Agregar nuevo documento
      await _firestore
          .collection('visitas_escolares')
          .doc(widget.visitaId)
          .update({
            'archivos_pendientes': FieldValue.arrayUnion([
              {
                'alumnoId': widget.alumnoId,
                'archivoUrl': url,
                'tipo': _tipoSeleccionado,
                'estado': 'pendiente',
                'fechaSubida': Timestamp.now(),
              },
            ]),
          });

      _mostrarMensaje('Documento subido con éxito', Colors.green);
      widget.onArchivoSubido();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _mostrarMensaje('Error al subir documento: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _cargando = false);
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

  Widget _buildTipoDocumento() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            'Tipo de Documento',
            style: GoogleFonts.roboto(fontSize: 14, color: Colors.grey[600]),
          ),
        ),
        DropdownButtonFormField<String>(
          value: _tipoSeleccionado,
          items:
              _estadoDocumentos.keys.map((tipo) {
                final nombre = tipo.replaceAll('_', ' ');
                final docInfo = _estadoDocumentos[tipo]!;
                final estado =
                    docInfo['subido'] ? ' (${docInfo['estado']})' : '';

                return DropdownMenuItem(
                  value: tipo,
                  child: Text(
                    '$nombre$estado',
                    style: GoogleFonts.roboto(
                      color:
                          docInfo['subido'] && docInfo['estado'] != 'rechazado'
                              ? Colors.grey
                              : Colors.black,
                    ),
                  ),
                );
              }).toList(),
          onChanged: (value) {
            final docInfo = _estadoDocumentos[value]!;
            if (!docInfo['subido'] || docInfo['estado'] == 'rechazado') {
              setState(() {
                _tipoSeleccionado = value;
                _archivo = null;
              });
            }
          },
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildArchivoSeleccionado() {
    if (_archivo == null) return const SizedBox();

    return Column(
      children: [
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.picture_as_pdf, color: Colors.red),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Documento seleccionado:',
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      _archivo!.path.split('/').last,
                      style: GoogleFonts.roboto(fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _archivo = null),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentosCompletados() {
    final completados = _estadoDocumentos.entries.where(
      (e) => e.value['subido'] == true && e.value['estado'] != 'rechazado',
    );
    if (completados.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          'Documentos subidos:',
          style: GoogleFonts.roboto(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        ...completados.map(
          (doc) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  doc.value['estado'] == 'aprobado'
                      ? Icons.check_circle
                      : Icons.pending,
                  color:
                      doc.value['estado'] == 'aprobado'
                          ? Colors.green
                          : Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '${doc.key.replaceAll('_', ' ')} (${doc.value['estado']})',
                  style: GoogleFonts.roboto(
                    color:
                        doc.value['estado'] == 'aprobado'
                            ? Colors.green
                            : Colors.black,
                  ),
                ),
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
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _seleccionarArchivo,
                    ),
                    _buildArchivoSeleccionado(),
                    if (_archivo != null) ...[
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _subirDocumento,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Subir Documento',
                          style: GoogleFonts.roboto(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                    _buildDocumentosCompletados(),
                  ],
                ),
              ),
    );
  }
}
