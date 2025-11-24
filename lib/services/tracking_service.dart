import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

/// Servicio global para rastrear la ubicación del patrullero cada 60 segundos.
/// Se inicia tras login (solo rol patrullero) y se detiene al cerrar sesión.
class TrackingService {
  TrackingService._internal();
  static final TrackingService instance = TrackingService._internal();

  Timer? _timer;
  bool _running = false;
  bool _permissionReady = false;
  String? _currentUid;

  /// Inicia el tracking para el usuario (solo si no estaba corriendo o cambia el UID).
  Future<void> startTracking(User user, String nombre) async {
    if (_running && _currentUid == user.uid) {
      debugPrint('[TrackingService] Ya corriendo para mismo usuario');
      return;
    }
    // Reinicia si estaba corriendo para otro usuario
    if (_running && _currentUid != user.uid) {
      stopTracking();
    }
    _currentUid = user.uid;
    _running = true;
    debugPrint('[TrackingService] Iniciando tracking para ${user.uid}');

    await _ensurePermission();
    if (!_permissionReady) {
      debugPrint('[TrackingService] Permisos no otorgados, abortando tracking');
      _running = false;
      return;
    }

    // Primera actualización inmediata
    await _sendLocation(user, nombre);

    _timer = Timer.periodic(const Duration(seconds: 60), (_) async {
      await _sendLocation(user, nombre);
    });
  }

  /// Detiene el tracking.
  void stopTracking() {
    _timer?.cancel();
    _timer = null;
    _running = false;
    _currentUid = null;
    debugPrint('[TrackingService] Tracking detenido');
  }

  Future<void> _ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('[TrackingService] Servicio de ubicación deshabilitado');
      return; // No marcamos permiso listo
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      debugPrint('[TrackingService] Permiso denegado');
      return;
    }
    _permissionReady = true;
  }

  Future<void> _sendLocation(User user, String nombre) async {
    if (!_running) return;
    if (!_permissionReady) return;
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await FirebaseFirestore.instance
          .collection('patrulleros_activos')
          .doc(user.uid)
          .set({
        'latitud': pos.latitude,
        'longitud': pos.longitude,
        'nombre': nombre,
        'ultima_actualizacion': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('[TrackingService] Ubicación enviada lat=${pos.latitude} lng=${pos.longitude}');
    } catch (e) {
      debugPrint('[TrackingService] Error enviando ubicación: $e');
    }
  }
}
