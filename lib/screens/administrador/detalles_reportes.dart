import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DetallesReportesScreen extends StatelessWidget {
  final Map<String, dynamic> reporte;

  const DetallesReportesScreen({super.key, required this.reporte});

  Widget _campoDetalle(String label, String value, {IconData? icon}) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Color.fromARGB(255, 3, 20, 70)),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontSize: 15, color: Colors.black87)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fecha = reporte['fecha'] != null
        ? (reporte['fecha'] as Timestamp).toDate()
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del reporte')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // Evidencia (carrusel de imágenes)
            if (reporte['imagenes'] != null && reporte['imagenes'] is List && (reporte['imagenes'] as List).isNotEmpty)
              Card( 
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.photo_library, color: Color.fromARGB(255, 3, 20, 70)),
                          SizedBox(width: 8),
                          Text(
                            'Evidencia',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 120,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: (reporte['imagenes'] as List)
                              .where((url) => url != null && url is String && url.isNotEmpty)
                              .map<Widget>((url) => Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.network(
                                        url,
                                        height: 100,
                                        width: 100,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          color: Colors.grey[200],
                                          width: 100,
                                          height: 100,
                                          child: const Icon(Icons.broken_image, size: 40, color: Colors.red),
                                        ),
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 10),
            _campoDetalle('Tipo de incidente', reporte['tipo_incidente'] ?? '', icon: Icons.warning_amber_rounded),
            _campoDetalle('Patrullero', reporte['nombre_patrullero'] ?? '', icon: Icons.person),
            _campoDetalle(
              'Fecha',
              fecha != null
                  ? "${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year} ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}"
                  : '',
              icon: Icons.calendar_today,
            ),
            _campoDetalle('Descripción', reporte['descripcion'] ?? '', icon: Icons.description_outlined),
            _campoDetalle('Dirección', reporte['direccion'] ?? '', icon: Icons.location_on_outlined),
            _campoDetalle('Intersecciones', reporte['intersecciones'] ?? '', icon: Icons.alt_route),
            _campoDetalle('Persona', reporte['nombre_persona'] ?? '', icon: Icons.account_circle_outlined),
            _campoDetalle('RUT', reporte['rut_persona'] ?? '', icon: Icons.badge_outlined),
            _campoDetalle('Móvil', reporte['movil'] ?? '', icon: Icons.directions_car_filled_outlined),
            _campoDetalle('Turno', reporte['turno'] ?? '', icon: Icons.access_time),
          ],
        ),
      ),
    );
  }
}