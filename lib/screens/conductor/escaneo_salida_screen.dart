import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'registro_salida_page.dart';

class EscaneoSalidaScreen extends StatefulWidget {
	const EscaneoSalidaScreen({super.key});

	@override
	State<EscaneoSalidaScreen> createState() => _EscaneoSalidaScreenState();
}

class _EscaneoSalidaScreenState extends State<EscaneoSalidaScreen> {
	CameraController? _cameraController;
	bool _procesando = false;
	String? _errorCamara;

	@override
	void initState() {
		super.initState();
		_inicializarCamara();
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
		if (controller == null || !controller.value.isInitialized || _procesando) {
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
					builder: (_) => RegistroSalidaPage(
						args: RegistroSalidaArgs(
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
			appBar: AppBar(title: const Text('Escanear salida')),
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
				onPressed: _procesando ? null : _capturarYProcesar,
				icon: const Icon(Icons.camera_alt),
				label: const Text('Capturar'),
			),
		);
	}
}
