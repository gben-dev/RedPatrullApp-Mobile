import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../contacto/contacto_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();

    return Scaffold(
      backgroundColor: Color.fromARGB(255, 255, 255, 255),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: 80),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Image.asset(
                'assets/images/imagen_login.png',
                height: 300,
              ),
            ),
            SizedBox(height: 20),
            Container(
              margin: EdgeInsets.symmetric(horizontal: 24),
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Login RedPatrullAPP',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(238, 10, 24, 66),
                    ),
                  ),
                  SizedBox(height: 24),
                  TextField(
                    controller: usernameController,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.person),
                      hintText: 'Usuario',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.lock),
                      hintText: 'Contraseña',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color.fromARGB(238, 10, 24, 66),
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        final localContext = context; // Guardar BuildContext localmente
                        final email = usernameController.text.trim();
                        final password = passwordController.text.trim();

                        try {
                          UserCredential userCredential = await FirebaseAuth.instance
                              .signInWithEmailAndPassword(email: email, password: password);

                          final uid = userCredential.user?.uid;

                          final userDoc = await FirebaseFirestore.instance
                              .collection('usuarios')
                              .doc(uid)
                              .get();

                          if (!localContext.mounted) return; // Verificar que el widget sigue montado

                          if (userDoc.exists) {
                            final data = userDoc.data();
                            final rol = data?['rol'];
                            if (rol == 'administrador') {
                              Navigator.pushReplacementNamed(
                                localContext,
                                '/home_adm',
                              );
                            } else if (rol == 'Patrullero') {
                              Navigator.pushReplacementNamed(
                                localContext,
                                '/home_pat',
                              );
                            } else if (rol == 'Conductor') {
                              Navigator.pushReplacementNamed(
                                localContext,
                                '/home_cond',
                              );
                            } else if (rol == 'Central_Camaras') {
                              Navigator.pushReplacementNamed(
                                localContext,
                                '/home_camaras',
                              );
                            } else {
                              ScaffoldMessenger.of(localContext).showSnackBar(
                                SnackBar(
                                  content: Text('Rol no autorizado para esta sección'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } else {
                            ScaffoldMessenger.of(localContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Tu cuenta aún no está habilitada. Contacta a RedPatrullAPP para obtener acceso.',
                                  style: TextStyle(color: Colors.white),
                                ),
                                backgroundColor: Colors.red,
                                duration: Duration(seconds: 3),
                              ),
                            );
                            await FirebaseAuth.instance.signOut();
                          }
                        } on FirebaseAuthException catch (e) {
                          if (!localContext.mounted) return; // Verificar que el widget sigue montado
                          String errorMsg = 'Error de autenticación';
                          if (e.code == 'user-not-found') {
                            errorMsg = 'Usuario no encontrado';
                          } else if (e.code == 'wrong-password') {
                            errorMsg = 'Contraseña incorrecta';
                          } else if (e.code == 'invalid-email') {
                            errorMsg = 'Correo electrónico inválido';
                          } else if (e.code == 'user-disabled') {
                            errorMsg = 'La cuenta ha sido deshabilitada';
                          } else if (e.code == 'too-many-requests') {
                            errorMsg = 'Demasiados intentos, intenta más tarde';
                          } else if (e.code == 'invalid-credential' || e.code == 'invalid-login-credentials') {
                            errorMsg = 'Las credenciales son incorrectas o han expirado.';
                          }
                          ScaffoldMessenger.of(localContext).showSnackBar(
                            SnackBar(
                              content: Text(errorMsg),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      child: Text(
                        'Iniciar Sesión',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ContactoScreen()),
                      );
                    },
                    child: Text.rich(
                      TextSpan(
                        text: '¿Necesitas una cuenta? ',
                        style: TextStyle(color: Colors.grey[700]),
                        children: [
                          TextSpan(
                            text: 'Contacta a RedPatrullAPP',
                            style: TextStyle(
                              color: Color.fromARGB(238, 10, 24, 66),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}