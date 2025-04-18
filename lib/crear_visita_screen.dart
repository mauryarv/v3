// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class CrearVisitaScreen extends StatefulWidget {
  final DocumentSnapshot? visita;

  const CrearVisitaScreen({super.key, this.visita});

  @override
  _CrearVisitaScreenState createState() => _CrearVisitaScreenState();
}

class _CrearVisitaScreenState extends State<CrearVisitaScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  List<String> empresas = [];
  List<String> grupos = [];
  List<String> profesores = [];
  Map<String, List<Map<String, String>>> alumnosPorGrupo = {};

  String? titulo;
  String? empresaSeleccionada;
  String? grupoSeleccionado;
  String? profesorSeleccionado;
  Map<String, List<String>> alumnosSeleccionados = {};
  DateTime? fechaSeleccionada;
  TimeOfDay? horaSeleccionada;
  TextEditingController tituloController = TextEditingController();
  TextEditingController nuevaEmpresaController = TextEditingController();
  Map<String, bool> seleccionarTodosPorGrupo = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();

    if (widget.visita != null) {
      var data = widget.visita!.data() as Map<String, dynamic>;
      setState(() {
        titulo = data["titulo"];
        tituloController.text = titulo ?? "";
        empresaSeleccionada = data["empresa"];
        grupoSeleccionado = data["grupo"];
        profesorSeleccionado = data["profesor"];

        Timestamp? fechaHoraTimestamp = data["fecha_hora"];
        if (fechaHoraTimestamp != null) {
          fechaSeleccionada = fechaHoraTimestamp.toDate();
          horaSeleccionada = TimeOfDay.fromDateTime(fechaSeleccionada!);
        }

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

  void _toggleSeleccionarTodos(String grupo) {
    setState(() {
      bool seleccionarTodos = seleccionarTodosPorGrupo[grupo] ?? false;
      seleccionarTodosPorGrupo[grupo] = !seleccionarTodos;

      if (seleccionarTodosPorGrupo[grupo]!) {
        alumnosSeleccionados[grupo] =
            alumnosPorGrupo[grupo]!.map((alumno) => alumno['id']!).toList();
      } else {
        alumnosSeleccionados[grupo] = [];
      }
    });
  }

  Future<void> _cargarDatos() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Cargar empresas
      QuerySnapshot empresasSnapshot =
          await _firestore.collection("empresas").get();

      // Cargar grupos únicos de alumnos
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
            empresasSnapshot.docs
                .map((doc) => doc["nombre"].toString())
                .toList();
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
        if (!alumnosSeleccionados.containsKey(grupo)) {
          alumnosSeleccionados[grupo] = [];
        }
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

    if (alumnosSeleccionados[grupoSeleccionado!]?.isEmpty ?? true) {
      _mostrarError("Por favor selecciona al menos un alumno");
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

      Map<String, dynamic> visitaData = {
        "titulo": titulo,
        "empresa": empresaSeleccionada,
        "grupo": grupoSeleccionado,
        "profesor": profesorSeleccionado,
        "alumnos":
            alumnosSeleccionados.values.expand((x) => x).toSet().toList(),
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
        crossAxisAlignment: CrossAxisAlignment.center, // Cambiado a center
        children: [
          // Título centrado
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

          // Contenido principal con formulario
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
                            // Campo de título
                            TextFormField(
                              controller: tituloController,
                              decoration: InputDecoration(
                                labelText: "Título de la visita",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Por favor ingresa un título';
                                }
                                return null;
                              },
                              onChanged: (value) {
                                setState(() {
                                  titulo = value;
                                });
                              },
                            ),

                            const SizedBox(height: 20),

                            // Selección de empresa
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: empresaSeleccionada,
                                    hint: const Text("Selecciona una empresa"),
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
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey[50],
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Selecciona una empresa';
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
                                  tooltip: 'Agregar nueva empresa',
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // Selección de grupo
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

                            // Selección de profesor
                            DropdownButtonFormField<String>(
                              value: profesorSeleccionado,
                              hint: const Text("Selecciona un profesor"),
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
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Selecciona un profesor';
                                }
                                return null;
                              },
                              isExpanded: true,
                            ),

                            const SizedBox(height: 20),

                            // Selección de fecha y hora
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

                            // Selección de alumnos
                            if (grupoSeleccionado != null &&
                                alumnosPorGrupo[grupoSeleccionado] != null) ...[
                              const Text(
                                "Selecciona los alumnos:",
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
                                      // Checkbox para seleccionar/deseleccionar todos
                                      CheckboxListTile(
                                        title: const Text(
                                          "Seleccionar/Deseleccionar Todos",
                                        ),
                                        value:
                                            seleccionarTodosPorGrupo[grupoSeleccionado] ??
                                            false,
                                        onChanged: (_) {
                                          _toggleSeleccionarTodos(
                                            grupoSeleccionado!,
                                          );
                                        },
                                        controlAffinity:
                                            ListTileControlAffinity.leading,
                                      ),
                                      const Divider(),
                                      // Lista de alumnos
                                      ConstrainedBox(
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
                                            return CheckboxListTile(
                                              title: Text(alumno['nombre']!),
                                              value:
                                                  alumnosSeleccionados[grupoSeleccionado]
                                                      ?.contains(
                                                        alumno['id'],
                                                      ) ??
                                                  false,
                                              onChanged: (bool? selected) {
                                                setState(() {
                                                  if (selected == true) {
                                                    if (!alumnosSeleccionados
                                                        .containsKey(
                                                          grupoSeleccionado,
                                                        )) {
                                                      alumnosSeleccionados[grupoSeleccionado!] =
                                                          [];
                                                    }
                                                    alumnosSeleccionados[grupoSeleccionado!]!
                                                        .add(alumno['id']!);
                                                  } else {
                                                    alumnosSeleccionados[grupoSeleccionado!]!
                                                        .remove(alumno['id']);
                                                  }
                                                });
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
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

class AgregarEmpresaScreen extends StatefulWidget {
  const AgregarEmpresaScreen({super.key});

  @override
  _AgregarEmpresaScreenState createState() => _AgregarEmpresaScreenState();
}

class _AgregarEmpresaScreenState extends State<AgregarEmpresaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  bool _isLoading = false;

  Future<void> _guardarEmpresa() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseFirestore.instance.collection("empresas").add({
        "nombre": _nombreController.text,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Empresa agregada exitosamente"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
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
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Visitas Escolares V3"),
        backgroundColor: Colors.blue,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nombreController,
                decoration: InputDecoration(
                  labelText: "Nombre de la empresa",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa un nombre';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _guardarEmpresa,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child:
                    _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                          "AGREGAR EMPRESA",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nombreController.dispose();
    super.dispose();
  }
}
