// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'package:v3/aprobar_archivos_screen.dart';
import 'package:v3/crear_visita_screen.dart';
import 'package:v3/detalle_visita_screen.dart';
import 'package:v3/login_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  _AdminScreenState createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  bool _showPassword = true;

  int _limit = 10;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  List<DocumentSnapshot> _loadedDocuments = [];
  String _searchText = '';
  List<DocumentSnapshot> _filteredDocuments = [];
  String _adminName = "Administrador";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _loadAdminData();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _mostrarDialogoAgregarAdmin() async {
    final formKey = GlobalKey<FormState>();
    final numeroController = TextEditingController();
    final nombreController = TextEditingController();
    final passwordController = TextEditingController();
    final respuestaController = TextEditingController();
    String preguntaSeleccionada = "¿Cuál es el nombre de tu primera mascota?";

    final List<String> preguntasSeguridad = [
      "¿Cuál es el nombre de tu primera mascota?",
      "¿En qué ciudad naciste?",
      "¿Cuál es tu comida favorita?",
    ];

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Agregar Nuevo Administrador',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            LayoutBuilder(
                              builder: (context, constraints) {
                                return SizedBox(
                                  width: constraints.maxWidth,
                                  child: TextFormField(
                                    controller: numeroController,
                                    decoration: InputDecoration(
                                      labelText:
                                          'Número de empleado (7 dígitos)',
                                      prefixIcon: const Icon(Icons.badge),
                                      border: const OutlineInputBorder(),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 12,
                                            horizontal: 16,
                                          ),
                                      errorMaxLines: 2,
                                    ),
                                    keyboardType: TextInputType.number,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Campo obligatorio';
                                      }
                                      if (value.length != 7 ||
                                          !RegExp(
                                            r'^[0-9]+$',
                                          ).hasMatch(value)) {
                                        return 'Debe tener exactamente 7 dígitos';
                                      }
                                      return null;
                                    },
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                return SizedBox(
                                  width: constraints.maxWidth,
                                  child: TextFormField(
                                    controller: nombreController,
                                    decoration: InputDecoration(
                                      labelText: 'Nombre completo',
                                      prefixIcon: const Icon(Icons.person),
                                      border: const OutlineInputBorder(),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 12,
                                            horizontal: 16,
                                          ),
                                      errorMaxLines: 2,
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Campo obligatorio';
                                      }
                                      return null;
                                    },
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),

                            // En tu widget:
                            LayoutBuilder(
                              builder: (context, constraints) {
                                return SizedBox(
                                  width: constraints.maxWidth,
                                  child: TextFormField(
                                    controller: passwordController,
                                    decoration: InputDecoration(
                                      labelText: 'Contraseña',
                                      prefixIcon: const Icon(Icons.lock),
                                      border: const OutlineInputBorder(),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 12,
                                            horizontal: 16,
                                          ),
                                      errorMaxLines: 3,
                                      helperText:
                                          'Mínimo 8 caracteres, 1 mayúscula, 1 minúscula, 1 número y 1 caracter especial (!@#\$%^&*)',
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _showPassword
                                              ? Icons.visibility
                                              : Icons.visibility_off,
                                          color: Colors.grey[600],
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _showPassword = !_showPassword;
                                          });
                                        },
                                      ),
                                    ),
                                    obscureText:
                                        !_showPassword, // Invertir el valor para el funcionamiento correcto
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Debe establecer una contraseña';
                                      }

                                      if (value.length < 8) {
                                        return 'La contraseña debe tener al menos 8 caracteres';
                                      }

                                      if (!RegExp(r'[A-Z]').hasMatch(value)) {
                                        return 'Debe contener al menos una letra mayúscula';
                                      }

                                      if (!RegExp(r'[a-z]').hasMatch(value)) {
                                        return 'Debe contener al menos una letra minúscula';
                                      }

                                      if (!RegExp(r'[0-9]').hasMatch(value)) {
                                        return 'Debe contener al menos un número';
                                      }

                                      if (!RegExp(
                                        r'[!@#$%^&*]',
                                      ).hasMatch(value)) {
                                        return 'Debe contener al menos un caracter especial (!@#\$%^&*)';
                                      }

                                      return null;
                                    },
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                return SizedBox(
                                  width: constraints.maxWidth,
                                  child: DropdownButtonFormField<String>(
                                    value: preguntaSeleccionada,
                                    decoration: InputDecoration(
                                      labelText: 'Pregunta de seguridad',
                                      prefixIcon: const Icon(Icons.security),
                                      border: const OutlineInputBorder(),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 12,
                                            horizontal: 16,
                                          ),
                                      errorMaxLines: 2,
                                    ),
                                    isExpanded: true,
                                    items:
                                        preguntasSeguridad
                                            .map(
                                              (pregunta) => DropdownMenuItem(
                                                value: pregunta,
                                                child: Text(
                                                  pregunta,
                                                  overflow:
                                                      TextOverflow.visible,
                                                  softWrap: true,
                                                ),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: (value) {
                                      preguntaSeleccionada = value!;
                                    },
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Seleccione una pregunta';
                                      }
                                      return null;
                                    },
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                return SizedBox(
                                  width: constraints.maxWidth,
                                  child: TextFormField(
                                    controller: respuestaController,
                                    decoration: InputDecoration(
                                      labelText: 'Respuesta de seguridad',
                                      prefixIcon: const Icon(
                                        Icons.question_answer,
                                      ),
                                      border: const OutlineInputBorder(),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 12,
                                            horizontal: 16,
                                          ),
                                      errorMaxLines: 2,
                                    ),
                                    obscureText: true,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Debe establecer una respuesta';
                                      }
                                      return null;
                                    },
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                            onPressed: () async {
                              if (formKey.currentState!.validate()) {
                                try {
                                  final doc =
                                      await _firestore
                                          .collection('usuarios')
                                          .doc(numeroController.text)
                                          .get();

                                  if (doc.exists &&
                                      doc.data()?['rol'] == 'admin') {
                                    _mostrarError(
                                      'Ya existe un administrador con este número',
                                    );
                                    return;
                                  }

                                  final passwordHash =
                                      sha256
                                          .convert(
                                            utf8.encode(
                                              passwordController.text,
                                            ),
                                          )
                                          .toString();
                                  final respuestaHash =
                                      sha256
                                          .convert(
                                            utf8.encode(
                                              respuestaController.text,
                                            ),
                                          )
                                          .toString();

                                  await _firestore
                                      .collection('usuarios')
                                      .doc(numeroController.text)
                                      .set({
                                        'numero_empleado':
                                            numeroController.text,
                                        'nombre': nombreController.text,
                                        'password': passwordHash,
                                        'pregunta_seguridad':
                                            preguntaSeleccionada,
                                        'respuesta_seguridad': respuestaHash,
                                        'rol': 'admin',
                                        'fecha_registro':
                                            FieldValue.serverTimestamp(),
                                      }, SetOptions(merge: true));

                                  Navigator.pop(context);
                                  _mostrarExito(
                                    'Administrador agregado exitosamente',
                                  );
                                } catch (e) {
                                  _mostrarError(
                                    'Error al agregar administrador: ${e.toString()}',
                                  );
                                }
                              }
                            },
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
          ),
    );
  }

  Future<void> _cargarAlumnosDesdeExcel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;

      if (bytes == null || bytes.isEmpty) {
        _mostrarError("No se pudo leer el archivo o está vacío");
        return;
      }

      bool isDialogOpen = true;
      int totalAlumnos = 0;
      int gruposProcesados = 0;
      final progressDialog = showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  title: const Text("Procesando archivo..."),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(value: totalAlumnos / 5000),
                      const SizedBox(height: 16),
                      Text("Alumnos procesados: $totalAlumnos"),
                      Text("Grupos procesados: $gruposProcesados"),
                    ],
                  ),
                );
              },
            ),
      );

      final excel = Excel.decodeBytes(bytes);
      List<String> errores = [];
      WriteBatch batch = _firestore.batch();
      const batchSize = 400;

      final alumnosActualesSnapshot =
          await _firestore
              .collection('usuarios')
              .where('rol', isEqualTo: 'alumno')
              .get();
      final alumnosActuales =
          alumnosActualesSnapshot.docs.map((doc) => doc.id).toSet();
      final alumnosEnExcel = <String>{};

      for (var sheetName in excel.tables.keys) {
        final sheet = excel.tables[sheetName]!;

        if (sheet.maxColumns < 2 ||
            sheet.row(0)[0]?.value.toString().toLowerCase() != "boleta" ||
            sheet.row(0)[1]?.value.toString().toLowerCase() != "nombre") {
          errores.add("Formato incorrecto en hoja '$sheetName'");
          continue;
        }

        for (var row in sheet.rows.skip(1)) {
          try {
            dynamic boletaValue = row[0]?.value;
            String boleta = boletaValue?.toString() ?? '';

            if (boletaValue is num) {
              boleta = boletaValue.toStringAsFixed(0);
            }

            if (boleta.length != 10 || !RegExp(r'^[0-9]+$').hasMatch(boleta)) {
              errores.add("Boleta inválida en hoja $sheetName: $boleta");
              continue;
            }

            final nombre = row[1]?.value?.toString().trim() ?? '';
            if (nombre.isEmpty) {
              errores.add("Nombre vacío para boleta $boleta");
              continue;
            }

            final alumnoRef = _firestore.collection('usuarios').doc(boleta);
            batch.set(alumnoRef, {
              'nombre': nombre,
              'rol': 'alumno',
              'grupo': sheetName,
              'fecha_registro': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

            alumnosEnExcel.add(boleta);
            totalAlumnos++;

            if (totalAlumnos % batchSize == 0) {
              await batch.commit();
              batch = _firestore.batch();
              if (isDialogOpen) {
                Navigator.pop(context);
                progressDialog.then((_) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder:
                        (context) => AlertDialog(
                          title: const Text("Procesando archivo..."),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                value: totalAlumnos / 5000,
                              ),
                              const SizedBox(height: 16),
                              Text("Alumnos procesados: $totalAlumnos"),
                              Text(
                                "Grupos procesados: ${gruposProcesados + 1}",
                              ),
                            ],
                          ),
                        ),
                  );
                });
              }
            }
          } catch (e) {
            errores.add("Error en hoja $sheetName: ${e.toString()}");
          }
        }
        gruposProcesados++;
      }

      if (totalAlumnos % batchSize != 0) {
        await batch.commit();
      }

      final alumnosAEliminar = alumnosActuales.difference(alumnosEnExcel);
      if (alumnosAEliminar.isNotEmpty) {
        final deleteBatch = _firestore.batch();
        for (final boleta in alumnosAEliminar) {
          deleteBatch.delete(_firestore.collection('usuarios').doc(boleta));
        }
        await deleteBatch.commit();
      }

      if (isDialogOpen) Navigator.pop(context);

      if (errores.isEmpty) {
        _mostrarExito(
          "$totalAlumnos alumnos cargados en $gruposProcesados grupos\n"
          "${alumnosAEliminar.length} alumnos eliminados por no estar en el archivo",
        );
      } else {
        String mensaje =
            "$totalAlumnos alumnos cargados, ${alumnosAEliminar.length} eliminados, pero con ${errores.length} errores";
        _mostrarError(mensaje);
      }
    } catch (e) {
      Navigator.pop(context);
      _mostrarError("Error al procesar archivo: ${e.toString()}");
    }
  }

  Future<void> _cargarProfesoresDesdeExcel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;

      if (bytes == null || bytes.isEmpty) {
        _mostrarError("No se pudo leer el archivo o está vacío");
        return;
      }

      bool isDialogOpen = true;
      int totalProfesores = 0;
      final progressDialog = showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  title: const Text("Procesando archivo..."),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(value: totalProfesores / 1000),
                      const SizedBox(height: 16),
                      Text("Profesores procesados: $totalProfesores"),
                    ],
                  ),
                );
              },
            ),
      );

      final usuariosSnapshot = await _firestore.collection('usuarios').get();
      final profesoresActuales =
          usuariosSnapshot.docs
              .where((doc) => doc.data()['rol'] == 'profesor')
              .map((doc) => doc.id)
              .toSet();
      final administradores =
          usuariosSnapshot.docs
              .where((doc) => doc.data()['rol'] == 'administrador')
              .map((doc) => doc.id)
              .toSet();
      final profesoresEnExcel = <String>{};

      final excel = Excel.decodeBytes(bytes);
      final sheet = excel.tables[excel.tables.keys.first]!;
      List<String> errores = [];
      WriteBatch batch = _firestore.batch();
      const batchSize = 400;

      if (sheet.maxColumns < 2 ||
          sheet.row(0)[0]?.value.toString().toLowerCase() != "numero" ||
          sheet.row(0)[1]?.value.toString().toLowerCase() != "nombre") {
        Navigator.pop(context);
        _mostrarError(
          "Formato incorrecto. Se requieren columnas: Número, Nombre",
        );
        return;
      }

      for (var row in sheet.rows.skip(1)) {
        try {
          final numeroEmpleado = row[0]?.value?.toString().trim() ?? '';
          final nombre = row[1]?.value?.toString().trim() ?? '';

          if (numeroEmpleado.isEmpty || nombre.isEmpty) continue;

          final profesorRef = _firestore
              .collection('usuarios')
              .doc(numeroEmpleado);
          batch.set(profesorRef, {
            'numero_empleado': numeroEmpleado,
            'nombre': nombre,
            'rol': 'profesor',
            'fecha_registro': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          profesoresEnExcel.add(numeroEmpleado);
          totalProfesores++;

          if (totalProfesores % batchSize == 0) {
            await batch.commit();
            batch = _firestore.batch();
            if (isDialogOpen) {
              Navigator.pop(context);
              progressDialog.then((_) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder:
                      (context) => AlertDialog(
                        title: const Text("Procesando archivo..."),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              value: totalProfesores / 1000,
                            ),
                            const SizedBox(height: 16),
                            Text("Profesores procesados: $totalProfesores"),
                          ],
                        ),
                      ),
                );
              });
            }
          }
        } catch (e) {
          errores.add(
            "Error en fila ${row.indexOf(row as Data?)}: ${e.toString()}",
          );
        }
      }

      if (totalProfesores % batchSize != 0) {
        await batch.commit();
      }

      final profesoresAEliminar = profesoresActuales
          .difference(profesoresEnExcel)
          .difference(administradores);

      if (profesoresAEliminar.isNotEmpty) {
        final deleteBatch = _firestore.batch();
        for (final numeroEmpleado in profesoresAEliminar) {
          deleteBatch.delete(
            _firestore.collection('usuarios').doc(numeroEmpleado),
          );
        }
        await deleteBatch.commit();
      }

      if (isDialogOpen) Navigator.pop(context);

      if (errores.isEmpty) {
        _mostrarExito(
          "$totalProfesores profesores cargados exitosamente\n"
          "${profesoresAEliminar.length} profesores eliminados por no estar en el archivo\n"
          "${administradores.length} administradores protegidos",
        );
      } else {
        String mensaje =
            "$totalProfesores profesores cargados, ${profesoresAEliminar.length} eliminados, "
            "${administradores.length} administradores protegidos, pero con ${errores.length} errores";
        _mostrarError(mensaje);
      }
    } catch (e) {
      Navigator.pop(context);
      _mostrarError("Error al procesar archivo: ${e.toString()}");
    }
  }

  Future<List<String>> _obtenerNombresAlumnos(List<dynamic> alumnosIds) async {
    if (alumnosIds.isEmpty) return [];

    try {
      final query = _firestore
          .collection('usuarios')
          .where(FieldPath.documentId, whereIn: alumnosIds.take(10).toList())
          .limit(10);

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => doc['nombre']?.toString() ?? 'Desconocido')
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener nombres: $e');
      }
      return List.filled(alumnosIds.length, 'Desconocido');
    }
  }

  void _filterVisitas(String query) {
    setState(() {
      _searchText = query.toLowerCase();
      if (_searchText.isEmpty) {
        _filteredDocuments = List.from(_loadedDocuments);
      } else {
        _filteredDocuments =
            _loadedDocuments.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['titulo'].toString().toLowerCase().contains(
                    _searchText,
                  ) ||
                  data['empresa'].toString().toLowerCase().contains(
                    _searchText,
                  ) ||
                  data['grupo'].toString().toLowerCase().contains(
                    _searchText,
                  ) ||
                  data['profesor'].toString().toLowerCase().contains(
                    _searchText,
                  );
            }).toList();
      }
    });
  }

  void _scrollListener() {
    if (_scrollController.offset >=
            _scrollController.position.maxScrollExtent &&
        !_scrollController.position.outOfRange) {
      if (!_isLoadingMore && _hasMore && _searchText.isEmpty) {
        _loadMoreVisitas();
      }
    }
  }

  Future<void> _loadMoreVisitas() async {
    if (!_hasMore || _isLoadingMore) return;

    setState(() => _isLoadingMore = true);

    try {
      setState(() => _limit += 10);
    } catch (e) {
      _mostrarError("Error al cargar más visitas: $e");
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _loadAdminData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _adminName = prefs.getString('user_name') ?? "Administrador";
        _isLoading = false;
      });
    } catch (e) {
      _mostrarError("Error al cargar datos del administrador");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } catch (e) {
      _mostrarError("Error al cerrar sesión");
    }
  }

  Future<void> _eliminarVisita(String visitaId) async {
    final confirm = await _showConfirmationDialog(
      title: "Eliminar visita",
      content: "Esta acción no se puede deshacer. ¿Deseas continuar?",
      confirmText: "Eliminar",
    );

    if (confirm) {
      try {
        await _firestore.collection("visitas_escolares").doc(visitaId).delete();
        _mostrarExito("Visita eliminada correctamente");
      } catch (e) {
        _mostrarError("Error al eliminar visita: $e");
      }
    }
  }

  Future<void> _editarVisita(DocumentSnapshot visita) async {
    final confirm = await _showConfirmationDialog(
      title: "Editar visita",
      content: "¿Deseas editar esta visita?",
      confirmText: "Editar",
      confirmColor: Colors.blue,
    );

    if (confirm) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CrearVisitaScreen(visita: visita),
        ),
      ).then((_) {
        _loadAdminData();
      });
    }
  }

  void _mostrarDetallesVisita(DocumentSnapshot doc) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetalleVisitaScreen(visitaId: doc.id),
      ),
    );
  }

  Future<bool> _showConfirmationDialog({
    required String title,
    required String content,
    String confirmText = "Confirmar",
    Color confirmColor = Colors.red,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancelar"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(confirmText, style: TextStyle(color: confirmColor)),
              ),
            ],
          ),
    );
    return result ?? false;
  }

  Future<void> _confirmLogout() async {
    final confirm = await _showConfirmationDialog(
      title: "Cerrar sesión",
      content: "¿Estás seguro de que deseas salir de la aplicación?",
      confirmText: "Salir",
    );

    if (confirm) {
      await _logout();
    }
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

  Future<void> _confirmOpenFiles(String visitaId) async {
    final confirm = await _showConfirmationDialog(
      title: "Revisar archivos",
      content: "¿Deseas revisar los archivos de esta visita?",
      confirmText: "Abrir",
      confirmColor: Colors.orange,
    );

    if (confirm) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AprobarArchivosScreen(visitaId: visitaId),
        ),
      );
    }
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 400;
          return Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.school, color: Colors.white, size: 24),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  isCompact ? 'Visitas' : 'Visitas Escolares',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: isCompact ? 18 : 20,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          );
        },
      ),
      actions: [
        LayoutBuilder(
          builder: (context, constraints) {
            final showFullName = constraints.maxWidth > 350;
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth:
                    showFullName
                        ? constraints.maxWidth * 0.3
                        : 40, // Ancho mínimo para el ícono
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person, color: Colors.amber[200], size: 20),
                    if (showFullName) ...[
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _adminName,
                          style: GoogleFonts.roboto(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.logout, size: 22),
          onPressed: _confirmLogout,
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

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Buscar visitas...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          suffixIcon:
              _searchText.isNotEmpty
                  ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _filterVisitas('');
                    },
                  )
                  : null,
        ),
        onChanged: _filterVisitas,
      ),
    );
  }

  Widget _buildVisitaCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final titulo = data["titulo"] ?? "Sin título";
    final empresa = data["empresa"] ?? "Desconocida";
    final ubicacion = data["ubicacion"] ?? "Ubicación no disponible";
    final grupo = data["grupo"] ?? "No asignado";
    final profesor = data["profesor"] ?? "No asignado";
    final alumnos = data["alumnos"] as List<dynamic>? ?? [];
    final timestamp = data["fecha_hora"] as Timestamp?;
    final fechaHoraTexto =
        timestamp != null
            ? DateFormat('dd/MM/yyyy - HH:mm').format(timestamp.toDate())
            : "No definida";

    return InkWell(
      onTap: () => _mostrarDetallesVisita(doc),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: FutureBuilder<List<String>>(
          future: _obtenerNombresAlumnos(alumnos),
          builder: (context, snapshot) {
            final alumnosTexto =
                snapshot.hasData
                    ? snapshot.data!.join(', ')
                    : snapshot.connectionState == ConnectionState.waiting
                    ? "Cargando..."
                    : "No disponibles";

            return Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          titulo,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[800],
                          ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.folder_open, color: Colors.orange),
                            onPressed: () => _confirmOpenFiles(doc.id),
                            tooltip: 'Revisar Archivos',
                          ),
                          IconButton(
                            icon: Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _editarVisita(doc),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _eliminarVisita(doc.id),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.business, empresa),
                  _buildInfoRow(Icons.location_on, "Ubicación: $ubicacion"),
                  _buildInfoRow(Icons.people, "Grupo: $grupo"),
                  _buildInfoRow(Icons.person, "Profesor: $profesor"),
                  _buildInfoRow(Icons.calendar_today, fechaHoraTexto),
                  const SizedBox(height: 4),
                  Text(
                    "Alumnos:",
                    style: GoogleFonts.roboto(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alumnosTexto,
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
            );
          },
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _searchText.isEmpty
                ? 'No hay visitas creadas'
                : 'No se encontraron resultados',
            style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginatedVisitasList() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          _firestore
              .collection("visitas_escolares")
              .orderBy("fecha_creacion", descending: true)
              .limit(_limit)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            _loadedDocuments.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        _loadedDocuments = snapshot.data!.docs;
        _filteredDocuments =
            _searchText.isEmpty
                ? List.from(_loadedDocuments)
                : _loadedDocuments.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['titulo'].toString().toLowerCase().contains(
                        _searchText,
                      ) ||
                      data['empresa'].toString().toLowerCase().contains(
                        _searchText,
                      ) ||
                      data['grupo'].toString().toLowerCase().contains(
                        _searchText,
                      ) ||
                      data['profesor'].toString().toLowerCase().contains(
                        _searchText,
                      );
                }).toList();

        if (snapshot.data!.docs.length < _limit) {
          _hasMore = false;
        }

        return Column(
          children: [
            _buildSearchField(),
            if (_filteredDocuments.isEmpty)
              _buildEmptyState()
            else
              ..._filteredDocuments.map((doc) => _buildVisitaCard(doc)),
            if (_isLoadingMore)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            if (!_hasMore &&
                _filteredDocuments.isNotEmpty &&
                _searchText.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'No hay más visitas para mostrar',
                  style: GoogleFonts.roboto(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              )
              : Column(
                children: [
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      'Visitas creadas',
                      style: GoogleFonts.caveat(
                        fontSize: 30,
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Cargar alumnos'),
                          onPressed: _cargarAlumnosDesdeExcel,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Cargar profesores'),
                          onPressed: _cargarProfesoresDesdeExcel,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(
                            Icons.person_add,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Agregar Administrador',
                            style: TextStyle(color: Colors.white),
                          ),
                          onPressed: _mostrarDialogoAgregarAdmin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple[700],
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: _buildPaginatedVisitasList(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: FloatingActionButton.extended(
                      backgroundColor: Colors.blue,
                      icon: const Icon(Icons.add),
                      label: const Text('Crear visita'),
                      onPressed:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CrearVisitaScreen(),
                            ),
                          ),
                    ),
                  ),
                ],
              ),
    );
  }
}
