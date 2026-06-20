import 'package:flutter/material.dart';

import 'services/supabase_auth_service.dart';

Future<void> limpiarEstadoSesionActual({SupabaseAuthUser? user}) async {}

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

  await supabaseAuth.signOut();

  if (!context.mounted) {
    return;
  }

  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
}
