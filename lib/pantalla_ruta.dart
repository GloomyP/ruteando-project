import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'cierre_sesion.dart';
import 'directions_service.dart'
    if (dart.library.js) 'directions_service_web.dart';
import 'location_service.dart' if (dart.library.js) 'location_service_web.dart';
import 'roles.dart';
import 'persistencia_rutas.dart';
import 'widgets/campana_notificaciones_admin.dart';
import 'widgets/menu_perfil_appbar.dart';

typedef _ParadaRuta = ({int id, String texto});
typedef _RutaCandidata = ({
  RutaGoogle ruta,
  _ParadaRuta destino,
  List<_ParadaRuta> paradasIntermedias,
});

class PantallaRuta extends StatefulWidget {
  final String? criterio;
  const PantallaRuta({super.key, this.criterio});

  @override
  State<PantallaRuta> createState() => _PantallaRutaState();
}

class _PantallaRutaState extends State<PantallaRuta> {
  static const List<String> _criteriosOptimizacion = [
    'Tiempo mas rapido',
    'Menor distancia',
    'Menor consumo de combustible',
  ];

  String? _ultimoOrigen;
  List<String> _ultimasParadasOrdenadas = [];
  String? _ultimaDistancia;
  String? _ultimoTiempo;

  final TextEditingController _origenController = TextEditingController(
    text: 'Plaza Sotomayor, Valparaiso, Chile',
  );
  final List<TextEditingController> _paradaControllers = [
    TextEditingController(text: 'Terminal Rodoviario Valparaiso, Chile'),
  ];
  final List<int> _paradaIds = [0];
  int _nextParadaId = 1;

  GoogleMapController? _mapController;

  String _distanciaTotal = 'Sin ruta';
  String _tiempoTotal = 'Sin ruta';
  String _estimacionTitulo = 'Estimacion:';
  String _estimacionValor = 'Ingresa origen y paradas';
  String _estado = 'Listo para generar una ruta.';
  bool _cargando = false;
  String? _tiempoCarga;
  bool _mostrarExito = false;
  bool _obteniendoUbicacion = false;
  late String _criterioSeleccionado;
  late final Future<RolUsuario> _rolFuture;

  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

  Future<void> _cerrarSesion(BuildContext context) async {
    await confirmarYCerrarSesion(context);
  }

  Future<void> _abrirPantalla(BuildContext context, String ruta) async {
    Navigator.pop(context);

    if (ruta == '/rutas') {
      return;
    }

    final rol = await cargarRolUsuario();
    final rutaAdmin = ruta != '/mi-ruta';
    if (rutaAdmin && !puedeAdministrar(rol)) {
      if (!context.mounted) {
        return;
      }

      Navigator.of(context).pushReplacementNamed('/mi-ruta');
      return;
    }

    if (!context.mounted) {
      return;
    }

    Navigator.of(context).pushReplacementNamed(ruta);
  }

  @override
  void initState() {
    super.initState();
    _rolFuture = cargarRolUsuario();
    _criterioSeleccionado = _criteriosOptimizacion.contains(widget.criterio)
        ? widget.criterio!
        : _criteriosOptimizacion.first;
    _origenController.addListener(_onCampoRutaCambiado);
    for (final controller in _paradaControllers) {
      controller.addListener(_onCampoRutaCambiado);
    }
  }

  @override
  void dispose() {
    _origenController.removeListener(_onCampoRutaCambiado);
    _origenController.dispose();
    for (final controller in _paradaControllers) {
      controller.removeListener(_onCampoRutaCambiado);
      controller.dispose();
    }
    super.dispose();
  }

  void _onCampoRutaCambiado() {
    if (mounted) {
      setState(() {});
    }
  }

  String get _criterioNormalizado => _criterioSeleccionado.toLowerCase();

  bool get _optimizaDistancia => _criterioNormalizado.contains('distancia');

  bool get _optimizaCombustible => _criterioNormalizado.contains('combustible');

  Color _colorRuta() {
    if (_optimizaDistancia) {
      return Colors.green;
    }

    if (_optimizaCombustible) {
      return Colors.orange;
    }

    return Colors.blueAccent;
  }

  IconData _iconoEstimacion() {
    if (_optimizaCombustible) {
      return Icons.local_gas_station;
    }

    if (_optimizaDistancia) {
      return Icons.straighten;
    }

    return Icons.speed;
  }

  Future<void> _usarUbicacionActual() async {
    setState(() {
      _obteniendoUbicacion = true;
      _estado = 'Solicitando permiso de ubicacion...';
    });

    try {
      final ubicacion = await obtenerUbicacionActual();
      setState(() {
        _origenController.text = ubicacion.comoOrigenGoogle;
        _estado = 'Ubicacion actual cargada como origen.';
        _obteniendoUbicacion = false;
      });
    } catch (e) {
      setState(() {
        _estado = 'No se pudo obtener la ubicacion actual: $e';
        _obteniendoUbicacion = false;
      });
    }
  }

  Future<void> _generarRuta() async {
    final origen = _origenController.text.trim();
    final paradas = List<_ParadaRuta>.generate(_paradaControllers.length, (
      index,
    ) {
      return (
        id: _paradaIds[index],
        texto: _paradaControllers[index].text.trim(),
      );
    }).where((parada) => parada.texto.isNotEmpty).toList();

    if (origen.isEmpty || paradas.isEmpty) {
      setState(() {
        _estado = 'Debes ingresar origen y al menos una parada.';
      });
      return;
    }

    final cronometro = Stopwatch()..start();

    setState(() {
      _cargando = true;
      _mostrarExito = false;
      _tiempoCarga = null;
      _estado = 'Consultando Google Directions...';
      _distanciaTotal = 'Calculando...';
      _tiempoTotal = 'Calculando...';
      _estimacionTitulo = 'Estimacion:';
      _estimacionValor = 'Calculando...';
    });

    try {
      final rutasCandidatas = await _obtenerRutasCandidatas(origen, paradas)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              throw TimeoutException(
                'La carga de la ruta excedio los 5 segundos.',
              );
            },
          );

      if (!mounted) return;

      setState(() {
        _estado = 'Optimizando paradas...';
      });

      final rutas = rutasCandidatas.map((candidata) => candidata.ruta).toList();

      if (rutas.isEmpty) {
        cronometro.stop();
        setState(() {
          _estado = 'La respuesta no incluye puntos para dibujar la ruta.';
          _cargando = false;
          _tiempoCarga = null;
        });
        return;
      }

      final rutaSeleccionada = _seleccionarRuta(rutas);
      final rutaCandidata = rutasCandidatas.firstWhere(
        (candidata) => candidata.ruta == rutaSeleccionada,
      );
      final estimacion = _calcularEstimacion(rutaSeleccionada, rutas);

      final paradasOrdenadas = <String>[];
      final orden = rutaSeleccionada.ordenParadas;
      if (orden.isEmpty) {
        paradasOrdenadas.addAll(
          rutaCandidata.paradasIntermedias.map((p) => p.texto),
        );
      } else {
        for (final idx in orden) {
          if (idx < rutaCandidata.paradasIntermedias.length) {
            paradasOrdenadas.add(rutaCandidata.paradasIntermedias[idx].texto);
          }
        }
      }
      paradasOrdenadas.add(rutaCandidata.destino.texto);

      if (!mounted) return;

      setState(() {
        _estado = 'Dibujando ruta en el mapa...';
      });

      // Validar que los datos de la ruta son correctos antes de asignarlos.
      final puntosValidos = rutaSeleccionada.puntos.isNotEmpty;
      if (!puntosValidos) {
        cronometro.stop();
        setState(() {
          _estado = 'Los datos de la ruta estan incompletos.';
          _cargando = false;
          _tiempoCarga = null;
        });
        return;
      }

      cronometro.stop();
      final segundosCarga = (cronometro.elapsedMilliseconds / 1000)
          .toStringAsFixed(1);

      setState(() {
        _ultimoOrigen = origen;
        _ultimasParadasOrdenadas = paradasOrdenadas;
        _ultimaDistancia =
            '${(rutaSeleccionada.distanciaMetros / 1000).toStringAsFixed(1)} km';
        _ultimoTiempo =
            '${(rutaSeleccionada.duracionSegundos / 60).round()} min';

        _distanciaTotal =
            '${(rutaSeleccionada.distanciaMetros / 1000).toStringAsFixed(1)} km';
        _tiempoTotal =
            '${(rutaSeleccionada.duracionSegundos / 60).round()} min';
        _estimacionTitulo = estimacion['titulo']!;
        _estimacionValor = estimacion['valor']!;
        _tiempoCarga = '${segundosCarga}s';
        _estado = rutaCandidata.paradasIntermedias.isEmpty
            ? 'Ruta generada con 1 parada en ${segundosCarga}s.'
            : 'Ruta generada con ${paradas.length} paradas en ${segundosCarga}s.';
        _cargando = false;
        _mostrarExito = true;
        _polylines = {
          Polyline(
            polylineId: PolylineId(
              'ruta_${DateTime.now().millisecondsSinceEpoch}',
            ),
            points: rutaSeleccionada.puntos,
            color: _colorRuta(),
            width: 6,
          ),
        };
        _markers = {
          Marker(
            markerId: const MarkerId('origen'),
            position: rutaSeleccionada.puntos.first,
            infoWindow: InfoWindow(title: 'Origen', snippet: origen),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen,
            ),
          ),
          Marker(
            markerId: MarkerId('parada_${rutaCandidata.destino.id}'),
            position: rutaSeleccionada.puntos.last,
            infoWindow: InfoWindow(
              title: 'Parada final',
              snippet: rutaCandidata.destino.texto,
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed,
            ),
          ),
          ..._crearMarkersParadas(
            rutaSeleccionada,
            rutaCandidata.paradasIntermedias,
          ),
        };
      });

      // Ocultar el indicador de exito despues de 3 segundos.
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _mostrarExito = false;
          });
        }
      });

      if (mounted) {
        await _ajustarCamara(rutaSeleccionada.puntos);
      }
    } on TimeoutException {
      cronometro.stop();
      if (!mounted) return;
      setState(() {
        _estado =
            'La carga excedio 5 segundos. Intenta con menos paradas o verifica tu conexion.';
        _cargando = false;
        _tiempoCarga = null;
      });
    } catch (e) {
      cronometro.stop();
      if (!mounted) return;
      setState(() {
        _estado = 'Error consultando la ruta: $e';
        _cargando = false;
        _tiempoCarga = null;
      });
    }
  }

  Future<List<_RutaCandidata>> _obtenerRutasCandidatas(
    String origen,
    List<_ParadaRuta> paradas,
  ) async {
    if (paradas.length == 1) {
      final rutas = await obtenerRutasGoogle(
        origen: origen,
        destino: paradas.first.texto,
      );
      return rutas
          .map(
            (ruta) => (
              ruta: ruta,
              destino: paradas.first,
              paradasIntermedias: <_ParadaRuta>[],
            ),
          )
          .toList();
    }

    // Ejecutar todas las consultas en paralelo para mejor rendimiento.
    final futures = <Future<List<_RutaCandidata>>>[];
    for (var index = 0; index < paradas.length; index++) {
      final destino = paradas[index];
      final paradasIntermedias = [
        ...paradas.take(index),
        ...paradas.skip(index + 1),
      ];
      futures.add(
        obtenerRutasGoogle(
          origen: origen,
          destino: destino.texto,
          paradas: paradasIntermedias.map((parada) => parada.texto).toList(),
        ).then(
          (rutas) => rutas
              .map(
                (ruta) => (
                  ruta: ruta,
                  destino: destino,
                  paradasIntermedias: paradasIntermedias,
                ),
              )
              .toList(),
        ),
      );
    }

    final resultados = await Future.wait(futures);
    return resultados.expand((lista) => lista).toList();
  }

  Set<Marker> _crearMarkersParadas(
    RutaGoogle rutaSeleccionada,
    List<_ParadaRuta> paradasIntermedias,
  ) {
    final orden = rutaSeleccionada.ordenParadas.isEmpty
        ? List<int>.generate(paradasIntermedias.length, (index) => index)
        : rutaSeleccionada.ordenParadas;
    final markers = <Marker>{};

    for (
      var index = 0;
      index < rutaSeleccionada.puntosParadas.length && index < orden.length;
      index++
    ) {
      final paradaOriginal = orden[index];
      final parada = paradaOriginal < paradasIntermedias.length
          ? paradasIntermedias[paradaOriginal]
          : null;
      markers.add(
        Marker(
          markerId: MarkerId('parada_${parada?.id ?? 'intermedia_$index'}'),
          position: rutaSeleccionada.puntosParadas[index],
          infoWindow: InfoWindow(
            title: 'Parada ${index + 1}',
            snippet: parada?.texto ?? 'Parada ${index + 1}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
      );
    }

    return markers;
  }

  void _agregarParada() {
    setState(() {
      final controller = TextEditingController()
        ..addListener(_onCampoRutaCambiado);
      _paradaControllers.add(controller);
      _paradaIds.add(_nextParadaId++);
      _estado = 'Nueva parada agregada.';
    });
  }

  Future<void> _quitarParada(int index) async {
    if (_paradaControllers.length == 1) {
      setState(() {
        _estado = 'Debe quedar al menos una parada.';
      });
      return;
    }

    final teniaRutaCalculada = _polylines.isNotEmpty;
    final paradaId = _paradaIds.removeAt(index);
    final controller = _paradaControllers.removeAt(index);
    controller.removeListener(_onCampoRutaCambiado);
    controller.dispose();
    setState(() {
      _markers = _markers
          .where((marker) => marker.markerId.value != 'parada_$paradaId')
          .toSet();
      _estado = teniaRutaCalculada
          ? 'Parada eliminada. Recalculando ruta...'
          : 'Parada eliminada del mapa.';
    });

    if (teniaRutaCalculada) {
      await _generarRuta();
    }
  }

  RutaGoogle _seleccionarRuta(List<RutaGoogle> rutas) {
    if (_optimizaDistancia) {
      return rutas.reduce(
        (actual, siguiente) =>
            siguiente.distanciaMetros < actual.distanciaMetros
            ? siguiente
            : actual,
      );
    }

    if (_optimizaCombustible) {
      return rutas.reduce(
        (actual, siguiente) =>
            siguiente.consumoEstimado < actual.consumoEstimado
            ? siguiente
            : actual,
      );
    }

    return rutas.reduce(
      (actual, siguiente) =>
          siguiente.duracionSegundos < actual.duracionSegundos
          ? siguiente
          : actual,
    );
  }

  Map<String, String> _calcularEstimacion(
    RutaGoogle rutaSeleccionada,
    List<RutaGoogle> rutas,
  ) {
    final peorRuta = rutas.reduce((actual, siguiente) {
      if (_optimizaDistancia) {
        return siguiente.distanciaMetros > actual.distanciaMetros
            ? siguiente
            : actual;
      }

      if (_optimizaCombustible) {
        return siguiente.consumoEstimado > actual.consumoEstimado
            ? siguiente
            : actual;
      }

      return siguiente.duracionSegundos > actual.duracionSegundos
          ? siguiente
          : actual;
    });

    if (_optimizaDistancia) {
      final ahorroKm =
          math.max(
            0,
            peorRuta.distanciaMetros - rutaSeleccionada.distanciaMetros,
          ) /
          1000;
      return {
        'titulo': 'Ahorro estimado de distancia:',
        'valor': '${ahorroKm.toStringAsFixed(1)} km',
      };
    }

    if (_optimizaCombustible) {
      final ahorroLitros = math.max(
        0,
        peorRuta.consumoEstimado - rutaSeleccionada.consumoEstimado,
      );
      return {
        'titulo': 'Ahorro estimado de combustible:',
        'valor': '${ahorroLitros.toStringAsFixed(2)} L',
      };
    }

    final ahorroMin =
        (math.max(
                  0,
                  peorRuta.duracionSegundos - rutaSeleccionada.duracionSegundos,
                ) /
                60)
            .round();
    return {'titulo': 'Ahorro estimado de tiempo:', 'valor': '$ahorroMin min'};
  }

  Future<void> _ajustarCamara(List<LatLng> puntos) async {
    final controller = _mapController;
    if (controller == null || puntos.isEmpty) {
      return;
    }

    double minLat = puntos.first.latitude;
    double maxLat = puntos.first.latitude;
    double minLng = puntos.first.longitude;
    double maxLng = puntos.first.longitude;

    for (final punto in puntos) {
      minLat = math.min(minLat, punto.latitude);
      maxLat = math.max(maxLat, punto.latitude);
      minLng = math.min(minLng, punto.longitude);
      maxLng = math.max(maxLng, punto.longitude);
    }

    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        72,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ruta Optimizada'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        actions: [CampanaNotificacionesAdmin(), const MenuPerfilAppBar()],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: FutureBuilder<RolUsuario>(
            future: _rolFuture,
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
                      title: const Text('Asignacion de Ruta'),
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
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) => _mapController = controller,
            initialCameraPosition: const CameraPosition(
              target: LatLng(-33.0458, -71.6197),
              zoom: 13,
            ),
            markers: _markers,
            polylines: _polylines,
          ),
          // Overlay de carga sobre el mapa.
          if (_cargando)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black54,
                child: Center(
                  child: Card(
                    elevation: 12,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 24,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 48,
                            height: 48,
                            child: CircularProgressIndicator(
                              strokeWidth: 4,
                              color: Colors.green[700],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _estado,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tiempo limite: 5 segundos',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // Indicador de exito tras la carga.
          if (_mostrarExito)
            Positioned(
              top: 16,
              right: 12,
              child: Card(
                color: Colors.green[700],
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Ruta cargada en $_tiempoCarga',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            top: 16,
            left: 12,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 320,
                  maxHeight: MediaQuery.sizeOf(context).height * 0.58,
                ),
                child: Card(
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: _origenController,
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: 'Origen',
                              prefixIcon: const Icon(
                                Icons.trip_origin,
                                size: 20,
                              ),
                              suffixIcon: IconButton(
                                tooltip: 'Usar ubicacion actual',
                                onPressed: _obteniendoUbicacion
                                    ? null
                                    : _usarUbicacionActual,
                                icon: _obteniendoUbicacion
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.my_location, size: 20),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Theme(
                            data: Theme.of(
                              context,
                            ).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              childrenPadding: EdgeInsets.zero,
                              maintainState: true,
                              initiallyExpanded: false,
                              leading: const Icon(Icons.location_on, size: 20),
                              title: Text(
                                'Paradas (${_paradaControllers.length})',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: const Text(
                                'Toca para editar la lista',
                                style: TextStyle(fontSize: 11),
                              ),
                              children: [
                                const SizedBox(height: 8),
                                ...List.generate(_paradaControllers.length, (
                                  index,
                                ) {
                                  final esUltima =
                                      index == _paradaControllers.length - 1;
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      bottom: esUltima ? 0 : 8,
                                    ),
                                    child: TextField(
                                      controller: _paradaControllers[index],
                                      textInputAction: esUltima
                                          ? TextInputAction.done
                                          : TextInputAction.next,
                                      onSubmitted: esUltima
                                          ? (_) => _generarRuta()
                                          : null,
                                      style: const TextStyle(fontSize: 13),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        labelText: 'Parada ${index + 1}',
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 12,
                                            ),
                                        prefixIcon: const Icon(
                                          Icons.place,
                                          size: 20,
                                        ),
                                        suffixIcon: IconButton(
                                          tooltip: 'Eliminar parada',
                                          onPressed: _cargando
                                              ? null
                                              : () => _quitarParada(index),
                                          icon: const Icon(
                                            Icons.remove_circle_outline,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: _cargando
                                        ? null
                                        : _agregarParada,
                                    icon: const Icon(
                                      Icons.add_location_alt,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'Agregar parada',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _estado,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 18,
            left: 12,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _criterioSeleccionado,
                          isDense: true,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'Optimizacion',
                            prefixIcon: Icon(Icons.tune, size: 20),
                          ),
                          items: _criteriosOptimizacion.map((criterio) {
                            return DropdownMenuItem<String>(
                              value: criterio,
                              child: Text(
                                criterio,
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: _cargando
                              ? null
                              : (criterio) {
                                  if (criterio == null) {
                                    return;
                                  }

                                  setState(() {
                                    _criterioSeleccionado = criterio;
                                    _estado =
                                        'Criterio actualizado. Optimiza para recalcular.';
                                  });
                                },
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _cargando ? null : _generarRuta,
                            icon: _cargando
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.route, size: 18),
                            label: Text(
                              _cargando ? 'Optimizando...' : 'Optimizar ruta',
                              style: const TextStyle(fontSize: 13),
                            ),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(36),
                              backgroundColor: Colors.green[700],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: (_cargando || _polylines.isEmpty)
                                ? null
                                : () => _mostrarDialogoAsignacion(context),
                            icon: const Icon(Icons.assignment_ind, size: 18),
                            label: const Text(
                              'Asignar ruta',
                              style: TextStyle(fontSize: 13),
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(36),
                              foregroundColor: Colors.blue[700],
                              side: BorderSide(
                                color: _polylines.isEmpty
                                    ? Colors.grey.shade300
                                    : Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ),
                        const Divider(height: 12),
                        _FilaResumen(
                          icono: Icons.directions_car,
                          color: Colors.green,
                          etiqueta: 'Distancia:',
                          valor: _distanciaTotal,
                        ),
                        const Divider(height: 12),
                        _FilaResumen(
                          icono: Icons.timer,
                          color: Colors.blue,
                          etiqueta: 'Tiempo:',
                          valor: _tiempoTotal,
                        ),
                        const Divider(height: 12),
                        _FilaResumen(
                          icono: _iconoEstimacion(),
                          color: _colorRuta(),
                          etiqueta: _estimacionTitulo,
                          valor: _estimacionValor,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarDialogoAsignacion(BuildContext context) async {
    if (_polylines.isEmpty ||
        _ultimoOrigen == null ||
        _ultimasParadasOrdenadas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe generar una ruta optimizada antes de asignarla.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _cargando = true;
      _estado = 'Cargando conductores...';
    });

    final repartidores = await cargarRepartidoresAsignables();
    final asignacionesActivas = await cargarAsignacionesGlobales();
    final emailsOcupados = asignacionesActivas
        .map(
          (asignacion) =>
              asignacion['repartidorEmail']?.toString().toLowerCase().trim(),
        )
        .whereType<String>()
        .toSet();
    final conductores = repartidores.where((repartidor) {
      final email = repartidor['correo']?.toLowerCase().trim() ?? '';
      return email.isNotEmpty && !emailsOcupados.contains(email);
    }).toList();

    setState(() {
      _cargando = false;
      _estado = 'Conductores cargados.';
    });

    if (!context.mounted) return;

    if (conductores.isEmpty) {
      showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Sin repartidores'),
            content: const Text(
              'No tienes repartidores registrados en tu empresa. '
              'Registra repartidores antes de asignar una ruta.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cerrar'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  Navigator.of(context).pushReplacementNamed('/repartidores');
                },
                child: const Text('Registrar Repartidores'),
              ),
            ],
          );
        },
      );
      return;
    }

    Map<String, String>? conductorSeleccionado = conductores.first;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Asignar Ruta Optimizada'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Selecciona un repartidor disponible:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Map<String, String>>(
                    initialValue: conductorSeleccionado,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Repartidor',
                      isDense: true,
                    ),
                    items: conductores.map((c) {
                      return DropdownMenuItem<Map<String, String>>(
                        value: c,
                        child: Text('${c['nombre']} (${c['correo']})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          conductorSeleccionado = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Resumen de la ruta:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Origen: $_ultimoOrigen',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text('• Paradas: ${_ultimasParadasOrdenadas.length}'),
                  Text('• Distancia: $_ultimaDistancia'),
                  Text('• Tiempo estimado: $_ultimoTiempo'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();
                    await _confirmarAsignacion(context, conductorSeleccionado!);
                  },
                  child: const Text('Asignar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _mensajeErrorAsignacion(Object error) {
    final texto = error.toString();
    if (texto.contains('Supabase') ||
        texto.contains('Unable to establish connection on channel')) {
      return 'No se pudo conectar con Supabase. Revisa la conexion, las tablas y permisos de la base de datos.';
    }

    return texto;
  }

  Future<void> _confirmarAsignacion(
    BuildContext context,
    Map<String, String> conductor,
  ) async {
    final email = conductor['correo'] ?? '';
    final nombre = conductor['nombre'] ?? '';

    if (!esConductorRepartidor(conductor)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solo puedes asignar rutas a usuarios repartidores.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El conductor seleccionado no tiene correo válido.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _cargando = true;
      _estado = 'Guardando asignación...';
    });

    try {
      final asignacionData = {
        'origen': _ultimoOrigen,
        'paradas': _ultimasParadasOrdenadas.map((texto) {
          return {'texto': texto, 'estado': 'Pendiente'};
        }).toList(),
        'distancia': _ultimaDistancia,
        'tiempo': _ultimoTiempo,
        'criterio': _criterioSeleccionado,
        'fechaAsignacion': DateTime.now().toIso8601String(),
        'repartidorEmail': email,
        'repartidorNombre': nombre,
      };

      await guardarRutaAsignada(email, asignacionData);
      await guardarNotificacionRuta(email, {
        'titulo': 'Nueva ruta asignada',
        'mensaje': 'Tienes una ruta optimizada pendiente.',
        'origen': _ultimoOrigen,
        'paradas': _ultimasParadasOrdenadas.length,
        'distancia': _ultimaDistancia,
        'tiempo': _ultimoTiempo,
        'criterio': _criterioSeleccionado,
        'rutaDestino': '/mi-ruta',
        'leida': false,
        'fechaCreacion': DateTime.now().toIso8601String(),
      });

      final asignaciones = await cargarAsignacionesGlobales();

      asignaciones.removeWhere((a) => a['repartidorEmail'] == email);
      asignaciones.add(asignacionData);

      await guardarAsignacionesGlobales(asignaciones);

      setState(() {
        _cargando = false;
        _estado = 'Ruta asignada exitosamente.';
      });

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ruta asignada con éxito a $nombre'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pushReplacementNamed('/asignacion-rutas');
    } catch (e) {
      final mensaje = _mensajeErrorAsignacion(e);
      setState(() {
        _cargando = false;
        _estado = 'Error al asignar: $mensaje';
      });

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar la asignación: $mensaje'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _FilaResumen extends StatelessWidget {
  const _FilaResumen({
    required this.icono,
    required this.color,
    required this.etiqueta,
    required this.valor,
  });

  final IconData icono;
  final Color color;
  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Row(
            children: [
              Icon(icono, color: color),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  etiqueta,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            valor,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
