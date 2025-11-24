import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class TurnoConductorActivo {
	const TurnoConductorActivo({required this.id, required this.data});

	final String id;
	final Map<String, dynamic> data;

	double? get kmSalida {
		final bruto = data['km_salida'];
		if (bruto is num) return bruto.toDouble();
		if (bruto is String) return double.tryParse(bruto);
		return null;
	}

	String? get nombreConductor => data['nombre_conductor'] as String?;
	String? get nombrePatrullero => data['nombre_patrullero'] as String?;
	String? get movil => data['movil'] as String?;
	String? get idConductor => data['id_conductor'] as String?;
	DateTime? get horaSalida {
		final ts = data['hora_salida'];
		if (ts is Timestamp) return ts.toDate();
		if (ts is DateTime) return ts;
		return null;
	}
}

class RegistroLlegadaArgs {
	const RegistroLlegadaArgs({
		required this.turno,
		required this.imageFile,
		required this.rawText,
		required this.kmDetectado,
	});

	final TurnoConductorActivo turno;
	final File imageFile;
	final String rawText;
	final double? kmDetectado;
}

class RegistroLlegadaPage extends StatefulWidget {
	const RegistroLlegadaPage({super.key, required this.args});

	final RegistroLlegadaArgs args;

	@override
	State<RegistroLlegadaPage> createState() => _RegistroLlegadaPageState();
}

class _RegistroLlegadaPageState extends State<RegistroLlegadaPage> {
	late final DateTime _horaLlegada;
	late final double? _kmLlegadaDetectado;
	late final TextEditingController _kmLlegadaCtrl;

	bool _guardando = false;

	@override
	void initState() {
		super.initState();
		_horaLlegada = DateTime.now();
		_kmLlegadaDetectado = widget.args.kmDetectado;
		final kmInicial = _kmLlegadaDetectado;
		_kmLlegadaCtrl = TextEditingController(
			text: kmInicial == null
					? ''
					: (kmInicial % 1 == 0
							? kmInicial.toStringAsFixed(0)
							: kmInicial.toStringAsFixed(1)),
		);
		_kmLlegadaCtrl.addListener(_onKilometrajeChange);
	}

	@override
	void dispose() {
		_kmLlegadaCtrl.removeListener(_onKilometrajeChange);
		_kmLlegadaCtrl.dispose();
		super.dispose();
	}

	void _onKilometrajeChange() {
		if (!mounted) return;
		setState(() {});
	}

	double? _obtenerKilometrajeLlegada() {
		var texto = _kmLlegadaCtrl.text.trim();
		if (texto.isEmpty) return null;
		texto = texto.replaceAll(' ', '').replaceAll(',', '.');
		texto = texto.replaceAll(RegExp(r'(?<=\d)\.(?=\d{3}(\D|$))'), '');
		return double.tryParse(texto);
	}

	Future<void> _registrarLlegada() async {
		if (_guardando) return;
		final turno = widget.args.turno;
		final kmSalida = (turno.kmSalida ?? 0).toInt();
		final kmLlegadaDouble = _obtenerKilometrajeLlegada();
		final kmLlegada = kmLlegadaDouble?.round();

		if (kmLlegada == null) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('No se detectó el kilometraje de llegada. Intenta nuevamente.')),
			);
			return;
		}

		if (kmLlegada < kmSalida) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('El kilometraje de llegada no puede ser menor al de salida.')),
			);
			return;
		}

		setState(() => _guardando = true);
		try {
			final fotoUrl = await _subirImagenACloudinary(widget.args.imageFile);
			if (fotoUrl == null) {
				if (!mounted) return;
				setState(() => _guardando = false);
				ScaffoldMessenger.of(context).showSnackBar(
					const SnackBar(content: Text('No se pudo subir la imagen. Intenta nuevamente.')),
				);
				return;
			}

			// Encontrar vehículo por móvil del turno
			final movilTurno = (turno.movil ?? '').replaceAll(RegExp(r'\D'), '');
			final vehQuery = await FirebaseFirestore.instance
					.collection('vehiculos_pat')
					.where('movil', isEqualTo: movilTurno)
					.limit(1)
					.get();
			if (vehQuery.docs.isEmpty) {
				throw 'No se encontró el vehículo asociado al móvil: ${turno.movil ?? ''}';
			}
			final vehRef = vehQuery.docs.first.reference;
			final turnoRef = FirebaseFirestore.instance.collection('turnos_conductores').doc(turno.id);

			await FirebaseFirestore.instance.runTransaction((tx) async {
				final vehSnap = await tx.get(vehRef);
				final dataVeh = vehSnap.data() ?? <String, dynamic>{};
				final kmActual = _asInt(dataVeh['km_actual']) ?? 0;
				final kmProxMant = _asInt(dataVeh['km_prox_mant']);

				final kmRecorridos = kmLlegada - kmSalida;
				final nuevoKmActual = kmActual + kmRecorridos;
				final bool mantPend = kmProxMant != null && nuevoKmActual >= (kmProxMant - 500);

				tx.update(turnoRef, {
					'estado': 'finalizado',
					'hora_llegada': Timestamp.fromDate(_horaLlegada),
					'km_llegada': kmLlegada,
					'km_recorridos': kmRecorridos,
					'foto_km_llegada': fotoUrl,
				});

				tx.update(vehRef, {
					'km_actual': nuevoKmActual,
					if (mantPend) 'mantencion_pendiente': true,
				});
			});

			if (!mounted) return;
			Navigator.of(context).pop(true);
		} catch (e) {
			if (!mounted) return;
			setState(() => _guardando = false);
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text('Error al registrar la llegada: $e')),
			);
		}
	}

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

	Future<String?> _subirImagenACloudinary(File imagen) async {
		const cloudName = 'dwhdt3z1g';
		const uploadPreset = 'upload_images_undigned';

		final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
		final request = http.MultipartRequest('POST', url)
			..fields['upload_preset'] = uploadPreset
			..files.add(await http.MultipartFile.fromPath('file', imagen.path));

		final response = await request.send();
		final res = await http.Response.fromStream(response);

		if (res.statusCode == 200) {
			final data = jsonDecode(res.body) as Map<String, dynamic>;
			return data['secure_url'] as String?;
		} else {
			debugPrint('Fallo subida Cloudinary: ${res.statusCode} ${res.body}');
			return null;
		}
	}

	String _formatearFechaHora(DateTime? fecha) {
		if (fecha == null) return 'Sin dato';
		String dosDigitos(int v) => v.toString().padLeft(2, '0');
		return '${dosDigitos(fecha.day)}/${dosDigitos(fecha.month)}/${fecha.year}  '
				'${dosDigitos(fecha.hour)}:${dosDigitos(fecha.minute)}';
	}

	String _formatearKilometraje(double? valor) {
		if (valor == null) return 'Sin lectura';
		final esEntero = valor % 1 == 0;
		return esEntero ? valor.toStringAsFixed(0) : valor.toStringAsFixed(1);
	}

	Widget _buildDato(String titulo, String valor, {IconData? icono}) {
		return Padding(
			padding: const EdgeInsets.only(bottom: 12),
			child: ListTile(
				tileColor: Colors.grey.shade100,
				shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
				leading: icono != null ? Icon(icono, color: const Color.fromARGB(237, 45, 69, 144)) : null,
				title: Text(
					titulo,
					style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
				),
				subtitle: Text(
					valor.isEmpty ? '—' : valor,
					style: const TextStyle(fontSize: 16),
				),
			),
		);
	}

	@override
	Widget build(BuildContext context) {
		final turno = widget.args.turno;
		final puedeGuardar = !_guardando && _obtenerKilometrajeLlegada() != null;

		return Scaffold(
			appBar: AppBar(title: const Text('Registrar llegada')),
			body: SingleChildScrollView(
				padding: const EdgeInsets.all(16),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						ClipRRect(
							borderRadius: BorderRadius.circular(12),
							child: Image.file(
								widget.args.imageFile,
								height: 220,
								width: double.infinity,
								fit: BoxFit.cover,
							),
						),
						const SizedBox(height: 16),
						_buildDato('Kilometraje salida', _formatearKilometraje(turno.kmSalida),
								icono: Icons.speed),
						TextField(
							controller: _kmLlegadaCtrl,
							keyboardType: const TextInputType.numberWithOptions(decimal: true),
							decoration: const InputDecoration(
								labelText: 'Kilometraje llegada',
								suffixText: 'km',
							),
							enabled: !_guardando,
						),
						const SizedBox(height: 12),
						_buildDato('Hora salida', _formatearFechaHora(turno.horaSalida),
								icono: Icons.access_time),
						_buildDato('Hora llegada', _formatearFechaHora(_horaLlegada),
								icono: Icons.timer),
						_buildDato('Móvil asignado', turno.movil ?? '', icono: Icons.local_taxi),
						_buildDato('Conductor', turno.nombreConductor ?? '', icono: Icons.person),
						_buildDato('Patrullero citado', turno.nombrePatrullero ?? '', icono: Icons.group),
						const SizedBox(height: 12),
						ExpansionTile(
							title: const Text('Ver texto crudo del OCR'),
							children: [
								Container(
									width: double.infinity,
									padding: const EdgeInsets.all(12),
									decoration: BoxDecoration(
										color: Colors.grey.shade200,
										borderRadius: BorderRadius.circular(8),
									),
									child: Text(
										widget.args.rawText.isEmpty
												? 'No se obtuvo texto durante el escaneo.'
												: widget.args.rawText,
										style: const TextStyle(fontSize: 12),
									),
								),
							],
						),
						const SizedBox(height: 24),
						SizedBox(
							width: double.infinity,
							child: ElevatedButton.icon(
								onPressed: puedeGuardar ? _registrarLlegada : null,
								icon: _guardando
										? const SizedBox(
												width: 20,
												height: 20,
												child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
											)
										: const Icon(Icons.check_circle_outline),
								label: Text(_guardando ? 'Guardando...' : 'Registrar Llegada'),
							),
						),
						const SizedBox(height: 12),
						TextButton.icon(
							onPressed: _guardando ? null : () => Navigator.of(context).pop(false),
							icon: const Icon(Icons.camera_alt_outlined),
							label: const Text('Volver a escanear'),
						),
					],
				),
			),
		);
	}
}
