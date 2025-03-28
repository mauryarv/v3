// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _numberController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _answerController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isNumberValid = false;
  bool _isNumberNumeric = true;
  bool _isPasswordValid = false;
  bool _isAnswerValid = false;
  bool _obscurePassword = true;
  bool _obscureAnswer = true;
  bool _isLoading = false;

  // Estados para validación de contraseña
  bool _hasMinLength = false;
  bool _hasUpperCase = false;
  bool _hasLowerCase = false;
  bool _hasNumberChar = false;
  bool _hasSpecialChar = false;

  // Estados para validación de número
  bool _hasValidLength = false;
  bool _isProfessorLength = false;
  bool _isStudentLength = false;

  String _selectedQuestion = "¿Cuál es el nombre de tu primera mascota?";
  final List<String> _securityQuestions = [
    "¿Cuál es el nombre de tu primera mascota?",
    "¿En qué ciudad naciste?",
    "¿Cuál es tu comida favorita?",
  ];

  @override
  void initState() {
    super.initState();
    _numberController.addListener(_validateNumber);
    _passwordController.addListener(_validatePassword);
    _answerController.addListener(_validateAnswer);
  }

  void _validateNumber() {
    final number = _numberController.text.trim();
    final isNumeric = RegExp(r'^[0-9]+$').hasMatch(number);

    setState(() {
      _isNumberNumeric = isNumeric;
      _isProfessorLength = number.length == 7;
      _isStudentLength = number.length == 10;
      _hasValidLength = _isProfessorLength || _isStudentLength;
      _isNumberValid = isNumeric && _hasValidLength;
    });
  }

  void _validatePassword() {
    final password = _passwordController.text;
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasUpperCase = password.contains(RegExp(r'[A-Z]'));
      _hasLowerCase = password.contains(RegExp(r'[a-z]'));
      _hasNumberChar = password.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
      _isPasswordValid =
          _hasMinLength &&
          _hasUpperCase &&
          _hasLowerCase &&
          _hasNumberChar &&
          _hasSpecialChar;
    });
  }

  void _validateAnswer() {
    setState(() {
      _isAnswerValid = _answerController.text.trim().isNotEmpty;
    });
  }

  Future<void> register() async {
    // Validar campos vacíos primero
    List<String> missingFields = [];

    if (_numberController.text.isEmpty) {
      missingFields.add("Número de boleta/trabajador");
    }

    if (_passwordController.text.isEmpty) {
      missingFields.add("Contraseña");
    }

    if (_answerController.text.isEmpty) {
      missingFields.add("Respuesta de seguridad");
    }

    if (missingFields.isNotEmpty) {
      String message = "Por favor complete los siguientes campos:\n";
      message += missingFields.map((field) => "• $field").join("\n");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validar formato de campos
    List<String> invalidFields = [];

    if (!_isNumberValid) {
      if (!_isNumberNumeric) {
        invalidFields.add(
          "El número de boleta/trabajador solo debe contener dígitos",
        );
      }
      if (!_hasValidLength) {
        invalidFields.add(
          "El número debe tener 7 dígitos (profesor) o 10 dígitos (alumno)",
        );
      }
    }

    if (!_isPasswordValid) {
      List<String> passwordErrors = [];
      if (!_hasMinLength) passwordErrors.add("mínimo 8 caracteres");
      if (!_hasUpperCase) passwordErrors.add("una mayúscula");
      if (!_hasLowerCase) passwordErrors.add("una minúscula");
      if (!_hasNumberChar) passwordErrors.add("un número");
      if (!_hasSpecialChar) passwordErrors.add("un carácter especial");

      invalidFields.add(
        "La contraseña debe tener: ${passwordErrors.join(', ')}",
      );
    }

    if (invalidFields.isNotEmpty) {
      String message = "Corrija los siguientes errores:\n";
      message += invalidFields.map((error) => "• $error").join("\n");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Proceso de registro
    setState(() {
      _isLoading = true;
    });

    try {
      String number = _numberController.text.trim();
      String password = _passwordController.text.trim();
      String securityAnswer = _answerController.text.trim();

      DocumentSnapshot docSnapshot =
          await _firestore.collection("usuarios").doc(number).get();

      if (docSnapshot.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("El usuario ya está registrado"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      String passwordHash = sha256.convert(utf8.encode(password)).toString();
      String securityAnswerHash =
          sha256.convert(utf8.encode(securityAnswer)).toString();

      await _firestore.collection("usuarios").doc(number).set({
        "password": passwordHash,
        "pregunta_seguridad": _selectedQuestion,
        "respuesta_seguridad": securityAnswerHash,
        "rol": _isStudentLength ? "alumno" : "profesor",
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Registro exitoso"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error al registrar usuario: $e"),
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

  void _showInfoDialog(String title, String content) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final iconSize = isSmallScreen ? 16.0 : 20.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Visitas Escolares V3',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'about') {
                _showInfoDialog(
                  'Acerca de la aplicación',
                  'Esta aplicación fue desarrollada para facilitar la gestión de visitas escolares del CECyT 3.\n'
                      'Su objetivo es proporcionar una herramienta eficiente para administradores, profesores y alumnos.',
                );
              } else if (value == 'credits') {
                _showInfoDialog(
                  'Créditos',
                  'Aplicación desarrollada por Reyes Vaca Mauricio Alberto.\n© 2025 Todos los derechos reservados.',
                );
              }
            },
            itemBuilder:
                (_) => const [
                  PopupMenuItem(
                    value: 'about',
                    child: Text('Acerca de la aplicación'),
                  ),
                  PopupMenuItem(value: 'credits', child: Text('Créditos')),
                ],
          ),
        ],
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
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 20.0 : screenSize.width * 0.15,
            vertical: 20.0,
          ),
          child: Column(
            children: [
              SizedBox(height: isSmallScreen ? 20 : 40),
              Text(
                '¡Regístrate!',
                style: GoogleFonts.caveat(
                  fontSize: 30,
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: isSmallScreen ? 20 : 30),
              _buildNumberField(isSmallScreen),
              SizedBox(height: isSmallScreen ? 10 : 15),
              _buildNumberRequirements(iconSize),
              SizedBox(height: isSmallScreen ? 15 : 20),
              _buildPasswordField(isSmallScreen),
              SizedBox(height: isSmallScreen ? 10 : 15),
              _buildPasswordRequirements(iconSize),
              SizedBox(height: isSmallScreen ? 15 : 20),
              _buildDropdownField(isSmallScreen),
              SizedBox(height: isSmallScreen ? 15 : 20),
              _buildAnswerField(isSmallScreen),
              SizedBox(height: isSmallScreen ? 20 : 30),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.blue, Colors.purple],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ElevatedButton(
                  onPressed:
                      (_isNumberValid &&
                              _isPasswordValid &&
                              _isAnswerValid &&
                              !_isLoading)
                          ? register
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    minimumSize: Size(double.infinity, isSmallScreen ? 50 : 60),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child:
                      _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                            "Registrar",
                            style: GoogleFonts.poppins(
                              fontSize: isSmallScreen ? 16 : 18,
                              color: Colors.white,
                            ),
                          ),
                ),
              ),
              SizedBox(height: isSmallScreen ? 15 : 20),
              TextButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                    (Route<dynamic> route) => false,
                  );
                },
                child: Text(
                  "¿Ya tienes cuenta? Inicia sesión",
                  style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                ),
              ),
              SizedBox(height: isSmallScreen ? 20 : 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumberField(bool isSmallScreen) {
    return TextField(
      controller: _numberController,
      keyboardType: TextInputType.number,
      maxLength: 10,
      decoration: InputDecoration(
        counterText: "",
        hintText: "P.ej. 1234567 o 1234567890",
        labelText: "Boleta/Trabajador",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: const Icon(Icons.numbers),
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
    );
  }

  Widget _buildNumberRequirements(double iconSize) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildValidationRow("Solo números (0-9)", _isNumberNumeric, iconSize),
        _buildValidationRow(
          "7 dígitos (profesor) o 10 dígitos (alumno)",
          _hasValidLength,
          iconSize,
        ),
        if (_hasValidLength)
          Padding(
            padding: const EdgeInsets.only(left: 24.0, top: 4),
            child: Text(
              _isProfessorLength
                  ? "Registrando como profesor"
                  : "Registrando como alumno",
              style: TextStyle(
                color: Colors.blue,
                fontSize: iconSize - 2,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPasswordField(bool isSmallScreen) {
    return TextField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        hintText: "P.ej. Admin1@",
        labelText: "Contraseña",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: const Icon(Icons.password),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed:
                  () => setState(() => _obscurePassword = !_obscurePassword),
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
    );
  }

  Widget _buildPasswordRequirements(double iconSize) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildValidationRow("Mínimo 8 caracteres", _hasMinLength, iconSize),
        _buildValidationRow("Al menos una mayúscula", _hasUpperCase, iconSize),
        _buildValidationRow("Al menos una minúscula", _hasLowerCase, iconSize),
        _buildValidationRow("Al menos un número", _hasNumberChar, iconSize),
        _buildValidationRow(
          "Al menos un carácter especial (!@#\$%^&*)",
          _hasSpecialChar,
          iconSize,
        ),
      ],
    );
  }

  Widget _buildDropdownField(bool isSmallScreen) {
    return DropdownButtonFormField<String>(
      value: _selectedQuestion,
      items:
          _securityQuestions
              .map(
                (q) => DropdownMenuItem(
                  value: q,
                  child: Text(
                    q,
                    style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                  ),
                ),
              )
              .toList(),
      onChanged: (value) => setState(() => _selectedQuestion = value!),
      decoration: InputDecoration(
        labelText: "Pregunta de seguridad",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: const Icon(Icons.security),
      ),
    );
  }

  Widget _buildAnswerField(bool isSmallScreen) {
    return TextField(
      controller: _answerController,
      obscureText: _obscureAnswer,
      decoration: InputDecoration(
        labelText: "Respuesta de seguridad",
        hintText: "P.ej. Firulais",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                _obscureAnswer ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: () => setState(() => _obscureAnswer = !_obscureAnswer),
            ),
            if (_answerController.text.isNotEmpty)
              IconButton(
                icon: Icon(
                  _isAnswerValid ? Icons.check_circle : Icons.error,
                  color: _isAnswerValid ? Colors.green : Colors.red,
                ),
                onPressed: null,
              ),
          ],
        ),
      ),
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
