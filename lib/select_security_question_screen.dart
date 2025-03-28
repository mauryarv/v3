// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'reset_password_screen.dart';

class SelectSecurityQuestionScreen extends StatefulWidget {
  final String userId;

  const SelectSecurityQuestionScreen({super.key, required this.userId});

  @override
  _SelectSecurityQuestionScreenState createState() =>
      _SelectSecurityQuestionScreenState();
}

class _SelectSecurityQuestionScreenState
    extends State<SelectSecurityQuestionScreen> {
  final TextEditingController _answerController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _selectedQuestion;
  bool _obscureAnswer = true;
  bool _isLoading = false;
  final List<String> _securityQuestions = [
    "¿Cuál es el nombre de tu primera mascota?",
    "¿En qué ciudad naciste?",
    "¿Cuál es tu comida favorita?",
  ];

  Future<void> _verifyQuestionAndAnswer() async {
    String selectedQuestion = _selectedQuestion ?? "";
    String answer = _answerController.text.trim();

    if (selectedQuestion.isEmpty || answer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Por favor, selecciona una pregunta y ingresa tu respuesta",
          ),
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
          await _firestore.collection("usuarios").doc(widget.userId).get();

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

      String storedQuestion = userDoc["pregunta_seguridad"];
      String storedAnswerHash = userDoc["respuesta_seguridad"];
      String enteredAnswerHash = sha256.convert(utf8.encode(answer)).toString();

      if (selectedQuestion == storedQuestion &&
          enteredAnswerHash == storedAnswerHash) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResetPasswordScreen(userId: widget.userId),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Pregunta o respuesta incorrecta"),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
                'Verificación de seguridad',
                style: GoogleFonts.caveat(
                  fontSize: 32,
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: isSmallScreen ? 10 : 15),
              Text(
                'Por favor selecciona tu pregunta de seguridad e ingresa la respuesta para verificar tu identidad',
                style: GoogleFonts.roboto(
                  fontSize: isSmallScreen ? 14 : 16,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: isSmallScreen ? 30 : 40),
              DropdownButtonFormField<String>(
                value: _selectedQuestion,
                items:
                    _securityQuestions.map((question) {
                      return DropdownMenuItem<String>(
                        value: question,
                        child: Text(
                          question,
                          style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                        ),
                      );
                    }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedQuestion = value;
                  });
                },
                decoration: InputDecoration(
                  labelText: "Pregunta de seguridad",
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
                  prefixIcon: const Icon(Icons.security, color: Colors.blue),
                ),
                isExpanded: true,
              ),
              SizedBox(height: isSmallScreen ? 20 : 30),
              TextField(
                controller: _answerController,
                obscureText: _obscureAnswer,
                decoration: InputDecoration(
                  labelText: "Respuesta de seguridad",
                  hintText: "Ingresa tu respuesta aquí",
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
                      _obscureAnswer ? Icons.visibility : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureAnswer = !_obscureAnswer;
                      });
                    },
                  ),
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
                    onPressed: _isLoading ? null : _verifyQuestionAndAnswer,
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
                              "Verificar respuesta",
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
