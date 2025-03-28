// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:v3/archivos_alumno_screen.dart';

class AprobarArchivosScreen extends StatefulWidget {
  final String visitaId;

  const AprobarArchivosScreen({super.key, required this.visitaId});

  @override
  _AprobarArchivosScreenState createState() => _AprobarArchivosScreenState();
}

class _AprobarArchivosScreenState extends State<AprobarArchivosScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Función para obtener el nombre del alumno por su ID
  Future<String> _obtenerNombreAlumno(String alumnoId) async {
    try {
      DocumentSnapshot alumnoDoc =
          await _firestore
              .collection(
                "usuarios",
              ) // Colección donde se almacenan los alumnos
              .doc(alumnoId)
              .get();
      if (alumnoDoc.exists) {
        return alumnoDoc["nombre"] ?? "Alumno desconocido";
      }
    } catch (e) {
      print("Error al obtener el nombre del alumno: $e");
    }
    return "Alumno desconocido";
  }

  // Función para determinar el estado de los archivos de un alumno
  String _determinarEstadoArchivos(List<Map<String, dynamic>> archivos) {
    bool todosAprobados = archivos.every(
      (archivo) => archivo["estado"] == "aprobado",
    );
    bool todosRechazados = archivos.every(
      (archivo) => archivo["estado"] == "rechazado",
    );

    if (todosAprobados) {
      return "aprobado";
    } else if (todosRechazados) {
      return "rechazado";
    } else {
      return "pendiente";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Aprobar Archivos")),
      body: StreamBuilder<DocumentSnapshot>(
        stream:
            _firestore
                .collection("visitas_escolares")
                .doc(widget.visitaId)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return Center(child: Text("No se encontraron datos"));
          }

          Map<String, dynamic>? data =
              snapshot.data!.data() as Map<String, dynamic>?;
          List<dynamic> archivosPendientes = data?["archivos_pendientes"] ?? [];

          if (archivosPendientes.isEmpty) {
            return Center(child: Text("No hay archivos pendientes"));
          }

          // Agrupar archivos por alumnoId
          Map<String, List<Map<String, dynamic>>> archivosPorAlumno = {};
          for (var archivo in archivosPendientes) {
            String alumnoId = archivo["alumnoId"] ?? "sin_alumno";
            if (!archivosPorAlumno.containsKey(alumnoId)) {
              archivosPorAlumno[alumnoId] = [];
            }
            archivosPorAlumno[alumnoId]!.add(archivo);
          }

          return ListView(
            children:
                archivosPorAlumno.entries.map((entry) {
                  String alumnoId = entry.key;
                  List<Map<String, dynamic>> archivosAlumno = entry.value;

                  return FutureBuilder<String>(
                    future: _obtenerNombreAlumno(alumnoId),
                    builder: (context, nombreSnapshot) {
                      if (nombreSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      }
                      String nombreAlumno =
                          nombreSnapshot.data ?? "Alumno desconocido";

                      // Determinar el estado de los archivos del alumno
                      String estadoArchivos = _determinarEstadoArchivos(
                        archivosAlumno,
                      );

                      return Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.all(16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => ArchivosAlumnoScreen(
                                      visitaId: widget.visitaId,
                                      alumnoId: alumnoId,
                                      nombreAlumno: nombreAlumno,
                                      archivos: archivosAlumno,
                                    ),
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  nombreAlumno,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              // Icono según el estado de los archivos
                              if (estadoArchivos == "aprobado")
                                Icon(Icons.check_circle, color: Colors.green),
                              if (estadoArchivos == "rechazado")
                                Icon(Icons.cancel, color: Colors.red),
                              if (estadoArchivos == "pendiente")
                                Icon(Icons.warning, color: Colors.orange),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }).toList(),
          );
        },
      ),
    );
  }
}
