// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use

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
  bool _isLoading = false;
  bool _isNumberValid = false;
  bool _isPasswordValid = false;

  // Estados para validación de contraseña
  bool _hasMinLength = false;
  bool _hasUpperCase = false;
  bool _hasLowerCase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;

  @override
  void initState() {
    super.initState();
    _numberController.addListener(_validateNumber);
    _passwordController.addListener(_validatePassword);
  }

  @override
  void dispose() {
    _numberController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _validateNumber() {
    final number = _numberController.text.trim();
    setState(() {
      _isNumberValid = number.length == 7 || number.length == 10;
    });
  }

  void _validatePassword() {
    final password = _passwordController.text;
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasUpperCase = password.contains(RegExp(r'[A-Z]'));
      _hasLowerCase = password.contains(RegExp(r'[a-z]'));
      _hasNumber = password.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
      _isPasswordValid =
          _hasMinLength &&
          _hasUpperCase &&
          _hasLowerCase &&
          _hasNumber &&
          _hasSpecialChar;
    });
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }

  Future<void> login() async {
    String number = _numberController.text.trim();
    String password = _passwordController.text.trim();

    // Validar campos vacíos
    if (number.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Por favor ingrese número y contraseña"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Validar formato de número
    if (!_isNumberValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "El número debe tener 7 dígitos (profesor) o 10 dígitos (alumno)",
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Validar contraseña
    if (!_isPasswordValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("La contraseña no cumple con los requisitos mínimos"),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      DocumentSnapshot userDoc =
          await _firestore.collection("usuarios").doc(number).get();

      if (!userDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Usuario no encontrado"),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      String storedPasswordHash = userDoc["password"];
      String enteredPasswordHash =
          sha256.convert(utf8.encode(password)).toString();

      if (storedPasswordHash == enteredPasswordHash) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Inicio de sesión exitoso"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', number);
        await prefs.setString('user_role', userDoc["rol"]);
        await prefs.setString('user_name', userDoc["nombre"]);

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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Rol desconocido"),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Contraseña incorrecta"),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error al iniciar sesión: $e"),
          backgroundColor: Colors.red,
        ),
      );
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
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final iconSize = isSmallScreen ? 16.0 : 20.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Visitas Escolares V3',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: isSmallScreen ? 18 : 22,
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
      body: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 24.0 : screenSize.width * 0.25,
            vertical: 24.0,
          ),
          child: Column(
            children: [
              SizedBox(height: isSmallScreen ? 20 : 40),
              Text(
                '¡Bienvenido!',
                style: GoogleFonts.caveat(
                  fontSize: 32,
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: isSmallScreen ? 10 : 15),
              Text(
                'Ingresa tus credenciales para acceder al sistema',
                style: GoogleFonts.roboto(
                  fontSize: isSmallScreen ? 14 : 16,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: isSmallScreen ? 30 : 40),
              TextField(
                controller: _numberController,
                keyboardType: TextInputType.number,
                maxLength: 10,
                decoration: InputDecoration(
                  counterText: "",
                  hintText: "Ejemplo: 1234567 o 1234567890",
                  labelText: "Boleta/ID de trabajador",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.blue),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.blue, width: 2),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    vertical: isSmallScreen ? 16 : 20,
                    horizontal: 16,
                  ),
                  prefixIcon: const Icon(Icons.numbers, color: Colors.blue),
                  suffixIcon:
                      _numberController.text.isEmpty
                          ? null
                          : IconButton(
                            icon: Icon(
                              _isNumberValid ? Icons.check_circle : Icons.error,
                              color: _isNumberValid ? Colors.green : Colors.red,
                            ),
                            onPressed: null,
                          ),
                ),
                style: TextStyle(fontSize: isSmallScreen ? 16 : 18),
              ),
              SizedBox(height: isSmallScreen ? 20 : 30),
              TextField(
                controller: _passwordController,
                obscureText: _obscureText,
                decoration: InputDecoration(
                  labelText: "Contraseña",
                  hintText: "Ingresa tu contraseña",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.blue),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.blue, width: 2),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    vertical: isSmallScreen ? 16 : 20,
                    horizontal: 16,
                  ),
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                    color: Colors.blue,
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          _obscureText
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Colors.grey,
                        ),
                        onPressed: _togglePasswordVisibility,
                      ),
                      if (_passwordController.text.isNotEmpty)
                        IconButton(
                          icon: Icon(
                            _isPasswordValid ? Icons.check_circle : Icons.error,
                            color: _isPasswordValid ? Colors.green : Colors.red,
                          ),
                          onPressed: null,
                        ),
                    ],
                  ),
                ),
                style: TextStyle(fontSize: isSmallScreen ? 16 : 18),
              ),
              SizedBox(height: isSmallScreen ? 10 : 15),
              _buildPasswordRequirements(iconSize),
              SizedBox(height: isSmallScreen ? 30 : 40),
              SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.blue, Colors.purple],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: EdgeInsets.symmetric(
                        vertical: isSmallScreen ? 16 : 20,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child:
                        _isLoading
                            ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                            : Text(
                              "Iniciar sesión",
                              style: GoogleFonts.poppins(
                                fontSize: isSmallScreen ? 16 : 18,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                  ),
                ),
              ),
              SizedBox(height: isSmallScreen ? 20 : 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RegisterScreen(),
                        ),
                      );
                    },
                    child: Text(
                      "Registrarse",
                      style: GoogleFonts.roboto(
                        fontSize: isSmallScreen ? 14 : 16,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ForgotPasswordScreen(),
                        ),
                      );
                    },
                    child: Text(
                      "¿Olvidaste tu contraseña?",
                      style: GoogleFonts.roboto(
                        fontSize: isSmallScreen ? 14 : 16,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
              if (!isSmallScreen) SizedBox(height: screenSize.height * 0.1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordRequirements(double iconSize) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildValidationRow("Mínimo 8 caracteres", _hasMinLength, iconSize),
        _buildValidationRow("Al menos una mayúscula", _hasUpperCase, iconSize),
        _buildValidationRow("Al menos una minúscula", _hasLowerCase, iconSize),
        _buildValidationRow("Al menos un número", _hasNumber, iconSize),
        _buildValidationRow(
          "Al menos un carácter especial (!@#\$%^&*)",
          _hasSpecialChar,
          iconSize,
        ),
      ],
    );
  }

  Widget _buildValidationRow(String text, bool isValid, double iconSize) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.error,
            color: isValid ? Colors.green : Colors.grey,
            size: iconSize,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: isValid ? Colors.green : Colors.grey,
              fontSize: iconSize - 2,
            ),
          ),
        ],
      ),
    );
  }
}
