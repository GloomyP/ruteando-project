import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'roles.dart';
import 'persistencia_rutas.dart';
import 'pantalla_perfil.dart';

String _formatearFechaEntrega(dynamic valor) {
  final texto = valor?.toString();
  if (texto == null || texto.isEmpty) {
    return 'Hora no registrada';
  }

  final fecha = DateTime.tryParse(texto);
  if (fecha == null) {
    return texto;
  }

  String dosDigitos(int numero) => numero.toString().padLeft(2, '0');
  return '${dosDigitos(fecha.day)}/${dosDigitos(fecha.month)}/${fecha.year} '
      '${dosDigitos(fecha.hour)}:${dosDigitos(fecha.minute)}';
}

Color _colorEstadoEntrega(String estado) {
  if (estado == 'Entregado') return const Color(0xFF16A34A);
  if (estado == 'En camino') return const Color(0xFF2563EB);
  return const Color(0xFF64748B);
}

IconData _iconoEstadoEntrega(String estado) {
  if (estado == 'Entregado') return Icons.check_circle_outline;
  if (estado == 'En camino') return Icons.local_shipping_outlined;
  return Icons.schedule_outlined;
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    required this.value,
    this.color = const Color(0xFF0B0F0D),
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
          Flexible(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineEntregaItem extends StatelessWidget {
  const _TimelineEntregaItem({
    required this.index,
    required this.texto,
    required this.estado,
    this.fechaEntrega,
  });

  final int index;
  final String texto;
  final String estado;
  final String? fechaEntrega;

  @override
  Widget build(BuildContext context) {
    final color = _colorEstadoEntrega(estado);
    final icono = _iconoEstadoEntrega(estado);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 0.28)),
                ),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(width: 2, height: 28, color: const Color(0xFFE5E7EB)),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAF9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    texto,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _EstadoChip(estado: estado, icono: icono, color: color),
                      if (fechaEntrega != null)
                        _HoraEntregaChip(fechaEntrega: fechaEntrega!),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EstadoChip extends StatelessWidget {
  const _EstadoChip({
    required this.estado,
    required this.icono,
    required this.color,
  });

  final String estado;
  final IconData icono;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            estado,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HoraEntregaChip extends StatelessWidget {
  const _HoraEntregaChip({required this.fechaEntrega});

  final String fechaEntrega;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0F0D),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            fechaEntrega,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

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
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cerrar sesion'),
          content: const Text('¿Quieres cerrar tu sesion de forma segura?'),
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

    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.popUntil((route) => route.isFirst);
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
                          backgroundColor: const Color(0xFFE9F8EF),
                          child: Icon(
                            Icons.local_shipping,
                            color: const Color(0xFF0B0F0D),
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
              backgroundColor: Colors.green[800],
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
              backgroundColor: Colors.green[800],
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
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
                            backgroundColor: Colors.green[800],
                            foregroundColor: Colors.white,
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
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.trip_origin,
                      size: 16,
                      color: Color(0xFF2563EB),
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
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    _InfoPill(
                      icon: Icons.route_outlined,
                      label: 'Distancia',
                      value: '${asignacion['distancia'] ?? 'N/A'}',
                      color: const Color(0xFF16A34A),
                    ),
                    _InfoPill(
                      icon: Icons.timer_outlined,
                      label: 'Tiempo',
                      value: '${asignacion['tiempo'] ?? 'N/A'}',
                      color: const Color(0xFF2563EB),
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
                    const Expanded(
                      child: Text(
                        'Estado de las entregas',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Progreso: $entregados / $total entregados',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                    color: entregados == total
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFF97316),
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
                      final fechaEntrega = estado == 'Entregado'
                          ? _formatearFechaEntrega(parada['fechaEntrega'])
                          : null;

                      return _TimelineEntregaItem(
                        index: idx,
                        texto: texto,
                        estado: estado,
                        fechaEntrega: fechaEntrega,
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
