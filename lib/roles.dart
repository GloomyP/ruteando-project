import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum RolUsuario {
  admin('admin', 'Administrador de empresa'),
  repartidor('repartidor', 'Repartidor');

  const RolUsuario(this.valor, this.etiqueta);

  final String valor;
  final String etiqueta;

  static RolUsuario desdeValor(String? valor) {
    return RolUsuario.values.firstWhere(
      (rol) => rol.valor == valor,
      orElse: () => RolUsuario.admin,
    );
  }
}

String usuarioRolKey({User? user}) {
  final usuario = user ?? FirebaseAuth.instance.currentUser;
  final identificador = usuario?.uid ?? usuario?.email;

  if (identificador != null && identificador.trim().isNotEmpty) {
    return 'rol_usuario_$identificador';
  }

  return 'rol_usuario_local';
}

Future<RolUsuario> cargarRolUsuario({User? user}) async {
  final prefs = await SharedPreferences.getInstance();
  return RolUsuario.desdeValor(prefs.getString(usuarioRolKey(user: user)));
}

Future<void> guardarRolUsuario(RolUsuario rol, {User? user}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(usuarioRolKey(user: user), rol.valor);
}

bool puedeAdministrar(RolUsuario rol) => rol == RolUsuario.admin;

String nombreUsuarioActual() {
  final user = FirebaseAuth.instance.currentUser;
  final nombre = user?.displayName?.trim();

  if (nombre != null && nombre.isNotEmpty) {
    return nombre;
  }

  final email = user?.email?.trim();
  if (email != null && email.isNotEmpty) {
    return email;
  }

  return 'usuario';
}
