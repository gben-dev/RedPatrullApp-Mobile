import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactoScreen extends StatelessWidget {
  ContactoScreen({super.key});

  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _empresaController = TextEditingController();
  final _correoController = TextEditingController();
  final _telefonoController = TextEditingController(); // <-- Nuevo controlador
  final _mensajeController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacto'),
        backgroundColor: Color.fromARGB(237, 255, 255, 255),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Ingrese su nombre' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _empresaController,
                decoration: const InputDecoration(
                  labelText: 'Empresa',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _correoController,
                decoration: const InputDecoration(
                  labelText: 'Correo',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingrese su correo';
                  }
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                    return 'Correo no válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _telefonoController,
                decoration: const InputDecoration(
                  labelText: 'Número teléfono',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) =>
                    value == null || value.isEmpty ? 'Ingrese su número de teléfono' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _mensajeController,
                decoration: const InputDecoration(
                  labelText: 'Mensaje',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.message),
                ),
                maxLines: 4,
                validator: (value) =>
                    value == null || value.isEmpty ? 'Ingrese un mensaje' : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color.fromARGB(238, 10, 24, 66),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      await FirebaseFirestore.instance.collection('contacto_empresas').add({
                        'Nombre': _nombreController.text.trim(),
                        'Empresa': _empresaController.text.trim(),
                        'Correo': _correoController.text.trim(),
                        'numero telefono': _telefonoController.text.trim(), // <-- Nuevo campo
                        'Mensaje': _mensajeController.text.trim(),
                      });
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Mensaje enviado')),
                      );
                      _nombreController.clear();
                      _empresaController.clear();
                      _correoController.clear();
                      _telefonoController.clear(); // <-- Limpiar campo
                      _mensajeController.clear();
                    }
                  },
                  child: const Text(
                    'Enviar',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final telefono = '56996107683'; // Cambia por el número de WhatsApp destino (sin +)
          final mensaje = Uri.encodeComponent('Hola, quiero contactar a la empresa.');
          final url = 'https://wa.me/$telefono?text=$mensaje';

          try {
            await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No se pudo abrir WhatsApp')),
            );
          }
        },
        backgroundColor: Colors.white,
        child: Image.asset(
          'assets/images/whatsapp_azul.png',
          width: 32,
          height: 32,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}