// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'detalle_visita_screen.dart';
import 'login_screen.dart';
import 'subir_archivo_screen.dart';

class AlumnoScreen extends StatefulWidget {
  final String alumnoId;

  const AlumnoScreen({super.key, required this.alumnoId});

  @override
  _AlumnoScreenState createState() => _AlumnoScreenState();
}

class _AlumnoScreenState extends State<AlumnoScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> visitas = [];
  String? alumnoNombre;
  bool _isLoading = true;
  bool _emergencyDataComplete = false;
  Map<String, dynamic>? _emergencyData;
  StreamSubscription<DocumentSnapshot>? _emergencyDataSubscription;

  // Lista de tipos de sangre disponibles
  static const List<String> bloodTypes = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  // Lista de opciones para campos de sí/no
  static const List<String> yesNoOptions = ['Sí', 'No'];

  // Controladores para el formulario de emergencia
  final _emergencyFormKey = GlobalKey<FormState>();
  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _contactRelationshipController = TextEditingController();
  final _curpController = TextEditingController();

  // Controladores para campos de descripción
  final _allergiesDetailController = TextEditingController();
  final _chronicDiseasesDetailController = TextEditingController();
  final _psychologicalConditionController = TextEditingController();
  final _surgicalInterventionController = TextEditingController();
  final _medicationController = TextEditingController();
  final _motorDisabilityController = TextEditingController();

  // Variables para los dropdowns
  String? _selectedBloodType;
  String? _hasAllergies;
  String? _hasChronicDiseases;
  String? _hasPsychologicalCondition;
  String? _hasSurgicalIntervention;
  String? _takesMedication;
  String? _hasMotorDisability;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    _setupEmergencyDataListener();
  }

  @override
  void dispose() {
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _contactRelationshipController.dispose();
    _curpController.dispose();
    _allergiesDetailController.dispose();
    _chronicDiseasesDetailController.dispose();
    _psychologicalConditionController.dispose();
    _surgicalInterventionController.dispose();
    _medicationController.dispose();
    _motorDisabilityController.dispose();
    _emergencyDataSubscription?.cancel();
    super.dispose();
  }

  void _setupEmergencyDataListener() {
    _emergencyDataSubscription = _firestore
        .collection('usuarios')
        .doc(widget.alumnoId)
        .collection('datos_emergencia')
        .doc('info')
        .snapshots()
        .listen((snapshot) {
          if (mounted) {
            setState(() {
              _emergencyData = snapshot.data();
              _emergencyDataComplete = snapshot.exists;
              _updateControllersFromData();
            });
          }
        });
  }

  void _updateControllersFromData() {
    if (_emergencyData != null) {
      _selectedBloodType = _emergencyData?['tipoSangre'];
      _hasAllergies = _emergencyData?['tieneAlergias'];
      _hasChronicDiseases = _emergencyData?['tieneEnfermedadesCronicas'];
      _hasPsychologicalCondition = _emergencyData?['padecimientoPsicologico'];
      _hasSurgicalIntervention = _emergencyData?['intervencionQuirurgica'];
      _takesMedication = _emergencyData?['tomaMedicamento'];
      _hasMotorDisability = _emergencyData?['discapacidadMotriz'];

      _contactNameController.text = _emergencyData?['nombreContacto'] ?? '';
      _contactPhoneController.text = _emergencyData?['telefonoContacto'] ?? '';
      _contactRelationshipController.text =
          _emergencyData?['parentescoContacto'] ?? '';
      _curpController.text = _emergencyData?['curp'] ?? '';
      _allergiesDetailController.text =
          _emergencyData?['detalleAlergias'] ?? '';
      _chronicDiseasesDetailController.text =
          _emergencyData?['detalleEnfermedadesCronicas'] ?? '';
      _psychologicalConditionController.text =
          _emergencyData?['detallePadecimientoPsicologico'] ?? '';
      _surgicalInterventionController.text =
          _emergencyData?['detalleIntervencionQuirurgica'] ?? '';
      _medicationController.text = _emergencyData?['detalleMedicamento'] ?? '';
      _motorDisabilityController.text =
          _emergencyData?['detalleDiscapacidadMotriz'] ?? '';
    }
  }

  Future<void> _cargarDatos() async {
    try {
      setState(() => _isLoading = true);
      await Future.wait([
        _cargarNombreAlumno(),
        _cargarVisitas(),
        _checkEmergencyData(),
      ]);
    } catch (e) {
      _mostrarError('Error al cargar datos: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkEmergencyData() async {
    try {
      final snapshot = await _firestore
          .collection('usuarios')
          .doc(widget.alumnoId)
          .collection('datos_emergencia')
          .doc('info')
          .get(GetOptions(source: Source.server));

      if (mounted) {
        setState(() {
          _emergencyData = snapshot.data();
          _emergencyDataComplete = snapshot.exists;
          _updateControllersFromData();
        });
      }
    } catch (e) {
      if (mounted) _mostrarError('Error al verificar datos de emergencia: $e');
    }
  }

  Future<void> _logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id');
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e) {
      if (mounted) _mostrarError("Error al cerrar sesión");
    }
  }

  Future<void> _cargarNombreAlumno() async {
    final snapshot =
        await _firestore.collection('usuarios').doc(widget.alumnoId).get();
    if (snapshot.exists && mounted) {
      setState(() => alumnoNombre = snapshot.get('nombre') as String?);
    }
  }

  Future<void> _cargarVisitas() async {
    try {
      final visitasSnapshot =
          await _firestore
              .collection('visitas_escolares')
              .where('alumnos', arrayContains: widget.alumnoId)
              .get();

      final visitasList =
          visitasSnapshot.docs.map((doc) {
            final data = doc.data();
            final archivosRaw =
                data['archivos_pendientes'] as List<dynamic>? ?? [];

            // Filtrar documentos del alumno y conservar el más reciente por tipo
            final Map<String, dynamic> archivosUnicos = {};
            for (var archivo in archivosRaw) {
              final archivoMap = archivo as Map<String, dynamic>;
              if (archivoMap['alumnoId'] == widget.alumnoId) {
                final tipo = archivoMap['tipo'] as String;
                final fecha = archivoMap['fechaSubida'] as Timestamp?;

                if (!archivosUnicos.containsKey(tipo) ||
                    (fecha != null &&
                        (archivosUnicos[tipo]['fechaSubida'] as Timestamp)
                                .compareTo(fecha) <
                            0)) {
                  archivosUnicos[tipo] = archivoMap;
                }
              }
            }

            return {
              'id': doc.id,
              'ubicacion': data['ubicacion'] as String? ?? 'Sin ubicación',
              'grupo': data['grupo'] as String? ?? 'Sin grupo',
              'fecha_hora': (data['fecha_hora'] as Timestamp?)?.toDate(),
              'archivos_pendientes': archivosUnicos.values.toList(),
            };
          }).toList();

      if (mounted) {
        setState(() => visitas = visitasList);
      }
    } catch (e) {
      if (mounted) _mostrarError('Error al cargar visitas: $e');
    }
  }

  Future<void> _showEmergencyDataDialog() async {
    return showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Datos de Emergencia',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            color: Colors.blue[800],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Por favor completa todos tus datos médicos y de emergencia',
                          style: GoogleFonts.roboto(
                            color: Colors.grey[700],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Form(
                          key: _emergencyFormKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Sección de información básica
                              Text(
                                'Información Básica',
                                style: GoogleFonts.roboto(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.blue[800],
                                ),
                              ),
                              const SizedBox(height: 10),

                              TextFormField(
                                controller: _curpController,
                                decoration: const InputDecoration(
                                  labelText: 'CURP',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.badge),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Este campo es obligatorio';
                                  }
                                  if (!RegExp(
                                    r'^[A-Z]{4}\d{6}[A-Z]{6}\d{2}$',
                                  ).hasMatch(value)) {
                                    return 'Ingresa una CURP válida';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 15),

                              // Sección de contacto de emergencia
                              Text(
                                'Contacto de Emergencia',
                                style: GoogleFonts.roboto(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.blue[800],
                                ),
                              ),
                              const SizedBox(height: 10),

                              TextFormField(
                                controller: _contactNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Nombre completo del contacto',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.person),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Este campo es obligatorio';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 15),

                              TextFormField(
                                controller: _contactPhoneController,
                                decoration: const InputDecoration(
                                  labelText: 'Teléfono del contacto',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.phone),
                                ),
                                keyboardType: TextInputType.phone,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Este campo es obligatorio';
                                  }
                                  if (!RegExp(r'^[0-9]{10}$').hasMatch(value)) {
                                    return 'Ingresa un teléfono válido (10 dígitos)';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 15),

                              TextFormField(
                                controller: _contactRelationshipController,
                                decoration: const InputDecoration(
                                  labelText: 'Parentesco con el contacto',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.family_restroom),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Este campo es obligatorio';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 15),

                              // Sección de información médica
                              Text(
                                'Información Médica',
                                style: GoogleFonts.roboto(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.blue[800],
                                ),
                              ),
                              const SizedBox(height: 10),

                              DropdownButtonFormField<String>(
                                value: _selectedBloodType,
                                decoration: const InputDecoration(
                                  labelText: 'Tipo de sangre',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.bloodtype),
                                ),
                                isExpanded: true,
                                items:
                                    bloodTypes.map((String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      );
                                    }).toList(),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Por favor selecciona tu tipo de sangre';
                                  }
                                  return null;
                                },
                                onChanged: (String? newValue) {
                                  setState(() {
                                    _selectedBloodType = newValue;
                                  });
                                },
                              ),
                              const SizedBox(height: 15),

                              // Campo de alergias modificado
                              DropdownButtonFormField<String>(
                                value: _hasAllergies,
                                decoration: const InputDecoration(
                                  labelText: '¿Tiene alergias?',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.warning),
                                ),
                                isExpanded: true,
                                items:
                                    yesNoOptions.map((String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      );
                                    }).toList(),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Por favor selecciona una opción';
                                  }
                                  return null;
                                },
                                onChanged: (String? newValue) {
                                  setState(() {
                                    _hasAllergies = newValue;
                                  });
                                },
                              ),
                              const SizedBox(height: 15),

                              if (_hasAllergies == 'Sí')
                                TextFormField(
                                  controller: _allergiesDetailController,
                                  decoration: const InputDecoration(
                                    labelText: 'Describa sus alergias',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.edit),
                                  ),
                                  validator: (value) {
                                    if (_hasAllergies == 'Sí' &&
                                        (value == null || value.isEmpty)) {
                                      return 'Por favor describa sus alergias';
                                    }
                                    return null;
                                  },
                                ),
                              if (_hasAllergies == 'Sí')
                                const SizedBox(height: 15),

                              // Campo de enfermedades crónicas modificado
                              DropdownButtonFormField<String>(
                                value: _hasChronicDiseases,
                                decoration: const InputDecoration(
                                  labelText: '¿Tiene enfermedades crónicas?',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.medical_services),
                                ),
                                isExpanded: true,
                                items:
                                    yesNoOptions.map((String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      );
                                    }).toList(),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Por favor selecciona una opción';
                                  }
                                  return null;
                                },
                                onChanged: (String? newValue) {
                                  setState(() {
                                    _hasChronicDiseases = newValue;
                                  });
                                },
                              ),
                              const SizedBox(height: 15),

                              if (_hasChronicDiseases == 'Sí')
                                TextFormField(
                                  controller: _chronicDiseasesDetailController,
                                  decoration: const InputDecoration(
                                    labelText:
                                        'Describa sus enfermedades crónicas',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.edit),
                                  ),
                                  validator: (value) {
                                    if (_hasChronicDiseases == 'Sí' &&
                                        (value == null || value.isEmpty)) {
                                      return 'Por favor describa sus enfermedades';
                                    }
                                    return null;
                                  },
                                ),
                              if (_hasChronicDiseases == 'Sí')
                                const SizedBox(height: 15),

                              // Campo de condición psicológica
                              DropdownButtonFormField<String>(
                                value: _hasPsychologicalCondition,
                                decoration: const InputDecoration(
                                  labelText:
                                      '¿Has sido diagnósticado con algún padecimiento de orden psicológico?',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.psychology),
                                ),
                                isExpanded: true,
                                items:
                                    yesNoOptions.map((String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      );
                                    }).toList(),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Por favor selecciona una opción';
                                  }
                                  return null;
                                },
                                onChanged: (String? newValue) {
                                  setState(() {
                                    _hasPsychologicalCondition = newValue;
                                  });
                                },
                              ),
                              const SizedBox(height: 15),

                              if (_hasPsychologicalCondition == 'Sí')
                                TextFormField(
                                  controller: _psychologicalConditionController,
                                  decoration: const InputDecoration(
                                    labelText: 'Descríbala, por favor',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.edit),
                                  ),
                                  validator: (value) {
                                    if (_hasPsychologicalCondition == 'Sí' &&
                                        (value == null || value.isEmpty)) {
                                      return 'Por favor descríbala';
                                    }
                                    return null;
                                  },
                                ),
                              if (_hasPsychologicalCondition == 'Sí')
                                const SizedBox(height: 15),

                              // Campo de intervención quirúrgica
                              DropdownButtonFormField<String>(
                                value: _hasSurgicalIntervention,
                                decoration: const InputDecoration(
                                  labelText:
                                      '¿Ha tenido alguna intervención quirúrgica?',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.medical_information),
                                ),
                                isExpanded: true,
                                items:
                                    yesNoOptions.map((String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      );
                                    }).toList(),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Por favor selecciona una opción';
                                  }
                                  return null;
                                },
                                onChanged: (String? newValue) {
                                  setState(() {
                                    _hasSurgicalIntervention = newValue;
                                  });
                                },
                              ),
                              const SizedBox(height: 15),

                              if (_hasSurgicalIntervention == 'Sí')
                                TextFormField(
                                  controller: _surgicalInterventionController,
                                  decoration: const InputDecoration(
                                    labelText:
                                        'Describa la intervención quirúrgica',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.edit),
                                  ),
                                  validator: (value) {
                                    if (_hasSurgicalIntervention == 'Sí' &&
                                        (value == null || value.isEmpty)) {
                                      return 'Por favor describa la intervención';
                                    }
                                    return null;
                                  },
                                ),
                              if (_hasSurgicalIntervention == 'Sí')
                                const SizedBox(height: 15),

                              // Campo de medicamentos
                              DropdownButtonFormField<String>(
                                value: _takesMedication,
                                decoration: const InputDecoration(
                                  labelText:
                                      '¿Toma algún medicamento actualmente?',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.medication),
                                ),
                                isExpanded: true,
                                items:
                                    yesNoOptions.map((String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      );
                                    }).toList(),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Por favor selecciona una opción';
                                  }
                                  return null;
                                },
                                onChanged: (String? newValue) {
                                  setState(() {
                                    _takesMedication = newValue;
                                  });
                                },
                              ),
                              const SizedBox(height: 15),

                              if (_takesMedication == 'Sí')
                                TextFormField(
                                  controller: _medicationController,
                                  decoration: const InputDecoration(
                                    labelText:
                                        'Describa los medicamentos que toma',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.edit),
                                  ),
                                  validator: (value) {
                                    if (_takesMedication == 'Sí' &&
                                        (value == null || value.isEmpty)) {
                                      return 'Por favor liste los medicamentos';
                                    }
                                    return null;
                                  },
                                ),
                              if (_takesMedication == 'Sí')
                                const SizedBox(height: 15),

                              // Campo de discapacidad motriz
                              DropdownButtonFormField<String>(
                                value: _hasMotorDisability,
                                decoration: const InputDecoration(
                                  labelText:
                                      '¿Requieres con alguna discapacidad motriz?',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.accessible),
                                ),
                                isExpanded: true,
                                items:
                                    yesNoOptions.map((String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      );
                                    }).toList(),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Por favor selecciona una opción';
                                  }
                                  return null;
                                },
                                onChanged: (String? newValue) {
                                  setState(() {
                                    _hasMotorDisability = newValue;
                                  });
                                },
                              ),
                              const SizedBox(height: 15),

                              if (_hasMotorDisability == 'Sí')
                                TextFormField(
                                  controller: _motorDisabilityController,
                                  decoration: const InputDecoration(
                                    labelText:
                                        'Describa su discapacidad motriz',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.edit),
                                  ),
                                  validator: (value) {
                                    if (_hasMotorDisability == 'Sí' &&
                                        (value == null || value.isEmpty)) {
                                      return 'Por favor describa su discapacidad';
                                    }
                                    return null;
                                  },
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                'Cancelar',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: () async {
                                if (_emergencyFormKey.currentState!
                                    .validate()) {
                                  try {
                                    // Guardar datos
                                    await _firestore
                                        .collection('usuarios')
                                        .doc(widget.alumnoId)
                                        .collection('datos_emergencia')
                                        .doc('info')
                                        .set({
                                          // Información básica
                                          'curp': _curpController.text,

                                          // Contacto de emergencia
                                          'nombreContacto':
                                              _contactNameController.text,
                                          'telefonoContacto':
                                              _contactPhoneController.text,
                                          'parentescoContacto':
                                              _contactRelationshipController
                                                  .text,

                                          // Información médica general
                                          'tipoSangre': _selectedBloodType,
                                          'tieneAlergias': _hasAllergies,
                                          'detalleAlergias':
                                              _allergiesDetailController.text,
                                          'tieneEnfermedadesCronicas':
                                              _hasChronicDiseases,
                                          'detalleEnfermedadesCronicas':
                                              _chronicDiseasesDetailController
                                                  .text,

                                          // Condiciones específicas
                                          'padecimientoPsicologico':
                                              _hasPsychologicalCondition,
                                          'detallePadecimientoPsicologico':
                                              _psychologicalConditionController
                                                  .text,
                                          'intervencionQuirurgica':
                                              _hasSurgicalIntervention,
                                          'detalleIntervencionQuirurgica':
                                              _surgicalInterventionController
                                                  .text,
                                          'tomaMedicamento': _takesMedication,
                                          'detalleMedicamento':
                                              _medicationController.text,
                                          'discapacidadMotriz':
                                              _hasMotorDisability,
                                          'detalleDiscapacidadMotriz':
                                              _motorDisabilityController.text,

                                          'fechaActualizacion':
                                              FieldValue.serverTimestamp(),
                                        });

                                    // Forzar recarga desde el servidor
                                    await _firestore
                                        .collection('usuarios')
                                        .doc(widget.alumnoId)
                                        .collection('datos_emergencia')
                                        .doc('info')
                                        .get(GetOptions(source: Source.server));

                                    if (mounted) {
                                      setState(() {
                                        _emergencyDataComplete = true;
                                      });
                                      await _cargarDatos();
                                      Navigator.pop(context);
                                      _mostrarExito(
                                        'Datos de emergencia guardados correctamente. Ahora puedes subir documentos.',
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      _mostrarError(
                                        'Error al guardar datos: $e',
                                      );
                                    }
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                              ),
                              child: const Text(
                                'Guardar',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _getEstadoColor(String? estado) {
    switch (estado) {
      case 'aprobado':
        return Colors.green;
      case 'rechazado':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _getNombreLegible(String tipo) {
    switch (tipo) {
      case 'CURP':
        return 'CURP';
      case 'INE_Tutor':
        return 'INE del Tutor';
      case 'Constancia_Medica':
        return 'Constancia Médica';
      default:
        return tipo.replaceAll('_', ' ');
    }
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: LayoutBuilder(
        builder: (context, constraints) {
          return constraints.maxWidth < 400
              ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.school, color: Colors.white, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Mis Visitas',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                ],
              )
              : Text(
                'Mis Visitas Escolares',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                ),
              );
        },
      ),
      actions: [
        LayoutBuilder(
          builder: (context, constraints) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      _emergencyDataComplete
                          ? Icons.verified_user
                          : Icons.warning,
                      color:
                          _emergencyDataComplete
                              ? Colors.green[200]
                              : Colors.amber[200],
                      size: 24,
                    ),
                    onPressed: _showEmergencyDataDialog,
                    tooltip:
                        _emergencyDataComplete
                            ? 'Datos de emergencia completos'
                            : 'Faltan datos de emergencia',
                  ),
                  if (constraints.maxWidth > 350) ...[
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        alumnoNombre ?? "Alumno",
                        style: GoogleFonts.roboto(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.logout, size: 22),
          onPressed: _logout,
          tooltip: 'Cerrar sesión',
          color: Colors.white,
        ),
      ],
      centerTitle: true,
      backgroundColor: Colors.blue,
      elevation: 4,
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

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.roboto(fontSize: 14, color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitaCard(Map<String, dynamic> visita) {
    final fechaHora = visita['fecha_hora'] as DateTime?;
    final archivosPendientes = visita['archivos_pendientes'] as List<dynamic>;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) =>
                      DetalleVisitaScreen(visitaId: visita['id'] as String),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "Visita ID: ${visita['id']}",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[800],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (archivosPendientes.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${archivosPendientes.length} documento(s)',
                        style: GoogleFonts.roboto(
                          color: Colors.orange[800],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _buildInfoRow(Icons.location_on, 'Lugar: ${visita['ubicacion']}'),
              _buildInfoRow(Icons.people, 'Grupo: ${visita['grupo']}'),
              if (fechaHora != null)
                _buildInfoRow(
                  Icons.calendar_today,
                  'Fecha y hora: ${DateFormat('dd/MM/yyyy - HH:mm').format(fechaHora)}',
                ),
              const SizedBox(height: 12),
              if (archivosPendientes.isNotEmpty) ...[
                Text(
                  'Documentos requeridos:',
                  style: GoogleFonts.roboto(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                ...archivosPendientes.map<Widget>((archivo) {
                  final archivoMap = archivo as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.insert_drive_file,
                          size: 16,
                          color: _getEstadoColor(
                            archivoMap['estado'] as String?,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _getNombreLegible(
                              archivoMap['tipo'] as String? ?? 'documento',
                            ),
                            style: GoogleFonts.roboto(
                              fontSize: 14,
                              color: Colors.grey[800],
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getEstadoColor(
                              archivoMap['estado'] as String?,
                            ).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            archivoMap['estado'] as String? ?? 'pendiente',
                            style: GoogleFonts.roboto(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _getEstadoColor(
                                archivoMap['estado'] as String?,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (!_emergencyDataComplete) {
                      _mostrarError(
                        'Completa y guarda tus datos de emergencia primero',
                      );
                      _showEmergencyDataDialog();
                      return;
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => SubirArchivoScreen(
                              visitaId: visita['id'] as String,
                              alumnoId: widget.alumnoId,
                              onArchivoSubido: _cargarDatos,
                            ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _emergencyDataComplete ? Colors.blue : Colors.grey,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Subir documento',
                    style: GoogleFonts.roboto(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _mostrarExito(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    return Scaffold(
      appBar: _buildAppBar(),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              )
              : visitas.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.assignment, size: 60, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No tienes visitas asignadas',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              )
              : SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 24,
                  vertical: 16,
                ),
                child: Column(children: visitas.map(_buildVisitaCard).toList()),
              ),
    );
  }
}
