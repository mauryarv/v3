// ignore_for_file: library_private_types_in_public_api

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DetalleVisitaScreen extends StatefulWidget {
  final String visitaId; // ID de la visita

  const DetalleVisitaScreen({super.key, required this.visitaId});

  @override
  _DetalleVisitaScreenState createState() => _DetalleVisitaScreenState();
}

class _DetalleVisitaScreenState extends State<DetalleVisitaScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? visitaDetalles;
  List<String> nombresAlumnos =
      []; // Lista para almacenar los nombres de los alumnos

  @override
  void initState() {
    super.initState();
    _cargarDetallesVisita();
  }

  // Cargar los detalles de la visita desde Firestore
  Future<void> _cargarDetallesVisita() async {
    try {
      DocumentSnapshot visitaSnapshot =
          await _firestore
              .collection('visitas_escolares')
              .doc(widget.visitaId) // Usar el ID de la visita
              .get();

      if (visitaSnapshot.exists) {
        setState(() {
          visitaDetalles = visitaSnapshot.data() as Map<String, dynamic>;
        });

        // Ahora cargar los nombres de los alumnos
        if (visitaDetalles != null && visitaDetalles!['alumnos'] != null) {
          List<String> alumnosIds = List<String>.from(
            visitaDetalles!['alumnos'],
          );
          _cargarNombresAlumnos(alumnosIds);
        }
      }
    } catch (e) {
      print('Error al cargar los detalles de la visita: $e');
    }
  }

  // Cargar los nombres de los alumnos usando sus IDs
  Future<void> _cargarNombresAlumnos(List<String> alumnosIds) async {
    try {
      List<String> nombres = [];

      for (String alumnoId in alumnosIds) {
        DocumentSnapshot alumnoSnapshot =
            await _firestore.collection('usuarios').doc(alumnoId).get();

        if (alumnoSnapshot.exists) {
          String nombreAlumno = alumnoSnapshot['nombre'];
          nombres.add(nombreAlumno);
        }
      }

      setState(() {
        nombresAlumnos = nombres;
      });
    } catch (e) {
      print('Error al cargar los nombres de los alumnos: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Detalles de la Visita')),
      body:
          visitaDetalles == null
              ? Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Título: ${visitaDetalles!['titulo']}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text('Empresa: ${visitaDetalles!['empresa']}'),
                    Text('Profesor: ${visitaDetalles!['profesor']}'),
                    Text(
                      'Fecha y Hora: ${visitaDetalles!['fecha_hora']?.toDate()}',
                    ),
                    SizedBox(height: 20),
                    Text('Alumnos Asignados:', style: TextStyle(fontSize: 18)),
                    ...nombresAlumnos.isEmpty
                        ? [Text('Cargando alumnos...')]
                        : nombresAlumnos
                            .map<Widget>((nombre) => Text(nombre))
                            .toList(),
                  ],
                ),
              ),
    );
  }
}
