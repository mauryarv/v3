// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'select_security_question_screen.dart';
import 'login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _userIdController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;

  Future<void> _verifyUserId() async {
    String userId = _userIdController.text.trim();

    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Por favor, ingresa tu ID de usuario"),
          backgroundColor: Colors.red,
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
          await _firestore.collection("usuarios").doc(userId).get();

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

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SelectSecurityQuestionScreen(userId: userId),
        ),
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
          },
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
                'Recuperar contraseña',
                style: GoogleFonts.caveat(
                  fontSize: 32,
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: isSmallScreen ? 10 : 15),
              Text(
                'Ingresa tu número de boleta/trabajador para continuar con el proceso de recuperación',
                style: GoogleFonts.roboto(
                  fontSize: isSmallScreen ? 14 : 16,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: isSmallScreen ? 30 : 40),
              TextField(
                controller: _userIdController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Número de boleta/trabajador",
                  hintText: "Ejemplo: 1234567 o 1234567890",
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
                    Icons.person_outline,
                    color: Colors.blue,
                  ),
                  suffixIcon:
                      _userIdController.text.isNotEmpty
                          ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () => _userIdController.clear(),
                          )
                          : null,
                ),
                style: TextStyle(fontSize: isSmallScreen ? 16 : 18),
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
                    onPressed: _isLoading ? null : _verifyUserId,
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
                              "Continuar",
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
}
