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
