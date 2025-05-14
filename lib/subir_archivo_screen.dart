// ignore_for_file: library_private_types_in_public_api

import 'dart:async';
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
  bool _esMayorEdad = false;
  bool _edadVerificada = false;

  final Map<String, Map<String, dynamic>> _estadoDocumentos = {
    'INE_Tutor': {
      'subido': false,
      'estado': '',
      'url': '',
      'fecha': null,
      'requerido': true,
    },
    'INE_Alumno': {
      'subido': false,
      'estado': '',
      'url': '',
      'fecha': null,
      'requerido': false,
    },
    'Constancia_Medica': {
      'subido': false,
      'estado': '',
      'url': '',
      'fecha': null,
      'requerido': true,
    },
  };

  @override
  void initState() {
    super.initState();
    _verificarEdadPorCurp();
    _verificarDocumentos();
  }

  @override
  void didUpdateWidget(SubirArchivoScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.alumnoId != widget.alumnoId ||
        oldWidget.visitaId != widget.visitaId) {
      _reiniciarEstados();
      _verificarEdadPorCurp();
      _verificarDocumentos();
    }
  }

  void _reiniciarEstados() {
    setState(() {
      _archivo = null;
      _tipoSeleccionado = null;
      _cargando = false;
      _edadVerificada = false;
      _esMayorEdad = false;
      for (var key in _estadoDocumentos.keys) {
        _estadoDocumentos[key] = {
          'subido': false,
          'estado': '',
          'url': '',
          'fecha': null,
          'requerido': key == 'INE_Alumno' ? false : true,
        };
      }
    });
  }

  Future<void> _verificarEdadPorCurp() async {
    try {
      if (!mounted) return;

      setState(() => _cargando = true);

      final snapshot = await _firestore
          .collection('usuarios')
          .doc(widget.alumnoId)
          .collection('datos_emergencia')
          .doc('info')
          .get()
          .timeout(const Duration(seconds: 10));

      if (!snapshot.exists) {
        if (mounted) {
          setState(() {
            _edadVerificada = true;
            _esMayorEdad = false;
            _cargando = false;
          });
        }
        return;
      }

      final curp = snapshot.data()?['curp'] as String?;

      if (curp == null || curp.isEmpty) {
        if (mounted) {
          setState(() {
            _edadVerificada = true;
            _esMayorEdad = false;
            _cargando = false;
          });
        }
        return;
      }

      final esMayor = _calcularMayoriaEdadPorCurp(curp);

      if (mounted) {
        setState(() {
          _esMayorEdad = esMayor;
          _edadVerificada = true;
          _estadoDocumentos['INE_Alumno']!['requerido'] = esMayor;
          _cargando = false;
        });
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _edadVerificada = true;
          _esMayorEdad = false;
          _cargando = false;
        });
      }
      _mostrarMensaje(
        'Tiempo de espera agotado al verificar edad',
        Colors.orange,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _edadVerificada = true;
          _esMayorEdad = false;
          _cargando = false;
        });
      }
      _mostrarMensaje('Error al verificar edad del alumno', Colors.orange);
    }
  }

  bool _validarFormatoCurp(String curp) {
    if (curp.length != 18) return false;
    final regex = RegExp(
      r'^[A-Z]{4}\d{6}[HM][A-Z]{5}[A-Z0-9]\d$',
      caseSensitive: true,
    );
    return regex.hasMatch(curp);
  }

  bool _calcularMayoriaEdadPorCurp(String curp) {
    if (!_validarFormatoCurp(curp)) return false;

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
      debugPrint('Error al calcular edad desde CURP: $e');
      return false;
    }
  }

  Future<void> _verificarDocumentos() async {
    try {
      if (!mounted) return;

      setState(() => _cargando = true);

      final snapshot = await _firestore
          .collection('visitas_escolares')
          .doc(widget.visitaId)
          .get()
          .timeout(const Duration(seconds: 10));

      if (!snapshot.exists) {
        if (mounted) setState(() => _cargando = false);
        return;
      }

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
          };
        }
      }

      if (mounted) setState(() => _cargando = false);
    } on TimeoutException {
      if (mounted) setState(() => _cargando = false);
      _mostrarMensaje(
        'Tiempo de espera al verificar documentos',
        Colors.orange,
      );
    } catch (e) {
      if (mounted) setState(() => _cargando = false);
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

    try {
      final resultado = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (resultado != null && resultado.files.isNotEmpty) {
        final archivo = File(resultado.files.single.path!);
        if (archivo.lengthSync() > 5 * 1024 * 1024) {
          _mostrarMensaje('El archivo no debe exceder 5MB', Colors.red);
          return;
        }
        if (mounted) {
          setState(() => _archivo = archivo);
        }
      }
    } catch (e) {
      _mostrarMensaje('Error al seleccionar archivo: $e', Colors.red);
    }
  }

  Future<void> _subirDocumento() async {
    if (_tipoSeleccionado == null || _archivo == null) {
      _mostrarMensaje('Selecciona un documento y un archivo', Colors.orange);
      return;
    }

    if (_tipoSeleccionado == 'INE_Alumno' && !_esMayorEdad) {
      _mostrarMensaje(
        'Este documento no es requerido para menores de edad',
        Colors.red,
      );
      return;
    }

    setState(() => _cargando = true);
    try {
      final nombreArchivo = _generarNombreArchivo(_tipoSeleccionado!);
      final rutaStorage =
          'visitas/${widget.visitaId}/${widget.alumnoId}/$nombreArchivo';
      final referencia = _storage.ref().child(rutaStorage);
      await referencia.putFile(_archivo!);
      final url = await referencia.getDownloadURL();

      final urlAnterior =
          _estadoDocumentos[_tipoSeleccionado]?['url'] as String? ?? '';

      await _reemplazarDocumentoExistente(url, nombreArchivo);

      if (urlAnterior.isNotEmpty) {
        await _eliminarArchivoStorage(urlAnterior);
      }

      _mostrarMensaje('Documento subido con éxito', Colors.green);
      widget.onArchivoSubido();
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      _mostrarMensaje('Error al subir documento: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _cargando = false);
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

      archivosPendientes.removeWhere(
        (archivo) =>
            archivo['alumnoId'] == widget.alumnoId &&
            archivo['tipo'] == _tipoSeleccionado,
      );

      archivosPendientes.add({
        'alumnoId': widget.alumnoId,
        'archivoUrl': url,
        'tipo': _tipoSeleccionado,
        'nombre': _getNombreLegible(_tipoSeleccionado!),
        'nombreArchivo': nombreArchivo,
        'estado': 'pendiente',
        'fechaSubida': Timestamp.now(),
      });

      await visitaRef.update({'archivos_pendientes': archivosPendientes});
    }
  }

  String _generarNombreArchivo(String tipo) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = _archivo?.path.split('.').last ?? 'pdf';
    return '${tipo}_${widget.alumnoId}_$timestamp.$extension';
  }

  String _getNombreLegible(String tipo) {
    switch (tipo) {
      case 'INE_Tutor':
        return 'INE del Tutor';
      case 'INE_Alumno':
        return 'INE del Alumno';
      case 'Constancia_Medica':
        return 'Constancia Médica';
      default:
        return tipo.replaceAll('_', ' ');
    }
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
    final documentosAplicables =
        _estadoDocumentos.entries.where((entry) {
          return entry.value['requerido'] == true &&
              (!entry.value['subido'] || entry.value['estado'] == 'rechazado');
        }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tipo de Documento',
          style: GoogleFonts.roboto(fontSize: 14, color: Colors.grey[600]),
        ),
        const SizedBox(height: 8),

        if (documentosAplicables.isEmpty)
          Text(
            'Todos los documentos requeridos ya han sido subidos',
            style: GoogleFonts.roboto(color: Colors.green),
          )
        else
          DropdownButtonFormField<String>(
            value: _tipoSeleccionado,
            items:
                documentosAplicables.map((entry) {
                  final tipo = entry.key;
                  final nombre = _getNombreLegible(tipo);
                  final estado =
                      entry.value['subido']
                          ? ' (${entry.value['estado']})'
                          : '';
                  return DropdownMenuItem(
                    value: tipo,
                    child: Text('$nombre$estado'),
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
              hintText: 'Selecciona un documento',
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
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(nombre)),
          if (estado['subido'] == true)
            Chip(
              label: Text(
                estado['estado'] ?? 'pendiente',
                style: TextStyle(
                  color:
                      color.computeLuminance() > 0.5
                          ? Colors.black
                          : Colors.white,
                ),
              ),
              backgroundColor: color,
            ),
        ],
      ),
    );
  }

  Widget _buildDocumentosRequeridosInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'Documentos requeridos para este alumno:',
          style: GoogleFonts.roboto(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        _buildDocumentoItem(
          'Constancia Médica de vigencia de derechos médicos',
          _estadoDocumentos['Constancia_Medica']!,
        ),
        _buildDocumentoItem(
          'INE del tutor legal',
          _estadoDocumentos['INE_Tutor']!,
        ),
        if (_esMayorEdad)
          _buildDocumentoItem(
            'INE del alumno (mayor de edad)',
            _estadoDocumentos['INE_Alumno']!,
          ),
        const SizedBox(height: 16),
        Text(
          _esMayorEdad
              ? 'Alumno mayor de edad: Requiere INE propia e INE del tutor'
              : 'Alumno menor de edad: Requiere INE del tutor',
          style: GoogleFonts.roboto(
            fontWeight: FontWeight.bold,
            color: Colors.blue[800],
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

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(
            'Cargando información del alumno...',
            style: GoogleFonts.roboto(fontSize: 16),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () {
              _verificarEdadPorCurp();
              _verificarDocumentos();
            },
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Sube los documentos requeridos para la visita escolar',
            style: GoogleFonts.poppins(fontSize: 16),
          ),
          const SizedBox(height: 24),
          _buildDocumentosRequeridosInfo(),
          _buildTipoDocumento(),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.upload_file),
            label: const Text('Seleccionar archivo (PDF, JPG, PNG)'),
            onPressed: _seleccionarArchivo,
          ),
          if (_archivo != null) ...[
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(
                Icons.insert_drive_file,
                color:
                    _archivo!.path.endsWith('.pdf') ? Colors.red : Colors.blue,
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
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Subir Documento',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
          _buildDocumentosCompletados(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body:
          (!_edadVerificada || _cargando)
              ? _buildLoadingScreen()
              : _buildMainContent(),
    );
  }
}
