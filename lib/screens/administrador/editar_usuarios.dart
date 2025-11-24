import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditarUsuarioScreen extends StatefulWidget {
  final String usuarioId; // ID del usuario a editar

  const EditarUsuarioScreen({super.key, required this.usuarioId});

  @override
  EditarUsuarioScreenState createState() => EditarUsuarioScreenState();
}

class EditarUsuarioScreenState extends State<EditarUsuarioScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  String? _selectedRol;

  @override
  void initState() {
    super.initState();
    _fetchUsuarioData();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsuarioData() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('usuarios').doc(widget.usuarioId).get();
      if (!mounted) return;
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        if (data.isNotEmpty) {
          setState(() {
            _nombreController.text = data['nombre'] ?? 'Sin nombre';
            _emailController.text = data['email'] ?? 'Sin email';
            _selectedRol = ['Conductor', 'Patrullero', 'Inspector', 'Administrador']
                .contains(data['rol'])
                ? data['rol']
                : null;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('El documento está vacío')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El usuario no existe en la base de datos')),
        );
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al obtener datos del usuario: $e')),
      );
    }
  }

  Future<void> _editarUsuario() async {
    if (_formKey.currentState!.validate()) {
      await FirebaseFirestore.instance.collection('usuarios').doc(widget.usuarioId).update({
        'nombre': _nombreController.text.trim(),
        'email': _emailController.text.trim(),
        'rol': _selectedRol,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario actualizado exitosamente')),
      );
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_nombreController.text.isEmpty && _emailController.text.isEmpty && _selectedRol == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Usuario'),
        backgroundColor: Color.fromARGB(237, 255, 255, 255),
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
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa el nombre';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa el email';
                  }
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                    return 'Ingresa un email válido';
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
                    _selectedRol = value;
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
                onPressed: _editarUsuario,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color.fromARGB(237, 45, 69, 144),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Actualizar Usuario',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}