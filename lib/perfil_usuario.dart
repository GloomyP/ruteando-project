import 'persistencia_rutas.dart';
import 'roles.dart';
import 'services/supabase_auth_service.dart';
import 'services/supabase_rest_service.dart';

class PerfilUsuario {
  const PerfilUsuario({
    required this.nombre,
    required this.email,
    required this.telefono,
    required this.region,
    required this.comuna,
    required this.direccion,
  });

  final String nombre;
  final String email;
  final String telefono;
  final String region;
  final String comuna;
  final String direccion;

  Map<String, String> toMap() {
    return {
      'nombre': nombre,
      'email': email,
      'telefono': telefono,
      'region': region,
      'comuna': comuna,
      'direccion': direccion,
    };
  }

  static PerfilUsuario desdeUsuario(
    SupabaseAuthUser user,
    Map<String, dynamic>? data,
  ) {
    final nombreAuth = user.displayName?.trim() ?? '';
    final email = user.email.toLowerCase().trim();
    final nombrePerfil = data?['nombre']?.toString().trim() ?? '';
    final telefonoPerfil = data?['telefono']?.toString().trim() ?? '';

    return PerfilUsuario(
      nombre: nombrePerfil.isNotEmpty ? nombrePerfil : nombreAuth,
      email: email,
      telefono: telefonoPerfil,
      region: data?['region']?.toString() ?? '',
      comuna: data?['comuna']?.toString() ?? '',
      direccion: data?['direccion']?.toString() ?? '',
    );
  }
}

String _perfilKey(SupabaseAuthUser user) {
  return user.email.toLowerCase().trim();
}

Future<PerfilUsuario> cargarPerfilUsuario({SupabaseAuthUser? user}) async {
  final usuario = user ?? supabaseAuth.currentUser;
  if (usuario == null) {
    return const PerfilUsuario(
      nombre: '',
      email: '',
      telefono: '',
      region: '',
      comuna: '',
      direccion: '',
    );
  }

  final rows = await supabaseRest.select(
    'perfiles_usuarios',
    filters: {'id': SupabaseConfig.eq(_perfilKey(usuario))},
    limit: 1,
  );
  final perfil = PerfilUsuario.desdeUsuario(
    usuario,
    rows.isNotEmpty ? rows.first : null,
  );

  final rol = await cargarRolUsuario(user: usuario);
  if (rol != RolUsuario.repartidor) {
    return perfil;
  }

  final conductor = await buscarConductorPorEmail(perfil.email);
  if (conductor == null) {
    return perfil;
  }

  final telefonoAdmin = conductor['telefono']?.trim() ?? '';
  final nombreAdmin = conductor['nombre']?.trim() ?? '';

  return PerfilUsuario(
    nombre: perfil.nombre.trim().isNotEmpty ? perfil.nombre : nombreAdmin,
    email: perfil.email,
    telefono: telefonoAdmin.isNotEmpty ? telefonoAdmin : perfil.telefono,
    region: perfil.region,
    comuna: perfil.comuna,
    direccion: perfil.direccion,
  );
}

Future<void> guardarPerfilUsuario(PerfilUsuario perfil, {SupabaseAuthUser? user}) async {
  final usuario = user ?? supabaseAuth.currentUser;
  if (usuario == null) {
    return;
  }

  final nombre = perfil.nombre.trim();
  if (nombre.isNotEmpty && usuario.displayName != nombre) {
    await supabaseAuth.updateDisplayName(nombre);
  }

  await supabaseRest.upsert('perfiles_usuarios', {
    'id': _perfilKey(usuario),
    ...perfil.toMap(),
    'actualizado': DateTime.now().toIso8601String(),
  }, onConflict: 'id');

  final rol = await cargarRolUsuario(user: usuario);
  if (rol == RolUsuario.repartidor) {
    await actualizarDatosRepartidorEnSistema(
      email: perfil.email,
      nombre: nombre,
      telefono: perfil.telefono.trim(),
    );
  }
}

Future<void> actualizarTelefonoPerfilPorAdmin({
  required String email,
  required String nombre,
  required String telefono,
}) async {
  final emailNormalizado = email.toLowerCase().trim();
  if (emailNormalizado.isEmpty) {
    return;
  }

  await supabaseRest.upsert('perfiles_usuarios', {
    'id': emailNormalizado,
    if (nombre.trim().isNotEmpty) 'nombre': nombre.trim(),
    'email': emailNormalizado,
    'telefono': telefono.trim(),
    'actualizado': DateTime.now().toIso8601String(),
  }, onConflict: 'id');
}
