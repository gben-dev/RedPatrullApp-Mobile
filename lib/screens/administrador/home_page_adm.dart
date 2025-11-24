import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Navegación a otras pantallas se maneja con rutas named desde main.dart

class HomePageAdm extends StatefulWidget {
  const HomePageAdm({super.key, this.message});

  final String? message;

  @override
  HomePageAdmState createState() => HomePageAdmState();
}

class HomePageAdmState extends State<HomePageAdm> {
  String? nombreUsuario;

  @override
  void initState() {
    super.initState();
    _fetchNombreUsuario();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final msg = widget.message;
      if (msg != null && msg.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    });
  }

  Future<void> _fetchNombreUsuario() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      if (!mounted) return;
      if (doc.exists) {
        setState(() {
          nombreUsuario = doc.data()?['nombre'] ?? 'Administrador';
        });
      }
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  Future<void> _navegarCrearUsuario() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final adminDoc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
    if (!mounted) return;
    final empresaAdmin = adminDoc.data()?['empresa'];
    if (empresaAdmin != null) {
      Navigator.pushNamed(
        context,
        '/crear_usuario',
        arguments: {'empresa': empresaAdmin},
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo obtener la empresa del administrador')),
      );
    }
  }

  Future<void> _navegarListarUsuarios() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final adminDoc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
    if (!mounted) return;
    final empresaAdmin = adminDoc.data()?['empresa'];
    if (empresaAdmin != null) {
      Navigator.pushNamed(
        context,
        '/listar_usuarios',
        arguments: {'empresa': empresaAdmin},
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo obtener la empresa del administrador')),
      );
    }
  }

  Future<void> _navegarListarReportes() async {
    Navigator.pushNamed(context, '/ver_reportes');
  }

  Future<void> _navegarAgregarVehiculo() async {
    Navigator.pushNamed(context, '/agregar_vehiculo');
  }

  Future<void> _navegarListarVehiculos() async {
    Navigator.pushNamed(context, '/listar_vehiculos');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Administrador'),
        backgroundColor: Color.fromARGB(237, 255, 255, 255),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color.fromARGB(237, 45, 69, 144)),
            tooltip: 'Cerrar sesión',
            onPressed: _logout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 32, left: 16, right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '¡Bienvenido ${nombreUsuario ?? 'Administrador'}!',
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
                icon: Icon(Icons.person_add, color: Color.fromARGB(237, 45, 69, 144), size: 32),
                label: Text(
                  'Crear usuario',
                  style: TextStyle(
                    color: Color.fromARGB(237, 45, 69, 144),
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: BorderSide(color: Color.fromARGB(255, 3, 20, 70), width: 2.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _navegarCrearUsuario,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 70,
              child: OutlinedButton.icon(
                icon: Icon(Icons.list_alt, color: Color.fromARGB(237, 45, 69, 144), size: 32),
                label: Text(
                  'Listar usuarios',
                  style: TextStyle(
                    color: Color.fromARGB(237, 45, 69, 144),
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: BorderSide(color: Color.fromARGB(255, 3, 20, 70), width: 2.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _navegarListarUsuarios,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 70,
              child: OutlinedButton.icon(
                icon: Icon(Icons.assignment, color: Color.fromARGB(237, 45, 69, 144), size: 32),
                label: Text(
                  'Listar reportes',
                  style: TextStyle(
                    color: Color.fromARGB(237, 45, 69, 144),
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: BorderSide(color: Color.fromARGB(255, 3, 20, 70), width: 2.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _navegarListarReportes,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 70,
              child: OutlinedButton.icon(
                icon: Icon(Icons.directions_car, color: Color.fromARGB(237, 45, 69, 144), size: 32),
                label: Text(
                  'Agregar Vehículo',
                  style: TextStyle(
                    color: Color.fromARGB(237, 45, 69, 144),
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: BorderSide(color: Color.fromARGB(255, 3, 20, 70), width: 2.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _navegarAgregarVehiculo,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 70,
              child: OutlinedButton.icon(
                icon: Icon(Icons.directions_car_filled_outlined, color: Color.fromARGB(237, 45, 69, 144), size: 32),
                label: Text(
                  'Listar Vehículos',
                  style: TextStyle(
                    color: Color.fromARGB(237, 45, 69, 144),
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: BorderSide(color: Color.fromARGB(255, 3, 20, 70), width: 2.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _navegarListarVehiculos,
              ),
            ),
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('usuarios')
                  .doc(FirebaseAuth.instance.currentUser?.uid)
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Text('No se encontró información del administrador.'),
                  );
                }
                final data = snapshot.data!.data() as Map<String, dynamic>;
                final empresa = data['empresa'] ?? 'Sin empresa';
                return Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Text(
                    'Empresa actual: $empresa',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}