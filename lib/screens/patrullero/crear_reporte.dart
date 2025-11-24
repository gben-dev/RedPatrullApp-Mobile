import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

class CrearReporteScreen extends StatefulWidget {
  const CrearReporteScreen({super.key});

  @override
  State<CrearReporteScreen> createState() => _CrearReporteScreenState();
}

class _CrearReporteScreenState extends State<CrearReporteScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _interseccionesController = TextEditingController();
  final TextEditingController _direccionController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();
  final TextEditingController _nombrePersonaController = TextEditingController();
  final TextEditingController _rutPersonaController = TextEditingController();
  final TextEditingController _movilController = TextEditingController();

  String? _tipoIncidente;
  String? _turno;
  DateTime? _fecha;
  TimeOfDay? _hora;

  String? _nombrePatrullero;

  // --- IMAGENES ---
  final List<File> _imagenesSeleccionadas = [];
  final List<String> _urlsImagenes = [];
  final int _maxImagenes = 5;
  final int _maxBytes = 3 * 1024 * 1024; // 3MB

  @override
  void initState() {
    super.initState();
    _fetchNombrePatrullero();
  }

  Future<void> _fetchNombrePatrullero() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      if (!mounted) return;
      setState(() {
        _nombrePatrullero = doc.data()?['nombre'] ?? 'Patrullero';
      });
    }
  }

  // Reducción automática de imagen a 3MB o menos
  Future<File> _reducirImagen(File file) async {
    final bytes = await file.readAsBytes();
    img.Image? image = img.decodeImage(bytes);
    if (image == null) return file;

    int quality = 90;
    Uint8List jpg;
    do {
      jpg = Uint8List.fromList(img.encodeJpg(image, quality: quality));
      quality -= 10;
    } while (jpg.length > _maxBytes && quality > 10);

    final tempDir = Directory.systemTemp;
    final tempFile = await File('${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg').create();
    await tempFile.writeAsBytes(jpg);
    return tempFile;
  }

  // Modifica la selección para reducir automáticamente las imágenes
  Future<void> _seleccionarImagenes() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(imageQuality: 90);

    if (!mounted) return;

    if (pickedFiles.isNotEmpty) {
      if (pickedFiles.length + _imagenesSeleccionadas.length > _maxImagenes) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Máximo $_maxImagenes imágenes por reporte')),
        );
        return;
      }
      for (var pickedFile in pickedFiles) {
        final file = File(pickedFile.path);
        final reducido = await _reducirImagen(file);
        if (!mounted) return;
        final reducidoSize = await reducido.length();
        if (!mounted) return;
        if (reducidoSize <= _maxBytes) {
          if (!mounted) return;
          setState(() {
            _imagenesSeleccionadas.add(reducido);
          });
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo reducir la imagen a menos de 3MB')),
          );
        }
      }
    }
  }

  // --- NUEVA FUNCIÓN PARA CLOUDINARY ---
  Future<String?> subirImagenACloudinary(File imagen) async {
    final cloudName = 'dwhdt3z1g'; // Ejemplo: dwhdt3z1g
    final uploadPreset = 'upload_images_undigned';

    final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', imagen.path));

    final response = await request.send();
    final res = await http.Response.fromStream(response);

    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      return data['secure_url'];
    } else {
      return null;
    }
  }

  // Subida de imágenes con mensaje de estado
  Future<void> _subirTodasLasImagenes() async {
    _urlsImagenes.clear();
    // Mostrar mensaje de subida
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Subiendo imágenes...')),
    );
    final urls = await Future.wait(
      _imagenesSeleccionadas.map((imgFile) => subirImagenACloudinary(imgFile)),
    );
    _urlsImagenes.addAll(urls.whereType<String>());
  }

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (!mounted) return;
    if (picked != null) setState(() => _fecha = picked);
  }

  Future<void> _seleccionarHora() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (!mounted) return;
    if (picked != null) setState(() => _hora = picked);
  }

  Future<void> _guardarReporte() async {
    if (_fecha == null || _hora == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes seleccionar fecha y hora del incidente')),
      );
      return;
    }
    if (_turno == null || _turno!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes seleccionar el turno/jornada')),
      );
      return;
    }

    // Subir imágenes antes de guardar el reporte
    await _subirTodasLasImagenes();
    if (!mounted) return;

    // Ajusta la hora local usando el offset del sistema
    final DateTime fechaHoraLocal = DateTime(
      _fecha!.year,
      _fecha!.month,
      _fecha!.day,
      _hora!.hour,
      _hora!.minute,
    ).subtract(DateTime.now().timeZoneOffset);

    try {
      await FirebaseFirestore.instance.collection('reportes').add({
        'descripcion': _descripcionController.text.trim(),
        'direccion': _direccionController.text.trim(),
        'fecha': Timestamp.fromDate(fechaHoraLocal),
        'fecha_creacion': FieldValue.serverTimestamp(),
        'intersecciones': _interseccionesController.text.trim(),
        'movil': _movilController.text.trim(),
        'nombre_patrullero': _nombrePatrullero,
        'nombre_persona': _nombrePersonaController.text.trim(),
        'rut_persona': _rutPersonaController.text.trim(),
        'tipo_incidente': _tipoIncidente,
        'turno': _turno?.toLowerCase(),
        'imagenes': _urlsImagenes, // Guarda la lista de URLs aquí
      });
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reporte enviado con éxito')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar el reporte: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Reporte de Incidente'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- IMÁGENES DEL REPORTE ---
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Imágenes del reporte', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Seleccionar imágenes'),
                            onPressed: _imagenesSeleccionadas.length >= _maxImagenes ? null : _seleccionarImagenes,
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text('${_imagenesSeleccionadas.length}/$_maxImagenes'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 80,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _imagenesSeleccionadas.length,
                          itemBuilder: (context, index) => Stack(
                            alignment: Alignment.topRight,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(_imagenesSeleccionadas[index], height: 70, width: 70, fit: BoxFit.cover),
                              ),
                              IconButton(
                                icon: const Icon(Icons.cancel, color: Colors.red, size: 20),
                                onPressed: () {
                                  setState(() {
                                    _imagenesSeleccionadas.removeAt(index);
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // --- UBICACIÓN ---
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Ubicación del incidente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _interseccionesController,
                        decoration: InputDecoration(
                          labelText: 'Intersecciones',
                          hintText: 'Ej: Av. Pajaritos con El Rosal',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.location_on_outlined),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Campo obligatorio' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _direccionController,
                        decoration: InputDecoration(
                          labelText: 'Dirección exacta',
                          hintText: 'Ej: Av. Pajaritos 1234',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.home_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.gps_fixed),
                        label: const Text('Usar mi ubicación actual'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade50,
                          foregroundColor: Colors.blue.shade900,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          var permission = await Geolocator.checkPermission();
                          if (!mounted) return;
                          if (permission == LocationPermission.denied) {
                            permission = await Geolocator.requestPermission();
                            if (!mounted) return;
                            if (permission == LocationPermission.denied) {
                              messenger.showSnackBar(
                                const SnackBar(content: Text('Permiso de ubicación denegado')),
                              );
                              return;
                            }
                          }
                          if (permission == LocationPermission.deniedForever) {
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Permiso de ubicación denegado permanentemente')),
                            );
                            return;
                          }
                          final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
                          if (!mounted) return;
                          setState(() {
                            _direccionController.text = '${position.latitude}, ${position.longitude}';
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // --- TIPO Y DESCRIPCIÓN ---
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tipo de incidente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        isExpanded: true, // <-- Solución al overflow
                        value: _tipoIncidente,
                        decoration: InputDecoration(
                          labelText: 'Selecciona tipo de incidente',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.warning_amber_rounded),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'VIF', child: Text('VIF')),
                          DropdownMenuItem(value: 'ACCIDENTE VEHICULAR', child: Text('ACCIDENTE VEHICULAR')),
                          DropdownMenuItem(value: 'ACCIDENTE PERSONA', child: Text('ACCIDENTE PERSONA')),
                          DropdownMenuItem(value: 'RIÑA', child: Text('RIÑA')),
                          DropdownMenuItem(value: 'INCENDIO ESTRUCTURAL', child: Text('INCENDIO ESTRUCTURAL')),
                          DropdownMenuItem(value: 'INCENDIO FORESTAL', child: Text('INCENDIO FORESTAL')),
                          DropdownMenuItem(value: 'DERRAME DE SUSTANCIAS PELIGROSAS', child: Text('DERRAME DE SUSTANCIAS PELIGROSAS')),
                          DropdownMenuItem(value: 'RUIDOS MOLESTOS', child: Text('RUIDOS MOLESTOS')),
                          DropdownMenuItem(value: 'FISCALIZACIÓN VEHICULAR', child: Text('FISCALIZACIÓN VEHICULAR')),
                          DropdownMenuItem(value: 'FISCALIZACIÓN COMERCIO ILEGAL', child: Text('FISCALIZACIÓN COMERCIO ILEGAL')),
                          DropdownMenuItem(value: 'ROBO', child: Text('ROBO')),
                          DropdownMenuItem(value: 'OTROS', child: Text('OTROS')),
                        ],
                        onChanged: (v) => setState(() => _tipoIncidente = v),
                        validator: (v) => v == null || v.isEmpty ? 'Selecciona un tipo' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descripcionController,
                        minLines: 3,
                        maxLines: 6,
                        decoration: InputDecoration(
                          labelText: 'Descripción',
                          hintText: 'Describa lo ocurrido con el mayor detalle posible...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.description_outlined),
                        ),
                        validator: (v) => v == null || v.trim().length < 10
                            ? 'Mínimo 10 caracteres'
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // --- DATOS DE LA PERSONA ---
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Datos de la persona que llamó o involucrado', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nombrePersonaController,
                        decoration: InputDecoration(
                          labelText: 'Nombre',
                          hintText: 'Nombre de la persona',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _rutPersonaController,
                        decoration: InputDecoration(
                          labelText: 'RUT',
                          hintText: 'Ej: 12.345.678-0',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.badge_outlined),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // --- FECHA Y HORA ---
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Fecha y hora del incidente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(_fecha == null
                                ? 'Fecha: no seleccionada'
                                : 'Fecha: ${_fecha!.day}/${_fecha!.month}/${_fecha!.year}'),
                          ),
                          TextButton(
                            onPressed: _seleccionarFecha,
                            child: const Text('Cambiar'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(_hora == null
                                ? 'Hora: no seleccionada'
                                : 'Hora: ${_hora!.format(context)}'),
                          ),
                          TextButton(
                            onPressed: _seleccionarHora,
                            child: const Text('Cambiar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // --- RESPONSABLE DEL REPORTE ---
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Datos del responsable del reporte', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text('Nombre del patrullero:', style: TextStyle(fontWeight: FontWeight.w500)),
                          const SizedBox(width: 8),
                          Text(
                            _nombrePatrullero ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color.fromARGB(255, 3, 20, 70),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _movilController,
                        decoration: InputDecoration(
                          labelText: 'Móvil o vehículo (Nro de móvil)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.directions_car_filled_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _turno,
                        decoration: InputDecoration(
                          labelText: 'Turno / jornada',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.access_time),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Día', child: Text('Día')),
                          DropdownMenuItem(value: 'Tarde', child: Text('Tarde')),
                          DropdownMenuItem(value: 'Noche', child: Text('Noche')),
                        ],
                        onChanged: (v) => setState(() => _turno = v),
                        validator: (v) => v == null || v.isEmpty ? 'Selecciona un turno/jornada' : null,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // --- BOTÓN ENVIAR ---
              Center(
                child: ElevatedButton(
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) return;

                    if (_fecha == null || _hora == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Debes seleccionar fecha y hora del incidente')),
                      );
                      return;
                    }
                    if (_turno == null || _turno!.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Debes seleccionar el turno/jornada')),
                      );
                      return;
                    }

                    // Solo aquí muestra el popup de carga
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => const Center(child: CircularProgressIndicator()),
                    );
                    await _guardarReporte();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Color.fromARGB(237, 45, 69, 144),
                    side: const BorderSide(color: Color.fromARGB(255, 3, 20, 70), width: 2.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                  ),
                  child: const Text('Enviar reporte'),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}