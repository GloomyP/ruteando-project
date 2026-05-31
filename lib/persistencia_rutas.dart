import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

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

String asignacionesGlobalesKey() {
  return empresaUsuarioKey();
}

String notificacionRutaKey(String email) {
  return email.toLowerCase().trim();
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
    return doc.data();
  } catch (_) {
    return null;
  }
}

Future<void> guardarRutaAsignada(
  String email,
  Map<String, dynamic> ruta,
) async {
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
    return doc.data();
  } catch (_) {
    return null;
  }
}

Future<void> guardarNotificacionRuta(
  String email,
  Map<String, dynamic> notificacion,
) async {
  await _firestore
      .collection('notificaciones_rutas')
      .doc(notificacionRutaKey(email))
      .set(notificacion, SetOptions(merge: true));
}

Future<void> marcarNotificacionRutaLeida(String email) async {
  await _firestore
      .collection('notificaciones_rutas')
      .doc(notificacionRutaKey(email))
      .update({
        'leida': true,
        'fechaLectura': DateTime.now().toIso8601String(),
      });
}

Future<void> borrarRutaAsignada(String email) async {
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
    final doc = await _firestore
        .collection('asignaciones_globales')
        .doc(asignacionesGlobalesKey())
        .get();
    final data = doc.data();
    if (data != null && data['lista'] is List) {
      return (data['lista'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
  } catch (_) {}
  return [];
}

Future<void> guardarAsignacionesGlobales(
  List<Map<String, dynamic>> asignaciones,
) async {
  await _firestore
      .collection('asignaciones_globales')
      .doc(asignacionesGlobalesKey())
      .set({'lista': asignaciones});
}

// ==========================================
// CONDUCTORES / REPARTIDORES VINCULADOS
// ==========================================
String conductoresUsuarioKey() {
  return empresaUsuarioKey();
}

Future<List<Map<String, String>>> cargarConductoresVinculados() async {
  try {
    final doc = await _firestore
        .collection('conductores_empresas')
        .doc(conductoresUsuarioKey())
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
  await _firestore
      .collection('conductores_empresas')
      .doc(conductoresUsuarioKey())
      .set({'lista': conductores});
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
