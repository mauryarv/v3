// ignore_for_file: library_private_types_in_public_api

import 'dart:io';
import 'package:flutter/foundation.dart';
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
  File? _archivo; // Solo para móvil
  Uint8List? _archivoWebBytes; // Solo para web
  PlatformFile? _platformFile; // Para ambas plataformas
  String? _tipoSeleccionado;
  bool _cargando = false;
  bool _esMayorEdad = false;

  final Map<String, Map<String, dynamic>> _estadoDocumentos = {
    'INE_Tutor': {
      'subido': false,
      'estado': '',
      'url': '',
      'fecha': null,
      'requerido': true,
      'motivoRechazo': null,
    },
    'INE_Alumno': {
      'subido': false,
      'estado': '',
      'url': '',
      'fecha': null,
      'requerido': false,
      'motivoRechazo': null,
    },
    'Constancia_Medica': {
      'subido': false,
      'estado': '',
      'url': '',
      'fecha': null,
      'requerido': true,
      'motivoRechazo': null,
    },
  };

  @override
  void initState() {
    super.initState();
    _verificarEdadPorCurp();
    _verificarDocumentos();
  }

  Future<void> _verificarEdadPorCurp() async {
    try {
      setState(() => _cargando = true);
      final snapshot =
          await _firestore
              .collection('usuarios')
              .doc(widget.alumnoId)
              .collection('datos_emergencia')
              .doc('info')
              .get();

      if (snapshot.exists) {
        final curp = snapshot.data()?['curp'] as String?;
        if (curp != null && curp.isNotEmpty) {
          final esMayor = _calcularMayoriaEdadPorCurp(curp);
          setState(() {
            _esMayorEdad = esMayor;
            _estadoDocumentos['INE_Alumno']!['requerido'] = esMayor;
          });
        }
      }
    } catch (e) {
      debugPrint('Error al verificar edad: $e');
    } finally {
      if (mounted) {
        setState(() {
          _cargando = false;
        });
      }
    }
  }

  bool _calcularMayoriaEdadPorCurp(String curp) {
    try {
      final fechaStr = curp.substring(4, 10);
      final year = int.parse(fechaStr.substring(0, 2));
      final month = int.parse(fechaStr.substring(2, 4));
      final day = int.parse(fechaStr.substring(4, 6));
      final siglo = year <= 21 ? 2000 : 1900;
      final fechaNacimiento = DateTime(siglo + year, month, day);
      final hoy = DateTime.now();
      int edad = hoy.year - fechaNacimiento.year;
      if (hoy.month < fechaNacimiento.month ||
          (hoy.month == fechaNacimiento.month &&
              hoy.day < fechaNacimiento.day)) {
        edad--;
      }
      return edad >= 18;
    } catch (e) {
      debugPrint('Error al calcular edad: $e');
      return false;
    }
  }

  Future<void> _verificarDocumentos() async {
    try {
      setState(() => _cargando = true);
      final snapshot =
          await _firestore
              .collection('visitas_escolares')
              .doc(widget.visitaId)
              .get();

      if (snapshot.exists) {
        final archivos =
            List.from(
              snapshot.data()?['archivos_pendientes'] ?? [],
            ).where((a) => a['alumnoId'] == widget.alumnoId).toList();

        for (var tipo in _estadoDocumentos.keys) {
          _estadoDocumentos[tipo] = {
            'subido': false,
            'estado': '',
            'url': '',
            'fecha': null,
            'requerido': tipo == 'INE_Alumno' ? _esMayorEdad : true,
            'motivoRechazo': null,
          };
        }

        for (var archivo in archivos) {
          final tipo = archivo['tipo'] as String;
          if (_estadoDocumentos.containsKey(tipo)) {
            _estadoDocumentos[tipo] = {
              'subido': true,
              'estado': archivo['estado'] ?? '',
              'url': archivo['archivoUrl'] ?? '',
              'fecha': archivo['fechaSubida'],
              'requerido': tipo == 'INE_Alumno' ? _esMayorEdad : true,
              'motivoRechazo': archivo['motivoRechazo'],
            };
          }
        }
      }
    } catch (e) {
      debugPrint('Error al verificar documentos: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _seleccionarArchivo() async {
    if (_tipoSeleccionado == null) {
      _mostrarMensaje('Selecciona un tipo de documento', Colors.orange);
      return;
    }

    final docInfo = _estadoDocumentos[_tipoSeleccionado]!;
    if (docInfo['subido'] == true && docInfo['estado'] == 'aprobado') {
      _mostrarMensaje('Documento ya aprobado', Colors.orange);
      return;
    }

    try {
      final resultado = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (resultado != null && resultado.files.isNotEmpty) {
        final file = resultado.files.first;

        // Verificar tamaño del archivo (5MB máximo)
        if (file.size > 5 * 1024 * 1024) {
          _mostrarMensaje('El archivo no debe exceder 5MB', Colors.red);
          return;
        }

        setState(() {
          _platformFile = file;
          if (kIsWeb) {
            _archivoWebBytes = file.bytes;
          } else {
            _archivo = File(file.path!);
          }
        });
      }
    } catch (e) {
      _mostrarMensaje('Error al seleccionar archivo: $e', Colors.red);
    }
  }

  Future<void> _subirDocumento() async {
    if (_tipoSeleccionado == null ||
        (_archivo == null && _archivoWebBytes == null)) {
      _mostrarMensaje('Selecciona un archivo', Colors.orange);
      return;
    }

    setState(() => _cargando = true);
    try {
      final extension = _platformFile?.extension ?? 'pdf';
      final nombreArchivo = _generarNombreArchivo(
        _tipoSeleccionado!,
        extension,
      );
      final rutaStorage =
          'visitas/${widget.visitaId}/${widget.alumnoId}/$nombreArchivo';
      final referencia = _storage.ref().child(rutaStorage);

      // Subir archivo según la plataforma
      if (kIsWeb) {
        await referencia.putData(_archivoWebBytes!);
      } else {
        await referencia.putFile(_archivo!);
      }

      final url = await referencia.getDownloadURL();

      // Eliminar archivo anterior si existe
      final urlAnterior =
          _estadoDocumentos[_tipoSeleccionado]?['url'] as String? ?? '';
      if (urlAnterior.isNotEmpty) {
        await _eliminarArchivoStorage(urlAnterior);
      }

      // Actualizar Firestore
      await _reemplazarDocumentoExistente(url, nombreArchivo);

      _mostrarMensaje('Documento subido con éxito', Colors.green);
      widget.onArchivoSubido();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _mostrarMensaje('Error al subir documento: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _eliminarArchivoStorage(String url) async {
    try {
      if (url.isNotEmpty) {
        await _storage.refFromURL(url).delete();
      }
    } catch (e) {
      debugPrint('Error al eliminar archivo: $e');
    }
  }

  Future<void> _reemplazarDocumentoExistente(
    String url,
    String nombreArchivo,
  ) async {
    final visitaRef = _firestore
        .collection('visitas_escolares')
        .doc(widget.visitaId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(visitaRef);
      if (!snapshot.exists) return;

      final archivosPendientes = List.from(
        snapshot.data()?['archivos_pendientes'] ?? [],
      );

      // Eliminar todas las versiones anteriores
      archivosPendientes.removeWhere(
        (archivo) =>
            archivo['alumnoId'] == widget.alumnoId &&
            archivo['tipo'] == _tipoSeleccionado,
      );

      // Agregar nuevo documento
      archivosPendientes.add({
        'alumnoId': widget.alumnoId,
        'archivoUrl': url,
        'tipo': _tipoSeleccionado,
        'nombre': _getNombreLegible(_tipoSeleccionado!),
        'nombreArchivo': nombreArchivo,
        'estado': 'pendiente',
        'fechaSubida': Timestamp.now(),
        'motivoRechazo': null,
      });

      transaction.update(visitaRef, {
        'archivos_pendientes': archivosPendientes,
      });
    });
  }

  String _generarNombreArchivo(String tipo, String extension) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${tipo}_${widget.alumnoId}_$timestamp.$extension';
  }

  String _getNombreLegible(String tipo) {
    return {
          'INE_Tutor': 'INE del Tutor',
          'INE_Alumno': 'INE del Alumno',
          'Constancia_Medica': 'Constancia Médica',
        }[tipo] ??
        tipo.replaceAll('_', ' ');
  }

  void _mostrarMensaje(String texto, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildTipoDocumento() {
    final documentosAplicables =
        _estadoDocumentos.entries.where((entry) {
          return entry.value['requerido'] == true &&
              (!entry.value['subido'] || entry.value['estado'] == 'rechazado');
        }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tipo de Documento', style: GoogleFonts.roboto(fontSize: 14)),
        const SizedBox(height: 8),
        documentosAplicables.isEmpty
            ? Text(
              'Todos los documentos requeridos subidos',
              style: GoogleFonts.roboto(color: Colors.green),
            )
            : DropdownButtonFormField<String>(
              value: _tipoSeleccionado,
              items:
                  documentosAplicables.map((entry) {
                    return DropdownMenuItem(
                      value: entry.key,
                      child: Text(
                        '${_getNombreLegible(entry.key)}${entry.value['subido'] ? ' (${entry.value['estado']})' : ''}',
                      ),
                    );
                  }).toList(),
              onChanged:
                  (value) => setState(() {
                    _tipoSeleccionado = value;
                    _archivo = null;
                    _archivoWebBytes = null;
                    _platformFile = null;
                  }),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
      ],
    );
  }

  Widget _buildDocumentoItem(String nombre, Map<String, dynamic> estado) {
    final icon =
        estado['subido'] == true
            ? estado['estado'] == 'aprobado'
                ? Icons.check_circle
                : Icons.warning
            : Icons.pending;

    final color =
        estado['subido'] == true
            ? estado['estado'] == 'aprobado'
                ? Colors.green
                : Colors.orange
            : Colors.grey;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(nombre)),
              if (estado['subido'] == true)
                Chip(
                  label: Text(estado['estado'] ?? 'pendiente'),
                  backgroundColor: color,
                ),
            ],
          ),
          if (estado['estado'] == 'rechazado' &&
              estado['motivoRechazo'] != null)
            Padding(
              padding: const EdgeInsets.only(left: 28, top: 4),
              child: Text(
                'Motivo: ${estado['motivoRechazo']}',
                style: GoogleFonts.roboto(
                  color: Colors.red[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Subir Documentos', style: GoogleFonts.poppins()),
        centerTitle: true,
      ),
      body:
          _cargando
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Subir documentos requeridos',
                      style: GoogleFonts.poppins(fontSize: 16),
                    ),
                    const SizedBox(height: 24),

                    // Documentos requeridos
                    Text(
                      'Documentos requeridos:',
                      style: GoogleFonts.roboto(fontWeight: FontWeight.bold),
                    ),
                    _buildDocumentoItem(
                      'Constancia Médica',
                      _estadoDocumentos['Constancia_Medica']!,
                    ),
                    _buildDocumentoItem(
                      'INE del tutor',
                      _estadoDocumentos['INE_Tutor']!,
                    ),
                    if (_esMayorEdad)
                      _buildDocumentoItem(
                        'INE del alumno',
                        _estadoDocumentos['INE_Alumno']!,
                      ),

                    const SizedBox(height: 24),
                    _buildTipoDocumento(),
                    const SizedBox(height: 16),

                    // Selector de archivo
                    OutlinedButton.icon(
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Seleccionar archivo'),
                      onPressed: _seleccionarArchivo,
                    ),

                    // Vista previa archivo
                    if (_platformFile != null) ...[
                      const SizedBox(height: 16),
                      ListTile(
                        leading: Icon(
                          Icons.insert_drive_file,
                          color:
                              _platformFile!.extension == 'pdf'
                                  ? Colors.red
                                  : Colors.blue,
                        ),
                        title: Text(_platformFile!.name),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed:
                              () => setState(() {
                                _platformFile = null;
                                _archivo = null;
                                _archivoWebBytes = null;
                              }),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _subirDocumento,
                        child: const Text('Subir Documento'),
                      ),
                    ],
                  ],
                ),
              ),
    );
  }
}
