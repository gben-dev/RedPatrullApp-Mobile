import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class HomePageConductor extends StatefulWidget {
  const HomePageConductor({super.key});

  @override
  State<HomePageConductor> createState() => _HomePageConductorState();
}

class _HomePageConductorState extends State<HomePageConductor> {
  String? _nombreConductor;
  bool _cargandoNombre = false;

  @override
  void initState() {
    super.initState();
    _cargarNombre();
  }

  Future<void> _cargarNombre() async {
    setState(() => _cargandoNombre = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _cargandoNombre = false);
        return;
      }

      final doc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      final nombre = doc.data()?['nombre'] as String?;
      if (!mounted) return;
      setState(() {
        _nombreConductor = nombre;
        _cargandoNombre = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargandoNombre = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo obtener la información del conductor: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tituloBienvenida = _cargandoNombre
        ? 'Cargando...'
        : '¡Bienvenido ${_nombreConductor ?? 'Conductor'}!';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Conductor'),
        backgroundColor: const Color.fromARGB(237, 255, 255, 255),
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 32, left: 16, right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tituloBienvenida,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(237, 45, 69, 144),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 70,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.receipt_long, color: Color.fromARGB(237, 45, 69, 144), size: 32),
                label: const Text(
                  'Agregar Boleta',
                  style: TextStyle(
                    color: Color.fromARGB(237, 45, 69, 144),
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color.fromARGB(255, 3, 20, 70), width: 2.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/escaneo_boletas',
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 70,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.directions_car, color: Color.fromARGB(237, 45, 69, 144), size: 32),
                label: const Text(
                  'Registrar Salida',
                  style: TextStyle(
                    color: Color.fromARGB(237, 45, 69, 144),
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color.fromARGB(255, 3, 20, 70), width: 2.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () async {
                  final resultado = await Navigator.pushNamed(
                    context,
                    '/escaneo_salida',
                  );
                  if (!mounted) return;
                  if (resultado == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Salida registrada correctamente')),
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 70,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.assignment_turned_in, color: Color.fromARGB(237, 45, 69, 144), size: 32),
                label: const Text(
                  'Registrar Llegada',
                  style: TextStyle(
                    color: Color.fromARGB(237, 45, 69, 144),
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color.fromARGB(255, 3, 20, 70), width: 2.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () async {
                  final resultado = await Navigator.pushNamed(
                    context,
                    '/escaneo_llegada',
                  );
                  if (!mounted) return;
                  if (resultado == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Llegada registrada correctamente')),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}