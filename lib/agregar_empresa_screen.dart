// ignore_for_file: library_private_types_in_public_api

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_google_places_hoc081098/flutter_google_places_hoc081098.dart';
import 'package:flutter_google_places_hoc081098/google_maps_webservice_places.dart';
import 'package:http/http.dart' as http;

const String googleApiKey = "AIzaSyApcSK58jVxe0m_QBfjtptqBvKI_-gKxvs";

class AgregarEmpresaScreen extends StatefulWidget {
  const AgregarEmpresaScreen({super.key});

  @override
  _AgregarEmpresaScreenState createState() => _AgregarEmpresaScreenState();
}

class _AgregarEmpresaScreenState extends State<AgregarEmpresaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _ubicacionController = TextEditingController();
  bool _isLoading = false;

  double? _latitud;
  double? _longitud;

  Future<void> _handleUbicacionAutocomplete() async {
    final Prediction? prediction = await PlacesAutocomplete.show(
      context: context,
      apiKey: googleApiKey,
      mode: Mode.overlay,
      language: "es",
      components: [Component(Component.country, "mx")],
    );

    if (prediction != null && prediction.placeId != null) {
      setState(() {
        _ubicacionController.text = prediction.description ?? "";
      });

      await _getCoordinatesFromPlaceId(prediction.placeId!);
    }
  }

  Future<void> _getCoordinatesFromPlaceId(String placeId) async {
    final String url =
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$googleApiKey';

    final response = await http.get(Uri.parse(url));
    final data = json.decode(response.body);

    if (data["status"] == "OK") {
      final location = data["result"]["geometry"]["location"];
      setState(() {
        _latitud = location["lat"];
        _longitud = location["lng"];
      });
    } else {
      if (kDebugMode) {
        print("Error obteniendo coordenadas: ${data["status"]}");
      }
    }
  }

  Future<void> _guardarEmpresa() async {
    if (!_formKey.currentState!.validate()) return;

    if (_latitud == null || _longitud == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Selecciona una ubicación válida con el autocompletado.",
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseFirestore.instance.collection("empresas").add({
        "nombre": _nombreController.text.trim(),
        "ubicacion": _ubicacionController.text.trim(),
        "latitud": _latitud,
        "longitud": _longitud,
        "fecha_creacion": FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Empresa agregada exitosamente"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al guardar empresa: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _ubicacionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Agregar Empresa"),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nombreController,
                decoration: InputDecoration(
                  labelText: "Nombre de la empresa",
                  prefixIcon: const Icon(Icons.business),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingresa el nombre de la empresa';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _handleUbicacionAutocomplete,
                child: AbsorbPointer(
                  child: TextFormField(
                    controller: _ubicacionController,
                    decoration: InputDecoration(
                      labelText: "Ubicación",
                      prefixIcon: const Icon(Icons.location_on),
                      hintText: "Usa el autocompletado",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Selecciona la ubicación';
                      }
                      return null;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isLoading ? null : _guardarEmpresa,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child:
                    _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                          "GUARDAR EMPRESA",
                          style: TextStyle(color: Colors.white),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
