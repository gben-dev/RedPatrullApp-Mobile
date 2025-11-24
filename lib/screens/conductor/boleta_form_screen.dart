import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class BoletaData {
  final String? fecha;
  final String? hora;
  final String? patente;
  final String? codigoAutorizacion;
  final String? producto;
  final String? litros;
  final String? precioUnitario;
  final String? iva;
  final String? impuestoEspecifico;
  final String? total;
  final String textoCompleto;

  BoletaData({
    required this.fecha,
    required this.hora,
    required this.patente,
    required this.codigoAutorizacion,
    required this.producto,
    required this.litros,
    required this.precioUnitario,
    required this.iva,
    required this.impuestoEspecifico,
    required this.total,
    required this.textoCompleto,
  });

  Map<String, dynamic> toMap({String? imageUrl, String? uid}) {
    return {
      'fecha': fecha,
      'hora': hora,
      'patente': patente,
      'codigo_autorizacion': codigoAutorizacion,
      'producto': producto,
      'litros': litros,
      'precio_unitario': precioUnitario,
      'iva': iva,
      'impuesto_especifico': impuestoEspecifico,
      'total': total,
      'texto_crudo': textoCompleto,
      'imagen_url': imageUrl,
      'uid_conductor': uid,
      'fecha_creacion': FieldValue.serverTimestamp(),
    };
  }
}

class BoletaFormScreen extends StatefulWidget {
  final BoletaData data;
  final File imageFile;
  const BoletaFormScreen({super.key, required this.data, required this.imageFile});

  @override
  State<BoletaFormScreen> createState() => _BoletaFormScreenState();
}

class _BoletaFormScreenState extends State<BoletaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fechaCtrl;
  late final TextEditingController _horaCtrl;
  late final TextEditingController _patenteCtrl;
  late final TextEditingController _codAutCtrl;
  late final TextEditingController _productoCtrl;
  late final TextEditingController _litrosCtrl;
  late final TextEditingController _precioUnitCtrl;
  late final TextEditingController _ivaCtrl;
  late final TextEditingController _impEspCtrl;
  late final TextEditingController _totalCtrl;

  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    final d = widget.data;
    _fechaCtrl = TextEditingController(text: d.fecha ?? '');
    _horaCtrl = TextEditingController(text: d.hora ?? '');
    _patenteCtrl = TextEditingController(text: d.patente ?? '');
    _codAutCtrl = TextEditingController(text: d.codigoAutorizacion ?? '');
    _productoCtrl = TextEditingController(text: d.producto ?? '');
    _litrosCtrl = TextEditingController(text: d.litros ?? '');
    _precioUnitCtrl = TextEditingController(text: d.precioUnitario ?? '');
    _ivaCtrl = TextEditingController(text: d.iva ?? '');
    _impEspCtrl = TextEditingController(text: d.impuestoEspecifico ?? '');
    _totalCtrl = TextEditingController(text: d.total ?? '');
  }

  @override
  void dispose() {
    _fechaCtrl.dispose();
    _horaCtrl.dispose();
    _patenteCtrl.dispose();
    _codAutCtrl.dispose();
    _productoCtrl.dispose();
    _litrosCtrl.dispose();
    _precioUnitCtrl.dispose();
    _ivaCtrl.dispose();
    _impEspCtrl.dispose();
    _totalCtrl.dispose();
    super.dispose();
  }

  void _recalcularTotal() {
    double parseNumber(String t) => double.tryParse(t.replaceAll(',', '.')) ?? 0;
    final l = parseNumber(_litrosCtrl.text);
    final pu = parseNumber(_precioUnitCtrl.text);
    final iva = parseNumber(_ivaCtrl.text);
    final imp = parseNumber(_impEspCtrl.text);
    if (l > 0 && pu > 0) {
      final base = l * pu;
      final total = (iva > 0 || imp > 0) ? base + iva + imp : base;
      _totalCtrl.text = total.toStringAsFixed(2);
      setState(() {});
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enviando = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      await FirebaseFirestore.instance.collection('boletas_combustible').add({
        'fecha': _fechaCtrl.text.trim(),
        'hora': _horaCtrl.text.trim(),
        'patente': _patenteCtrl.text.trim().toUpperCase(),
        'codigo_autorizacion': _codAutCtrl.text.trim(),
        'producto': _productoCtrl.text.trim().toUpperCase(),
        'litros': _litrosCtrl.text.trim(),
        'precio_unitario': _precioUnitCtrl.text.trim(),
        'iva': _ivaCtrl.text.trim(),
        'impuesto_especifico': _impEspCtrl.text.trim(),
        'total': _totalCtrl.text.trim(),
        'texto_crudo': widget.data.textoCompleto,
        'uid_conductor': uid,
        'fecha_creacion': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Boleta guardada')));
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Widget _campo(String label, TextEditingController c, {TextInputType? tipo, String? Function(String?)? validator, void Function()? onChanged}) {
    return TextFormField(
      controller: c,
      decoration: InputDecoration(labelText: label),
      keyboardType: tipo,
      validator: validator,
      onChanged: (_) => onChanged?.call(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Revisar Boleta')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(widget.imageFile, height: 220, width: double.infinity, fit: BoxFit.cover)),
            const SizedBox(height: 16),
            _campo('Fecha', _fechaCtrl, validator: (v) => v == null || v.isEmpty ? 'Requerido' : null),
            Row(children: [Expanded(child: _campo('Hora', _horaCtrl)), const SizedBox(width: 12), Expanded(child: _campo('Patente', _patenteCtrl))]),
            Row(children: [Expanded(child: _campo('Cod. Autorización', _codAutCtrl)), const SizedBox(width: 12), Expanded(child: _campo('Producto', _productoCtrl))]),
            Row(children: [Expanded(child: _campo('Litros', _litrosCtrl, tipo: TextInputType.number, onChanged: _recalcularTotal)), const SizedBox(width: 12), Expanded(child: _campo('Precio Unitario', _precioUnitCtrl, tipo: TextInputType.number, onChanged: _recalcularTotal))]),
            Row(children: [Expanded(child: _campo('IVA', _ivaCtrl, tipo: TextInputType.number, onChanged: _recalcularTotal)), const SizedBox(width: 12), Expanded(child: _campo('Imp. Específico', _impEspCtrl, tipo: TextInputType.number, onChanged: _recalcularTotal))]),
            _campo('Total', _totalCtrl, tipo: TextInputType.number),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _enviando ? null : _guardar, icon: const Icon(Icons.cloud_upload), label: Text(_enviando ? 'Guardando...' : 'Guardar en Base de Datos'))),
            const SizedBox(height: 12),
            ExpansionTile(title: const Text('Ver texto completo OCR'), children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6)), child: Text(widget.data.textoCompleto, style: const TextStyle(fontSize: 12)))])
          ]),
        ),
      ),
    );
  }
}
