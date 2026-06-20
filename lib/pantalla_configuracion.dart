import 'package:flutter/material.dart';

import 'services/app_settings_service.dart';
import 'services/supabase_auth_service.dart';

class PantallaConfiguracion extends StatelessWidget {
  const PantallaConfiguracion({super.key});

  Future<void> _cambiarContrasena(BuildContext context) async {
    final email = supabaseAuth.currentUser?.email;
    if (email == null || email.trim().isEmpty) {
      return;
    }

    await supabaseAuth.sendPasswordResetEmail(email);
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Enviamos un enlace para cambiar tu contrasena.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppSettingsState>(
      valueListenable: appSettingsService,
      builder: (context, settings, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Configuracion'),
            backgroundColor: Colors.green[800],
            foregroundColor: Colors.white,
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: SwitchListTile(
                    secondary: const Icon(Icons.dark_mode_outlined),
                    title: const Text('Tema oscuro'),
                    value: settings.themeMode == ThemeMode.dark,
                    onChanged: (value) {
                      appSettingsService.cambiarTema(
                        value ? ThemeMode.dark : ThemeMode.light,
                      );
                    },
                  ),
                ),
                Card(
                  child: SwitchListTile(
                    secondary: const Icon(Icons.notifications_outlined),
                    title: const Text('Notificaciones internas'),
                    value: settings.notificacionesInternasActivas,
                    onChanged: appSettingsService.cambiarNotificacionesInternas,
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.lock_reset_outlined),
                    title: const Text('Cambiar contrasena'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _cambiarContrasena(context),
                  ),
                ),
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('Informacion de la app'),
                    subtitle: Text('Ruteando - gestion de rutas y entregas'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
