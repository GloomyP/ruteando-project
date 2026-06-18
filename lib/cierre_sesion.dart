import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> limpiarEstadoSesionActual({User? user}) async {
  final usuario = user ?? FirebaseAuth.instance.currentUser;
  final email = usuario?.email?.toLowerCase().trim();
  if (email == null || email.isEmpty) {
    return;
  }

  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('notificacion_ruta_$email');
}

Future<void> confirmarYCerrarSesion(
  BuildContext context, {
  String mensaje = 'Quieres cerrar tu sesion de forma segura?',
}) async {
  final confirmar = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Cerrar sesion'),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesion'),
          ),
        ],
      );
    },
  );

  if (confirmar != true || !context.mounted) {
    return;
  }

  final user = FirebaseAuth.instance.currentUser;
  await limpiarEstadoSesionActual(user: user);
  await FirebaseAuth.instance.signOut();

  if (!context.mounted) {
    return;
  }

  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
}
