import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
  app: Firebase.app(),
  databaseId:
      'ruteando', // <-- Aquí le indicamos el nombre exacto que le pusiste
);

String empresaUsuarioKey() {
  try {
    final user = FirebaseAuth.instance.currentUser;
    final identificador = user?.uid ?? user?.email;

    if (identificador != null && identificador.trim().isNotEmpty) {
      return 'empresa_vinculada_usuario_$identificador';
    }
  } catch (_) {}
  return 'empresa_vinculada_usuario_local';
}

String rutaAsignadaKey(String email) {
  return email.toLowerCase().trim();
}

String _rutaAsignadaLocalKey(String email) {
  return 'ruta_asignada_${rutaAsignadaKey(email)}';
}

String asignacionesGlobalesKey() {
  return empresaUsuarioKey();
}

Future<String> empresaOperativaKey() async {
  final fallback = empresaUsuarioKey();

  if (Firebase.apps.isEmpty) {
    return fallback;
  }

  try {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email?.toLowerCase().trim();
    if (email == null || email.isEmpty) {
      return fallback;
    }

    final doc = await _firestore
        .collection('usuarios_empresas')
        .doc(email)
        .get();
    final empresaKey = doc.data()?['empresaKey']?.toString().trim();
    if (empresaKey != null && empresaKey.isNotEmpty) {
      return empresaKey;
    }
  } catch (_) {}

  return fallback;
}

Future<void> vincularUsuarioAEmpresaActual(String email) async {
  final emailNormalizado = email.toLowerCase().trim();
  if (emailNormalizado.isEmpty || Firebase.apps.isEmpty) {
    return;
  }

  await _firestore.collection('usuarios_empresas').doc(emailNormalizado).set({
    'empresaKey': await empresaOperativaKey(),
    'actualizado': DateTime.now().toIso8601String(),
  }, SetOptions(merge: true));
}

String notificacionRutaKey(String email) {
  return email.toLowerCase().trim();
}

String _notificacionRutaLocalKey(String email) {
  return 'notificacion_ruta_${notificacionRutaKey(email)}';
}

// ==========================================
// RUTAS ASIGNADAS INDIVIDUALES (REPARTIDOR)
// ==========================================
Future<Map<String, dynamic>?> cargarRutaAsignada(String email) async {
  try {
    final doc = await _firestore
        .collection('rutas_asignadas')
        .doc(rutaAsignadaKey(email))
        .get();
    final data = doc.data();
    if (data != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_rutaAsignadaLocalKey(email), jsonEncode(data));
      return data;
    }
  } catch (_) {}

  final prefs = await SharedPreferences.getInstance();
  final data = prefs.getString(_rutaAsignadaLocalKey(email));
  if (data == null) {
    return null;
  }

  final decoded = jsonDecode(data);
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }

  return null;
}

Future<void> guardarRutaAsignada(
  String email,
  Map<String, dynamic> ruta,
) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_rutaAsignadaLocalKey(email), jsonEncode(ruta));

  if (Firebase.apps.isEmpty) {
    return;
  }

  await _firestore
      .collection('rutas_asignadas')
      .doc(rutaAsignadaKey(email))
      .set(ruta, SetOptions(merge: true));
}

// ==========================================
// NOTIFICACIONES DE RUTAS
// ==========================================
Future<Map<String, dynamic>?> cargarNotificacionRuta(String email) async {
  try {
    final doc = await _firestore
        .collection('notificaciones_rutas')
        .doc(notificacionRutaKey(email))
        .get();
    final data = doc.data();
    if (data != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_notificacionRutaLocalKey(email), jsonEncode(data));
      return data;
    }
  } catch (_) {}

  final prefs = await SharedPreferences.getInstance();
  final data = prefs.getString(_notificacionRutaLocalKey(email));
  if (data == null) {
    return null;
  }

  final decoded = jsonDecode(data);
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }

  return null;
}

Future<void> guardarNotificacionRuta(
  String email,
  Map<String, dynamic> notificacion,
) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    _notificacionRutaLocalKey(email),
    jsonEncode(notificacion),
  );

  if (Firebase.apps.isEmpty) {
    return;
  }

  await _firestore
      .collection('notificaciones_rutas')
      .doc(notificacionRutaKey(email))
      .set(notificacion, SetOptions(merge: true));
}

Future<void> marcarNotificacionRutaLeida(String email) async {
  final notificacion = await cargarNotificacionRuta(email);
  if (notificacion != null) {
    await guardarNotificacionRuta(email, {
      ...notificacion,
      'leida': true,
      'fechaLectura': DateTime.now().toIso8601String(),
    });
  }

  if (Firebase.apps.isEmpty) {
    return;
  }

  await _firestore
      .collection('notificaciones_rutas')
      .doc(notificacionRutaKey(email))
      .update({
        'leida': true,
        'fechaLectura': DateTime.now().toIso8601String(),
      });
}

Future<void> borrarRutaAsignada(String email) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_rutaAsignadaLocalKey(email));
  await prefs.remove(_notificacionRutaLocalKey(email));

  if (Firebase.apps.isEmpty) {
    return;
  }

  await _firestore
      .collection('rutas_asignadas')
      .doc(rutaAsignadaKey(email))
      .delete();
  await _firestore
      .collection('notificaciones_rutas')
      .doc(notificacionRutaKey(email))
      .delete();
}

// ==========================================
// ASIGNACIONES GLOBALES (ADMINISTRADOR)
// ==========================================
Future<List<Map<String, dynamic>>> cargarAsignacionesGlobales() async {
  try {
    final key = await empresaOperativaKey();
    final doc = await _firestore
        .collection('asignaciones_globales')
        .doc(key)
        .get();
    final data = doc.data();
    if (data != null && data['lista'] is List) {
      return (data['lista'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
  } catch (_) {}

  final prefs = await SharedPreferences.getInstance();
  final data = prefs.getString(asignacionesGlobalesKey());
  if (data == null) {
    return [];
  }

  final decoded = jsonDecode(data);
  if (decoded is List) {
    return decoded
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  return [];
}

Future<void> guardarAsignacionesGlobales(
  List<Map<String, dynamic>> asignaciones,
) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(asignacionesGlobalesKey(), jsonEncode(asignaciones));

  if (Firebase.apps.isEmpty) {
    return;
  }

  final key = await empresaOperativaKey();
  await _firestore.collection('asignaciones_globales').doc(key).set({
    'lista': asignaciones,
  });
}

// ==========================================
// CONDUCTORES / REPARTIDORES VINCULADOS
// ==========================================
String conductoresUsuarioKey() {
  return empresaUsuarioKey();
}

Future<List<Map<String, String>>> cargarConductoresVinculados() async {
  try {
    final key = await empresaOperativaKey();
    final doc = await _firestore
        .collection('conductores_empresas')
        .doc(key)
        .get();
    final data = doc.data();
    if (data != null && data['lista'] is List) {
      return (data['lista'] as List)
          .map((conductor) {
            if (conductor is Map) {
              return conductor.map(
                (key, value) => MapEntry(key.toString(), value.toString()),
              );
            }
            return <String, String>{};
          })
          .where((element) => element.isNotEmpty)
          .toList();
    }
  } catch (_) {}
  return [];
}

Future<void> guardarConductoresVinculados(
  List<Map<String, String>> conductores,
) async {
  final key = await empresaOperativaKey();
  await _firestore.collection('conductores_empresas').doc(key).set({
    'lista': conductores,
  });
}

Future<void> eliminarRepartidorDeSistema(String email) async {
  final emailNormalizado = email.toLowerCase().trim();
  if (emailNormalizado.isEmpty) {
    return;
  }

  await borrarRutaAsignada(emailNormalizado);

  final conductoresSnapshot = await _firestore
      .collection('conductores_empresas')
      .get();
  for (final doc in conductoresSnapshot.docs) {
    final data = doc.data();
    final lista = data['lista'];
    if (lista is! List) {
      continue;
    }

    final conductores = lista.where((conductor) {
      if (conductor is! Map) {
        return true;
      }

      final correo = conductor['correo']?.toString().toLowerCase().trim();
      return correo != emailNormalizado;
    }).toList();

    if (conductores.length != lista.length) {
      await doc.reference.set({'lista': conductores}, SetOptions(merge: true));
    }
  }

  final asignacionesSnapshot = await _firestore
      .collection('asignaciones_globales')
      .get();
  for (final doc in asignacionesSnapshot.docs) {
    final data = doc.data();
    final lista = data['lista'];
    if (lista is! List) {
      continue;
    }

    final asignaciones = lista.where((asignacion) {
      if (asignacion is! Map) {
        return true;
      }

      final correo = asignacion['repartidorEmail']
          ?.toString()
          .toLowerCase()
          .trim();
      return correo != emailNormalizado;
    }).toList();

    if (asignaciones.length != lista.length) {
      await doc.reference.set({'lista': asignaciones}, SetOptions(merge: true));
    }
  }

  await _firestore
      .collection('perfiles_usuarios')
      .doc(emailNormalizado)
      .delete();
}

Future<Map<String, String>?> buscarConductorPorEmail(String email) async {
  final emailNormalizado = email.toLowerCase().trim();
  if (emailNormalizado.isEmpty) {
    return null;
  }

  final conductoresSnapshot = await _firestore
      .collection('conductores_empresas')
      .get();
  for (final doc in conductoresSnapshot.docs) {
    final data = doc.data();
    final lista = data['lista'];
    if (lista is! List) {
      continue;
    }

    for (final conductor in lista) {
      if (conductor is! Map) {
        continue;
      }

      final mutable = conductor.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
      final correo = mutable['correo']?.toLowerCase().trim();
      if (correo == emailNormalizado) {
        return mutable;
      }
    }
  }

  return null;
}

Future<void> actualizarDatosRepartidorEnSistema({
  required String email,
  required String nombre,
  required String telefono,
}) async {
  final emailNormalizado = email.toLowerCase().trim();
  if (emailNormalizado.isEmpty) {
    return;
  }

  final conductoresSnapshot = await _firestore
      .collection('conductores_empresas')
      .get();
  for (final doc in conductoresSnapshot.docs) {
    final data = doc.data();
    final lista = data['lista'];
    if (lista is! List) {
      continue;
    }

    var actualizado = false;
    final conductores = lista.map((conductor) {
      if (conductor is! Map) {
        return conductor;
      }

      final mutable = Map<String, dynamic>.from(conductor);
      final correo = mutable['correo']?.toString().toLowerCase().trim();
      if (correo == emailNormalizado) {
        mutable['nombre'] = nombre;
        mutable['telefono'] = telefono;
        actualizado = true;
      }
      return mutable;
    }).toList();

    if (actualizado) {
      await doc.reference.set({'lista': conductores}, SetOptions(merge: true));
    }
  }

  final rutaDoc = _firestore
      .collection('rutas_asignadas')
      .doc(rutaAsignadaKey(email));
  final rutaSnapshot = await rutaDoc.get();
  if (rutaSnapshot.exists) {
    await rutaDoc.set({'repartidorNombre': nombre}, SetOptions(merge: true));
  }

  final asignacionesSnapshot = await _firestore
      .collection('asignaciones_globales')
      .get();
  for (final doc in asignacionesSnapshot.docs) {
    final data = doc.data();
    final lista = data['lista'];
    if (lista is! List) {
      continue;
    }

    var actualizado = false;
    final asignaciones = lista.map((asignacion) {
      if (asignacion is! Map) {
        return asignacion;
      }

      final mutable = Map<String, dynamic>.from(asignacion);
      final correo = mutable['repartidorEmail']
          ?.toString()
          .toLowerCase()
          .trim();
      if (correo == emailNormalizado) {
        mutable['repartidorNombre'] = nombre;
        actualizado = true;
      }
      return mutable;
    }).toList();

    if (actualizado) {
      await doc.reference.set({'lista': asignaciones}, SetOptions(merge: true));
    }
  }
}
