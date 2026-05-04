import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'directions_service.dart'
    if (dart.library.js) 'directions_service_web.dart';
import 'location_service.dart' if (dart.library.js) 'location_service_web.dart';

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

  final TextEditingController _origenController = TextEditingController(
    text: 'Plaza Sotomayor, Valparaiso, Chile',
  );
  final TextEditingController _destinoController = TextEditingController(
    text: 'Terminal Rodoviario Valparaiso, Chile',
  );

  GoogleMapController? _mapController;

  String _distanciaTotal = 'Sin ruta';
  String _tiempoTotal = 'Sin ruta';
  String _estimacionTitulo = 'Estimacion:';
  String _estimacionValor = 'Ingresa origen y destino';
  String _estado = 'Listo para generar una ruta.';
  bool _cargando = false;
  bool _obteniendoUbicacion = false;
  late String _criterioSeleccionado;

  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _criterioSeleccionado = _criteriosOptimizacion.contains(widget.criterio)
        ? widget.criterio!
        : _criteriosOptimizacion.first;
  }

  @override
  void dispose() {
    _origenController.dispose();
    _destinoController.dispose();
    super.dispose();
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
    final destino = _destinoController.text.trim();

    if (origen.isEmpty || destino.isEmpty) {
      setState(() {
        _estado = 'Debes ingresar origen y destino.';
      });
      return;
    }

    setState(() {
      _cargando = true;
      _estado = 'Consultando Google Directions...';
      _distanciaTotal = 'Calculando...';
      _tiempoTotal = 'Calculando...';
      _estimacionTitulo = 'Estimacion:';
      _estimacionValor = 'Calculando...';
    });

    try {
      final rutas = await obtenerRutasGoogle(origen: origen, destino: destino);

      if (rutas.isEmpty) {
        setState(() {
          _estado = 'La respuesta no incluye puntos para dibujar la ruta.';
          _cargando = false;
        });
        return;
      }

      final rutaSeleccionada = _seleccionarRuta(rutas);
      final estimacion = _calcularEstimacion(rutaSeleccionada, rutas);

      setState(() {
        _distanciaTotal =
            '${(rutaSeleccionada.distanciaMetros / 1000).toStringAsFixed(1)} km';
        _tiempoTotal =
            '${(rutaSeleccionada.duracionSegundos / 60).round()} min';
        _estimacionTitulo = estimacion['titulo']!;
        _estimacionValor = estimacion['valor']!;
        _estado = 'Ruta generada con ${rutas.length} alternativa(s).';
        _cargando = false;
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
            markerId: const MarkerId('destino'),
            position: rutaSeleccionada.puntos.last,
            infoWindow: InfoWindow(title: 'Destino', snippet: destino),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed,
            ),
          ),
        };
      });

      await _ajustarCamara(rutaSeleccionada.puntos);
    } catch (e) {
      setState(() {
        _estado = 'Error consultando la ruta: $e';
        _cargando = false;
      });
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
          Positioned(
            top: 16,
            left: 12,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Card(
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
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
                            prefixIcon: const Icon(Icons.trip_origin, size: 20),
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
                        TextField(
                          controller: _destinoController,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _generarRuta(),
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'Destino',
                            prefixIcon: Icon(Icons.place, size: 20),
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
