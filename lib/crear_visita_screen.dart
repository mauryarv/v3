// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CrearVisitaScreen extends StatefulWidget {
  final DocumentSnapshot? visita;

  const CrearVisitaScreen({super.key, this.visita});

  @override
  _CrearVisitaScreenState createState() => _CrearVisitaScreenState();
}

class _CrearVisitaScreenState extends State<CrearVisitaScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<String> empresas = [];
  List<String> grupos = [];
  List<String> profesores = [];
  Map<String, List<Map<String, String>>> alumnosPorGrupo =
      {}; // Mapa de grupo -> lista de alumnos (ID y nombre)

  String? titulo;
  String? empresaSeleccionada;
  String? grupoSeleccionado;
  String? profesorSeleccionado;
  Map<String, List<String>> alumnosSeleccionados = {}; // Mapa de ID de alumnos
  DateTime? fechaSeleccionada;
  TimeOfDay? horaSeleccionada;
  TextEditingController tituloController = TextEditingController();
  TextEditingController nuevaEmpresaController =
      TextEditingController(); // Controlador para la nueva empresa
  // Variable para manejar el estado de selección de todos los alumnos por grupo
  Map<String, bool> seleccionarTodosPorGrupo = {};

  @override
  void initState() {
    super.initState();
    _cargarDatos();

    if (widget.visita != null) {
      var data = widget.visita!.data() as Map<String, dynamic>;

      setState(() {
        titulo = data["titulo"];
        tituloController.text =
            titulo ?? ""; // Establece el texto en el controlador
        empresaSeleccionada = data["empresa"];
        grupoSeleccionado = data["grupo"];
        profesorSeleccionado = data["profesor"];

        // Convertir Timestamp de Firebase a DateTime
        Timestamp? fechaHoraTimestamp = data["fecha_hora"];
        if (fechaHoraTimestamp != null) {
          fechaSeleccionada = fechaHoraTimestamp.toDate();
          horaSeleccionada = TimeOfDay.fromDateTime(fechaSeleccionada!);
        }

        // Cargar alumnos seleccionados por su ID
        List<dynamic> alumnosGuardados = data["alumnos"] ?? [];
        alumnosSeleccionados = {};

        for (var alumnoId in alumnosGuardados) {
          _firestore.collection("usuarios").doc(alumnoId).get().then((doc) {
            if (doc.exists) {
              String grupoAlumno = doc["grupo"];
              setState(() {
                if (!alumnosSeleccionados.containsKey(grupoAlumno)) {
                  alumnosSeleccionados[grupoAlumno] = [];
                }
                alumnosSeleccionados[grupoAlumno]!.add(alumnoId);
              });
            }
          });
        }
      });
    }
  }

  // Método para manejar la selección/deselección de todos los alumnos en un grupo
  void _toggleSeleccionarTodos(String grupo) {
    setState(() {
      // Si todos los alumnos están seleccionados, deseleccionamos, y viceversa
      bool seleccionarTodos = seleccionarTodosPorGrupo[grupo] ?? false;
      seleccionarTodosPorGrupo[grupo] = !seleccionarTodos;

      if (seleccionarTodosPorGrupo[grupo]!) {
        // Seleccionar todos los alumnos del grupo
        alumnosSeleccionados[grupo] =
            alumnosPorGrupo[grupo]!.map((alumno) => alumno['id']!).toList();
      } else {
        // Deseleccionar todos los alumnos del grupo
        alumnosSeleccionados[grupo] = [];
      }
    });
  }

  Future<void> _cargarDatos() async {
    try {
      // Cargar empresas
      QuerySnapshot empresasSnapshot =
          await _firestore.collection("empresas").get();
      setState(() {
        empresas =
            empresasSnapshot.docs
                .map((doc) => doc["nombre"].toString())
                .toList();
      });

      // Cargar grupos únicos de alumnos
      QuerySnapshot alumnosSnapshot =
          await _firestore
              .collection("usuarios")
              .where("rol", isEqualTo: "alumno")
              .get();
      setState(() {
        grupos =
            alumnosSnapshot.docs
                .map((doc) => doc["grupo"].toString())
                .toSet()
                .toList();
      });

      // Cargar profesores
      QuerySnapshot profesoresSnapshot =
          await _firestore
              .collection("usuarios")
              .where("rol", isEqualTo: "profesor")
              .get();
      setState(() {
        profesores =
            profesoresSnapshot.docs
                .map((doc) => doc["nombre"].toString())
                .toList();
      });
    } catch (e) {
      print("Error al cargar datos: $e");
    }
  }

  Future<void> _cargarAlumnosPorGrupo(String grupo) async {
    try {
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

        // Si el grupo ya tenía alumnos seleccionados, mantenerlos
        if (!alumnosSeleccionados.containsKey(grupo)) {
          alumnosSeleccionados[grupo] = [];
        }
      });
    } catch (e) {
      print("Error al cargar alumnos: $e");
    }
  }

  Future<void> _seleccionarFecha() async {
    DateTime? fecha = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (fecha != null) {
      setState(() {
        fechaSeleccionada = fecha;
      });
    }
  }

  Future<void> _seleccionarHora() async {
    TimeOfDay? hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
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

  // Método para navegar a la pantalla de agregar empresa
  void _navegarAgregarEmpresa() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AgregarEmpresaScreen()),
    ).then((_) {
      _cargarDatos(); // Recargar las empresas después de agregar una nueva
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Crear Visita Escolar")),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Campo de título
            TextField(
              controller: tituloController,
              decoration: InputDecoration(labelText: "Título de la visita"),
              onChanged: (value) {
                setState(() {
                  titulo = value;
                });
              },
            ),

            SizedBox(height: 20),

            // Selección de empresa
            Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    value: empresaSeleccionada,
                    hint: Text("Selecciona una empresa"),
                    items:
                        empresas.map((empresa) {
                          return DropdownMenuItem<String>(
                            value: empresa,
                            child: Text(empresa),
                          );
                        }).toList(),
                    onChanged: (value) {
                      setState(() {
                        empresaSeleccionada = value;
                      });
                    },
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add),
                  onPressed:
                      _navegarAgregarEmpresa, // Navegar a la pantalla de agregar empresa
                ),
              ],
            ),

            SizedBox(height: 20),

            // Selección de grupo
            DropdownButton<String>(
              value: grupoSeleccionado,
              hint: Text("Selecciona un grupo"),
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
                _cargarAlumnosPorGrupo(value!);
              },
            ),

            SizedBox(height: 20),

            // Selección de profesor
            DropdownButton<String>(
              value: profesorSeleccionado,
              hint: Text("Selecciona un profesor"),
              items:
                  profesores.map((profesor) {
                    return DropdownMenuItem<String>(
                      value: profesor,
                      child: Text(profesor),
                    );
                  }).toList(),
              onChanged: (value) {
                setState(() {
                  profesorSeleccionado = value;
                });
              },
            ),

            SizedBox(height: 20),

            // Selección de fecha
            Row(
              children: [
                Text(
                  fechaSeleccionada == null
                      ? "Seleccionar fecha"
                      : DateFormat('yyyy-MM-dd').format(fechaSeleccionada!),
                ),
                Spacer(),
                ElevatedButton(
                  onPressed: _seleccionarFecha,
                  child: Text("Fecha"),
                ),
              ],
            ),

            SizedBox(height: 20),

            Row(
              children: [
                Text(
                  horaSeleccionada == null
                      ? "Seleccionar hora"
                      : horaSeleccionada!.format(context),
                ),
                Spacer(),
                ElevatedButton(
                  onPressed: _seleccionarHora,
                  child: Text("Hora"),
                ),
              ],
            ),

            SizedBox(height: 20),

            // Selección de alumnos
            if (alumnosPorGrupo.isNotEmpty &&
                alumnosPorGrupo[grupoSeleccionado] != null) ...[
              Text("Selecciona los alumnos:"),
              // Checkbox para seleccionar/deseleccionar todos los alumnos
              Row(
                children: [
                  Checkbox(
                    value: seleccionarTodosPorGrupo[grupoSeleccionado] ?? false,
                    onChanged: (_) {
                      _toggleSeleccionarTodos(grupoSeleccionado!);
                    },
                  ),
                  Text("Seleccionar/Deseleccionar Todos los Alumnos"),
                ],
              ),
              Expanded(
                child: ListView(
                  children:
                      alumnosPorGrupo[grupoSeleccionado]!.map((alumno) {
                        return CheckboxListTile(
                          title: Text(alumno['nombre']!), // Mostrar el nombre
                          value:
                              alumnosSeleccionados[grupoSeleccionado]?.contains(
                                alumno['id'],
                              ) ??
                              false,
                          onChanged: (bool? selected) {
                            setState(() {
                              if (selected == true) {
                                if (!alumnosSeleccionados.containsKey(
                                  grupoSeleccionado,
                                )) {
                                  alumnosSeleccionados[grupoSeleccionado!] = [];
                                }
                                alumnosSeleccionados[grupoSeleccionado!]!.add(
                                  alumno['id']!,
                                );
                              } else {
                                alumnosSeleccionados[grupoSeleccionado!]!
                                    .remove(alumno['id']);
                              }
                            });
                          },
                        );
                      }).toList(),
                ),
              ),
            ],

            SizedBox(height: 20),

            ElevatedButton(
              onPressed: () async {
                if (titulo != null &&
                    empresaSeleccionada != null &&
                    grupoSeleccionado != null &&
                    profesorSeleccionado != null &&
                    alumnosSeleccionados[grupoSeleccionado!]!.isNotEmpty &&
                    fechaSeleccionada != null &&
                    horaSeleccionada != null) {
                  DateTime? fechaHoraCombinada = _combinarFechaYHora();

                  if (fechaHoraCombinada != null) {
                    Map<String, dynamic> visitaData = {
                      "titulo": titulo,
                      "empresa": empresaSeleccionada,
                      "grupo": grupoSeleccionado,
                      "profesor": profesorSeleccionado,
                      "alumnos":
                          alumnosSeleccionados.values
                              .expand((x) => x)
                              .toSet()
                              .toList(), // Usamos los IDs
                      "fecha_hora": Timestamp.fromDate(fechaHoraCombinada),
                      "fecha_creacion":
                          widget.visita != null
                              ? widget.visita!["fecha_creacion"]
                              : FieldValue.serverTimestamp(),
                    };

                    if (widget.visita == null) {
                      // Crear nueva visita
                      await _firestore
                          .collection("visitas_escolares")
                          .add(visitaData);
                    } else {
                      // Editar visita existente
                      await _firestore
                          .collection("visitas_escolares")
                          .doc(widget.visita!.id)
                          .update(visitaData);
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Visita guardada exitosamente")),
                    );
                    Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Selecciona tanto fecha como hora"),
                      ),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Por favor, completa todos los campos"),
                    ),
                  );
                }
              },
              child: Text(
                widget.visita == null ? "Guardar Visita" : "Actualizar Visita",
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Nueva pantalla para agregar empresa
class AgregarEmpresaScreen extends StatefulWidget {
  const AgregarEmpresaScreen({super.key});

  @override
  _AgregarEmpresaScreenState createState() => _AgregarEmpresaScreenState();
}

class _AgregarEmpresaScreenState extends State<AgregarEmpresaScreen> {
  final _nombreController = TextEditingController();

  Future<void> _guardarEmpresa() async {
    String nombreEmpresa = _nombreController.text;

    if (nombreEmpresa.isNotEmpty) {
      await FirebaseFirestore.instance.collection("empresas").add({
        "nombre": nombreEmpresa,
      });
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Por favor ingresa un nombre válido")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Agregar Empresa")),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nombreController,
              decoration: InputDecoration(labelText: "Nombre de la empresa"),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _guardarEmpresa,
              child: Text("Agregar Empresa"),
            ),
          ],
        ),
      ),
    );
  }
}
