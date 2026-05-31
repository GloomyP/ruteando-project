import 'dart:async';
import 'package:flutter/material.dart';
import 'menu_drawer.dart';
import 'persistencia_rutas.dart';
import 'pantalla_perfil.dart';

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

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: completada ? 1 : 4,
          color: completada ? Colors.green[50] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: completada ? Colors.green.shade300 : Colors.transparent,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: completada
                          ? Colors.green[200]
                          : Colors.blue[100],
                      foregroundColor: completada
                          ? Colors.green[800]
                          : Colors.blue[800],
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
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            completada ? 'Ruta finalizada' : 'En ruta',
                            style: TextStyle(
                              fontSize: 12,
                              color: completada
                                  ? Colors.green[700]
                                  : Colors.blue[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${(porcentaje * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
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
                    backgroundColor: Colors.grey[200],
                    color: completada ? Colors.green : Colors.blue,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _IndicadorEstado(
                      etiqueta: 'Pendientes',
                      valor: pendientes,
                      color: Colors.grey,
                    ),
                    _IndicadorEstado(
                      etiqueta: 'En Camino',
                      valor: enCamino,
                      color: Colors.orange,
                    ),
                    _IndicadorEstado(
                      etiqueta: 'Entregadas',
                      valor: entregados,
                      color: Colors.green,
                    ),
                  ],
                ),
                const Divider(height: 24),
                // --- Aquí integramos el detalle desplegable ---
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
                        estadoColor = Colors.orange;
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

class _IndicadorEstado extends StatelessWidget {
  const _IndicadorEstado({
    required this.etiqueta,
    required this.valor,
    required this.color,
  });

  final String etiqueta;
  final int valor;
  final Color color;

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
        Text(etiqueta, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
      ],
    );
  }
}
