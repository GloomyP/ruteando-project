import 'package:flutter/material.dart';

import 'roles.dart';
import 'web_focus_helper.dart'
    if (dart.library.html) 'web_focus_helper_web.dart';

class AppMenuDrawer extends StatelessWidget {
  const AppMenuDrawer({super.key, this.currentRoute});

  final String? currentRoute;

  Future<void> _abrirRuta(BuildContext context, String routeName) async {
    liberarFocoPlataforma();
    final navigator = Navigator.of(context);
    navigator.pop();

    if (routeName == currentRoute) {
      return;
    }

    final rol = await cargarRolUsuario();
    final esRutaAdmin = routeName != '/mi-ruta';
    if (esRutaAdmin && !puedeAdministrar(rol)) {
      navigator.pushReplacementNamed('/mi-ruta');
      return;
    }

    navigator.pushReplacementNamed(routeName);
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: FutureBuilder<RolUsuario>(
          future: cargarRolUsuario(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final rol = snapshot.data ?? RolUsuario.admin;
            final esAdmin = puedeAdministrar(rol);

            return Column(
              children: [
                DrawerHeader(
                  margin: EdgeInsets.zero,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.green[100],
                        child: Icon(
                          Icons.local_shipping,
                          color: Colors.green[800],
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Bienvenido, ${nombreUsuarioActual()}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                if (esAdmin) ...[
                  _DrawerRouteTile(
                    icon: Icons.home_outlined,
                    title: 'Inicio',
                    selected: currentRoute == '/inicio',
                    onTap: () => _abrirRuta(context, '/inicio'),
                  ),
                  _DrawerRouteTile(
                    icon: Icons.alt_route,
                    title: 'Rutas',
                    selected: currentRoute == '/rutas',
                    onTap: () => _abrirRuta(context, '/rutas'),
                  ),
                  _DrawerRouteTile(
                    icon: Icons.assignment_outlined,
                    title: 'Asignación de pedidos',
                    selected: currentRoute == '/asignacion-rutas',
                    onTap: () => _abrirRuta(context, '/asignacion-rutas'),
                  ),
                  _DrawerRouteTile(
                    icon: Icons.monitor_heart_outlined,
                    title: 'Monitoreo de Entregas',
                    selected: currentRoute == '/monitoreo-entregas',
                    onTap: () => _abrirRuta(context, '/monitoreo-entregas'),
                  ),
                  _DrawerRouteTile(
                    icon: Icons.people_alt_outlined,
                    title: 'Repartidores',
                    selected: currentRoute == '/repartidores',
                    onTap: () => _abrirRuta(context, '/repartidores'),
                  ),
                  _DrawerRouteTile(
                    icon: Icons.inventory_2_outlined,
                    title: 'Inventario',
                    selected: currentRoute == '/inventario',
                    onTap: () => _abrirRuta(context, '/inventario'),
                  ),
                  _DrawerRouteTile(
                    icon: Icons.business_outlined,
                    title: 'Empresas',
                    selected: currentRoute == '/empresa',
                    onTap: () => _abrirRuta(context, '/empresa'),
                  ),
                ] else ...[
                  _DrawerRouteTile(
                    icon: Icons.route_outlined,
                    title: 'Mi ruta asignada',
                    selected: currentRoute == '/mi-ruta',
                    onTap: () => _abrirRuta(context, '/mi-ruta'),
                  ),
                  _DrawerRouteTile(
                    icon: Icons.fact_check_outlined,
                    title: 'Estado de entregas',
                    selected: currentRoute == '/mi-ruta',
                    onTap: () => _abrirRuta(context, '/mi-ruta'),
                  ),
                ],
                const Spacer(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DrawerRouteTile extends StatelessWidget {
  const _DrawerRouteTile({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      selected: selected,
      selectedTileColor: Colors.green.withValues(alpha: 0.12),
      selectedColor: Colors.green[800],
      onTap: onTap,
    );
  }
}
