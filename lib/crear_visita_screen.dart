// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'agregar_empresa_screen.dart';

class CrearVisitaScreen extends StatefulWidget {
  final DocumentSnapshot? visita;

  const CrearVisitaScreen({super.key, this.visita});

  @override
  _CrearVisitaScreenState createState() => _CrearVisitaScreenState();
}

class _CrearVisitaScreenState extends State<CrearVisitaScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  List<Map<String, dynamic>> empresas = [];
  List<String> grupos = [];
  List<String> profesores = [];
  Map<String, List<Map<String, String>>> alumnosPorGrupo = {};

  int? _empresaSeleccionadaIndex;
  String? grupoSeleccionado;
  List<String> profesoresSeleccionados = [];
  List<String> alumnosSeleccionados = [];
  DateTime? fechaSeleccionada;
  TimeOfDay? horaSeleccionada;
  TextEditingController observacionesController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();

    if (widget.visita != null) {
      var data = widget.visita!.data() as Map<String, dynamic>;
      setState(() {
        grupoSeleccionado = data["grupo"];
        profesoresSeleccionados = List<String>.from(data["profesores"] ?? []);
        observacionesController.text = data["observaciones"] ?? "";

        // Buscar índice de la empresa por ubicación
        final ubicacion = data["ubicacion"];
        _empresaSeleccionadaIndex = empresas.indexWhere(
          (emp) => emp['ubicacion'] == ubicacion,
        );

        Timestamp? fechaHoraTimestamp = data["fecha_hora"];
        if (fechaHoraTimestamp != null) {
          fechaSeleccionada = fechaHoraTimestamp.toDate();
          horaSeleccionada = TimeOfDay.fromDateTime(fechaSeleccionada!);
        }

        List<dynamic> alumnosGuardados = data["alumnos"] ?? [];
        alumnosSeleccionados =
            alumnosGuardados.map((e) => e.toString()).toList();
      });
    }
  }

  Future<void> _cargarDatos() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Cargar empresas (solo ubicación)
      QuerySnapshot empresasSnapshot =
          await _firestore.collection("empresas").get();

      // Cargar grupos de alumnos
      QuerySnapshot alumnosSnapshot =
          await _firestore
              .collection("usuarios")
              .where("rol", isEqualTo: "alumno")
              .get();

      // Cargar profesores
      QuerySnapshot profesoresSnapshot =
          await _firestore
              .collection("usuarios")
              .where("rol", isEqualTo: "profesor")
              .get();

      setState(() {
        empresas =
            empresasSnapshot.docs.map((doc) {
              return {
                'ubicacion': doc["ubicacion"]?.toString() ?? 'No disponible',
              };
            }).toList();

        grupos =
            alumnosSnapshot.docs
                .map((doc) => doc["grupo"].toString())
                .toSet()
                .toList();

        profesores =
            profesoresSnapshot.docs
                .map((doc) => doc["nombre"].toString())
                .toList();

        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _mostrarError("Error al cargar datos: $e");
    }
  }

  Future<void> _cargarAlumnosPorGrupo(String grupo) async {
    try {
      setState(() {
        _isLoading = true;
      });

      QuerySnapshot alumnosSnapshot =
          await _firestore
              .collection("usuarios")
              .where("grupo", isEqualTo: grupo)
              .where("rol", isEqualTo: "alumno")
              .get();

      List<Map<String, String>> alumnosGrupo = [];
      for (var doc in alumnosSnapshot.docs) {
        alumnosGrupo.add({'id': doc.id, 'nombre': doc["nombre"]});
      }

      setState(() {
        alumnosPorGrupo[grupo] = alumnosGrupo;
        alumnosSeleccionados =
            alumnosGrupo.map((alumno) => alumno['id']!).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _mostrarError("Error al cargar alumnos: $e");
    }
  }

  Future<void> _seleccionarFecha() async {
    final DateTime? fecha = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: Colors.blue),
            ),
          ),
          child: child!,
        );
      },
    );

    if (fecha != null) {
      setState(() {
        fechaSeleccionada = fecha;
      });
    }
  }

  Future<void> _seleccionarHora() async {
    final TimeOfDay? hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: Colors.blue),
            ),
          ),
          child: child!,
        );
      },
    );

    if (hora != null) {
      setState(() {
        horaSeleccionada = hora;
      });
    }
  }

  DateTime? _combinarFechaYHora() {
    if (fechaSeleccionada != null && horaSeleccionada != null) {
      return DateTime(
        fechaSeleccionada!.year,
        fechaSeleccionada!.month,
        fechaSeleccionada!.day,
        horaSeleccionada!.hour,
        horaSeleccionada!.minute,
      );
    }
    return null;
  }

  void _navegarAgregarEmpresa() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AgregarEmpresaScreen()),
    ).then((_) {
      _cargarDatos();
    });
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

  Future<void> _guardarVisita() async {
    if (!_formKey.currentState!.validate()) return;

    if (_empresaSeleccionadaIndex == null) {
      _mostrarError("Por favor selecciona una ubicación de empresa");
      return;
    }

    if (profesoresSeleccionados.isEmpty) {
      _mostrarError("Por favor selecciona al menos un profesor");
      return;
    }

    if (fechaSeleccionada == null || horaSeleccionada == null) {
      _mostrarError("Por favor selecciona fecha y hora");
      return;
    }

    DateTime? fechaHoraCombinada = _combinarFechaYHora();
    if (fechaHoraCombinada == null) {
      _mostrarError("Error al combinar fecha y hora");
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      final ubicacionEmpresa =
          empresas[_empresaSeleccionadaIndex!]['ubicacion'];

      Map<String, dynamic> visitaData = {
        "ubicacion": ubicacionEmpresa,
        "grupo": grupoSeleccionado,
        "profesores": profesoresSeleccionados,
        "alumnos": alumnosSeleccionados,
        "observaciones": observacionesController.text,
        "fecha_hora": Timestamp.fromDate(fechaHoraCombinada),
        "fecha_creacion":
            widget.visita != null
                ? widget.visita!["fecha_creacion"]
                : FieldValue.serverTimestamp(),
      };

      if (widget.visita == null) {
        await _firestore.collection("visitas_escolares").add(visitaData);
        _mostrarExito("Visita creada exitosamente");
      } else {
        await _firestore
            .collection("visitas_escolares")
            .doc(widget.visita!.id)
            .update(visitaData);
        _mostrarExito("Visita actualizada exitosamente");
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      _mostrarError("Error al guardar la visita: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.visita == null ? 'Nueva Visita Escolar' : 'Editar Visita',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
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
        actions: <Widget>[
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'about') {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text(
                        'Acerca de la aplicación',
                        style: GoogleFonts.poppins(),
                      ),
                      content: Text(
                        'Esta aplicación fue desarrollada para facilitar la gestión de visitas escolares del CECyT 3. '
                        'Su objetivo es proporcionar una herramienta eficiente para administradores, profesores y alumnos.',
                        style: GoogleFonts.roboto(),
                      ),
                      actions: <Widget>[
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text('Cerrar'),
                        ),
                      ],
                    );
                  },
                );
              } else if (value == 'credits') {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text('Créditos', style: GoogleFonts.poppins()),
                      content: Text(
                        'Aplicación desarrollada por Reyes Vaca Mauricio Alberto.\n'
                        '© 2025 Todos los derechos reservados.',
                        style: GoogleFonts.roboto(),
                      ),
                      actions: <Widget>[
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text('Cerrar'),
                        ),
                      ],
                    );
                  },
                );
              }
            },
            itemBuilder:
                (BuildContext context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'about',
                    child: Text(
                      'Acerca de la aplicación',
                      style: GoogleFonts.roboto(),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'credits',
                    child: Text('Créditos', style: GoogleFonts.roboto()),
                  ),
                ],
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0),
            child: Center(
              child: Text(
                "Datos de visita",
                style: GoogleFonts.caveat(
                  fontSize: 30,
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    value: _empresaSeleccionadaIndex,
                                    hint: const Text("Selecciona un lugar"),
                                    items: List.generate(empresas.length, (
                                      index,
                                    ) {
                                      return DropdownMenuItem<int>(
                                        value: index,
                                        child: Text(
                                          empresas[index]['ubicacion'],
                                        ),
                                      );
                                    }),
                                    onChanged: (value) {
                                      setState(() {
                                        _empresaSeleccionadaIndex = value;
                                      });
                                    },
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey[50],
                                    ),
                                    validator: (value) {
                                      if (value == null) {
                                        return 'Selecciona un lugar';
                                      }
                                      return null;
                                    },
                                    isExpanded: true,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                IconButton(
                                  icon: const Icon(
                                    Icons.add,
                                    color: Colors.blue,
                                  ),
                                  onPressed: _navegarAgregarEmpresa,
                                  tooltip: 'Agregar nueva ubicación',
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            DropdownButtonFormField<String>(
                              value: grupoSeleccionado,
                              hint: const Text("Selecciona un grupo"),
                              items:
                                  grupos.map((grupo) {
                                    return DropdownMenuItem<String>(
                                      value: grupo,
                                      child: Text(grupo),
                                    );
                                  }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  grupoSeleccionado = value;
                                });
                                if (value != null) {
                                  _cargarAlumnosPorGrupo(value);
                                }
                              },
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Selecciona un grupo';
                                }
                                return null;
                              },
                              isExpanded: true,
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              "Selecciona los profesores:",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),
                            Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  children: [
                                    ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxHeight: size.height * 0.3,
                                      ),
                                      child: ListView.builder(
                                        shrinkWrap: true,
                                        itemCount: profesores.length,
                                        itemBuilder: (context, index) {
                                          final profesor = profesores[index];
                                          return CheckboxListTile(
                                            title: Text(profesor),
                                            value: profesoresSeleccionados
                                                .contains(profesor),
                                            onChanged: (bool? selected) {
                                              setState(() {
                                                if (selected == true) {
                                                  profesoresSeleccionados.add(
                                                    profesor,
                                                  );
                                                } else {
                                                  profesoresSeleccionados
                                                      .remove(profesor);
                                                }
                                              });
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                    if (profesoresSeleccionados.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 8.0,
                                        ),
                                        child: Text(
                                          "Profesores seleccionados: ${profesoresSeleccionados.length}",
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: observacionesController,
                              decoration: InputDecoration(
                                labelText: "Observaciones",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              maxLines: 3,
                              keyboardType: TextInputType.multiline,
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: _seleccionarFecha,
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        labelText: "Fecha",
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey[50],
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            fechaSeleccionada == null
                                                ? "Seleccionar fecha"
                                                : DateFormat(
                                                  'yyyy-MM-dd',
                                                ).format(fechaSeleccionada!),
                                          ),
                                          const Icon(
                                            Icons.calendar_today,
                                            color: Colors.blue,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: InkWell(
                                    onTap: _seleccionarHora,
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        labelText: "Hora",
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey[50],
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            horaSeleccionada == null
                                                ? "Seleccionar hora"
                                                : horaSeleccionada!.format(
                                                  context,
                                                ),
                                          ),
                                          const Icon(
                                            Icons.access_time,
                                            color: Colors.blue,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            if (grupoSeleccionado != null &&
                                alumnosPorGrupo[grupoSeleccionado] != null) ...[
                              const Text(
                                "Alumnos del grupo seleccionado:",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 10),
                              Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxHeight: size.height * 0.3,
                                    ),
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      itemCount:
                                          alumnosPorGrupo[grupoSeleccionado]!
                                              .length,
                                      itemBuilder: (context, index) {
                                        final alumno =
                                            alumnosPorGrupo[grupoSeleccionado]![index];
                                        return ListTile(
                                          title: Text(alumno['nombre']!),
                                          leading: const Icon(
                                            Icons.person,
                                            color: Colors.blue,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "Total de alumnos: ${alumnosPorGrupo[grupoSeleccionado]!.length}",
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                            const SizedBox(height: 30),
                            ElevatedButton(
                              onPressed: _guardarVisita,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child:
                                  _isLoading
                                      ? const CircularProgressIndicator(
                                        color: Colors.white,
                                      )
                                      : Text(
                                        widget.visita == null
                                            ? "GUARDAR VISITA"
                                            : "ACTUALIZAR VISITA",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                            ),
                          ],
                        ),
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}
