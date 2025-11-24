import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/tracking_service.dart';

import 'screens/login/login_screen.dart';
import 'screens/administrador/home_page_adm.dart';
import 'screens/administrador/crear_usuario.dart';
import 'screens/administrador/listar_usuarios.dart';
import 'screens/administrador/ver_reportes.dart';
import 'screens/administrador/detalles_reportes.dart';
import 'screens/administrador/agregar_vehiculos.dart';
import 'screens/administrador/listar_vehiculos.dart';
import 'screens/patrullero/home_page_pat.dart';
import 'screens/patrullero/crear_reporte.dart';
import 'screens/conductor/home_page_cond.dart';
import 'screens/conductor/escaneo_boletas.dart';
import 'screens/conductor/escaneo_salida_screen.dart';
import 'screens/conductor/escaneo_llegada_screen.dart';
import 'screens/central_camaras/home_page_central_camaras.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Listener global para iniciar/detener tracking.
  FirebaseAuth.instance.authStateChanges().listen((user) async {
    if (user == null) {
      TrackingService.instance.stopTracking();
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();
      final data = snap.data() ?? {};
      final rol = (data['rol'] as String?)?.toLowerCase();
      final nombre = data['nombre'] as String? ?? 'Patrullero';
      if (rol == 'patrullero') {
        TrackingService.instance.startTracking(user, nombre);
      } else {
        TrackingService.instance.stopTracking();
      }
    } catch (e) {
      TrackingService.instance.stopTracking();
      debugPrint('[Main] Error iniciando tracking: $e');
    }
  });

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  Route<dynamic> _buildRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
  return MaterialPageRoute(builder: (_) => const LoginScreen(), settings: settings);
      case '/home_adm':
        final message = settings.arguments as String?;
  return MaterialPageRoute(builder: (_) => HomePageAdm(message: message), settings: settings);
      case '/crear_usuario':
        final args = settings.arguments as Map<String, dynamic>?;
        final empresa = args?['empresa'] as String? ?? '';
  return MaterialPageRoute(builder: (_) => CrearUsuarioScreen(empresa: empresa), settings: settings);
      case '/listar_usuarios':
        final args = settings.arguments as Map<String, dynamic>?;
        final empresa = args?['empresa'] as String? ?? '';
  return MaterialPageRoute(builder: (_) => ListarUsuariosScreen(empresa: empresa), settings: settings);
      case '/ver_reportes':
  return MaterialPageRoute(builder: (_) => const VerReportesScreen(), settings: settings);
      case '/detalles_reporte':
        final args = settings.arguments as Map<String, dynamic>?;
        final reporte = args?['reporte'] as Map<String, dynamic>?;
        if (reporte == null) {
          return MaterialPageRoute(
            builder: (_) => const Scaffold(
              body: Center(child: Text('Reporte no disponible')),
            ),
          );
        }
  return MaterialPageRoute(builder: (_) => DetallesReportesScreen(reporte: reporte), settings: settings);
      case '/home_pat':
  return MaterialPageRoute(builder: (_) => const HomePagePat(), settings: settings);
      case '/crear_reporte':
  return MaterialPageRoute(builder: (_) => const CrearReporteScreen(), settings: settings);
      case '/home_cond':
  return MaterialPageRoute(builder: (_) => const HomePageConductor(), settings: settings);
      case '/escaneo_boletas':
        return MaterialPageRoute(builder: (_) => const EscaneoBoletasScreen(), settings: settings);
      case '/escaneo_salida':
        return MaterialPageRoute(builder: (_) => const EscaneoSalidaScreen(), settings: settings);
      case '/escaneo_llegada':
        return MaterialPageRoute(builder: (_) => const EscaneoLlegadaScreen(), settings: settings);
      case '/home_camaras':
  return MaterialPageRoute(builder: (_) => const HomePageCentralCamaras(), settings: settings);
      case '/agregar_vehiculo':
        return MaterialPageRoute(builder: (_) => const AgregarVehiculoScreen(), settings: settings);
      case '/listar_vehiculos':
        return MaterialPageRoute(builder: (_) => const ListarVehiculosScreen(), settings: settings);
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Ruta no encontrada')),
          ),
          settings: settings,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateRoute: _buildRoute,
      initialRoute: '/',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 3, 20, 70),
          primary: const Color.fromARGB(255, 3, 20, 70),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: Color.fromARGB(255, 3, 20, 70),
              width: 2.0,
            ),
          ),
          labelStyle: TextStyle(
            color: Color.fromARGB(255, 3, 20, 70),
          ),
          floatingLabelStyle: TextStyle(
            color: Color.fromARGB(255, 3, 20, 70),
          ),
        ),
      ),
    );
  }
}
