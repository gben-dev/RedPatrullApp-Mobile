import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class AgregarVehiculoScreen extends StatefulWidget {
	const AgregarVehiculoScreen({super.key});

	@override
	State<AgregarVehiculoScreen> createState() => _AgregarVehiculoScreenState();
}

class _AgregarVehiculoScreenState extends State<AgregarVehiculoScreen> {
	final _formKey = GlobalKey<FormState>();
	final TextEditingController _patenteController = TextEditingController();
	final TextEditingController _movilController = TextEditingController();
	final TextEditingController _kmMantController = TextEditingController();
	bool _saving = false;

	Future<void> _guardarVehiculo() async {
		if (!_formKey.currentState!.validate()) return;
		setState(() => _saving = true);
		try {
			// Asegura que Firebase esté inicializado (en caso de uso fuera del árbol principal)
			try { Firebase.app(); } catch (_) { await Firebase.initializeApp(); }

			final kmProx = int.tryParse(_kmMantController.text.trim());
			if (kmProx == null) {
				throw 'El kilometraje de mantención debe ser un número entero.';
			}

			await FirebaseFirestore.instance.collection('vehiculos_pat').add({
				'patente': _patenteController.text.trim().toUpperCase(),
				'movil': _movilController.text.trim(),
				'km_prox_mant': kmProx,
				'km_actual': 0,
				'created_at': FieldValue.serverTimestamp(),
			});

			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Vehículo agregado correctamente')),
			);
			Navigator.of(context).pop();
		} catch (e) {
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text('Error al guardar vehículo: $e')),
			);
		} finally {
			if (mounted) setState(() => _saving = false);
		}
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text('Agregar Vehículo'),
				backgroundColor: const Color.fromARGB(237, 255, 255, 255),
				foregroundColor: Colors.black87,
				elevation: 1,
			),
			body: SingleChildScrollView(
				padding: const EdgeInsets.all(16),
				child: Form(
					key: _formKey,
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							TextFormField(
								controller: _patenteController,
								textCapitalization: TextCapitalization.characters,
								decoration: const InputDecoration(labelText: 'Patente (ej: ABCD12)'),
								validator: (v) {
									if (v == null || v.trim().isEmpty) return 'Ingresa la patente';
									if (v.trim().length < 6) return 'Patente inválida';
									return null;
								},
							),
							TextFormField(
								controller: _movilController,
								decoration: const InputDecoration(labelText: 'Móvil'),
								validator: (v) {
									if (v == null || v.trim().isEmpty) return 'Ingresa el número o nombre de móvil';
									return null;
								},
							),
							TextFormField(
								controller: _kmMantController,
								decoration: const InputDecoration(labelText: 'KM próximo mantención'),
								keyboardType: TextInputType.number,
								validator: (v) {
									if (v == null || v.trim().isEmpty) return 'Ingresa km próximo mantención';
									if (int.tryParse(v.trim()) == null) return 'Debe ser numérico';
									return null;
								},
							),
							const SizedBox(height: 24),
							SizedBox(
								width: double.infinity,
								child: ElevatedButton.icon(
									onPressed: _saving ? null : _guardarVehiculo,
									icon: const Icon(Icons.save),
									label: _saving
											? const SizedBox(
													height: 18,
													width: 18,
													child: CircularProgressIndicator(strokeWidth: 2),
												)
											: const Text('Guardar Vehículo'),
								),
							),
						],
					),
				),
			),
		);
	}
}

