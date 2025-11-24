import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class RegistroSalidaArgs {
	const RegistroSalidaArgs({
		required this.imageFile,
		required this.rawText,
		required this.kmDetectado,
	});

	final File imageFile;
	final String rawText;
	final double? kmDetectado;
}

class _PatrulleroOpcion {
	const _PatrulleroOpcion({required this.id, required this.nombre});

	final String id;
	final String nombre;
}

class RegistroSalidaPage extends StatefulWidget {
	const RegistroSalidaPage({super.key, required this.args});

	final RegistroSalidaArgs args;

	@override
	State<RegistroSalidaPage> createState() => _RegistroSalidaPageState();
}


class _RegistroSalidaPageState extends State<RegistroSalidaPage> {
	late final DateTime _horaSalida;
	late final double? _kmSalidaDetectado;

	late final TextEditingController _kmSalidaCtrl;

	bool _cargandoUsuario = true;
	bool _guardando = false;
	String? _errorCarga;

		String? _uidConductor;
		String? _nombreConductor;
		final List<String> _movilesDisponibles = <String>[]; // Cargados desde Firestore
		bool _cargandoMoviles = true;
		String? _errorMoviles;
		String? _movilSeleccionado;
		String? _movilPreferidoUsuario; // valor sugerido desde el perfil del usuario
	final List<_PatrulleroOpcion> _patrulleros = [];
	bool _cargandoPatrulleros = true;
	String? _errorPatrulleros;
	String? _patrulleroSeleccionadoId;
	String? _nombrePatrulleroAsignado;
  String? _empresaUsuario;

	@override
	void initState() {
		super.initState();
		_horaSalida = DateTime.now();
		_kmSalidaDetectado = widget.args.kmDetectado;
		_kmSalidaCtrl = TextEditingController(
			text: _kmSalidaDetectado == null ? '' : _formatearKilometraje(_kmSalidaDetectado),
		);
			_cargarDatosConductor();
			_cargarPatrulleros();
			_cargarMoviles();
	}

	@override
	void dispose() {
		_kmSalidaCtrl.dispose();
		super.dispose();
	}

		String? _extraerCodigoMovilPreferido(String? valor) {
			if (valor == null || valor.isEmpty) return null;
			// Coincidencia exacta
			if (_movilesDisponibles.contains(valor)) return valor;
			// Extraer dígitos del string (e.g., "MOVIL 10" -> "10")
			final m = RegExp(r'\d+').firstMatch(valor);
			final digits = m?.group(0);
			if (digits != null && _movilesDisponibles.contains(digits)) return digits;
			return null;
		}

	Future<void> _cargarDatosConductor() async {
		setState(() {
			_cargandoUsuario = true;
			_errorCarga = null;
		});
		try {
			final user = FirebaseAuth.instance.currentUser;
			if (user == null) {
				setState(() {
					_errorCarga = 'Sesión no válida.';
					_cargandoUsuario = false;
				});
				return;
			}

			final doc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
			final data = doc.data() ?? <String, dynamic>{};
			if (!mounted) return;
					final movilCrudo = (data['movil'] ?? data['movil_asignado']) as String? ?? '';
					_empresaUsuario = (data['empresa'] as String?)?.trim();
			final patrullero =
					(data['nombre_patrullero'] ?? data['patrullero_asignado']) as String? ?? '';
					// Guardamos la preferencia; la selección final se hará cuando tengamos la lista de móviles
					_movilPreferidoUsuario = movilCrudo;
			setState(() {
				_uidConductor = user.uid;
				_nombreConductor = data['nombre'] as String? ?? user.displayName ?? 'Conductor';
				_nombrePatrulleroAsignado = patrullero;
				_cargandoUsuario = false;
			});
					_preseleccionarPatrullero();
					_preseleccionarMovil();
		} catch (e) {
			if (!mounted) return;
			setState(() {
				_errorCarga = 'No se pudo cargar la información del conductor.';
				_cargandoUsuario = false;
			});
			debugPrint('Error cargando datos del conductor: $e');
		}

	}

			Future<void> _cargarMoviles() async {
				setState(() {
					_cargandoMoviles = true;
					_errorMoviles = null;
				});
				try {
					// 1) Cargar móviles desde vehiculos_pat, filtrando por empresa si está disponible
					Query vehQuery = FirebaseFirestore.instance.collection('vehiculos_pat');
					if (_empresaUsuario != null && _empresaUsuario!.isNotEmpty) {
						vehQuery = vehQuery.where('empresa', isEqualTo: _empresaUsuario);
					}
					final snap = await vehQuery.get();

					// 2) Obtener móviles en ruta para excluirlos
					final enRutaSnap = await FirebaseFirestore.instance
							.collection('turnos_conductores')
							.where('estado', isEqualTo: 'en ruta')
							.get();
					final enRuta = <String>{};
					for (final d in enRutaSnap.docs) {
						final dataTurno = d.data() as Map<String, dynamic>?;
						final movilStr = (dataTurno?['movil']?.toString() ?? '').trim(); // ej: "MOVIL 10"
						final m = RegExp(r'\d+').firstMatch(movilStr);
						final cod = m?.group(0);
						if (cod != null && cod.isNotEmpty) enRuta.add(cod);
					}
					final valores = <String>{};
					for (final d in snap.docs) {
						final data = d.data() as Map<String, dynamic>?;
						final movil = (data?['movil']?.toString() ?? '').trim();
						if (movil.isNotEmpty && !enRuta.contains(movil)) valores.add(movil);
					}
					final lista = valores.toList();
					// Ordenar numéricamente si son números, de lo contrario lexicográfico
					lista.sort((a, b) {
						final ai = int.tryParse(a);
						final bi = int.tryParse(b);
						if (ai != null && bi != null) return ai.compareTo(bi);
						return a.toLowerCase().compareTo(b.toLowerCase());
					});
					if (!mounted) return;
					setState(() {
						_movilesDisponibles
							..clear()
							..addAll(lista);
						_cargandoMoviles = false;
					});
					_preseleccionarMovil();
				} catch (e) {
					if (!mounted) return;
					setState(() {
						_errorMoviles = 'No se pudieron cargar los móviles: $e';
						_cargandoMoviles = false;
					});
				}
			}

			void _preseleccionarMovil() {
				if (_cargandoMoviles || _movilesDisponibles.isEmpty) return;
				final preferido = _extraerCodigoMovilPreferido(_movilPreferidoUsuario);
				setState(() {
					_movilSeleccionado = preferido ?? _movilesDisponibles.first;
				});
			}


	Future<void> _cargarPatrulleros() async {
		setState(() {
			_cargandoPatrulleros = true;
			_errorPatrulleros = null;
		});
		try {
			final resultados = await Future.wait([
				FirebaseFirestore.instance
						.collection('usuarios')
						.where('rol', isEqualTo: 'Patrullero')
						.get(),
				FirebaseFirestore.instance
						.collection('usuarios')
						.where('rol', isEqualTo: 'Inspector')
						.get(),
			]);

			final patron = <_PatrulleroOpcion>[];
			for (final snapshot in resultados) {
				for (final doc in snapshot.docs) {
					final data = doc.data();
					final nombre = (data['nombre'] as String?)?.trim();
					if (nombre == null || nombre.isEmpty) continue;
					patron.add(_PatrulleroOpcion(id: doc.id, nombre: nombre));
				}
			}
			patron.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
			if (!mounted) return;
			setState(() {
				_patrulleros
					..clear()
					..addAll(patron);
				_cargandoPatrulleros = false;
			});
			_preseleccionarPatrullero();
		} catch (e) {
			if (!mounted) return;
			setState(() {
				_errorPatrulleros = 'No se pudieron cargar los patrulleros: $e';
				_cargandoPatrulleros = false;
			});
		}
	}

	void _preseleccionarPatrullero() {
		if (_nombrePatrulleroAsignado == null || _nombrePatrulleroAsignado!.trim().isEmpty) {
			return;
		}
		final nombreBuscado = _nombrePatrulleroAsignado!.trim().toLowerCase();
		for (final opcion in _patrulleros) {
			if (opcion.nombre.trim().toLowerCase() == nombreBuscado) {
				setState(() => _patrulleroSeleccionadoId = opcion.id);
				return;
			}
		}
	}

	_PatrulleroOpcion? _patrulleroSeleccionado() {
		if (_patrulleroSeleccionadoId == null) return null;
		try {
			return _patrulleros.firstWhere((o) => o.id == _patrulleroSeleccionadoId);
		} catch (_) {
			return null;
		}
	}

	Future<void> _registrarSalida() async {
		if (_guardando) return;
		final kmSalidaDouble = _obtenerKilometraje();
		final kmSalida = kmSalidaDouble?.round();
		if (kmSalida == null) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Ingresa un kilometraje de salida válido.')),
			);
			return;
		}
		if (_uidConductor == null) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('No se pudo identificar al conductor.')),
			);
			return;
		}
		if (_movilSeleccionado == null) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Selecciona un móvil asignado.')),
			);
			return;
		}
		final patrulleroSeleccionado = _patrulleroSeleccionado();
		if (patrulleroSeleccionado == null) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Selecciona un patrullero/inspector.')),
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

			await FirebaseFirestore.instance.runTransaction((transaction) async {
				// Crear turno
				final turnoRef = FirebaseFirestore.instance.collection('turnos_conductores').doc();
				transaction.set(turnoRef, {
					'estado': 'en ruta',
					'fecha_creacion': FieldValue.serverTimestamp(),
					'foto_km_salida': fotoUrl,
					'km_salida': kmSalida,
					'hora_salida': Timestamp.fromDate(_horaSalida),
					'id_conductor': _uidConductor,
					'nombre_conductor': _nombreConductor ?? '',
					'movil': 'MOVIL ${_movilSeleccionado!}',
					'nombre_patrullero': patrulleroSeleccionado.nombre,
					'id_patrullero': patrulleroSeleccionado.id,
					'km_recorridos': null,
					'km_llegada': null,
					'foto_km_llegada': null,
					'hora_llegada': null,
				});

				// Actualizar km_actual del vehículo (busca por móvil o necesita mapeo?)
				final vehiculosQuery = await FirebaseFirestore.instance
						.collection('vehiculos_pat')
						.where('movil', isEqualTo: _movilSeleccionado)
						.limit(1)
						.get();
				if (vehiculosQuery.docs.isNotEmpty) {
					final vehiculoDoc = vehiculosQuery.docs.first;
					transaction.update(vehiculoDoc.reference, {
						'km_actual': kmSalida,
					});
				}
			});

			if (!mounted) return;
			Navigator.of(context).pop(true);
		} catch (e) {
			if (!mounted) return;
			setState(() => _guardando = false);
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text('Error al registrar la salida: $e')),
			);
		}
	}

	double? _obtenerKilometraje() {
		final texto = _kmSalidaCtrl.text.trim().replaceAll(',', '.');
		if (texto.isEmpty) return null;
		return double.tryParse(texto);
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

	String _formatearFechaHora(DateTime fecha) {
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
		final puedeGuardar = !_guardando && !_cargandoUsuario && _errorCarga == null &&
			!_cargandoPatrulleros && _errorPatrulleros == null &&
			!_cargandoMoviles && _errorMoviles == null &&
				_obtenerKilometraje() != null &&
				_movilSeleccionado != null &&
				_patrulleroSeleccionadoId != null;

		return Scaffold(
			appBar: AppBar(title: const Text('Registrar salida')),
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
						if (_cargandoUsuario)
							const Center(child: CircularProgressIndicator()),
						if (_errorCarga != null)
							Padding(
								padding: const EdgeInsets.only(bottom: 12),
								child: Text(
									_errorCarga!,
									style: const TextStyle(color: Colors.red),
								),
							),
						TextField(
							controller: _kmSalidaCtrl,
							keyboardType: const TextInputType.numberWithOptions(decimal: true),
							decoration: const InputDecoration(
								labelText: 'Kilometraje salida',
								suffixText: 'km',
							),
							enabled: !_guardando,
						),
						const SizedBox(height: 12),
						_buildDato('Hora salida', _formatearFechaHora(_horaSalida), icono: Icons.access_time),
									const SizedBox(height: 12),
									if (_cargandoMoviles)
										const Center(child: CircularProgressIndicator())
									else if (_errorMoviles != null)
										Padding(
											padding: const EdgeInsets.symmetric(vertical: 8),
											child: Column(
												crossAxisAlignment: CrossAxisAlignment.start,
												children: [
													Text(_errorMoviles!, style: const TextStyle(color: Colors.red)),
													TextButton.icon(
														onPressed: _guardando ? null : _cargarMoviles,
														icon: const Icon(Icons.refresh),
														label: const Text('Reintentar'),
													),
												],
											),
										)
									else if (_movilesDisponibles.isEmpty)
									  Padding(
									    padding: const EdgeInsets.symmetric(vertical: 8),
									    child: Column(
									      crossAxisAlignment: CrossAxisAlignment.start,
									      children: [
									        const Text('No hay móviles disponibles para asignar.', style: TextStyle(color: Colors.black87)),
									        if (_empresaUsuario != null && _empresaUsuario!.isNotEmpty)
									          Text('Empresa: ${_empresaUsuario!}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
									        TextButton.icon(
									          onPressed: _guardando ? null : _cargarMoviles,
									          icon: const Icon(Icons.refresh),
									          label: const Text('Reintentar'),
									        ),
									      ],
									    ),
									  )
									else
										DropdownButtonFormField<String>(
											value: _movilSeleccionado,
											items: _movilesDisponibles
													.map(
														(codigo) => DropdownMenuItem(
															value: codigo,
															child: Text('Móvil $codigo'),
														),
													)
													.toList(),
											decoration: const InputDecoration(labelText: 'Móvil asignado'),
											onChanged: _guardando
													? null
													: (valor) => setState(() => _movilSeleccionado = valor),
										),
						const SizedBox(height: 12),
						if (_cargandoPatrulleros)
							const Center(child: CircularProgressIndicator()),
						if (_errorPatrulleros != null)
							Padding(
								padding: const EdgeInsets.symmetric(vertical: 8),
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										Text(
											_errorPatrulleros!,
											style: const TextStyle(color: Colors.red),
										),
										TextButton.icon(
											onPressed: _guardando ? null : _cargarPatrulleros,
											icon: const Icon(Icons.refresh),
											label: const Text('Reintentar'),
										),
									],
								),
							),
						if (!_cargandoPatrulleros && _errorPatrulleros == null)
							DropdownButtonFormField<String>(
								value: _patrulleroSeleccionadoId != null &&
										_patrulleros.any((o) => o.id == _patrulleroSeleccionadoId)
									? _patrulleroSeleccionadoId
									: null,
								items: _patrulleros
										.map(
											(opcion) => DropdownMenuItem(
												value: opcion.id,
												child: Text(opcion.nombre),
											),
										)
										.toList(),
								decoration: const InputDecoration(labelText: 'Patrullero/Inspector'),
								onChanged: _guardando
										? null
										: (valor) => setState(() => _patrulleroSeleccionadoId = valor),
							),
						const SizedBox(height: 12),
						_buildDato('Conductor', _nombreConductor ?? '', icono: Icons.person),
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
								onPressed: puedeGuardar ? _registrarSalida : null,
								icon: _guardando
										? const SizedBox(
												width: 20,
												height: 20,
												child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
											)
										: const Icon(Icons.check_circle_outline),
								label: Text(_guardando ? 'Guardando...' : 'Registrar Salida'),
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
