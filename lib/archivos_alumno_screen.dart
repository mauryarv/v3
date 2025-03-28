// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class ArchivosAlumnoScreen extends StatefulWidget {
  final String visitaId;
  final String alumnoId;
  final String nombreAlumno;
  final List<Map<String, dynamic>> archivos;

  const ArchivosAlumnoScreen({
    super.key,
    required this.visitaId,
    required this.alumnoId,
    required this.nombreAlumno,
    required this.archivos,
  });

  @override
  _ArchivosAlumnoScreenState createState() => _ArchivosAlumnoScreenState();
}

class _ArchivosAlumnoScreenState extends State<ArchivosAlumnoScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Función para actualizar el estado del archivo (aprobado o rechazado)
  Future<void> _actualizarEstadoArchivo(
    Map<String, dynamic> archivo,
    String nuevoEstado,
  ) async {
    try {
      DocumentReference visitaRef = _firestore
          .collection("visitas_escolares")
          .doc(widget.visitaId);

      // Eliminar el archivo original (con el estado anterior)
      await visitaRef.update({
        "archivos_pendientes": FieldValue.arrayRemove([archivo]),
      });

      // Agregar el archivo con el nuevo estado
      archivo["estado"] = nuevoEstado;
      await visitaRef.update({
        "archivos_pendientes": FieldValue.arrayUnion([archivo]),
      });

      // Actualizar el estado en la pantalla
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al actualizar el estado del archivo")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Archivos de ${widget.nombreAlumno}")),
      body: ListView.builder(
        itemCount: widget.archivos.length,
        itemBuilder: (context, index) {
          var archivo = widget.archivos[index];
          String nombre = archivo["nombre"] ?? "Sin nombre";
          String url = archivo["archivoUrl"] ?? "";
          String estado = archivo["estado"] ?? "pendiente";

          return Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListTile(
              title: Text(
                nombre,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text("Estado: $estado"),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Botón para aprobar el archivo
                  IconButton(
                    icon: Icon(Icons.check, color: Colors.green),
                    onPressed: () {
                      _actualizarEstadoArchivo(archivo, "aprobado");
                    },
                  ),
                  // Botón para rechazar el archivo
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.red),
                    onPressed: () {
                      _actualizarEstadoArchivo(archivo, "rechazado");
                    },
                  ),
                ],
              ),
              onTap: () async {
                if (await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(Uri.parse(url));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("No se pudo abrir el archivo")),
                  );
                }
              },
            ),
          );
        },
      ),
    );
  }
}
