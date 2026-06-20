import 'dart:convert';

import 'package:http/http.dart' as http;

import 'services/supabase_auth_service.dart';
import 'services/supabase_rest_service.dart';

enum RolUsuario {
  admin('admin', 'Administrador de empresa'),
  repartidor('repartidor', 'Repartidor');

  const RolUsuario(this.valor, this.etiqueta);

  final String valor;
  final String etiqueta;

  static RolUsuario desdeValor(String? valor) {
    return RolUsuario.values.firstWhere(
      (rol) => rol.valor == valor,
      orElse: () => RolUsuario.repartidor,
    );
  }
}

String usuarioRolKey({SupabaseAuthUser? user}) {
  final usuario = user ?? supabaseAuth.currentUser;
  final identificador = usuario?.email.toLowerCase().trim() ?? usuario?.uid;
  if (identificador != null && identificador.isNotEmpty) {
    return identificador;
  }

  return 'local';
}

Future<Map<String, dynamic>?> _cargarRolRow(String identificador) async {
  if (identificador == 'local' || !supabaseRest.isConfigured) {
    return null;
  }

  final rows = await supabaseRest.select(
    'roles_usuarios',
    filters: {'id': SupabaseConfig.eq(identificador)},
    limit: 1,
  );
  return rows.isNotEmpty ? rows.first : null;
}

Future<RolUsuario> cargarRolUsuario({SupabaseAuthUser? user}) async {
  final row = await _cargarRolRow(usuarioRolKey(user: user));
  return RolUsuario.desdeValor(row?['rol']?.toString());
}

Future<void> guardarRolUsuario(RolUsuario rol, {SupabaseAuthUser? user}) async {
  final identificador = usuarioRolKey(user: user);
  if (identificador == 'local') {
    return;
  }

  await supabaseRest.upsert('roles_usuarios', {
    'id': identificador,
    'rol': rol.valor,
    'actualizado': DateTime.now().toIso8601String(),
  }, onConflict: 'id');
}

Future<void> guardarRolUsuarioPorEmail(String email, RolUsuario rol) async {
  final identificador = email.toLowerCase().trim();
  if (identificador.isEmpty) {
    return;
  }

  await supabaseRest.upsert('roles_usuarios', {
    'id': identificador,
    'rol': rol.valor,
    'deshabilitado': false,
    if (rol == RolUsuario.admin) ...{
      'debeCambiarContrasena': false,
      'contrasenaTemporalVisible': '****',
    },
    'actualizado': DateTime.now().toIso8601String(),
  }, onConflict: 'id');
}

Future<bool> debeCambiarContrasena({SupabaseAuthUser? user}) async {
  final row = await _cargarRolRow(usuarioRolKey(user: user));
  return row?['debeCambiarContrasena'] == true;
}

Future<bool> usuarioDeshabilitado({SupabaseAuthUser? user}) async {
  final row = await _cargarRolRow(usuarioRolKey(user: user));
  return row?['deshabilitado'] == true;
}

Future<void> guardarCambioContrasenaRequerido({
  required String email,
  required String contrasenaTemporal,
}) async {
  final identificador = email.toLowerCase().trim();
  if (identificador.isEmpty) {
    return;
  }

  await supabaseRest.upsert('roles_usuarios', {
    'id': identificador,
    'rol': RolUsuario.repartidor.valor,
    'deshabilitado': false,
    'debeCambiarContrasena': true,
    'contrasenaTemporalVisible': contrasenaTemporal,
    'actualizado': DateTime.now().toIso8601String(),
  }, onConflict: 'id');
}

Future<void> deshabilitarUsuarioRepartidor(String email) async {
  final identificador = email.toLowerCase().trim();
  if (identificador.isEmpty) {
    return;
  }

  await supabaseRest.upsert('roles_usuarios', {
    'id': identificador,
    'rol': RolUsuario.repartidor.valor,
    'deshabilitado': true,
    'debeCambiarContrasena': false,
    'contrasenaTemporalVisible': '****',
    'actualizado': DateTime.now().toIso8601String(),
  }, onConflict: 'id');
}

Future<void> marcarContrasenaCambiada({SupabaseAuthUser? user}) async {
  final identificador = usuarioRolKey(user: user);
  if (identificador == 'local') {
    return;
  }

  final token = supabaseAuth.accessToken;
  if (token != null && token.isNotEmpty) {
    final endpoint = Uri.base.resolve('/api/mark-password-changed');
    final response = await http.post(
      endpoint,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    if (!(response.statusCode == 404 &&
        (Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1'))) {
      final body = response.body.trim();
      final decoded = body.isEmpty ? null : jsonDecode(body);
      final mensaje = decoded is Map
          ? (decoded['error'] ?? decoded['message'])?.toString()
          : null;
      throw SupabaseAuthException(
        mensaje ?? 'No se pudo marcar la contrasena como cambiada.',
        response.statusCode,
      );
    }
  }

  await supabaseRest.upsert('roles_usuarios', {
    'id': identificador,
    'debeCambiarContrasena': false,
    'contrasenaTemporalVisible': '****',
    'actualizado': DateTime.now().toIso8601String(),
  }, onConflict: 'id');
}

bool puedeAdministrar(RolUsuario rol) => rol == RolUsuario.admin;

String nombreUsuarioActual() {
  final user = supabaseAuth.currentUser;
  final nombre = user?.displayName?.trim();
  if (nombre != null && nombre.isNotEmpty) {
    return nombre;
  }

  final email = user?.email.trim();
  if (email != null && email.isNotEmpty) {
    return email;
  }

  return 'usuario';
}
