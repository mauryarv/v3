// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v3/forgot_password_screen.dart';
import 'register_screen.dart';
import 'profesor_screen.dart';
import 'alumno_screen.dart';
import 'admin_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _numberController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscureText = true;

  bool _isNumberTextEmpty = true;
  bool _isPasswordTextEmpty = true;

  @override
  void initState() {
    super.initState();

    _numberController.addListener(() {
      setState(() {
        _isNumberTextEmpty = _numberController.text.isEmpty;
      });
    });

    _passwordController.addListener(() {
      setState(() {
        _isPasswordTextEmpty = _passwordController.text.isEmpty;
      });
    });
  }

  @override
  void dispose() {
    _numberController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }

  bool _validatePassword(String password) {
    String pattern =
        r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#\$%\^&\*\(\)_\+\-=\[\]\{\};:\,<>\./?\\|`~]).{8,}$';
    RegExp regex = RegExp(pattern);
    return regex.hasMatch(password);
  }

  Future<void> login() async {
    String number = _numberController.text.trim();
    String password = _passwordController.text.trim();

    if (number.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ingrese número y contraseña")),
      );
      return;
    }

    if (!(number.length == 10 || number.length == 7)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("El número debe tener 7 dígitos o 10 dígitos"),
        ),
      );
      return;
    }

    if (!_validatePassword(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "La contraseña debe tener al menos 8 caracteres, incluyendo:\n"
            "- Una letra mayúscula\n"
            "- Una letra minúscula\n"
            "- Un número\n"
            "- Un carácter especial",
          ),
        ),
      );
      return;
    }

    try {
      DocumentSnapshot userDoc =
          await _firestore.collection("usuarios").doc(number).get();

      if (!userDoc.exists) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Usuario no encontrado")));
        return;
      }

      String storedPasswordHash = userDoc["password"];
      String enteredPasswordHash =
          sha256.convert(utf8.encode(password)).toString();

      if (storedPasswordHash == enteredPasswordHash) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Inicio de sesión exitoso")),
        );

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', number);
        await prefs.setString('user_role', userDoc["rol"]);
        await prefs.setString(
          'user_name',
          userDoc["nombre"],
        ); // Guardar el nombre

        if (number.length == 10) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => AlumnoScreen(alumnoId: number),
            ),
          );
        } else if (number.length == 7) {
          String specificRole = userDoc["rol"];

          if (specificRole == "profesor") {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => ProfesorScreen()),
            );
          } else if (specificRole == "administrador") {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => AdminScreen()),
            );
          } else {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text("Rol desconocido")));
          }
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Contraseña incorrecta")));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error al iniciar sesión: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Visitas Escolares V3',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        actions: <Widget>[
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'about') {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text('Acerca de la aplicación'),
                      content: Text(
                        'Esta aplicación fue desarrollada para facilitar la gestión de visitas escolares del CECyT 3. '
                        'Su objetivo es proporcionar una herramienta eficiente para administradores, profesores y alumnos.',
                      ),
                      actions: <Widget>[
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: Text('Cerrar'),
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
                      title: Text('Créditos'),
                      content: Text(
                        'Aplicación desarrollada por Reyes Vaca Mauricio Alberto.\n'
                        '© 2025 Todos los derechos reservados.',
                      ),
                      actions: <Widget>[
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: Text('Cerrar'),
                        ),
                      ],
                    );
                  },
                );
              }
            },
            itemBuilder:
                (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'about', // Valor para identificar la opción
                    child: Text('Acerca de la aplicación'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'credits', // Valor para identificar la opción
                    child: Text('Créditos'),
                  ),
                ],
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
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(screenWidth * 0.05),
          child: Column(
            children: [
              Text(
                '¡Bienvenido!',
                style: GoogleFonts.caveat(
                  fontSize: 30,
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: screenHeight * 0.04),
              TextField(
                controller: _numberController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: "P.ej. 1234567 o 1234567890",
                  labelText: "Boleta/Trabajador",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.numbers),
                  suffixIcon:
                      _isNumberTextEmpty
                          ? null
                          : IconButton(
                            icon: Icon(Icons.clear),
                            onPressed: () {
                              _numberController.clear();
                            },
                          ),
                ),
              ),
              SizedBox(height: screenHeight * 0.02),
              TextField(
                controller: _passwordController,
                obscureText: _obscureText,
                decoration: InputDecoration(
                  hintText: "P.ej. Admin1@",
                  labelText: "Contraseña",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.password),
                  suffixIcon:
                      _isPasswordTextEmpty
                          ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  _obscureText
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed: _togglePasswordVisibility,
                              ),
                            ],
                          )
                          : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.clear),
                                onPressed: () {
                                  _passwordController.clear();
                                },
                              ),
                              IconButton(
                                icon: Icon(
                                  _obscureText
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed: _togglePasswordVisibility,
                              ),
                            ],
                          ),
                ),
              ),
              SizedBox(height: screenHeight * 0.04),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue, Colors.purple],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ElevatedButton(
                  onPressed: login, // Tu función de login
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    minimumSize: Size(screenWidth * 0.8, screenHeight * 0.06),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    "Iniciar sesión",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              SizedBox(height: screenHeight * 0.02),
              TextButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => RegisterScreen()),
                    (Route<dynamic> route) => false,
                  );
                },
                child: Text("¿No tienes cuenta? Regístrate"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ForgotPasswordScreen(),
                    ),
                    (Route<dynamic> route) => false,
                  );
                },
                child: Text("¿Olvidaste tu contraseña?"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
