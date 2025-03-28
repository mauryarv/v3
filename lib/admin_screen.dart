// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:v3/aprobar_archivos_screen.dart';
import 'crear_visita_screen.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  _AdminScreenState createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _adminName =
      "Administrador"; // Variable para almacenar el nombre del administrador

  @override
  void initState() {
    super.initState();
    _loadAdminName(); // Cargar el nombre del administrador al iniciar la pantalla
  }

  // Método para cargar el nombre del administrador desde SharedPreferences
  Future<void> _loadAdminName() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _adminName =
          prefs.getString('user_name') ??
          "Administrador"; // Obtener el nombre guardado
    });
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

  Future<void> _eliminarVisita(String visitaId) async {
    try {
      await _firestore.collection("visitas_escolares").doc(visitaId).delete();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Visita eliminada correctamente")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error al eliminar visita")));
    }
  }

  void _editarVisita(DocumentSnapshot visita) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CrearVisitaScreen(visita: visita),
      ),
    );
  }

  Future<List<String>> _obtenerNombresAlumnos(List<dynamic> alumnosIds) async {
    List<String> nombres = [];
    for (String id in alumnosIds) {
      var alumnoDoc = await _firestore.collection('usuarios').doc(id).get();
      if (alumnoDoc.exists) {
        nombres.add(alumnoDoc['nombre'] ?? 'Desconocido');
      }
    }
    return nombres;
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
                  _adminName, // Nombre del administrador
                  style: TextStyle(color: Colors.yellow, fontSize: 16),
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
      body: Column(
        children: [
          SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Visitas creadas',
              style: GoogleFonts.caveat(
                fontSize: 30,
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  _firestore
                      .collection("visitas_escolares")
                      .orderBy("fecha_creacion", descending: true)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text("No hay visitas creadas"));
                }
                return ListView(
                  children:
                      snapshot.data!.docs.map((doc) {
                        var data = doc.data() as Map<String, dynamic>;
                        String titulo = data["titulo"] ?? "Sin título";
                        String empresa = data["empresa"] ?? "Desconocida";
                        String grupo = data["grupo"] ?? "No asignado";
                        String profesor = data["profesor"] ?? "No asignado";
                        List<dynamic> alumnos = data["alumnos"] ?? [];
                        Timestamp? timestamp = data["fecha_hora"] as Timestamp?;
                        String fechaHoraTexto = "No definida";
                        if (timestamp != null) {
                          fechaHoraTexto = DateFormat(
                            'yyyy-MM-dd HH:mm',
                          ).format(timestamp.toDate());
                        }

                        return FutureBuilder<List<String>>(
                          future: _obtenerNombresAlumnos(alumnos),
                          builder: (context, alumnosSnapshot) {
                            String alumnosTexto = "Cargando...";
                            if (alumnosSnapshot.connectionState ==
                                ConnectionState.done) {
                              alumnosTexto =
                                  alumnosSnapshot.hasData
                                      ? alumnosSnapshot.data!.join(', ')
                                      : "No disponibles";
                            }

                            return Card(
                              margin: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ListTile(
                                title: Text(
                                  titulo,
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("📍 Empresa: $empresa"),
                                    Text("👥 Grupo: $grupo"),
                                    Text("🎓 Profesor: $profesor"),
                                    Text("📅 Fecha y Hora: $fechaHoraTexto"),
                                    Text("👦 Alumnos: $alumnosTexto"),
                                  ],
                                ),
                                isThreeLine: true,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.folder_open,
                                        color: Colors.orange,
                                      ),
                                      onPressed:
                                          () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (context) =>
                                                      AprobarArchivosScreen(
                                                        visitaId: doc.id,
                                                      ),
                                            ),
                                          ),
                                      tooltip: 'Revisar Archivos',
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.edit,
                                        color: Colors.blue,
                                      ),
                                      onPressed: () => _editarVisita(doc),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () => _eliminarVisita(doc.id),
                                    ),
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
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: FloatingActionButton.extended(
              backgroundColor: Colors.blue,
              autofocus: true,
              hoverElevation: 50,
              hoverColor: Colors.orange,
              heroTag: 'uniqueTag',
              label: Row(children: [Icon(Icons.add), Text('Crear')]),
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CrearVisitaScreen(),
                    ),
                  ),
            ),
          ),
          SizedBox(height: 30),
        ],
      ),
    );
  }
}
