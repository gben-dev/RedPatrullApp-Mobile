import 'package:flutter/material.dart';

class HomePageCentralCamaras extends StatelessWidget {
  const HomePageCentralCamaras({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Central Cámaras'),
        backgroundColor: Color.fromARGB(237, 255, 255, 255),
      ),
      body: const Center(
        child: Text(
          'Bienvenido a Central Cámaras',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color.fromARGB(237, 45, 69, 144)),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
