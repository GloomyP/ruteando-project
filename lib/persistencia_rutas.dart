import 'dart:async';

import 'roles.dart';
import 'services/supabase_auth_service.dart';
import 'services/supabase_rest_service.dart';

String empresaUsuarioKey() {
  try {
    final user = supabaseAuth.currentUser;
    final identificador = user?.email.toLowerCase().trim() ?? user?.uid;

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

String historialRutasTerminadasKey() {
  return 'historial_rutas_terminadas_${asignacionesGlobalesKey()}';
}

String notificacionRutaKey(String email) {
  return email.toLowerCase().trim();
}

Future<String> empresaOperativaKey() async {
  final keys = await _empresaKeysCandidatas();
  return keys.isNotEmpty ? keys.first : empresaUsuarioKey();
}

Future<Set<String>> _empresaKeysCandidatas() async {
  final fallback = empresaUsuarioKey();
  final keys = <String>{};
  final user = supabaseAuth.currentUser;
  final email = user?.email.toLowerCase().trim();
  final uid = user?.uid.trim();

  if (email != null && email.isNotEmpty) {
    final rows = await supabaseRest.select(
      'usuarios_empresas',
      filters: {'id': SupabaseConfig.eq(email)},
      limit: 1,
    );
    final empresaKey = rows.isNotEmpty
        ? (rows.first['empresa_key'] ?? rows.first['empresaKey'])
              ?.toString()
              .trim()
        : null;
    if (empresaKey != null && empresaKey.isNotEmpty) {
      keys.add(empresaKey);
    }
  }

  for (final identificador in [email, uid].whereType<String>()) {
    if (identificador.trim().isNotEmpty) {
      keys.add(identificador.trim());
    }
  }

  keys.add(fallback);
  return keys.where((key) => key.trim().isNotEmpty).toSet();
}

Future<void> vincularUsuarioAEmpresaActual(String email) async {
  final emailNormalizado = email.toLowerCase().trim();
  if (emailNormalizado.isEmpty) {
    return;
  }

  final empresaKey = await empresaOperativaKey();
  await supabaseRest.upsert('usuarios_empresas', {
    'id': emailNormalizado,
    'empresa_key': empresaKey,
    'empresaKey': empresaKey,
    'actualizado': DateTime.now().toIso8601String(),
  }, onConflict: 'id');
}

Future<Map<String, dynamic>?> cargarRutaAsignada(String email) async {
  final rows = await supabaseRest.select(
    'rutas_asignadas',
    filters: {'id': SupabaseConfig.eq(rutaAsignadaKey(email))},
    limit: 1,
  );
  if (rows.isEmpty) {
    return null;
  }

  final ruta = rows.first['ruta'];
  return ruta is Map ? Map<String, dynamic>.from(ruta) : rows.first;
}

Stream<Map<String, dynamic>?> escucharRutaAsignada(String email) {
  return Stream.fromFuture(cargarRutaAsignada(email));
}

Future<void> guardarRutaAsignada(
  String email,
  Map<String, dynamic> ruta,
) async {
  await supabaseRest.upsert('rutas_asignadas', {
    'id': rutaAsignadaKey(email),
    'email': rutaAsignadaKey(email),
    'ruta': ruta,
    'actualizado': DateTime.now().toIso8601String(),
  }, onConflict: 'id');
}

Future<Map<String, dynamic>?> cargarNotificacionRuta(String email) async {
  final rows = await supabaseRest.select(
    'notificaciones_rutas',
    filters: {'id': SupabaseConfig.eq(notificacionRutaKey(email))},
    limit: 1,
  );
  if (rows.isEmpty) {
    return null;
  }

  final notificacion = rows.first['notificacion'];
  return notificacion is Map
      ? Map<String, dynamic>.from(notificacion)
      : rows.first;
}

Future<void> guardarNotificacionRuta(
  String email,
  Map<String, dynamic> notificacion,
) async {
  await supabaseRest.upsert('notificaciones_rutas', {
    'id': notificacionRutaKey(email),
    'email': notificacionRutaKey(email),
    'notificacion': notificacion,
    'actualizado': DateTime.now().toIso8601String(),
  }, onConflict: 'id');
}

Future<void> marcarNotificacionRutaLeida(String email) async {
  final notificacion = await cargarNotificacionRuta(email);
  if (notificacion == null) {
    return;
  }

  await guardarNotificacionRuta(email, {
    ...notificacion,
    'leida': true,
    'fechaLectura': DateTime.now().toIso8601String(),
  });
}

Future<List<Map<String, dynamic>>> cargarNotificacionesInternas() async {
  final key = await empresaOperativaKey();
  final rows = await supabaseRest.select(
    'notificaciones_internas',
    filters: {'id': SupabaseConfig.eq(key)},
    limit: 1,
  );

  return _mapearListaDinamica(rows.isNotEmpty ? rows.first['lista'] : null);
}

Stream<List<Map<String, dynamic>>> escucharNotificacionesInternas() {
  return Stream.fromFuture(cargarNotificacionesInternas());
}

Future<void> guardarNotificacionesInternas(
  List<Map<String, dynamic>> notificaciones,
) async {
  final key = await empresaOperativaKey();
  await supabaseRest.upsert('notificaciones_internas', {
    'id': key,
    'lista': notificaciones,
    'actualizado': DateTime.now().toIso8601String(),
  }, onConflict: 'id');
}

Future<void> borrarRutaAsignada(String email) async {
  await supabaseRest.delete(
    'rutas_asignadas',
    filters: {'id': SupabaseConfig.eq(rutaAsignadaKey(email))},
  );
  await supabaseRest.delete(
    'notificaciones_rutas',
    filters: {'id': SupabaseConfig.eq(notificacionRutaKey(email))},
  );
}

Future<List<Map<String, dynamic>>> cargarAsignacionesGlobales() async {
  final key = await empresaOperativaKey();
  final rows = await supabaseRest.select(
    'asignaciones_globales',
    filters: {'id': SupabaseConfig.eq(key)},
    limit: 1,
  );

  return _mapearListaDinamica(rows.isNotEmpty ? rows.first['lista'] : null);
}

Future<void> guardarAsignacionesGlobales(
  List<Map<String, dynamic>> asignaciones,
) async {
  final rol = await cargarRolUsuario();
  if (!puedeAdministrar(rol)) {
    return;
  }

  final key = await empresaOperativaKey();
  await supabaseRest.upsert('asignaciones_globales', {
    'id': key,
    'lista': asignaciones,
    'actualizado': DateTime.now().toIso8601String(),
  }, onConflict: 'id');
}

Future<List<Map<String, dynamic>>> cargarHistorialRutasTerminadas() async {
  final key = await empresaOperativaKey();
  final rows = await supabaseRest.select(
    'historial_rutas_terminadas',
    filters: {'id': SupabaseConfig.eq(key)},
    limit: 1,
  );

  return _mapearListaDinamica(rows.isNotEmpty ? rows.first['lista'] : null);
}

Future<void> guardarHistorialRutasTerminadas(
  List<Map<String, dynamic>> historial,
) async {
  final key = await empresaOperativaKey();
  await supabaseRest.upsert('historial_rutas_terminadas', {
    'id': key,
    'lista': historial,
    'actualizado': DateTime.now().toIso8601String(),
  }, onConflict: 'id');
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

String conductoresUsuarioKey() {
  return empresaUsuarioKey();
}

Future<List<Map<String, String>>> cargarConductoresVinculados() async {
  final keys = await _empresaKeysCandidatas();
  for (final key in keys) {
    final rows = await supabaseRest.select(
      'conductores_empresas',
      filters: {'id': SupabaseConfig.eq(key)},
      limit: 1,
    );
    final conductores = rows.isNotEmpty
        ? _mapearConductores(rows.first['lista'])
        : const <Map<String, String>>[];
    if (conductores.isNotEmpty) {
      return conductores;
    }
  }

  return _cargarRepartidoresDesdeSupabase();
}

Future<List<Map<String, String>>> _cargarRepartidoresDesdeSupabase() async {
  final repartidores = <Map<String, String>>[];
  final vistos = <String>{};
  final roles = await supabaseRest.select(
    'roles_usuarios',
    filters: {
      'rol': SupabaseConfig.eq(RolUsuario.repartidor.valor),
      'deshabilitado': SupabaseConfig.eq('false'),
    },
  );

  for (final rol in roles) {
    final correo = rol['id']?.toString().toLowerCase().trim() ?? '';
    if (correo.isEmpty || vistos.contains(correo) || rol['deshabilitado'] == true) {
      continue;
    }

    final perfiles = await supabaseRest.select(
      'perfiles_usuarios',
      filters: {'id': SupabaseConfig.eq(correo)},
      limit: 1,
    );
    final perfil = perfiles.isNotEmpty ? perfiles.first : rol;
    final nombre = (perfil['nombre'] ?? correo).toString().trim();

    vistos.add(correo);
    repartidores.add({
      'nombre': nombre.isNotEmpty ? nombre : 'Repartidor',
      'rut': perfil['rut']?.toString().trim() ?? '',
      'correo': correo,
      'telefono': perfil['telefono']?.toString().trim() ?? '',
      'rol': RolUsuario.repartidor.valor,
    });
  }

  return repartidores;
}

List<Map<String, String>> _mapearConductores(dynamic lista) {
  if (lista is! List) {
    return [];
  }

  return lista
      .whereType<Map>()
      .map(
        (conductor) => conductor.map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        ),
      )
      .where((element) => element.isNotEmpty)
      .toList();
}

List<Map<String, dynamic>> _mapearListaDinamica(dynamic lista) {
  if (lista is! List) {
    return [];
  }

  return lista
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
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
  final key = await empresaOperativaKey();
  await supabaseRest.upsert('conductores_empresas', {
    'id': key,
    'lista': conductores,
    'actualizado': DateTime.now().toIso8601String(),
  }, onConflict: 'id');
}

Future<void> eliminarRepartidorDeSistema(String email) async {
  final emailNormalizado = email.toLowerCase().trim();
  if (emailNormalizado.isEmpty) {
    return;
  }

  await borrarRutaAsignada(emailNormalizado);

  final conductores = await cargarConductoresVinculados();
  conductores.removeWhere((conductor) {
    final correo = conductor['correo']?.toLowerCase().trim();
    return correo == emailNormalizado;
  });
  await guardarConductoresVinculados(conductores);

  final asignaciones = await cargarAsignacionesGlobales();
  asignaciones.removeWhere((asignacion) {
    final correo = asignacion['repartidorEmail']
        ?.toString()
        .toLowerCase()
        .trim();
    return correo == emailNormalizado;
  });
  await guardarAsignacionesGlobales(asignaciones);

  await supabaseRest.delete(
    'perfiles_usuarios',
    filters: {'id': SupabaseConfig.eq(emailNormalizado)},
  );
  await supabaseRest.delete(
    'roles_usuarios',
    filters: {'id': SupabaseConfig.eq(emailNormalizado)},
  );
}

Future<Map<String, String>?> buscarConductorPorEmail(String email) async {
  final emailNormalizado = email.toLowerCase().trim();
  if (emailNormalizado.isEmpty) {
    return null;
  }

  final conductores = await cargarConductoresVinculados();
  for (final conductor in conductores) {
    final correo = conductor['correo']?.toLowerCase().trim();
    if (correo == emailNormalizado) {
      return conductor;
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

  final conductores = await cargarConductoresVinculados();
  var conductoresActualizados = false;
  final nuevosConductores = conductores.map((conductor) {
    final mutable = Map<String, String>.from(conductor);
    final correo = mutable['correo']?.toLowerCase().trim();
    if (correo == emailNormalizado) {
      mutable['nombre'] = nombre;
      mutable['telefono'] = telefono;
      conductoresActualizados = true;
    }
    return mutable;
  }).toList();
  if (conductoresActualizados) {
    await guardarConductoresVinculados(nuevosConductores);
  }

  await supabaseRest.upsert('perfiles_usuarios', {
    'id': emailNormalizado,
    'email': emailNormalizado,
    if (nombre.trim().isNotEmpty) 'nombre': nombre.trim(),
    'telefono': telefono.trim(),
    'actualizado': DateTime.now().toIso8601String(),
  }, onConflict: 'id');

  final ruta = await cargarRutaAsignada(emailNormalizado);
  if (ruta != null) {
    await guardarRutaAsignada(emailNormalizado, {
      ...ruta,
      'repartidorNombre': nombre,
    });
  }

  final asignaciones = await cargarAsignacionesGlobales();
  var asignacionesActualizadas = false;
  final nuevasAsignaciones = asignaciones.map((asignacion) {
    final mutable = Map<String, dynamic>.from(asignacion);
    final correo = mutable['repartidorEmail']?.toString().toLowerCase().trim();
    if (correo == emailNormalizado) {
      mutable['repartidorNombre'] = nombre;
      asignacionesActualizadas = true;
    }
    return mutable;
  }).toList();
  if (asignacionesActualizadas) {
    await guardarAsignacionesGlobales(nuevasAsignaciones);
  }
}
