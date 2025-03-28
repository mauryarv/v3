// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v3/detalle_visita_screen.dart';
import 'package:v3/login_screen.dart';
import 'package:v3/subir_archivo_screen.dart'; // Asegúrate de importar la pantalla de subida de archivo

class AlumnoScreen extends StatefulWidget {
  final String alumnoId; // ID del alumno

  const AlumnoScreen({super.key, required this.alumnoId});

  @override
  _AlumnoScreenState createState() => _AlumnoScreenState();
}

class _AlumnoScreenState extends State<AlumnoScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> visitas = [];
  String? alumnoNombre;

  @override
  void initState() {
    super.initState();
    _cargarVisitas();
    _cargarNombreAlumno();
  }

  Future<void> _logout() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error al cerrar sesión")));
    }
  }

  // Cargar el nombre del alumno desde la base de datos
  Future<void> _cargarNombreAlumno() async {
    try {
      DocumentSnapshot alumnoSnapshot =
          await _firestore.collection('usuarios').doc(widget.alumnoId).get();
      if (alumnoSnapshot.exists) {
        setState(() {
          alumnoNombre = alumnoSnapshot['nombre'];
        });
      }
    } catch (e) {
      print('Error al cargar el nombre del alumno: $e');
    }
  }

  // Cargar las visitas asignadas al alumno
  Future<void> _cargarVisitas() async {
    try {
      QuerySnapshot visitasSnapshot =
          await _firestore
              .collection('visitas_escolares')
              .where(
                'alumnos',
                arrayContains: widget.alumnoId,
              ) // Buscar por ID de alumno
              .get();

      setState(() {
        visitas =
            visitasSnapshot.docs.map((doc) {
              var data = doc.data() as Map<String, dynamic>;

              // Filtrar solo los archivos que corresponden al alumno actual
              List<dynamic> archivosPendientes =
                  data['archivos_pendientes'] ?? [];
              archivosPendientes =
                  archivosPendientes.where((archivo) {
                    return archivo['alumnoId'] == widget.alumnoId;
                  }).toList(); // Filtra por el alumnoId

              return {
                'id': doc.id,
                'titulo': data['titulo'],
                'empresa': data['empresa'],
                'fecha_hora': data['fecha_hora']?.toDate(),
                'profesor': data['profesor'],
                'archivos_pendientes':
                    archivosPendientes, // Solo archivos del alumno
              };
            }).toList();
      });
    } catch (e) {
      print('Error al cargar visitas: $e');
    }
  }

  // Método para navegar a la pantalla de subir archivo
  void _navegarASubirArchivo(String visitaId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => SubirArchivoScreen(
              visitaId: visitaId,
              alumnoId: widget.alumnoId,
              onArchivoSubido: _cargarVisitas, // Ahora sí está definido
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Visitas Escolares V3',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        actions: [
          // Icono para mostrar el nombre del administrador
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                Icon(Icons.person, color: Colors.yellow), // Icono de persona
                SizedBox(width: 5), // Espacio entre el icono y el texto
                Text(
                  alumnoNombre ?? "Alumno", // Nombre del alumno
                  style: TextStyle(color: Colors.black, fontSize: 16),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Cerrar sesión',
            color: Colors.red,
          ),
        ],
        centerTitle: true,
        backgroundColor: Colors.blue,
        shadowColor: Colors.grey,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4C60AF), Color.fromARGB(255, 37, 195, 248)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child:
            visitas.isEmpty
                ? Center(child: Text('No tienes visitas asignadas.'))
                : ListView.builder(
                  itemCount: visitas.length,
                  itemBuilder: (context, index) {
                    var visita = visitas[index];
                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        title: Text(visita['titulo']),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Empresa: ${visita['empresa']}'),
                            Text('Profesor: ${visita['profesor']}'),
                            Text(
                              'Fecha y Hora: ${visita['fecha_hora'] != null ? '${visita['fecha_hora']!.toLocal()}' : 'No disponible'}',
                            ),
                            // Mostrar archivos pendientes
                            ...visita['archivos_pendientes'].map<Widget>((
                              archivo,
                            ) {
                              return ListTile(
                                title: Text('Archivo: ${archivo['nombre']}'),
                                subtitle: Text('Estado: ${archivo['estado']}'),
                              );
                            }).toList(),
                          ],
                        ),
                        trailing: ElevatedButton(
                          onPressed: () => _navegarASubirArchivo(visita['id']),
                          child: Text('Subir archivo'),
                        ),
                        onTap: () {
                          // Navegar a la pantalla de detalles
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => DetalleVisitaScreen(
                                    visitaId: visita['id'],
                                  ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
      ),
    );
  }
}
