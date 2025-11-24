import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ListarUsuariosScreen extends StatelessWidget {
  final String empresa; // Recibe la empresa del administrador

  const ListarUsuariosScreen({super.key, required this.empresa});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuarios de la Empresa'),
        backgroundColor: Color.fromARGB(237, 255, 255, 255),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('usuarios')
            .where('empresa', isEqualTo: empresa) // Filtra por empresa
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay usuarios registrados.'));
          }

          final usuarios = snapshot.data!.docs;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Nombre')),
                DataColumn(label: Text('Email')),
                DataColumn(label: Text('RUT')), // Nuevo campo
                DataColumn(label: Text('Teléfono')), // Nuevo campo
                DataColumn(label: Text('Rol')),
                DataColumn(label: Text('Acciones')),
              ],
              rows: usuarios.map((usuario) {
                final data = usuario.data() as Map<String, dynamic>;
                return DataRow(cells: [
                  DataCell(Text(data['nombre'] ?? '')),
                  DataCell(Text(data['email'] ?? '')),
                  DataCell(Text(data['rut'] ?? '')), // Mostrar RUT
                  DataCell(Text(data['telefono'] ?? '')), // Mostrar Teléfono
                  DataCell(Text(data['rol'] ?? '')),
                  DataCell(Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () {
                          final localContext = context; // Guardar BuildContext localmente
                            Navigator.pushNamed(
                              localContext,
                              '/crear_usuario',
                              arguments: {'empresa': empresa},
                            );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final localContext = context; // Guardar BuildContext localmente
                          final confirm = await showDialog<bool>(
                            context: localContext,
                            builder: (localContext) => AlertDialog(
                              title: const Text('Confirmar eliminación'),
                              content: const Text('¿Estás seguro de que deseas eliminar este usuario?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(localContext, false),
                                  child: const Text('Cancelar'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(localContext, true),
                                  child: const Text('Eliminar'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            await FirebaseFirestore.instance.collection('usuarios').doc(usuario.id).delete();
                            if (!localContext.mounted) return; // Verificar que el widget sigue montado
                            ScaffoldMessenger.of(localContext).showSnackBar(
                              const SnackBar(content: Text('Usuario eliminado exitosamente')),
                            );
                          }
                        },
                      ),
                    ],
                  )),
                ]);
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}

class EditarUsuarioScreen extends StatefulWidget {
  final String usuarioId;

  const EditarUsuarioScreen({super.key, required this.usuarioId});

  @override
  EditarUsuarioScreenState createState() => EditarUsuarioScreenState();
}

class EditarUsuarioScreenState extends State<EditarUsuarioScreen> {
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _rutController = TextEditingController(); // Controlador para RUT
  final TextEditingController _telefonoController = TextEditingController(); // Controlador para Teléfono
  String _selectedRol = 'Conductor'; // Usa un valor válido por defecto

  @override
  void initState() {
    super.initState();
    _fetchUsuarioData();
  }

  Future<void> _fetchUsuarioData() async {
    try {
      final localContext = context; // Guardar BuildContext localmente
      final doc = await FirebaseFirestore.instance.collection('usuarios').doc(widget.usuarioId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        if (!localContext.mounted) return; // Verificar que el widget sigue montado
        setState(() {
          _nombreController.text = data['nombre'] ?? 'Sin nombre';
          _emailController.text = data['email'] ?? 'Sin email';
          _rutController.text = data['rut'] ?? 'Sin RUT'; // Obtener RUT
          _telefonoController.text = data['telefono'] ?? 'Sin teléfono'; // Obtener Teléfono
          _selectedRol = data['rol'] ?? 'Sin rol';
        });
      } else {
        if (!localContext.mounted) return; // Verificar que el widget sigue montado
        ScaffoldMessenger.of(localContext).showSnackBar(
          const SnackBar(content: Text('El usuario no existe en la base de datos')),
        );
        Navigator.pop(localContext); // Regresa a la pantalla anterior
      }
    } catch (e) {
      if (!mounted) return; // Verificar que el widget sigue montado
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al obtener datos del usuario: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Usuario'),
        backgroundColor: Color.fromARGB(237, 255, 255, 255),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nombreController,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _rutController,
              decoration: const InputDecoration(labelText: 'RUT'), // Campo para RUT
            ),
            TextField(
              controller: _telefonoController,
              decoration: const InputDecoration(labelText: 'Teléfono'), // Campo para Teléfono
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
              onPressed: () async {
                final localContext = context; // Guardar BuildContext localmente
                final nombre = _nombreController.text;
                final email = _emailController.text;
                final rut = _rutController.text; // Obtener RUT
                final telefono = _telefonoController.text; // Obtener Teléfono
                final rol = _selectedRol;

                if (nombre.isEmpty || email.isEmpty || rut.isEmpty || telefono.isEmpty || rol.isEmpty) {
                  if (!localContext.mounted) return; // Verificar que el widget sigue montado
                  ScaffoldMessenger.of(localContext).showSnackBar(
                    const SnackBar(content: Text('Por favor, completa todos los campos')),
                  );
                  return;
                }

                try {
                  await FirebaseFirestore.instance.collection('usuarios').doc(widget.usuarioId).update({
                    'nombre': nombre,
                    'email': email,
                    'rut': rut, // Actualizar RUT
                    'telefono': telefono, // Actualizar Teléfono
                    'rol': rol,
                  });
                  if (!localContext.mounted) return; // Verificar que el widget sigue montado
                  ScaffoldMessenger.of(localContext).showSnackBar(
                    const SnackBar(content: Text('Usuario actualizado exitosamente')),
                  );
                  Navigator.pop(localContext); // Regresa a la pantalla anterior
                } catch (e) {
                  if (!localContext.mounted) return; // Verificar que el widget sigue montado
                  ScaffoldMessenger.of(localContext).showSnackBar(
                    SnackBar(content: Text('Error al actualizar el usuario: $e')),
                  );
                }
              },
              child: const Text('Guardar cambios'),
            ),
          ],
        ),
      ),
    );
  }
}