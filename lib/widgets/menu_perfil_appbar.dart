import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../cierre_sesion.dart';
import '../pantalla_configuracion.dart';
import '../pantalla_perfil.dart';
import '../roles.dart';

class MenuPerfilAppBar extends StatelessWidget {
  const MenuPerfilAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Firebase.apps.isEmpty
        ? null
        : FirebaseAuth.instance.currentUser;
    final nombre = nombreUsuarioActual();
    final email = user?.email?.trim() ?? 'Email no registrado';
    final inicial = nombre.trim().isNotEmpty ? nombre.trim()[0] : 'U';

    return PopupMenuButton<String>(
      tooltip: 'Cuenta',
      offset: const Offset(0, 12),
      constraints: const BoxConstraints(minWidth: 280, maxWidth: 340),
      color: Theme.of(context).colorScheme.surface,
      onSelected: (value) async {
        if (value == 'perfil') {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: '/perfil'),
              builder: (_) => const PantallaPerfil(),
            ),
          );
          return;
        }
        if (value == 'configuracion') {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const PantallaConfiguracion(),
            ),
          );
          return;
        }
        if (value == 'cerrar_sesion') {
          await confirmarYCerrarSesion(context);
        }
      },
      itemBuilder: (context) {
        final dividerColor = Theme.of(context).colorScheme.outlineVariant;
        return [
          PopupMenuItem<String>(
            enabled: false,
            child: _ResumenUsuario(
              nombre: nombre,
              email: email,
              inicial: inicial.toUpperCase(),
              fotoUrl: user?.photoURL,
            ),
          ),
          PopupMenuItem<String>(
            enabled: false,
            height: 1,
            padding: EdgeInsets.zero,
            child: Divider(height: 1, color: dividerColor),
          ),
          const PopupMenuItem<String>(
            value: 'perfil',
            child: _MenuCuentaItem(
              icon: Icons.edit_outlined,
              label: 'Editar perfil',
            ),
          ),
          const PopupMenuItem<String>(
            value: 'configuracion',
            child: _MenuCuentaItem(
              icon: Icons.settings_outlined,
              label: 'Configuracion',
            ),
          ),
          PopupMenuItem<String>(
            enabled: false,
            height: 1,
            padding: EdgeInsets.zero,
            child: Divider(height: 1, color: dividerColor),
          ),
          const PopupMenuItem<String>(
            value: 'cerrar_sesion',
            child: _MenuCuentaItem(
              icon: Icons.logout,
              label: 'Cerrar sesion',
              danger: true,
            ),
          ),
        ];
      },
      icon: CircleAvatar(
        radius: 16,
        backgroundColor: Colors.white,
        foregroundColor: Colors.green[900],
        backgroundImage: user?.photoURL == null
            ? null
            : NetworkImage(user!.photoURL!),
        child: user?.photoURL == null
            ? Text(
                inicial.toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w700),
              )
            : null,
      ),
    );
  }
}

class _ResumenUsuario extends StatelessWidget {
  const _ResumenUsuario({
    required this.nombre,
    required this.email,
    required this.inicial,
    required this.fotoUrl,
  });

  final String nombre;
  final String email;
  final String inicial;
  final String? fotoUrl;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: colors.primaryContainer,
          foregroundColor: colors.onPrimaryContainer,
          backgroundImage: fotoUrl == null ? null : NetworkImage(fotoUrl!),
          child: fotoUrl == null
              ? Text(
                  inicial,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuCuentaItem extends StatelessWidget {
  const _MenuCuentaItem({
    required this.icon,
    required this.label,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = danger ? colors.error : colors.primary;
    final textColor = danger ? colors.error : colors.onSurface;
    final background = danger
        ? colors.errorContainer.withValues(alpha: 0.55)
        : colors.primaryContainer.withValues(alpha: 0.75);
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, size: 19, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
