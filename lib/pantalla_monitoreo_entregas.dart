import 'dart:async';
import 'package:flutter/material.dart';
import 'menu_drawer.dart';
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
  if (estado == 'En camino') return const Color(0xFFF97316);
  return const Color(0xFF64748B);
}

IconData _iconoEstadoEntrega(String estado) {
  if (estado == 'Entregado') return Icons.check_circle_outline;
  if (estado == 'En camino') return Icons.local_shipping_outlined;
  return Icons.schedule_outlined;
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

class PantallaMonitoreoEntregas extends StatefulWidget {
  const PantallaMonitoreoEntregas({super.key});

  @override
  State<PantallaMonitoreoEntregas> createState() =>
      _PantallaMonitoreoEntregasState();
}

class _PantallaMonitoreoEntregasState extends State<PantallaMonitoreoEntregas> {
  List<Map<String, dynamic>> _asignacionesActivas = [];
  bool _cargandoInicial = true;
  Timer? _timerActualizacion;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    // Actualización periódica cada 3 segundos
    _timerActualizacion = Timer.periodic(const Duration(seconds: 3), (_) {
      _cargarDatos(silencioso: true);
    });
  }

  @override
  void dispose() {
    _timerActualizacion?.cancel();
    super.dispose();
  }

  Future<void> _cargarDatos({bool silencioso = false}) async {
    if (!silencioso) {
      setState(() => _cargandoInicial = true);
    }

    final asignacionesRaw = await cargarAsignacionesGlobales();
    final List<Map<String, dynamic>> asignacionesActualizadas = [];

    for (final asignacion in asignacionesRaw) {
      final email = asignacion['repartidorEmail']?.toString() ?? '';
      if (email.isNotEmpty) {
        final rutaReal = await cargarRutaAsignada(email);
        if (rutaReal != null) {
          asignacionesActualizadas.add(rutaReal);
          continue;
        }
      }
      asignacionesActualizadas.add(asignacion);
    }

    if (!mounted) return;

    setState(() {
      _asignacionesActivas = asignacionesActualizadas;
      _cargandoInicial = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoreo de Entregas'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        actions: [CampanaNotificacionesAdmin(), const MenuPerfilAppBar()],
      ),
      drawer: const AppMenuDrawer(currentRoute: '/monitoreo-entregas'),
      body: _cargandoInicial
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _cargarDatos(silencioso: false),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: _asignacionesActivas.isEmpty
                      ? _buildEmptyState()
                      : _buildListaMonitoreo(),
                ),
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 48),
        Icon(Icons.monitor_heart_outlined, size: 96, color: Colors.grey[400]),
        const SizedBox(height: 24),
        const Text(
          'No hay rutas activas',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Actualmente no hay repartidores con rutas asignadas para monitorear.',
          style: TextStyle(fontSize: 15, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildListaMonitoreo() {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _asignacionesActivas.length,
      itemBuilder: (context, index) {
        final colors = Theme.of(context).colorScheme;
        final isDark = colors.brightness == Brightness.dark;
        final asignacion = _asignacionesActivas[index];
        final nombre =
            asignacion['repartidorNombre']?.toString() ?? 'Repartidor';
        final paradasList = asignacion['paradas'] as List? ?? [];

        final total = paradasList.length;
        final entregados = paradasList
            .where((p) => (p as Map)['estado'] == 'Entregado')
            .length;
        final enCamino = paradasList
            .where((p) => (p as Map)['estado'] == 'En camino')
            .length;
        final pendientes = total - entregados - enCamino;

        final porcentaje = total > 0 ? entregados / total : 0.0;
        final completada = entregados == total && total > 0;
        final cardColor = completada
            ? colors.primaryContainer
            : (isDark ? colors.surfaceContainerHighest : colors.surface);
        final primaryText = completada
            ? colors.onPrimaryContainer
            : colors.onSurface;
        final secondaryText = completada
            ? colors.onPrimaryContainer.withValues(alpha: 0.82)
            : colors.onSurfaceVariant;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          color: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: completada ? colors.primary : colors.outlineVariant,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: completada
                          ? const Color(0xFFDCFCE7)
                          : Colors.green[800],
                      foregroundColor: completada
                          ? const Color(0xFF166534)
                          : Colors.white,
                      child: Icon(
                        completada ? Icons.check_circle : Icons.local_shipping,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nombre,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: primaryText,
                            ),
                          ),
                          Text(
                            completada ? 'Ruta finalizada' : 'En ruta',
                            style: TextStyle(
                              fontSize: 12,
                              color: completada
                                  ? secondaryText
                                  : (isDark
                                        ? const Color(0xFF93C5FD)
                                        : Colors.blue[700]),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${(porcentaje * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: primaryText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: porcentaje,
                    minHeight: 10,
                    backgroundColor: isDark
                        ? colors.surface
                        : colors.surfaceContainerHighest,
                    color: completada
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFF97316),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.spaceAround,
                  spacing: 20,
                  runSpacing: 12,
                  children: [
                    _IndicadorEstado(
                      etiqueta: 'Pendientes',
                      valor: pendientes,
                      color: isDark ? const Color(0xFFD1D5DB) : Colors.grey,
                      labelColor: secondaryText,
                    ),
                    _IndicadorEstado(
                      etiqueta: 'En Camino',
                      valor: enCamino,
                      color: Colors.orange,
                      labelColor: secondaryText,
                    ),
                    _IndicadorEstado(
                      etiqueta: 'Entregadas',
                      valor: entregados,
                      color: const Color(0xFF16A34A),
                      labelColor: secondaryText,
                    ),
                  ],
                ),
                Divider(
                  height: 24,
                  color: completada
                      ? colors.onPrimaryContainer.withValues(alpha: 0.45)
                      : colors.outlineVariant,
                ),
                // --- Aquí integramos el detalle desplegable ---
                Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    iconColor: primaryText,
                    collapsedIconColor: secondaryText,
                    title: Text(
                      'Ver paradas intermedias',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: primaryText,
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

class _IndicadorEstado extends StatelessWidget {
  const _IndicadorEstado({
    required this.etiqueta,
    required this.valor,
    required this.color,
    required this.labelColor,
  });

  final String etiqueta;
  final int valor;
  final Color color;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          valor.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(etiqueta, style: TextStyle(fontSize: 12, color: labelColor)),
      ],
    );
  }
}
