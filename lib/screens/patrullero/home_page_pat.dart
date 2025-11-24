import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class HomePagePat extends StatefulWidget {
  const HomePagePat({super.key});

  @override
  HomePagePatState createState() => HomePagePatState();
}

class HomePagePatState extends State<HomePagePat> {
  String? nombreUsuario;

  @override
  void initState() {
    super.initState();
    _fetchNombreUsuario();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _fetchNombreUsuario() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();
      if (!mounted) return;
      if (doc.exists) {
        setState(() {
          nombreUsuario = doc.data()?['nombre'] ?? 'Patrullero';
        });
      }
    } else {
      debugPrint('[HomePagePat] Usuario no logueado.');
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  Future<void> _callNumber(String number) async {
    final uri = Uri.parse('tel:$number');
    try {
      final canLaunch = await canLaunchUrl(uri);
      if (canLaunch) {
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se abrió el marcador para $number')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Marcador no disponible en este dispositivo')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al intentar marcar $number: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio Patrullero'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 32, left: 16, right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '¡Bienvenido ${nombreUsuario ?? 'Patrullero'}!',
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
                icon: const Icon(Icons.report,
                    color: Color.fromARGB(237, 45, 69, 144), size: 32),
                label: const Text(
                  'Crear Reporte',
                  style: TextStyle(
                    color: Color.fromARGB(237, 45, 69, 144),
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side:
                      const BorderSide(color: Color.fromARGB(255, 3, 20, 70), width: 2.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/crear_reporte',
                      arguments: {'nombrePatrullero': nombreUsuario ?? ''},
                    );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'call_131',
            mini: true,
            // Celeste para ambulancia
            backgroundColor: const Color.fromARGB(255, 0, 188, 212),
            onPressed: () => _callNumber('131'),
            tooltip: 'Llamar Ambulancia (131)',
            child: const Icon(Icons.medical_services),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'call_132',
            mini: true,
            backgroundColor: const Color.fromARGB(255, 220, 53, 69),
            onPressed: () => _callNumber('132'),
            tooltip: 'Llamar Bomberos (132)',
            child: const Icon(Icons.local_fire_department),
          ),
          const SizedBox(height: 12),
            FloatingActionButton(
              heroTag: 'call_133',
              mini: true,
              // Verde para policía
              backgroundColor: const Color.fromARGB(255, 76, 175, 80),
              onPressed: () => _callNumber('133'),
              tooltip: 'Llamar Policía (133)',
              child: const Icon(Icons.local_police),
            ),
        ],
      ),
    );
  }
}
