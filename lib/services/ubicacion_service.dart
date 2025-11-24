import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Servicio para enviar periódicamente la ubicación del patrullero a Firestore.
/// Usa un Timer.periodic y solo actualiza si el usuario se mueve más de 30 metros.
/// Llama a [start] para comenzar y [stop] para detener el servicio.
class UbicacionService {
  final int intervaloSegundos;
  final double distanciaMinimaMetros;
  Timer? _timer;
  Position? _ultimaPosicion;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  UbicacionService({
    this.intervaloSegundos = 30,
    this.distanciaMinimaMetros = 30,
  });

  /// Inicia el servicio de ubicación.
  Future<void> start() async {
    final user = _auth.currentUser;
    if (user == null) {
  debugPrint('[UbicacionService] No hay usuario logueado. Abortando start.');
      return;
    }

    // Solicita permisos de ubicación
    LocationPermission permiso = await Geolocator.checkPermission();
  debugPrint('[UbicacionService] Permiso actual: $permiso');

    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
  debugPrint('[UbicacionService] Permiso solicitado: $permiso');
      if (permiso == LocationPermission.denied) return;
    }
    if (permiso == LocationPermission.deniedForever) return;

    // Obtiene la posición inicial
    _ultimaPosicion = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    await _actualizarFirestore(_ultimaPosicion!);

    // Inicia el timer periódico
    _timer = Timer.periodic(Duration(seconds: intervaloSegundos), (_) async {
      try {
        final nuevaPos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        if (_ultimaPosicion == null ||
            Geolocator.distanceBetween(
                  _ultimaPosicion!.latitude,
                  _ultimaPosicion!.longitude,
                  nuevaPos.latitude,
                  nuevaPos.longitude,
                ) >= distanciaMinimaMetros) {
          _ultimaPosicion = nuevaPos;
          await _actualizarFirestore(nuevaPos);
        }
      } catch (e) {
        debugPrint('[UbicacionService] Error al obtener ubicación: $e');
      }
    });
  }

  /// Detiene el servicio de ubicación.
  void stop() {
    _timer?.cancel();
    _timer = null;
  debugPrint('[UbicacionService] Servicio detenido.');
  }

  /// Actualiza la ubicación en Firestore bajo 'patrulleros_activos/UID'.
  Future<void> _actualizarFirestore(Position pos) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final docRef = FirebaseFirestore.instance
        .collection('patrulleros_activos')
        .doc(user.uid);

    await docRef.set({
      'nombre': user.displayName ?? 'Patrullero',
      'latitud': pos.latitude,
      'longitud': pos.longitude,
      'ultima_actualizacion': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

  debugPrint('[UbicacionService] Ubicación actualizada en Firestore: '
    'lat=${pos.latitude}, lng=${pos.longitude}');
  }
}
