import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'boleta_form_screen.dart';

class EscaneoBoletasScreen extends StatefulWidget {
  const EscaneoBoletasScreen({super.key});

  @override
  State<EscaneoBoletasScreen> createState() => _EscaneoBoletasScreenState();
}

class _EscaneoBoletasScreenState extends State<EscaneoBoletasScreen> {
  CameraController? _cameraController;
  XFile? _fotoTomada;
  bool _procesando = false;

  @override
  void initState() {
    super.initState();
    _inicializarCamara();
  }

  Future<void> _inicializarCamara() async {
    final cameras = await availableCameras();
    final camera = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back);
    _cameraController = CameraController(camera, ResolutionPreset.high);
    await _cameraController!.initialize();
    if (mounted) setState(() {});
  }

  String _normNumero(String? s) {
    if (s == null) return '';
    // Quitar espacios y miles con punto si formato chileno (31.865) -> 31865
    var t = s.trim();
    // Si tiene tanto coma como punto, asumimos coma decimal ("31.865" probablemente miles) sólo si hay un único separador.
    // Reglas simples:
    // - Reemplazar puntos que actúan como separador de miles: si hay más de 3 dígitos antes y 3 después.
    t = t.replaceAll(RegExp(r'(?<=\d)\.(?=\d{3}(\D|$))'), '');
    // Reemplazar coma decimal por punto
    if (t.contains(',')) t = t.replaceAll(',', '.');
    return t;
  }

  double? _toDouble(String? s) {
    final n = _normNumero(s);
    if (n.isEmpty) return null;
    return double.tryParse(n);
  }

  // -------------------- PARSEO BOLETA --------------------
  BoletaData _parseBoleta(String texto) {
    final full = texto
        .replaceAll('\r', '')
        .replaceAll('\u00A0', ' ')
        .replaceAllMapped(RegExp(r'[|]'), (_) => ' ');

  String? firstMatch(RegExp exp) {
      final m = exp.firstMatch(full);
      return (m != null && m.groupCount >= 1) ? m.group(1)?.trim() : null;
    }

  final fecha = firstMatch(RegExp(r'(?:Fecha(?:\s*Emisi[oó]n)?[:\-]?\s*)(\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4})', caseSensitive: false))
    ?? firstMatch(RegExp(r'\b(\d{2}[\/\-]\d{2}[\/\-]\d{2,4})\b'));
  final hora = firstMatch(RegExp(r'(?:Hora(?:\s*Emisi[oó]n)?[:\-]?\s*)(\d{1,2}:\d{2}:\d{2})', caseSensitive: false))
    ?? firstMatch(RegExp(r'(?:Hora(?:\s*Emisi[oó]n)?[:\-]?\s*)(\d{1,2}:\d{2})', caseSensitive: false))
    ?? firstMatch(RegExp(r'\b(\d{2}:\d{2}:\d{2})\b'))
    ?? firstMatch(RegExp(r'\b(\d{2}:\d{2})\b'));

  final patente = firstMatch(RegExp(r'(?:Patente[:\-]?\s*)([A-Z0-9]{4,8})', caseSensitive: false));
  final codigoAut = firstMatch(RegExp(r'(?:C[oó]d(?:igo)?\s*Aut(?:orizaci[oó]n)?[:\-]?\s*)([A-Z0-9]{6,})', caseSensitive: false));

    // Producto
  String? producto = firstMatch(RegExp(r'\b(DIESEL)\b', caseSensitive: false)) ??
    firstMatch(RegExp(r'\b(GASOLINA\s*(?:93|95|97))\b', caseSensitive: false)) ??
    firstMatch(RegExp(r'\b(PETR[ÓO]LEO\s*DI[EÉ]SEL)\b', caseSensitive: false));

    final lines = full
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    String? litros;
    String? precioUnit;
    String? ivaMonto;
    String? impEspecifico;
    String? total;

    final regexLineaCantidadPrecio = RegExp(
        r'(\d+(?:[\.,]\d{1,3})?)\s*(?:L|LT|LTS)?\s*[xX×]\s*\$?\s*([\d\.\,]+)',
        caseSensitive: false);

    for (var l in lines) {
      // Cantidad x Precio
      if (litros == null || precioUnit == null) {
        final m = regexLineaCantidadPrecio.firstMatch(l);
        if (m != null) {
          litros = m.group(1);
            precioUnit = m.group(2);
        }
      }
      // IVA
      ivaMonto ??= RegExp(r'I\.?V\.?A.*?(?:19\s*%[^0-9]*)?[:=\s]*([0-9\.\,]+)', caseSensitive: false)
          .firstMatch(l)
          ?.group(1);

      // Impuesto específico
      impEspecifico ??= RegExp(
        r'(?:Imp(?:uesto)?\.?\s*(?:Espec[ií]fico|Esp)[^\d]{0,10})([0-9\.\,]+)',
        caseSensitive: false,
      ).firstMatch(l)?.group(1);

      // Total (última coincidencia tiene prioridad)
      final totMatch = RegExp(r'(?:Total(?:\s*(?:a\s*Pagar)?)?[:=\s\$]*)([0-9\.\,]+)', caseSensitive: false)
          .firstMatch(l);
      if (totMatch != null) total = totMatch.group(1);

      if (producto == null &&
          RegExp(r'DIESEL|GASOLINA|PETR[ÓO]LEO', caseSensitive: false).hasMatch(l)) {
        producto = l.split(RegExp(r'\s{2,}')).first;
      }
    }

    // Normalizar y calcular total si falta
    double? litrosD = _toDouble(litros);
    double? precioD = _toDouble(precioUnit);
    double? ivaD = _toDouble(ivaMonto);
    double? impEspD = _toDouble(impEspecifico);
    double? totalD = _toDouble(total);

    if (totalD == null && litrosD != null && precioD != null) {
      final base = litrosD * precioD;
      final calculado = base + (ivaD ?? 0) + (impEspD ?? 0);
      if (calculado > 0) {
        totalD = calculado;
        total = calculado.toStringAsFixed(2);
      }
    }

    return BoletaData(
      fecha: fecha,
      hora: hora,
      patente: patente,
      codigoAutorizacion: codigoAut,
      producto: producto,
      litros: litrosD != null
          ? litrosD.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')
          : litros,
      precioUnitario: precioD != null ? precioD.toStringAsFixed(2) : precioUnit,
      iva: ivaMonto,
      impuestoEspecifico: impEspecifico,
      total: total,
      textoCompleto: full,
    );
  }

  void _abrirFormulario(BoletaData data, XFile foto) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => BoletaFormScreen(data: data, imageFile: File(foto.path))));
  }

  Future<void> _tomarFotoYDetectarTexto() async {
    setState(() { _procesando = true; });
    final foto = await _cameraController!.takePicture();
    _fotoTomada = foto;
    final inputImage = InputImage.fromFilePath(foto.path);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final recognizedText = await textRecognizer.processImage(inputImage);
    final data = _parseBoleta(recognizedText.text);
    setState(() { _procesando = false; });
    _abrirFormulario(data, foto);
  }

  @override
  void dispose() { _cameraController?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear Boleta')),
      body: _cameraController == null || !_cameraController!.value.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Stack(children: [
              if (_fotoTomada == null) CameraPreview(_cameraController!) else Image.file(File(_fotoTomada!.path), fit: BoxFit.cover, width: double.infinity, height: double.infinity),
              if (_procesando) Container(color: Colors.black54, child: const Center(child: CircularProgressIndicator())),
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (_fotoTomada == null)
                    FloatingActionButton(onPressed: _procesando ? null : _tomarFotoYDetectarTexto, child: const Icon(Icons.camera_alt))
                  else
                    ElevatedButton(onPressed: () { setState(() { _fotoTomada = null; }); }, child: const Text('Tomar otra foto'))
                ]),
              ),
            ]),
    );
  }
}