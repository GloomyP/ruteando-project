import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
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

// Conectamos a tu base de datos específica "ruteando"
FirebaseFirestore get _firestore => FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: 'ruteando',
    );

String usuarioRolKey({User? user}) {
  User? usuario;
  try {
    usuario = user ?? FirebaseAuth.instance.currentUser;
  } catch (_) {
    // Firebase no inicializado en tests de widgets.
  }
  
  // Usamos el correo como llave única en la base de datos
  final identificador = usuario?.email?.toLowerCase().trim() ?? usuario?.uid;

  if (identificador != null && identificador.isNotEmpty) {
    return identificador;
  }

  return 'local';
}

Future<RolUsuario> cargarRolUsuario({User? user}) async {
  final identificador = usuarioRolKey(user: user);
  
  if (identificador != 'local') {
    try {
      // 1. Intentar cargar el rol desde la nube (Firestore)
      final doc = await _firestore.collection('roles_usuarios').doc(identificador).get();
      if (doc.exists && doc.data() != null) {
        final rolString = doc.data()!['rol'] as String?;
        final rol = RolUsuario.desdeValor(rolString);
        
        // Actualizar el caché local de respaldo
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('rol_usuario_$identificador', rol.valor);
        
        return rol;
      }
    } catch (_) {
      // Si falla la red, ignoramos el error y tratamos de cargar localmente
    }
  }

  // 2. Si no está en la nube o no hay internet, cargamos el caché local
  final prefs = await SharedPreferences.getInstance();
  return RolUsuario.desdeValor(prefs.getString('rol_usuario_$identificador'));
}

Future<void> guardarRolUsuario(RolUsuario rol, {User? user}) async {
  final identificador = usuarioRolKey(user: user);
  
  // 1. Guardar localmente (caché)
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('rol_usuario_$identificador', rol.valor);

  // 2. Guardar en la nube (Firestore)
  if (identificador != 'local') {
    try {
      await _firestore.collection('roles_usuarios').doc(identificador).set({
        'rol': rol.valor,
        'actualizado': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error guardando rol en la nube: $e');
    }
  }
}

bool puedeAdministrar(RolUsuario rol) => rol == RolUsuario.admin;

String nombreUsuarioActual() {
  User? user;
  try {
    user = FirebaseAuth.instance.currentUser;
  } catch (_) {
    // Firebase no inicializado en tests de widgets.
  }
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