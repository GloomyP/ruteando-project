import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'persistencia_rutas.dart';
import 'roles.dart';

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

  static PerfilUsuario desdeUsuario(User user, Map<String, dynamic>? data) {
    final nombreAuth = user.displayName?.trim() ?? '';
    final email = user.email?.toLowerCase().trim() ?? '';

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

FirebaseFirestore get _firestore =>
    FirebaseFirestore.instanceFor(app: Firebase.app());

String _perfilKey(User user) {
  return user.email?.toLowerCase().trim() ?? user.uid;
}

Future<PerfilUsuario> cargarPerfilUsuario({User? user}) async {
  final usuario = user ?? FirebaseAuth.instance.currentUser;
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

  if (Firebase.apps.isEmpty) {
    return PerfilUsuario.desdeUsuario(usuario, null);
  }

  try {
    final doc = await _firestore
        .collection('perfiles_usuarios')
        .doc(_perfilKey(usuario))
        .get();
    final data = doc.data();
    final perfil = PerfilUsuario.desdeUsuario(usuario, data);

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
  } catch (_) {
    return PerfilUsuario.desdeUsuario(usuario, null);
  }
}

Future<void> guardarPerfilUsuario(PerfilUsuario perfil, {User? user}) async {
  final usuario = user ?? FirebaseAuth.instance.currentUser;
  if (usuario == null) {
    return;
  }

  final nombre = perfil.nombre.trim();
  if (nombre.isNotEmpty && usuario.displayName != nombre) {
    await usuario.updateDisplayName(nombre);
  }

  if (Firebase.apps.isEmpty) {
    return;
  }

  await _firestore.collection('perfiles_usuarios').doc(_perfilKey(usuario)).set(
    {...perfil.toMap(), 'actualizado': DateTime.now().toIso8601String()},
    SetOptions(merge: true),
  );

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
  if (emailNormalizado.isEmpty || Firebase.apps.isEmpty) {
    return;
  }

  await _firestore.collection('perfiles_usuarios').doc(emailNormalizado).set({
    if (nombre.trim().isNotEmpty) 'nombre': nombre.trim(),
    'email': emailNormalizado,
    'telefono': telefono.trim(),
    'actualizado': DateTime.now().toIso8601String(),
  }, SetOptions(merge: true));
}
