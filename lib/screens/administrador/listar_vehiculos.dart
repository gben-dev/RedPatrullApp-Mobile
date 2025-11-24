import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ListarVehiculosScreen extends StatelessWidget {
	const ListarVehiculosScreen({super.key});

	void _editar(BuildContext context, DocumentReference ref, Map<String, dynamic> data) {
		final movilCtrl = TextEditingController(text: data['movil']?.toString() ?? '');
		final kmCtrl = TextEditingController(text: data['km_prox_mant']?.toString() ?? '');
		final formKey = GlobalKey<FormState>();

		showDialog(
			context: context,
			builder: (ctx) => AlertDialog(
				title: const Text('Editar Vehículo'),
				content: Form(
					key: formKey,
					child: Column(
						mainAxisSize: MainAxisSize.min,
						children: [
							TextFormField(
								controller: movilCtrl,
								decoration: const InputDecoration(labelText: 'Móvil'),
								validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa móvil' : null,
							),
							TextFormField(
								controller: kmCtrl,
								decoration: const InputDecoration(labelText: 'KM próximo mantención'),
								keyboardType: TextInputType.number,
								validator: (v) {
									if (v == null || v.trim().isEmpty) return 'Ingresa km';
									if (int.tryParse(v.trim()) == null) return 'Debe ser numérico';
									return null;
								},
							),
						],
					),
				),
				actions: [
					TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
					ElevatedButton(
						onPressed: () async {
							if (!formKey.currentState!.validate()) return;
							try {
								await ref.update({
									'movil': movilCtrl.text.trim(),
									'km_prox_mant': kmCtrl.text.trim(),
									'updated_at': FieldValue.serverTimestamp(),
								});
								if (ctx.mounted) Navigator.pop(ctx);
								ScaffoldMessenger.of(context).showSnackBar(
									const SnackBar(content: Text('Vehículo actualizado')),
								);
							} catch (e) {
								ScaffoldMessenger.of(context).showSnackBar(
									SnackBar(content: Text('Error al actualizar: $e')),
								);
							}
						},
						child: const Text('Guardar'),
					),
				],
			),
		);
	}

	void _eliminar(BuildContext context, DocumentReference ref, String patente) {
		showDialog(
			context: context,
			builder: (ctx) => AlertDialog(
				title: const Text('Eliminar Vehículo'),
				content: Text('¿Seguro que deseas eliminar el vehículo de patente $patente?'),
				actions: [
					TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
					ElevatedButton(
						style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
						onPressed: () async {
							try {
								await ref.delete();
								if (ctx.mounted) Navigator.pop(ctx);
								ScaffoldMessenger.of(context).showSnackBar(
									const SnackBar(content: Text('Vehículo eliminado')),
								);
							} catch (e) {
								ScaffoldMessenger.of(context).showSnackBar(
									SnackBar(content: Text('Error al eliminar: $e')),
								);
							}
						},
						child: const Text('Eliminar'),
					),
				],
			),
		);
	}

	Widget _cardVehiculo(BuildContext context, DocumentSnapshot doc) {
		final data = doc.data() as Map<String, dynamic>;
		final patente = (data['patente'] ?? '').toString();
		final movil = (data['movil'] ?? '').toString();
		final kmMant = (data['km_prox_mant'] ?? '').toString();

		return Card(
			elevation: 2,
			margin: const EdgeInsets.symmetric(vertical: 8),
			shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
			child: Padding(
				padding: const EdgeInsets.all(14),
				child: Row(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						ClipRRect(
							borderRadius: BorderRadius.circular(10),
							child: Container(
								color: Colors.grey[200],
								width: 90,
								height: 90,
								alignment: Alignment.center,
								child: const Icon(Icons.directions_car, size: 40, color: Color.fromARGB(255, 3, 20, 70)),
							),
						),
						const SizedBox(width: 16),
						Expanded(
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									_filaDato('PATENTE', patente, icon: Icons.confirmation_number_outlined),
									_filaDato('MÓVIL', movil, icon: Icons.local_shipping_outlined),
									_filaDato('KM MANTENCIÓN', kmMant, icon: Icons.build_circle_outlined),
									const SizedBox(height: 8),
									Row(
										children: [
											TextButton.icon(
												onPressed: () => _editar(context, doc.reference, data),
												icon: const Icon(Icons.edit, size: 18),
												label: const Text('Editar'),
											),
											const SizedBox(width: 8),
											TextButton.icon(
												onPressed: () => _eliminar(context, doc.reference, patente),
												icon: const Icon(Icons.delete, size: 18, color: Colors.red),
												label: const Text('Eliminar', style: TextStyle(color: Colors.red)),
											),
										],
									),
								],
							),
						),
					],
				),
			),
		);
	}

	Widget _filaDato(String label, String value, {IconData? icon}) {
		return Padding(
			padding: const EdgeInsets.only(bottom: 6),
			child: Row(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					if (icon != null) ...[
						Icon(icon, size: 20, color: const Color.fromARGB(255, 3, 20, 70)),
						const SizedBox(width: 8),
					],
					Expanded(
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
								const SizedBox(height: 2),
								Text(value.isEmpty ? '-' : value, style: const TextStyle(fontSize: 14, color: Colors.black87)),
							],
						),
					),
				],
			),
		);
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text('Vehículos'),
			),
			body: Padding(
				padding: const EdgeInsets.all(16),
				child: StreamBuilder<QuerySnapshot>(
					stream: FirebaseFirestore.instance
							.collection('vehiculos_pat')
							.orderBy('created_at', descending: true)
							.snapshots(),
					builder: (context, snapshot) {
						if (snapshot.connectionState == ConnectionState.waiting) {
							return const Center(child: CircularProgressIndicator());
						}
						if (snapshot.hasError) {
							return Center(child: Text('Error: ${snapshot.error}'));
						}
						final docs = snapshot.data?.docs ?? [];
						if (docs.isEmpty) {
							return const Center(child: Text('No hay vehículos registrados'));
						}
						return ListView.builder(
							itemCount: docs.length,
							itemBuilder: (context, index) => _cardVehiculo(context, docs[index]),
						);
					},
				),
			),
			floatingActionButton: FloatingActionButton(
				onPressed: () => Navigator.of(context).pushNamed('/agregar_vehiculo'),
				child: const Icon(Icons.add),
			),
		);
	}
}

