// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:v3/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfesorScreen extends StatefulWidget {
  const ProfesorScreen({super.key});

  @override
  _ProfesorScreenState createState() => _ProfesorScreenState();
}

class _ProfesorScreenState extends State<ProfesorScreen> {
  String? profesorNombre; // Variable para almacenar el nombre del profesor

  @override
  void initState() {
    super.initState();
    _cargarNombreProfesor(); // Cargar el nombre del profesor al iniciar la pantalla
  }

  // Método para cargar el nombre del profesor desde SharedPreferences
  Future<void> _cargarNombreProfesor() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      profesorNombre =
          prefs.getString('user_name') ??
          "Profesor"; // Obtener el nombre guardado
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
                  profesorNombre ?? "Profesor", // Nombre del profesor
                  style: TextStyle(color: Colors.white, fontSize: 16),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Bienvenido Profesor",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text(
              "Aquí puedes gestionar las actividades, comentarios y más para las visitas escolares.",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                // Acción para ver las visitas escolares en las que el profesor está asignado
              },
              child: Text("Ver Mis Visitas Escolares"),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Acción para gestionar actividades en las visitas
              },
              child: Text("Gestionar Actividades de la Visita"),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Acción para ver los comentarios o preguntas de los alumnos sobre la visita
              },
              child: Text("Ver Comentarios de Alumnos"),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Acción para gestionar los materiales o recursos necesarios para la visita
              },
              child: Text("Gestionar Materiales para la Visita"),
            ),
          ],
        ),
      ),
    );
  }
}
