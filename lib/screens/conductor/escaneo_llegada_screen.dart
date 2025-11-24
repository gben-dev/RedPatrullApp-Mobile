import 'dart:io';

import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'registro_llegada_page.dart';

class EscaneoLlegadaScreen extends StatefulWidget {
	const EscaneoLlegadaScreen({super.key});

	@override
	State<EscaneoLlegadaScreen> createState() => _EscaneoLlegadaScreenState();
}

class _EscaneoLlegadaScreenState extends State<EscaneoLlegadaScreen> {
	CameraController? _cameraController;
	bool _procesando = false;
	bool _cargandoTurno = true;
	String? _errorCamara;
	String? _infoTurno;
	TurnoConductorActivo? _turnoActivo;

	@override
	void initState() {
		super.initState();
		_cargarTurnoActivo();
		_inicializarCamara();
	}

	Future<void> _cargarTurnoActivo() async {
		setState(() {
			_cargandoTurno = true;
			_infoTurno = null;
		});
		try {
			final user = FirebaseAuth.instance.currentUser;
			if (user == null) {
				setState(() {
					_infoTurno = 'No se encontró sesión activa.';
					_turnoActivo = null;
					_cargandoTurno = false;
				});
				return;
			}

			final query = await FirebaseFirestore.instance
					.collection('turnos_conductores')
					.where('id_conductor', isEqualTo: user.uid)
					.where('estado', isEqualTo: 'en ruta')
					.limit(1)
					.get();

			if (!mounted) return;
			if (query.docs.isEmpty) {
				setState(() {
					_turnoActivo = null;
					_infoTurno = 'No existen turnos en ruta para este conductor.';
					_cargandoTurno = false;
				});
			} else {
				final doc = query.docs.first;
				setState(() {
					_turnoActivo = TurnoConductorActivo(id: doc.id, data: doc.data());
					_cargandoTurno = false;
				});
			}
		} catch (e) {
			if (!mounted) return;
			setState(() {
				_turnoActivo = null;
				_infoTurno = 'No se pudo obtener la información del turno: $e';
				_cargandoTurno = false;
			});
		}
	}

	Future<void> _inicializarCamara() async {
		try {
			final cameras = await availableCameras();
			if (cameras.isEmpty) {
				setState(() => _errorCamara = 'No se encontró cámara disponible.');
				return;
			}
			final camera = cameras.firstWhere(
				(c) => c.lensDirection == CameraLensDirection.back,
				orElse: () => cameras.first,
			);
			final controller = CameraController(camera, ResolutionPreset.high);
			await controller.initialize();
			if (!mounted) {
				controller.dispose();
				return;
			}
			setState(() => _cameraController = controller);
		} catch (e) {
			setState(() => _errorCamara = 'Error al inicializar la cámara: $e');
		}
	}

	@override
	void dispose() {
		_cameraController?.dispose();
		super.dispose();
	}

	Future<void> _capturarYProcesar() async {
		final controller = _cameraController;
		final turno = _turnoActivo;
		if (controller == null || !controller.value.isInitialized || _procesando) {
			return;
		}
		if (turno == null) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Debes contar con una salida activa antes de registrar llegada.')),
			);
			return;
		}

		setState(() => _procesando = true);
		String? rutaCaptura;
		try {
			final captura = await controller.takePicture();
			final ruta = captura.path;
			rutaCaptura = ruta;
			final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
			String textoReconocido;
			try {
				final inputImage = InputImage.fromFilePath(ruta);
				final recognizedText = await textRecognizer.processImage(inputImage);
				textoReconocido = recognizedText.text;
			} finally {
				await textRecognizer.close();
			}

			final kmDetectado = _extraerKilometraje(textoReconocido);

			if (!mounted) return;
			final resultado = await Navigator.of(context).push<bool>(
				MaterialPageRoute(
					builder: (_) => RegistroLlegadaPage(
						args: RegistroLlegadaArgs(
							turno: turno,
							imageFile: File(ruta),
							rawText: textoReconocido,
							kmDetectado: kmDetectado,
						),
					),
				),
			);

			if (!mounted) return;
			if (resultado == true) {
				Navigator.of(context).pop(true);
			} else {
				setState(() => _procesando = false);
			}
		} catch (e) {
			if (!mounted) return;
			setState(() => _procesando = false);
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text('No se pudo procesar la imagen: $e')),
			);
			if (rutaCaptura != null) {
				final file = File(rutaCaptura);
				if (file.existsSync()) {
					file.deleteSync();
				}
			}
		}
	}

	double? _extraerKilometraje(String texto) {
		final normalizado = texto.replaceAll('\n', ' ').replaceAll(',', '.');
		final expresion = RegExp(r'\d+(?:[\.]\d{3})*(?:\.\d+)?');
		double? mejor;

		for (final match in expresion.allMatches(normalizado)) {
			var candidato = match.group(0);
			if (candidato == null) continue;
			final puntos = RegExp(r'\.(?=\d{3}(?:\D|\b))');
			candidato = candidato.replaceAll(puntos, '');
			final valor = double.tryParse(candidato);
			if (valor == null) continue;
			if (valor < 10) continue;
			if (mejor == null || valor > mejor) {
				mejor = valor;
			}
		}

		return mejor;
	}

	@override
	Widget build(BuildContext context) {
		final controller = _cameraController;

		return Scaffold(
			appBar: AppBar(
				title: const Text('Escanear llegada'),
				actions: [
					IconButton(
						icon: const Icon(Icons.refresh),
						tooltip: 'Recargar turno activo',
						onPressed: _cargandoTurno ? null : _cargarTurnoActivo,
					),
				],
			),
			body: Builder(
				builder: (context) {
					if (_errorCamara != null) {
						return Center(
							child: Padding(
								padding: const EdgeInsets.all(16),
								child: Text(
									_errorCamara!,
									textAlign: TextAlign.center,
									style: const TextStyle(color: Colors.red),
								),
							),
						);
					}

					if (controller == null || !controller.value.isInitialized) {
						return const Center(child: CircularProgressIndicator());
					}

					return Stack(
						children: [
							CameraPreview(controller),
							if (_cargandoTurno)
								Container(
									color: Colors.black38,
									child: const Center(child: CircularProgressIndicator()),
								)
							else if (_turnoActivo == null)
								Container(
									color: Colors.black54,
									child: Center(
										child: Padding(
											padding: const EdgeInsets.all(24),
											child: Column(
												mainAxisSize: MainAxisSize.min,
												children: [
													Text(
														_infoTurno ?? 'No hay turno en ruta disponible.',
														textAlign: TextAlign.center,
														style: const TextStyle(color: Colors.white, fontSize: 16),
													),
													const SizedBox(height: 16),
													ElevatedButton.icon(
														onPressed: _cargarTurnoActivo,
														icon: const Icon(Icons.refresh),
														label: const Text('Reintentar'),
													),
												],
											),
										),
									),
								),
							if (_procesando)
								Container(
									color: Colors.black45,
									child: const Center(child: CircularProgressIndicator()),
								),
						],
					);
				},
			),
			floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
							floatingActionButton: FloatingActionButton.extended(
								onPressed:
										_procesando || _turnoActivo == null || _cargandoTurno ? null : _capturarYProcesar,
				icon: const Icon(Icons.camera_alt),
				label: const Text('Capturar'),
			),
		);
	}
}
