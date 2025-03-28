// ignore_for_file: depend_on_referenced_packages, library_private_types_in_public_api, use_build_context_synchronously

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

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
  File? _archivoPDF;
  String? _archivoURL;
  String? _tipoArchivoSeleccionado;
  Map<String, bool> archivosSubidos = {
    'CURP': false,
    'INE_Tutor': false,
    'Constancia_Medica': false,
  };

  @override
  void initState() {
    super.initState();
    _contarArchivosSubidos();
  }

  // Comprobar si ya hay un archivo pendiente para el tipo seleccionado
  Future<bool> _hayArchivoPendiente(String tipo) async {
    DocumentSnapshot visitaDoc =
        await _firestore
            .collection('visitas_escolares')
            .doc(widget.visitaId)
            .get();
    if (visitaDoc.exists) {
      List<dynamic> archivos = [];
      if (visitaDoc.exists && visitaDoc.data() != null) {
        Map<String, dynamic> data = visitaDoc.data() as Map<String, dynamic>;
        if (data.containsKey('archivos_pendientes')) {
          archivos = data['archivos_pendientes'] as List<dynamic>;
        }
      }

      for (var archivo in archivos) {
        if (archivo['alumnoId'] == widget.alumnoId && archivo['tipo'] == tipo) {
          if (archivo['estado'] == 'pendiente') {
            return true; // Ya hay un archivo pendiente de revisión
          }
        }
      }
    }
    return false; // No hay archivo pendiente
  }

  // Comprobar si ya hay un archivo rechazado para este tipo
  Future<bool> _hayArchivoRechazado(String tipo) async {
    DocumentSnapshot visitaDoc =
        await _firestore
            .collection('visitas_escolares')
            .doc(widget.visitaId)
            .get();
    if (visitaDoc.exists) {
      List<dynamic> archivos = [];
      if (visitaDoc.exists && visitaDoc.data() != null) {
        Map<String, dynamic> data = visitaDoc.data() as Map<String, dynamic>;
        if (data.containsKey('archivos_pendientes')) {
          archivos = data['archivos_pendientes'] as List<dynamic>;
        }
      }

      for (var archivo in archivos) {
        if (archivo['alumnoId'] == widget.alumnoId && archivo['tipo'] == tipo) {
          if (archivo['estado'] == 'rechazado') {
            return true; // Ya hay un archivo rechazado para este tipo
          }
        }
      }
    }
    return false; // No hay archivo rechazado
  }

  // Contar los archivos subidos
  Future<void> _contarArchivosSubidos() async {
    DocumentSnapshot visitaDoc =
        await _firestore
            .collection('visitas_escolares')
            .doc(widget.visitaId)
            .get();
    if (visitaDoc.exists) {
      List<dynamic> archivos = [];
      if (visitaDoc.exists && visitaDoc.data() != null) {
        Map<String, dynamic> data = visitaDoc.data() as Map<String, dynamic>;
        if (data.containsKey('archivos_pendientes')) {
          archivos = data['archivos_pendientes'] as List<dynamic>;
        }
      }

      for (var archivo in archivos) {
        if (archivo['alumnoId'] == widget.alumnoId &&
            archivosSubidos.containsKey(archivo['tipo']) &&
            archivo['estado'] != 'rechazado') {
          archivosSubidos[archivo['tipo']] = true;
        }
      }
      setState(() {});
    }
  }

  // Seleccionar archivo
  Future<void> _seleccionarArchivo(BuildContext context) async {
    if (_tipoArchivoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Por favor, selecciona el tipo de archivo.')),
      );
      return;
    }

    // Verificar si ya hay un archivo pendiente para este tipo
    bool hayPendiente = await _hayArchivoPendiente(_tipoArchivoSeleccionado!);
    if (hayPendiente) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ya tienes un archivo pendiente para este tipo.'),
        ),
      );
      return;
    }

    // Verificar si hay un archivo rechazado y permitir volver a subirlo
    bool hayRechazado = await _hayArchivoRechazado(_tipoArchivoSeleccionado!);
    if (hayRechazado) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Este archivo fue rechazado, puedes subir uno nuevo.'),
        ),
      );
    }

    if (archivosSubidos[_tipoArchivoSeleccionado!] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Este archivo ya ha sido subido.')),
      );
      return;
    }

    FilePickerResult? resultado = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (resultado != null) {
      File archivoSeleccionado = File(resultado.files.single.path!);
      int fileSize = archivoSeleccionado.lengthSync();

      if (fileSize > 2 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('El archivo no debe superar los 2MB.')),
        );
        return;
      }

      setState(() {
        _archivoPDF = archivoSeleccionado;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se seleccionó ningún archivo')),
      );
    }
  }

  // Subir archivo
  Future<void> _subirArchivo(BuildContext context) async {
    if (_archivoPDF == null || _tipoArchivoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Por favor, selecciona un archivo y su tipo.')),
      );
      return;
    }

    try {
      String fileName = '$_tipoArchivoSeleccionado.pdf';
      Reference storageRef = FirebaseStorage.instance.ref().child(
        'visitas/${widget.visitaId}/${widget.alumnoId}/$fileName',
      );

      // Eliminar archivo rechazado si lo hay
      DocumentSnapshot visitaDoc =
          await _firestore
              .collection('visitas_escolares')
              .doc(widget.visitaId)
              .get();
      if (visitaDoc.exists) {
        List<dynamic> archivos = [];
        if (visitaDoc.exists && visitaDoc.data() != null) {
          Map<String, dynamic> data = visitaDoc.data() as Map<String, dynamic>;
          if (data.containsKey('archivos_pendientes')) {
            archivos = data['archivos_pendientes'] as List<dynamic>;
          }
        }

        for (var archivo in archivos) {
          if (archivo['alumnoId'] == widget.alumnoId &&
              archivo['tipo'] == _tipoArchivoSeleccionado &&
              archivo['estado'] == 'rechazado') {
            // Eliminar archivo rechazado
            await _firestore
                .collection('visitas_escolares')
                .doc(widget.visitaId)
                .update({
                  'archivos_pendientes': FieldValue.arrayRemove([archivo]),
                });
            break; // Salir del bucle después de eliminar
          }
        }
      }

      // Subir el nuevo archivo
      await storageRef.putFile(_archivoPDF!);
      _archivoURL = await storageRef.getDownloadURL();

      await _firestore
          .collection('visitas_escolares')
          .doc(widget.visitaId)
          .update({
            'archivos_pendientes': FieldValue.arrayUnion([
              {
                'alumnoId': widget.alumnoId,
                'archivoUrl': _archivoURL,
                'nombre': fileName,
                'tipo': _tipoArchivoSeleccionado,
                'estado': 'pendiente',
              },
            ]),
          });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Archivo subido exitosamente.')));

      archivosSubidos[_tipoArchivoSeleccionado!] = true;
      widget.onArchivoSubido();
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al subir el archivo: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Subir Archivos')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Selecciona el tipo de archivo a subir:'),
            DropdownButton<String>(
              value: _tipoArchivoSeleccionado,
              hint: Text('Selecciona el tipo de archivo'),
              items:
                  archivosSubidos.keys.map((String tipo) {
                    return DropdownMenuItem<String>(
                      value: tipo,
                      child: Text(tipo.replaceAll('_', ' ')),
                    );
                  }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _tipoArchivoSeleccionado = newValue;
                });
              },
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _seleccionarArchivo(context),
              child: Text('Seleccionar archivo PDF'),
            ),
            SizedBox(height: 20),
            if (_archivoPDF != null)
              Text(
                'Archivo seleccionado: ${_archivoPDF!.path.split('/').last}',
              ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _subirArchivo(context),
              child: Text('Subir archivo'),
            ),
          ],
        ),
      ),
    );
  }
}
