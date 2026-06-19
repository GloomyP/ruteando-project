import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'roles.dart';

final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
  app: Firebase.app(),
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

String historialRutasTerminadasKey() {
  return 'historial_rutas_terminadas_${asignacionesGlobalesKey()}';
}

Future<String> empresaOperativaKey() async {
  final keys = await _empresaKeysCandidatas();
  return keys.isNotEmpty ? keys.first : empresaUsuarioKey();
}

Future<Set<String>> _empresaKeysCandidatas() async {
  final fallback = empresaUsuarioKey();
  final keys = <String>{};

  if (Firebase.apps.isEmpty) {
    return {fallback};
  }

  try {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email?.toLowerCase().trim();
    final uid = user?.uid.trim();

    if (email != null && email.isNotEmpty) {
      final doc = await _firestore
          .collection('usuarios_empresas')
          .doc(email)
          .get();
      final empresaKey = doc.data()?['empresaKey']?.toString().trim();
      if (empresaKey != null && empresaKey.isNotEmpty) {
        keys.add(empresaKey);
      }
    }

    final identificadores = [
      email,
      uid,
    ].whereType<String>().where((id) => id.isNotEmpty).toSet();

    for (final identificador in identificadores) {
      final empresaDoc = await _firestore
          .collection('empresas_usuarios')
          .doc(identificador)
          .get();
      final rut = empresaDoc.data()?['rut']?.toString().trim();
      if (rut != null && rut.isNotEmpty) {
        keys.add(rut);
      }
      keys.add(identificador);
    }
  } catch (error) {
    debugPrint('No se pudieron resolver llaves de empresa: $error');
  }

  keys.add(fallback);
  return keys.where((key) => key.trim().isNotEmpty).toSet();
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

String _notificacionesInternasLocalKey() {
  return 'notificaciones_internas_${asignacionesGlobalesKey()}';
}

// ==========================================
// RUTAS ASIGNADAS INDIVIDUALES (REPARTIDOR)
// ==========================================
Future<Map<String, dynamic>?> cargarRutaAsignada(String email) async {
  if (kIsWeb) {
    return _cargarRutaAsignadaLocal(email);
  }

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

  return _cargarRutaAsignadaLocal(email);
}

Future<Map<String, dynamic>?> _cargarRutaAsignadaLocal(String email) async {
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

Stream<Map<String, dynamic>?> escucharRutaAsignada(String email) {
  if (Firebase.apps.isEmpty || kIsWeb) {
    return Stream.fromFuture(cargarRutaAsignada(email));
  }

  return _firestore
      .collection('rutas_asignadas')
      .doc(rutaAsignadaKey(email))
      .snapshots()
      .asyncMap((doc) async {
        final data = doc.data();
        if (data != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_rutaAsignadaLocalKey(email), jsonEncode(data));
        }
        return data;
      });
}

Future<void> guardarRutaAsignada(
  String email,
  Map<String, dynamic> ruta,
) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_rutaAsignadaLocalKey(email), jsonEncode(ruta));

  if (Firebase.apps.isEmpty || kIsWeb) {
    return;
  }

  try {
    await _firestore
        .collection('rutas_asignadas')
        .doc(rutaAsignadaKey(email))
        .set(ruta, SetOptions(merge: true));
  } catch (error) {
    debugPrint('No se pudo sincronizar la ruta asignada: $error');
  }
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

  if (Firebase.apps.isEmpty || kIsWeb) {
    return;
  }

  try {
    await _firestore
        .collection('notificaciones_rutas')
        .doc(notificacionRutaKey(email))
        .set(notificacion, SetOptions(merge: true));
  } catch (error) {
    debugPrint('No se pudo sincronizar la notificacion de ruta: $error');
  }
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

  if (Firebase.apps.isEmpty || kIsWeb) {
    return;
  }

  try {
    await _firestore
        .collection('notificaciones_rutas')
        .doc(notificacionRutaKey(email))
        .update({
          'leida': true,
          'fechaLectura': DateTime.now().toIso8601String(),
        });
  } catch (error) {
    debugPrint('No se pudo sincronizar lectura de notificacion: $error');
  }
}

// ==========================================
// NOTIFICACIONES INTERNAS (ADMINISTRADOR)
// ==========================================
Future<List<Map<String, dynamic>>>
_cargarNotificacionesInternasLocales() async {
  final prefs = await SharedPreferences.getInstance();
  final data = prefs.getString(_notificacionesInternasLocalKey());
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

Future<List<Map<String, dynamic>>> cargarNotificacionesInternas() async {
  if (Firebase.apps.isEmpty || kIsWeb) {
    return _cargarNotificacionesInternasLocales();
  }

  try {
    final key = await empresaOperativaKey();
    final doc = await _firestore
        .collection('notificaciones_internas')
        .doc(key)
        .get();
    final data = doc.data();
    if (data != null && data['lista'] is List) {
      final notificaciones = (data['lista'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _notificacionesInternasLocalKey(),
        jsonEncode(notificaciones),
      );
      return notificaciones;
    }
  } catch (_) {}

  return _cargarNotificacionesInternasLocales();
}

Stream<List<Map<String, dynamic>>> escucharNotificacionesInternas() {
  if (Firebase.apps.isEmpty || kIsWeb) {
    return Stream.fromFuture(cargarNotificacionesInternas());
  }

  return Stream.fromFuture(empresaOperativaKey()).asyncExpand((key) {
    return _firestore
        .collection('notificaciones_internas')
        .doc(key)
        .snapshots()
        .asyncMap((doc) async {
          final data = doc.data();
          if (data != null && data['lista'] is List) {
            final notificaciones = (data['lista'] as List)
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(
              _notificacionesInternasLocalKey(),
              jsonEncode(notificaciones),
            );
            return notificaciones;
          }
          return cargarNotificacionesInternas();
        });
  });
}

Future<void> guardarNotificacionesInternas(
  List<Map<String, dynamic>> notificaciones,
) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    _notificacionesInternasLocalKey(),
    jsonEncode(notificaciones),
  );

  if (Firebase.apps.isEmpty || kIsWeb) {
    return;
  }

  final key = await empresaOperativaKey();
  await _firestore.collection('notificaciones_internas').doc(key).set({
    'lista': notificaciones,
  });
}

Future<void> borrarRutaAsignada(String email) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_rutaAsignadaLocalKey(email));
  await prefs.remove(_notificacionRutaLocalKey(email));

  if (Firebase.apps.isEmpty || kIsWeb) {
    return;
  }

  try {
    await _firestore
        .collection('rutas_asignadas')
        .doc(rutaAsignadaKey(email))
        .delete();
    await _firestore
        .collection('notificaciones_rutas')
        .doc(notificacionRutaKey(email))
        .delete();
  } catch (error) {
    debugPrint('No se pudo sincronizar borrado de ruta asignada: $error');
  }
}

// ==========================================
// ASIGNACIONES GLOBALES (ADMINISTRADOR)
// ==========================================
Future<List<Map<String, dynamic>>> cargarAsignacionesGlobales() async {
  if (Firebase.apps.isEmpty || kIsWeb) {
    return _cargarAsignacionesGlobalesLocales();
  }

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

  return _cargarAsignacionesGlobalesLocales();
}

Future<List<Map<String, dynamic>>> _cargarAsignacionesGlobalesLocales() async {
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

  if (Firebase.apps.isEmpty || kIsWeb) {
    return;
  }

  final key = await empresaOperativaKey();
  try {
    await _firestore.collection('asignaciones_globales').doc(key).set({
      'lista': asignaciones,
    });
  } catch (error) {
    debugPrint('No se pudieron sincronizar asignaciones globales: $error');
  }
}

// ==========================================
// HISTORIAL DE RUTAS TERMINADAS
// ==========================================
Future<List<Map<String, dynamic>>> cargarHistorialRutasTerminadas() async {
  try {
    final key = await empresaOperativaKey();
    final doc = await _firestore
        .collection('historial_rutas_terminadas')
        .doc(key)
        .get();
    final data = doc.data();
    if (data != null && data['lista'] is List) {
      final historial = (data['lista'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        historialRutasTerminadasKey(),
        jsonEncode(historial),
      );
      return historial;
    }
  } catch (_) {}

  final prefs = await SharedPreferences.getInstance();
  final data = prefs.getString(historialRutasTerminadasKey());
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

Future<void> guardarHistorialRutasTerminadas(
  List<Map<String, dynamic>> historial,
) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(historialRutasTerminadasKey(), jsonEncode(historial));

  if (Firebase.apps.isEmpty) {
    return;
  }

  final key = await empresaOperativaKey();
  await _firestore.collection('historial_rutas_terminadas').doc(key).set({
    'lista': historial,
  });
}

Future<void> registrarRutaTerminada(Map<String, dynamic> ruta) async {
  final historial = await cargarHistorialRutasTerminadas();
  final fechaTermino =
      ruta['fechaCompletado']?.toString() ?? DateTime.now().toIso8601String();
  final email = ruta['repartidorEmail']?.toString().toLowerCase().trim() ?? '';
  final id =
      ruta['historialId']?.toString() ??
      ruta['rutaId']?.toString() ??
      ruta['id']?.toString() ??
      'terminada_${email}_$fechaTermino';

  final rutaTerminada = {
    ...ruta,
    'historialId': id,
    'estadoRecorrido': ruta['estadoRecorrido'] ?? 'Completado',
    'estadoFinal':
        ruta['estadoFinal'] ?? ruta['estadoRecorrido'] ?? 'Completado',
    'fechaCompletado': fechaTermino,
  };

  historial.removeWhere((item) => item['historialId']?.toString() == id);
  historial.insert(0, rutaTerminada);
  await guardarHistorialRutasTerminadas(historial);
}

Future<void> liberarRepartidorDeRutaActiva(String email) async {
  final emailNormalizado = email.toLowerCase().trim();
  if (emailNormalizado.isEmpty) {
    return;
  }

  final asignaciones = await cargarAsignacionesGlobales();
  asignaciones.removeWhere((asignacion) {
    final asignado = asignacion['repartidorEmail']
        ?.toString()
        .toLowerCase()
        .trim();
    return asignado == emailNormalizado;
  });
  await guardarAsignacionesGlobales(asignaciones);
}

// ==========================================
// CONDUCTORES / REPARTIDORES VINCULADOS
// ==========================================
String conductoresUsuarioKey() {
  return empresaUsuarioKey();
}

String _conductoresLocalKey() {
  return 'conductores_empresas_${conductoresUsuarioKey()}';
}

Future<List<Map<String, String>>> _cargarConductoresLocales() async {
  final prefs = await SharedPreferences.getInstance();
  final data = prefs.getString(_conductoresLocalKey());
  if (data == null) {
    return [];
  }

  final decoded = jsonDecode(data);
  if (decoded is! List) {
    return [];
  }

  return decoded
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

Future<void> _guardarConductoresLocales(
  List<Map<String, String>> conductores,
) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_conductoresLocalKey(), jsonEncode(conductores));
}

Future<List<Map<String, String>>> cargarConductoresVinculados() async {
  try {
    final keys = await _empresaKeysCandidatas();
    for (final key in keys) {
      final doc = await _firestore
          .collection('conductores_empresas')
          .doc(key)
          .get();
      final data = doc.data();
      final conductores = _mapearConductores(data?['lista']);
      if (conductores.isNotEmpty) {
        await _guardarConductoresLocales(conductores);
        return conductores;
      }
    }

    final snapshot = await _firestore.collection('conductores_empresas').get();
    final todos = <Map<String, String>>[];
    final correosVistos = <String>{};
    for (final doc in snapshot.docs) {
      final conductores = _mapearConductores(doc.data()['lista']);
      for (final conductor in conductores) {
        final correo = conductor['correo']?.toLowerCase().trim() ?? '';
        final llave = correo.isNotEmpty
            ? correo
            : '${conductor['rut'] ?? ''}_${conductor['nombre'] ?? ''}';
        if (llave.isEmpty || correosVistos.contains(llave)) {
          continue;
        }
        correosVistos.add(llave);
        todos.add(conductor);
      }
    }
    if (todos.isNotEmpty) {
      await _guardarConductoresLocales(todos);
      return todos;
    }

    final usuarios = await _cargarRepartidoresDesdeColeccionesUsuarios();
    if (usuarios.isNotEmpty) {
      await _guardarConductoresLocales(usuarios);
      return usuarios;
    }
  } catch (error) {
    debugPrint('No se pudieron cargar repartidores desde Firestore: $error');
  }
  return _cargarConductoresLocales();
}

Future<List<Map<String, String>>>
_cargarRepartidoresDesdeColeccionesUsuarios() async {
  const colecciones = ['usuarios', 'users', 'repartidores', 'conductores'];
  final repartidores = <Map<String, String>>[];
  final vistos = <String>{};

  for (final coleccion in colecciones) {
    final snapshot = await _firestore.collection(coleccion).get();
    final esColeccionGenerica = coleccion == 'usuarios' || coleccion == 'users';

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final rol = (data['rol'] ?? data['role'] ?? data['tipo'] ?? '')
          .toString()
          .toLowerCase()
          .trim();
      if (esColeccionGenerica &&
          rol.isNotEmpty &&
          rol != RolUsuario.repartidor.valor) {
        continue;
      }

      final email = (data['correo'] ?? data['email'] ?? data['mail'] ?? '')
          .toString();
      final correo = email.trim().isNotEmpty
          ? email.toLowerCase().trim()
          : (doc.id.contains('@') ? doc.id.toLowerCase().trim() : '');
      final nombre =
          (data['nombre'] ??
                  data['name'] ??
                  data['displayName'] ??
                  data['nombreCompleto'] ??
                  correo)
              .toString()
              .trim();
      final rut = (data['rut'] ?? data['run'] ?? data['dni'] ?? '')
          .toString()
          .trim();
      final telefono =
          (data['telefono'] ?? data['phone'] ?? data['celular'] ?? '')
              .toString()
              .trim();

      final llave = correo.isNotEmpty ? correo : '${doc.id}_$nombre';
      if (llave.trim().isEmpty || vistos.contains(llave)) {
        continue;
      }

      vistos.add(llave);
      repartidores.add({
        'nombre': nombre.isNotEmpty ? nombre : 'Repartidor',
        'rut': rut,
        'correo': correo,
        'telefono': telefono,
        'rol': RolUsuario.repartidor.valor,
      });
    }
  }

  return repartidores;
}

List<Map<String, String>> _mapearConductores(dynamic lista) {
  if (lista is! List) {
    return [];
  }

  return lista
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

Future<List<Map<String, String>>> cargarRepartidoresAsignables() async {
  final conductores = await cargarConductoresVinculados();
  return conductores.where(esConductorRepartidor).toList();
}

bool esConductorRepartidor(Map<String, String> conductor) {
  return conductor['rol']?.toString().trim() == 'repartidor';
}

Future<void> guardarConductoresVinculados(
  List<Map<String, String>> conductores,
) async {
  await _guardarConductoresLocales(conductores);

  final key = await empresaOperativaKey();
  try {
    await _firestore.collection('conductores_empresas').doc(key).set({
      'lista': conductores,
    });
  } catch (error) {
    debugPrint('No se pudieron sincronizar repartidores con Firestore: $error');
  }
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
