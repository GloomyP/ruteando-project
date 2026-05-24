import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

String empresaUsuarioKey() {
  try {
    final user = FirebaseAuth.instance.currentUser;
    final identificador = user?.uid ?? user?.email;

    if (identificador != null && identificador.trim().isNotEmpty) {
      return 'empresa_vinculada_usuario_$identificador';
    }
  } catch (_) {
    // Los tests de widgets pueden correr sin Firebase inicializado.
  }
  return 'empresa_vinculada_usuario_local';
}

String rutaAsignadaKey(String email) {
  return 'ruta_asignada_${email.toLowerCase().trim()}';
}

String asignacionesGlobalesKey() {
  return 'asignaciones_rutas_${empresaUsuarioKey()}';
}

Future<Map<String, dynamic>?> cargarRutaAsignada(String email) async {
  final prefs = await SharedPreferences.getInstance();
  final data = prefs.getString(rutaAsignadaKey(email));
  if (data == null) return null;
  try {
    return jsonDecode(data) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

Future<void> guardarRutaAsignada(String email, Map<String, dynamic> ruta) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(rutaAsignadaKey(email), jsonEncode(ruta));
}

Future<void> borrarRutaAsignada(String email) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(rutaAsignadaKey(email));
}

Future<List<Map<String, dynamic>>> cargarAsignacionesGlobales() async {
  final prefs = await SharedPreferences.getInstance();
  final data = prefs.getString(asignacionesGlobalesKey());
  if (data == null) return [];
  try {
    final decoded = jsonDecode(data);
    if (decoded is List) {
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
  } catch (_) {}
  return [];
}

Future<void> guardarAsignacionesGlobales(List<Map<String, dynamic>> asignaciones) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(asignacionesGlobalesKey(), jsonEncode(asignaciones));
}

String conductoresUsuarioKey() {
  return 'conductores_${empresaUsuarioKey()}';
}

Future<List<Map<String, String>>> cargarConductoresVinculados() async {
  final prefs = await SharedPreferences.getInstance();
  final data = prefs.getString(conductoresUsuarioKey());

  if (data == null) {
    return [];
  }

  try {
    final decoded = jsonDecode(data);
    if (decoded is List) {
      return decoded.map((conductor) {
        if (conductor is Map) {
          return conductor.map((key, value) => MapEntry(key.toString(), value.toString()));
        }
        return <String, String>{};
      }).where((element) => element.isNotEmpty).toList();
    }
  } catch (_) {}
  return [];
}

Future<void> guardarConductoresVinculados(List<Map<String, String>> conductores) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(conductoresUsuarioKey(), jsonEncode(conductores));
}
