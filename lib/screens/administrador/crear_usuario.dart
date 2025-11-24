import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class CrearUsuarioScreen extends StatefulWidget {
  final String empresa;

  const CrearUsuarioScreen({super.key, required this.empresa});

  @override
  CrearUsuarioScreenState createState() => CrearUsuarioScreenState();
}

class CrearUsuarioScreenState extends State<CrearUsuarioScreen> { 
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _rutController = TextEditingController(); // Nuevo campo RUT
  final TextEditingController _telefonoController = TextEditingController(); // Nuevo campo Teléfono
  String _selectedRol = 'Conductor';

  Future<void> _crearUsuario() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Usa una instancia secundaria de Firebase Auth para no cerrar la sesión del administrador
        final defaultApp = Firebase.app();
        FirebaseApp? secondaryApp;
        UserCredential userCredential;
        try {
          try {
            secondaryApp = Firebase.app('SecondaryAuth');
          } catch (_) {
            secondaryApp = await Firebase.initializeApp(
              name: 'SecondaryAuth',
              options: defaultApp.options,
            );
          }

          final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
          userCredential = await secondaryAuth.createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: '123456', // Contraseña por defecto
          );
          await secondaryAuth.signOut();
        } finally {
          if (secondaryApp != null) {
            await secondaryApp.delete();
          }
        }

        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(userCredential.user?.uid)
            .set({
          'nombre': _nombreController.text.trim(),
          'email': _emailController.text.trim(),
          'rut': _rutController.text.trim(), // Guardar RUT
          'telefono': _telefonoController.text.trim(), // Guardar Teléfono
          'rol': _selectedRol,
          'empresa': widget.empresa,
        });

        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/home_adm',
            (Route<dynamic> route) => false,
            arguments: 'Usuario creado correctamente',
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al crear usuario: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Usuario'),
        backgroundColor: Color.fromARGB(237, 255, 255, 255),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa un email';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _rutController,
                decoration: const InputDecoration(labelText: 'RUT (ej: 12.345.678-0)'), // Nuevo campo
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa un RUT válido';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _telefonoController,
                decoration: const InputDecoration(labelText: 'Teléfono (ej: 997014952)'), // Nuevo campo
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa un número de teléfono válido';
                  }
                  return null;
                },
              ),
              DropdownButtonFormField<String>(
                value: _selectedRol,
                decoration: const InputDecoration(labelText: 'Rol'),
                items: const [
                  DropdownMenuItem(value: 'Conductor', child: Text('Conductor')),
                  DropdownMenuItem(value: 'Patrullero', child: Text('Patrullero')),
                  DropdownMenuItem(value: 'Inspector', child: Text('Inspector')),
                  DropdownMenuItem(value: 'Administrador', child: Text('Administrador')),
                  DropdownMenuItem(value: 'Central_Camaras', child: Text('Central Cámaras')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedRol = value!;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor selecciona un rol';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _crearUsuario,
                child: const Text('Crear Usuario'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

