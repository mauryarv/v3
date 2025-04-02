// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String userId;

  const ResetPasswordScreen({super.key, required this.userId});

  @override
  _ResetPasswordScreenState createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController _newPasswordController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _hasMinLength = false;
  bool _hasUpperCase = false;
  bool _hasLowerCase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;

  void _validatePassword(String value) {
    setState(() {
      _hasMinLength = value.length >= 8;
      _hasUpperCase = value.contains(RegExp(r'[A-Z]'));
      _hasLowerCase = value.contains(RegExp(r'[a-z]'));
      _hasNumber = value.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
  }

  bool get _isPasswordValid {
    return _hasMinLength &&
        _hasUpperCase &&
        _hasLowerCase &&
        _hasNumber &&
        _hasSpecialChar;
  }

  Future<void> _resetPassword() async {
    if (!_isPasswordValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("La contraseña no cumple con los requisitos"),
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
      String newPasswordHash =
          sha256.convert(utf8.encode(_newPasswordController.text)).toString();

      await _firestore.collection("usuarios").doc(widget.userId).update({
        "password": newPasswordHash,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Contraseña restablecida exitosamente"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString()}"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: isSmallScreen ? 20 : 40),
              Text(
                'Restablecer contraseña',
                style: GoogleFonts.caveat(
                  fontSize: 32,
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: isSmallScreen ? 10 : 15),
              Text(
                'Crea una nueva contraseña segura para tu cuenta',
                style: GoogleFonts.roboto(
                  fontSize: isSmallScreen ? 14 : 16,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: isSmallScreen ? 30 : 40),
              TextField(
                controller: _newPasswordController,
                obscureText: _obscurePassword,
                onChanged: _validatePassword,
                decoration: InputDecoration(
                  labelText: "Nueva contraseña",
                  hintText: "Ingresa tu nueva contraseña",
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
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                style: TextStyle(fontSize: isSmallScreen ? 16 : 18),
              ),
              SizedBox(height: isSmallScreen ? 15 : 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildValidationRow(
                    "Mínimo 8 caracteres",
                    _hasMinLength,
                    iconSize,
                  ),
                  _buildValidationRow(
                    "Al menos una mayúscula (A-Z)",
                    _hasUpperCase,
                    iconSize,
                  ),
                  _buildValidationRow(
                    "Al menos una minúscula (a-z)",
                    _hasLowerCase,
                    iconSize,
                  ),
                  _buildValidationRow(
                    "Al menos un número (0-9)",
                    _hasNumber,
                    iconSize,
                  ),
                  _buildValidationRow(
                    "Al menos un carácter especial (!@#\$%^&*)",
                    _hasSpecialChar,
                    iconSize,
                  ),
                ],
              ),
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
                    onPressed: _isLoading ? null : _resetPassword,
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
                              "Restablecer contraseña",
                              style: GoogleFonts.poppins(
                                fontSize: isSmallScreen ? 16 : 18,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                  ),
                ),
              ),
              if (!isSmallScreen) SizedBox(height: screenSize.height * 0.1),
              SizedBox(height: isSmallScreen ? 20 : 30),
            ],
          ),
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
