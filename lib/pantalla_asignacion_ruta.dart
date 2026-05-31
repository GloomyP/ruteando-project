import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'roles.dart';
import 'persistencia_rutas.dart';
import 'pantalla_perfil.dart';

class PantallaAsignacionRuta extends StatefulWidget {
  const PantallaAsignacionRuta({super.key});

  @override
  State<PantallaAsignacionRuta> createState() => _PantallaAsignacionRutaState();
}

class _PantallaAsignacionRutaState extends State<PantallaAsignacionRuta> {
  List<Map<String, dynamic>> _asignaciones = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);

    // Cargar asignaciones globales
    final asignacionesRaw = await cargarAsignacionesGlobales();
    final List<Map<String, dynamic>> asignacionesActualizadas = [];

    // Para cada asignación, buscar el estado real y más actualizado del conductor
    for (final asignacion in asignacionesRaw) {
      final email = asignacion['repartidorEmail']?.toString() ?? '';
      if (email.isNotEmpty) {
        final rutaReal = await cargarRutaAsignada(email);
        if (rutaReal != null) {
          // Usar la versión más reciente guardada por el conductor
          asignacionesActualizadas.add(rutaReal);
          continue;
        }
      }
      asignacionesActualizadas.add(asignacion);
    }

    setState(() {
      _asignaciones = asignacionesActualizadas;
      _cargando = false;
    });
  }

  Future<void> _eliminarAsignacion(String email, String nombre) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Eliminar asignación'),
          content: Text(
            '¿Estás seguro de que quieres eliminar la ruta asignada a $nombre?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

    setState(() => _cargando = true);

    // 1. Borrar la asignación individual del conductor
    await borrarRutaAsignada(email);

    // 2. Borrar de la lista global
    final asignaciones = await cargarAsignacionesGlobales();
    asignaciones.removeWhere((a) => a['repartidorEmail'] == email);
    await guardarAsignacionesGlobales(asignaciones);

    // 3. Recargar
    await _cargarDatos();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Asignación de $nombre eliminada con éxito'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _abrirPantalla(BuildContext context, String ruta) async {
    Navigator.pop(context);

    if (ruta == '/asignacion-rutas') {
      return;
    }

    final rol = await cargarRolUsuario();
    final rutaAdmin = ruta != '/mi-ruta';
    if (rutaAdmin && !puedeAdministrar(rol)) {
      if (!context.mounted) return;
      Navigator.of(context).pushReplacementNamed('/mi-ruta');
      return;
    }

    if (!context.mounted) return;
    Navigator.of(context).pushReplacementNamed(ruta);
  }

  Future<void> _cerrarSesion(BuildContext context) async {
    Navigator.pop(context);
    Navigator.of(context).popUntil((route) => route.isFirst);
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asignación de Rutas'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Perfil',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const PantallaPerfil(),
                ),
              );
            },
            icon: const Icon(Icons.account_circle),
          ),
        ],
      ),
      drawer: Drawer(
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
                    ListTile(
                      leading: const Icon(Icons.home_outlined),
                      title: const Text('Inicio'),
                      onTap: () => _abrirPantalla(context, '/inicio'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.alt_route),
                      title: const Text('Rutas'),
                      onTap: () => _abrirPantalla(context, '/rutas'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.assignment_outlined),
                      title: const Text('Asignación de Ruta'),
                      onTap: () => _abrirPantalla(context, '/asignacion-rutas'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.monitor_heart_outlined),
                      title: const Text('Monitoreo de Entregas'),
                      onTap: () =>
                          _abrirPantalla(context, '/monitoreo-entregas'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.people_alt_outlined),
                      title: const Text('Repartidores'),
                      onTap: () => _abrirPantalla(context, '/repartidores'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.inventory_2_outlined),
                      title: const Text('Inventario'),
                      onTap: () => _abrirPantalla(context, '/inventario'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.business_outlined),
                      title: const Text('Empresas'),
                      onTap: () => _abrirPantalla(context, '/empresa'),
                    ),
                  ] else ...[
                    ListTile(
                      leading: const Icon(Icons.route_outlined),
                      title: const Text('Mi ruta asignada'),
                      onTap: () => _abrirPantalla(context, '/mi-ruta'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.fact_check_outlined),
                      title: const Text('Estado de entregas'),
                      onTap: () => _abrirPantalla(context, '/mi-ruta'),
                    ),
                  ],
                  const Spacer(),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Cerrar sesión'),
                    onTap: () => _cerrarSesion(context),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _cargarDatos,
        child: Center(
          child: _cargando
              ? const CircularProgressIndicator()
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: _asignaciones.isEmpty
                      ? _buildEmptyState()
                      : _buildListaAsignaciones(),
                ),
        ),
      ),
      floatingActionButton: _asignaciones.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () =>
                  Navigator.of(context).pushReplacementNamed('/rutas'),
              icon: const Icon(Icons.add),
              label: const Text('Nueva Asignación'),
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      shrinkWrap: true,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 48),
        Icon(Icons.assignment_outlined, size: 96, color: Colors.grey[400]),
        const SizedBox(height: 24),
        const Text(
          'Sin rutas asignadas hoy',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Genera y asigna rutas optimizadas a tus repartidores para planificar la operación diaria de tu flota.',
          style: TextStyle(fontSize: 15, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        Center(
          child: FilledButton.icon(
            onPressed: () =>
                Navigator.of(context).pushReplacementNamed('/rutas'),
            icon: const Icon(Icons.alt_route),
            label: const Text('Planificar y Optimizar Ruta'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              backgroundColor: Colors.green[700],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListaAsignaciones() {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _asignaciones.length,
      itemBuilder: (context, index) {
        final asignacion = _asignaciones[index];
        final nombre =
            asignacion['repartidorNombre']?.toString() ?? 'Repartidor';
        final email = asignacion['repartidorEmail']?.toString() ?? '';
        final origen =
            asignacion['origen']?.toString() ?? 'Origen no especificado';
        final paradasList = asignacion['paradas'] as List? ?? [];

        // Calcular estadísticas de paradas
        final total = paradasList.length;
        final entregados = paradasList
            .where((p) => (p as Map)['estado'] == 'Entregado')
            .length;
        final porcentaje = total > 0 ? entregados / total : 0.0;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.green[100],
                            foregroundColor: Colors.green[800],
                            child: const Icon(Icons.person),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nombre,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  email,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Eliminar asignación',
                      onPressed: () => _eliminarAsignacion(email, nombre),
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                    ),
                  ],
                ),
                const Divider(height: 24),
                const Text(
                  'Detalle del trayecto',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.trip_origin,
                      size: 16,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Origen: $origen',
                        style: const TextStyle(fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Destino final: ${paradasList.isNotEmpty ? (paradasList.last as Map)['texto'] : 'No definido'}',
                        style: const TextStyle(fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Distancia: ${asignacion['distancia'] ?? 'N/A'}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Tiempo: ${asignacion['tiempo'] ?? 'N/A'}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Optimización: ${asignacion['criterio'] ?? 'N/A'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.blueAccent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Estado de las entregas',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Progreso: $entregados / $total entregados',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: entregados == total
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: porcentaje,
                    backgroundColor: Colors.grey[200],
                    color: entregados == total ? Colors.green : Colors.orange,
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 12),
                // Lista compacta de paradas
                Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    title: const Text(
                      'Ver paradas intermedias',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    dense: true,
                    tilePadding: EdgeInsets.zero,
                    children: paradasList.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final parada = entry.value as Map;
                      final texto = parada['texto']?.toString() ?? '';
                      final estado =
                          parada['estado']?.toString() ?? 'Pendiente';

                      Color estadoColor = Colors.grey;
                      IconData estadoIcon = Icons.pending_outlined;
                      if (estado == 'En camino') {
                        estadoColor = Colors.blue;
                        estadoIcon = Icons.directions_car_outlined;
                      } else if (estado == 'Entregado') {
                        estadoColor = Colors.green;
                        estadoIcon = Icons.check_circle_outline;
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 10,
                              backgroundColor: Colors.green[50],
                              child: Text(
                                '${idx + 1}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.green[800],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                texto,
                                style: const TextStyle(fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: estadoColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    estadoIcon,
                                    size: 10,
                                    color: estadoColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    estado,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: estadoColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
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
