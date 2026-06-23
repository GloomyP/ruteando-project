import 'package:flutter/material.dart';
import 'roles.dart';
import 'persistencia_rutas.dart';
import 'widgets/campana_notificaciones_admin.dart';
import 'widgets/menu_perfil_appbar.dart';

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
    final fondo = Color.alphaBlend(
      color.withValues(alpha: 0.1),
      Theme.of(context).cardTheme.color ??
          Theme.of(context).colorScheme.surface,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
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

class _RutaHistorialCard extends StatelessWidget {
  const _RutaHistorialCard({required this.ruta});

  final Map<String, dynamic> ruta;

  @override
  Widget build(BuildContext context) {
    final nombre = ruta['repartidorNombre']?.toString() ?? 'Repartidor';
    final email = ruta['repartidorEmail']?.toString() ?? '';
    final origen = ruta['origen']?.toString() ?? 'Origen no registrado';
    final paradas = ruta['paradas'] as List? ?? [];
    final destino = paradas.isNotEmpty && paradas.last is Map
        ? (paradas.last as Map)['texto']?.toString() ?? 'Destino no registrado'
        : 'Destino no registrado';
    final estadoFinal =
        ruta['estadoFinal']?.toString() ??
        ruta['estadoRecorrido']?.toString() ??
        'Completado';
    final fecha =
        ruta['fechaCompletado'] ??
        ruta['fechaAsignacion'] ??
        ruta['fechaInicio'];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.green.withValues(alpha: 0.12),
                  foregroundColor: Colors.green[800],
                  child: const Icon(Icons.route_outlined),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (email.isNotEmpty)
                        Text(
                          email,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(estadoFinal),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: Colors.green.withValues(alpha: 0.12),
                  labelStyle: TextStyle(
                    color: Colors.green[800],
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _HistorialDato(
              icon: Icons.event_outlined,
              texto: 'Fecha: ${_formatearFechaEntrega(fecha)}',
            ),
            _HistorialDato(icon: Icons.trip_origin, texto: 'Origen: $origen'),
            _HistorialDato(
              icon: Icons.location_on_outlined,
              texto: 'Destino: $destino',
            ),
            _HistorialDato(
              icon: Icons.pin_drop_outlined,
              texto: 'Paradas: ${paradas.length}',
            ),
            _HistorialDato(
              icon: Icons.play_circle_outline,
              texto: 'Inicio: ${_formatearFechaEntrega(ruta['fechaInicio'])}',
            ),
            _HistorialDato(
              icon: Icons.flag_circle_outlined,
              texto:
                  'Termino: ${_formatearFechaEntrega(ruta['fechaCompletado'])}',
            ),
          ],
        ),
      ),
    );
  }
}

class _HistorialDato extends StatelessWidget {
  const _HistorialDato({required this.icon, required this.texto});

  final IconData icon;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Expanded(child: Text(texto, style: const TextStyle(fontSize: 13))),
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
    final fondo = Color.alphaBlend(
      color.withValues(alpha: 0.12),
      Theme.of(context).cardTheme.color ??
          Theme.of(context).colorScheme.surface,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: fondo,
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
          if (_rutaEstaTerminada(rutaReal)) {
            await registrarRutaTerminada(rutaReal);
            await liberarRepartidorDeRutaActiva(email);
            continue;
          }
          // Usar la versión más reciente guardada por el conductor
          asignacionesActualizadas.add(rutaReal);
          continue;
        }
      }
      if (_rutaEstaTerminada(asignacion)) {
        await registrarRutaTerminada(asignacion);
        await liberarRepartidorDeRutaActiva(email);
        continue;
      }
      asignacionesActualizadas.add(asignacion);
    }

    setState(() {
      _asignaciones = asignacionesActualizadas;
      _cargando = false;
    });
  }

  bool _rutaEstaTerminada(Map<String, dynamic> ruta) {
    final estado = ruta['estadoRecorrido']?.toString();
    return estado == 'Completado';
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

  Future<void> _mostrarHistorialRutas() async {
    final historial = await cargarHistorialRutasTerminadas();
    historial.sort((a, b) {
      final fechaA =
          DateTime.tryParse(
            a['fechaCompletado']?.toString() ??
                a['fechaAsignacion']?.toString() ??
                '',
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final fechaB =
          DateTime.tryParse(
            b['fechaCompletado']?.toString() ??
                b['fechaAsignacion']?.toString() ??
                '',
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return fechaB.compareTo(fechaA);
    });

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          title: const Text('Historial de rutas'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620, maxHeight: 560),
            child: historial.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Text('No hay rutas terminadas en el historial.'),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: historial.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      return _RutaHistorialCard(ruta: historial[index]);
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _cambiarRepartidor(Map<String, dynamic> asignacion) async {
    final emailActual = asignacion['repartidorEmail']?.toString() ?? '';
    final nombreActual =
        asignacion['repartidorNombre']?.toString() ?? 'Repartidor';
    final repartidores = await cargarRepartidoresAsignables();
    final emailsAsignados = _asignaciones
        .map((a) => a['repartidorEmail']?.toString().toLowerCase().trim())
        .whereType<String>()
        .toSet();
    final disponibles = repartidores.where((repartidor) {
      final email = repartidor['correo']?.toLowerCase().trim() ?? '';
      return email.isNotEmpty &&
          email != emailActual.toLowerCase().trim() &&
          !emailsAsignados.contains(email);
    }).toList();

    if (!mounted) return;

    if (disponibles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay otros repartidores disponibles.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Map<String, String>? seleccionado = disponibles.first;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Cambiar repartidor'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ruta actual asignada a $nombreActual.'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Map<String, String>>(
                    initialValue: seleccionado,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Nuevo repartidor',
                      isDense: true,
                    ),
                    items: disponibles.map((repartidor) {
                      return DropdownMenuItem<Map<String, String>>(
                        value: repartidor,
                        child: Text(
                          '${repartidor['nombre']} (${repartidor['correo']})',
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => seleccionado = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Se mantendran los datos de la ruta y solo cambiara el repartidor asignado.',
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Confirmar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmar != true || seleccionado == null) {
      return;
    }

    if (!mounted) return;

    if (!esConductorRepartidor(seleccionado!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solo puedes asignar rutas a usuarios repartidores.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final nuevoEmail = seleccionado!['correo']?.trim() ?? '';
    final nuevoNombre = seleccionado!['nombre']?.trim() ?? '';
    if (nuevoEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El repartidor seleccionado no tiene correo valido.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _cargando = true);

    final nuevaAsignacion = Map<String, dynamic>.from(asignacion)
      ..['repartidorEmail'] = nuevoEmail
      ..['repartidorNombre'] = nuevoNombre;

    await borrarRutaAsignada(emailActual);
    await guardarRutaAsignada(nuevoEmail, nuevaAsignacion);
    await guardarNotificacionRuta(nuevoEmail, {
      'titulo': 'Nueva ruta asignada',
      'mensaje': 'Tienes una ruta optimizada pendiente.',
      'origen': nuevaAsignacion['origen'],
      'paradas': (nuevaAsignacion['paradas'] as List?)?.length ?? 0,
      'distancia': nuevaAsignacion['distancia'],
      'tiempo': nuevaAsignacion['tiempo'],
      'criterio': nuevaAsignacion['criterio'],
      'rutaDestino': '/mi-ruta',
      'leida': false,
      'fechaCreacion': DateTime.now().toIso8601String(),
    });

    final asignaciones = await cargarAsignacionesGlobales();
    asignaciones.removeWhere((a) {
      final email = a['repartidorEmail']?.toString().toLowerCase().trim();
      return email == emailActual.toLowerCase().trim() ||
          email == nuevoEmail.toLowerCase().trim();
    });
    asignaciones.add(nuevaAsignacion);
    await guardarAsignacionesGlobales(asignaciones);

    await _cargarDatos();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ruta reasignada a $nuevoNombre.'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asignación de Rutas'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        actions: [CampanaNotificacionesAdmin(), const MenuPerfilAppBar()],
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
                ],
              );
            },
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _cargarDatos,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: _mostrarHistorialRutas,
                        icon: const Icon(Icons.history),
                        label: const Text('Historial de rutas'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: _cargando
                            ? SizedBox(
                                height: constraints.maxHeight > 72
                                    ? constraints.maxHeight - 72
                                    : 120,
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : _asignaciones.isEmpty
                            ? _buildEmptyState()
                            : _buildListaAsignaciones(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                backgroundColor: Colors.green[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListaAsignaciones() {
    return Column(
      children: List.generate(_asignaciones.length, (index) {
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
                    TextButton.icon(
                      onPressed: () => _cambiarRepartidor(asignacion),
                      icon: const Icon(Icons.swap_horiz, size: 18),
                      label: const Text('Cambiar repartidor'),
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
      }),
    );
  }
}
