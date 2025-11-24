import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VerReportesScreen extends StatefulWidget {
  const VerReportesScreen({super.key});

  @override
  State<VerReportesScreen> createState() => _VerReportesScreenState();
}

class _VerReportesScreenState extends State<VerReportesScreen> {
  String? filtroPatrullero;
  DateTime? filtroFecha;
  String? filtroTipoIncidente;

  final List<String> tiposIncidente = [
    'VIF',
    'ACCIDENTE VEHICULAR',
    'ACCIDENTE PERSONA',
    'RIÑA',
    'INCENDIO ESTRUCTURAL',
    'INCENDIO FORESTAL',
    'DERRAME DE SUSTANCIAS PELIGROSAS',
    'RUIDOS MOLESTOS',
    'FISCALIZACIÓN VEHICULAR',
    'FISCALIZACIÓN COMERCIO ILEGAL',
    'ROBO',
    'OTROS',
  ];

  Future<List<QueryDocumentSnapshot>> _getReportes() async {
    Query query = FirebaseFirestore.instance.collection('reportes');

    if (filtroPatrullero != null && filtroPatrullero!.isNotEmpty) {
      query = query.where('nombre_patrullero', isEqualTo: filtroPatrullero);
    }
    if (filtroFecha != null) {
      query = query.where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(filtroFecha!));
    }
    if (filtroTipoIncidente != null && filtroTipoIncidente!.isNotEmpty) {
      query = query.where('tipo_incidente', isEqualTo: filtroTipoIncidente);
    }

    final snapshot = await query.orderBy('fecha_creacion', descending: true).get();
    return snapshot.docs;
  }

  Future<List<String>> _getNombresPatrulleros() async {
    final snapshot = await FirebaseFirestore.instance.collection('usuarios').get();
    return snapshot.docs
        .map((doc) => doc.data()['nombre'] as String? ?? '')
        .where((nombre) => nombre.isNotEmpty)
        .toList();
  }

  void _mostrarFiltros() async {
    String? patrullero = filtroPatrullero;
    DateTime? fecha = filtroFecha;
    String? tipoIncidente = filtroTipoIncidente;

    await showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FutureBuilder<List<String>>(
                future: _getNombresPatrulleros(),
                builder: (context, snapshot) {
                  final patrulleros = snapshot.data ?? [];
                  return DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: patrullero != null && patrulleros.contains(patrullero) ? patrullero : null,
                    decoration: const InputDecoration(labelText: 'Patrullero'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Todos')),
                      ...patrulleros.map((nombre) => DropdownMenuItem(value: nombre, child: Text(nombre))),
                    ],
                    onChanged: (v) => patrullero = v,
                  );
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: tipoIncidente != null && tiposIncidente.contains(tipoIncidente) ? tipoIncidente : null,
                decoration: const InputDecoration(labelText: 'Tipo de incidente'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todos')),
                  ...tiposIncidente.map((tipo) => DropdownMenuItem(value: tipo, child: Text(tipo))),
                ],
                onChanged: (v) => tipoIncidente = v,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      fecha == null
                        ? 'Fecha: no seleccionada'
                        : 'Fecha: ${fecha!.day}/${fecha!.month}/${fecha!.year}'
                    ),
                  ),
                  TextButton(
                    child: const Text('Seleccionar fecha'),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: fecha ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (!context.mounted) return;
                      if (picked != null) {
                        if (!mounted) return;
                        fecha = picked;
                        Navigator.pop(context);
                        _mostrarFiltros();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                child: const Text('Aplicar filtros'),
                onPressed: () {
                  setState(() {
                    filtroPatrullero = patrullero;
                    filtroFecha = fecha;
                    filtroTipoIncidente = tipoIncidente;
                  });
                  Navigator.pop(context);
                },
              ),
              TextButton(
                child: const Text('Limpiar filtros'),
                onPressed: () {
                  setState(() {
                    filtroPatrullero = null;
                    filtroFecha = null;
                    filtroTipoIncidente = null;
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes creados'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filtrar',
            onPressed: _mostrarFiltros,
          ),
        ],
      ),
      body: FutureBuilder<List<QueryDocumentSnapshot>>(
        future: _getReportes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay reportes.'));
          }
          final reportes = snapshot.data!;
          return ListView.builder(
            itemCount: reportes.length,
            itemBuilder: (context, index) {
              final reporte = reportes[index].data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/detalles_reporte',
                      arguments: {'reporte': reporte},
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Carrusel de imágenes
                        if (reporte['imagenes'] != null && reporte['imagenes'] is List && (reporte['imagenes'] as List).isNotEmpty)
                          SizedBox(
                            height: 120,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: (reporte['imagenes'] as List)
                                  .where((url) => url != null && url is String && url.isNotEmpty)
                                  .map<Widget>((url) => ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          url,
                                          height: 110,
                                          width: 110,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Container(
                                            color: Colors.grey[200],
                                            width: 110,
                                            height: 110,
                                            child: const Icon(Icons.broken_image, size: 40, color: Colors.red),
                                          ),
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.deepOrange.shade400),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                reporte['tipo_incidente']?.toString().toUpperCase() ?? 'SIN TIPO',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                reporte['nombre_patrullero'] ?? 'Sin nombre',
                                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.blue),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 18, color: Colors.grey[600]),
                            const SizedBox(width: 6),
                            Text(
                              reporte['fecha'] != null
                                  ? (reporte['fecha'] as Timestamp).toDate().toString().substring(0, 16)
                                  : 'Sin fecha',
                              style: TextStyle(color: Colors.grey[700], fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          reporte['descripcion'] ?? '',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}