// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AgregarEmpresaScreen extends StatefulWidget {
  const AgregarEmpresaScreen({super.key});

  @override
  _AgregarEmpresaScreenState createState() => _AgregarEmpresaScreenState();
}

class _AgregarEmpresaScreenState extends State<AgregarEmpresaScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  TextEditingController nombreController = TextEditingController();
  TextEditingController ubicacionController = TextEditingController();

  Future<void> _agregarEmpresa() async {
    if (nombreController.text.isNotEmpty &&
        ubicacionController.text.isNotEmpty) {
      try {
        await _firestore.collection("empresas").add({
          'nombre': nombreController.text,
          'ubicacion': ubicacionController.text,
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Empresa agregada exitosamente")),
        );
        Navigator.pop(context); // Regresa a la pantalla anterior
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error al agregar la empresa")));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Por favor, completa todos los campos")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Agregar Nueva Empresa")),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: nombreController,
              decoration: InputDecoration(labelText: "Nombre de la empresa"),
            ),
            TextField(
              controller: ubicacionController,
              decoration: InputDecoration(labelText: "Ubicación de la empresa"),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _agregarEmpresa,
              child: Text("Agregar Empresa"),
            ),
          ],
        ),
      ),
    );
  }
}
