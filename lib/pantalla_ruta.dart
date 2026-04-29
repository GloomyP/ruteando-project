import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class PantallaRuta extends StatefulWidget {
  final String? criterio;
  const PantallaRuta({super.key, this.criterio});

  @override
  State<PantallaRuta> createState() => _PantallaRutaState();
}

class _PantallaRutaState extends State<PantallaRuta> {
  late GoogleMapController mapController;

  // Coordenadas fijas en Valparaiso para el MVP.
  final LatLng _puntoOrigen = const LatLng(-33.0458, -71.6197);
  final LatLng _puntoDestino = const LatLng(-33.0488, -71.6127);
  final LatLng _waypoint1 = const LatLng(-33.0465, -71.6150);
  final LatLng _waypoint2 = const LatLng(-33.0442, -71.6109);
  final LatLng _waypoint3 = const LatLng(-33.0508, -71.6171);

  String _distanciaTotal = 'Calculando...';
  String _tiempoTotal = 'Calculando...';
  String _estimacionTitulo = 'Estimacion:';
  String _estimacionValor = 'Calculando...';
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

  // API Key corregida (W mayuscula y sin caracteres extra).
  final String _googleApiKey = 'AIzaSyCOZU6OnAkzM5ln9yiCWOoEQtbdlWlWURU';

  @override
  void initState() {
    super.initState();
    _configurarMarcadores();
    _obtenerRutaOptimizada();
  }

  void _configurarMarcadores() {
    _markers = {
      Marker(
        markerId: const MarkerId('origen'),
        position: _puntoOrigen,
        infoWindow: const InfoWindow(title: 'Punto de Partida'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
      Marker(
        markerId: const MarkerId('entrega1'),
        position: _waypoint1,
        infoWindow: const InfoWindow(title: 'Visita 1'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      ),
      Marker(
        markerId: const MarkerId('entrega2'),
        position: _waypoint2,
        infoWindow: const InfoWindow(title: 'Visita 2'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
      ),
      Marker(
        markerId: const MarkerId('entrega3'),
        position: _waypoint3,
        infoWindow: const InfoWindow(title: 'Visita 3'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
      ),
      Marker(
        markerId: const MarkerId('destino'),
        position: _puntoDestino,
        infoWindow: const InfoWindow(title: 'Destino Final'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };
  }

  String get _criterioNormalizado => (widget.criterio ?? '').toLowerCase();

  String get _criterioMostrado {
    if (widget.criterio == null || widget.criterio!.isEmpty) {
      return 'Tiempo mas rapido';
    }

    return widget.criterio!;
  }

  bool get _optimizaDistancia => _criterioNormalizado.contains('distancia');

  bool get _optimizaCombustible => _criterioNormalizado.contains('combustible');

  List<LatLng> _waypointsPorCriterio() {
    if (_optimizaDistancia) {
      return [_waypoint2, _waypoint1, _waypoint3];
    }

    if (_optimizaCombustible) {
      return [_waypoint3, _waypoint1, _waypoint2];
    }

    return [_waypoint1, _waypoint2, _waypoint3];
  }

  String _parametroWaypoints(List<LatLng> puntos) {
    final puntosTexto = puntos
        .map((punto) => '${punto.latitude},${punto.longitude}')
        .join('|');

    if (_optimizaDistancia || _optimizaCombustible) {
      return puntosTexto;
    }

    return 'optimize:true|$puntosTexto';
  }

  Color _colorRuta() {
    if (_optimizaDistancia) {
      return Colors.green;
    }

    if (_optimizaCombustible) {
      return Colors.orange;
    }

    return Colors.blueAccent;
  }

  String _parametrosExtraGoogle() {
    if (_optimizaCombustible) {
      return '&avoid=highways';
    }

    if (_optimizaDistancia) {
      return '&alternatives=true';
    }

    return '';
  }

  Map<String, String> _calcularEstimacion(double distKm, int tiempoMin) {
    if (_optimizaDistancia) {
      final ahorroDistancia = distKm * 0.08;
      return {
        'titulo': 'Ahorro estimado de distancia:',
        'valor': '${ahorroDistancia.toStringAsFixed(1)} km',
      };
    }

    if (_optimizaCombustible) {
      final litrosEstimados = distKm * 0.11;
      final ahorroCombustible = litrosEstimados * 0.12;
      return {
        'titulo': 'Ahorro estimado de combustible:',
        'valor': '${ahorroCombustible.toStringAsFixed(2)} L',
      };
    }

    final ahorroTiempo = (tiempoMin * 0.10).clamp(1, 999).round();
    return {
      'titulo': 'Ahorro estimado de tiempo:',
      'valor': '$ahorroTiempo min',
    };
  }

  Future<void> _obtenerRutaOptimizada() async {
    String origin = '${_puntoOrigen.latitude},${_puntoOrigen.longitude}';
    String destination = '${_puntoDestino.latitude},${_puntoDestino.longitude}';
    String waypoints = _parametroWaypoints(_waypointsPorCriterio());

    String googleUrl =
        'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=$origin'
        '&destination=$destination'
        '&waypoints=$waypoints'
        '${_parametrosExtraGoogle()}'
        '&key=$_googleApiKey';

    String url =
        'https://api.allorigins.win/raw?url=${Uri.encodeComponent(googleUrl)}';

    try {
      debugPrint('Iniciando peticion a Google via AllOrigins...');
      var response = await http.get(Uri.parse(url));

      debugPrint('RESPUESTA RECIBIDA: ${response.body}');

      var json = jsonDecode(response.body);

      if (json['status'] == 'OK') {
        var routes = json['routes'][0];
        var legs = routes['legs'];

        int distanciaTotalMetros = 0;
        int tiempoTotalSegundos = 0;

        for (var leg in legs) {
          distanciaTotalMetros += (leg['distance']['value'] as int);
          tiempoTotalSegundos += (leg['duration']['value'] as int);
        }

        double distKm = distanciaTotalMetros / 1000;
        int tiempoMin = (tiempoTotalSegundos / 60).round();
        final estimacion = _calcularEstimacion(distKm, tiempoMin);

        PolylinePoints polylinePoints = PolylinePoints();
        List<PointLatLng> result = polylinePoints.decodePolyline(
          routes['overview_polyline']['points'],
        );

        List<LatLng> polylineCoordinates = [];
        if (result.isNotEmpty) {
          for (var point in result) {
            polylineCoordinates.add(LatLng(point.latitude, point.longitude));
          }
        }

        setState(() {
          _distanciaTotal = '${distKm.toStringAsFixed(1)} km';
          _tiempoTotal = '$tiempoMin min';
          _estimacionTitulo = estimacion['titulo']!;
          _estimacionValor = estimacion['valor']!;

          _polylines = {
            Polyline(
              polylineId: PolylineId('ruta_${_criterioMostrado.hashCode}'),
              points: polylineCoordinates,
              color: _colorRuta(),
              width: 5,
            ),
          };
        });
        debugPrint('Calculos y ruta actualizados correctamente.');
      } else {
        debugPrint('GOOGLE STATUS: ${json["status"]}');
        debugPrint('ERROR: ${json["error_message"] ?? "Sin detalles"}');
      }
    } catch (e) {
      debugPrint('Excepcion en la peticion: $e');
    }
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
            onMapCreated: (controller) => mapController = controller,
            initialCameraPosition: const CameraPosition(
              target: LatLng(-33.0458, -71.6197),
              zoom: 14.5,
            ),
            markers: _markers,
            polylines: _polylines,
          ),
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.tune, color: Colors.deepPurple),
                            SizedBox(width: 8),
                            Text(
                              'Criterio:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Flexible(
                          child: Text(
                            _criterioMostrado,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                            ),
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.directions_car, color: Colors.green),
                            SizedBox(width: 8),
                            Text(
                              'Distancia Total:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _distanciaTotal,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.timer, color: Colors.blue),
                            SizedBox(width: 8),
                            Text(
                              'Tiempo Estimado:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _tiempoTotal,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Row(
                            children: [
                              Icon(
                                _optimizaCombustible
                                    ? Icons.local_gas_station
                                    : _optimizaDistancia
                                    ? Icons.straighten
                                    : Icons.speed,
                                color: _colorRuta(),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _estimacionTitulo,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _estimacionValor,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _colorRuta(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
