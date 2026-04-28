import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class PantallaRuta extends StatefulWidget {
  final String? criterio;
  const PantallaRuta({super.key, this.criterio});

  @override
  State<PantallaRuta> createState() => _PantallaRutaState();
}

class _PantallaRutaState extends State<PantallaRuta> {
  late GoogleMapController mapController;

  // Coordenadas fijas en Valparaíso para el MVP
  final LatLng _puntoOrigen = const LatLng(-33.0458, -71.6197);
  final LatLng _puntoDestino = const LatLng(-33.0488, -71.6127);
  final LatLng _waypoint1 = const LatLng(-33.0465, -71.6150);

  String _distanciaTotal = "Calculando...";
  String _tiempoTotal = "Calculando...";
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

  // API Key corregida (W mayúscula y sin caracteres extra)
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
        markerId: const MarkerId('destino'),
        position: _puntoDestino,
        infoWindow: const InfoWindow(title: 'Destino Final'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };
  }

  Future<void> _obtenerRutaOptimizada() async {
    String origin = "${_puntoOrigen.latitude},${_puntoOrigen.longitude}";
    String destination = "${_puntoDestino.latitude},${_puntoDestino.longitude}";
    String waypoints = "${_waypoint1.latitude},${_waypoint1.longitude}";

    // 1. Construcción de la URL de Google
    String googleUrl = "https://maps.googleapis.com/maps/api/directions/json?"
        "origin=$origin"
        "&destination=$destination"
        "&waypoints=optimize:true|$waypoints" 
        "&key=$_googleApiKey";

    // 2. Uso del proxy AllOrigins para evitar bloqueos de CORS en el navegador
    String url = "https://api.allorigins.win/raw?url=${Uri.encodeComponent(googleUrl)}";

    try {
      debugPrint("Iniciando petición a Google via AllOrigins...");
      var response = await http.get(Uri.parse(url));
      
      debugPrint("RESPUESTA RECIBIDA: ${response.body}");

      var json = jsonDecode(response.body);

      if (json["status"] == "OK") {
        var routes = json["routes"][0];
        var legs = routes["legs"];

        int distanciaTotalMetros = 0;
        int tiempoTotalSegundos = 0;

        for (var leg in legs) {
          distanciaTotalMetros += (leg["distance"]["value"] as int);
          tiempoTotalSegundos += (leg["duration"]["value"] as int);
        }

        double distKm = distanciaTotalMetros / 1000;
        int tiempoMin = (tiempoTotalSegundos / 60).round();

        PolylinePoints polylinePoints = PolylinePoints();
        List<PointLatLng> result = polylinePoints.decodePolyline(routes["overview_polyline"]["points"]);
        
        List<LatLng> polylineCoordinates = [];
        if (result.isNotEmpty) {
          for (var point in result) {
            polylineCoordinates.add(LatLng(point.latitude, point.longitude));
          }
        }

        setState(() {
          _distanciaTotal = "${distKm.toStringAsFixed(1)} km";
          _tiempoTotal = "$tiempoMin min";
          
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('ruta_optimizada'),
              points: polylineCoordinates,
              color: Colors.blueAccent,
              width: 5,
            ),
          );
        });
        debugPrint("Cálculos y ruta actualizados correctamente.");
      } else {
        debugPrint("GOOGLE STATUS: ${json["status"]}");
        debugPrint("ERROR: ${json["error_message"] ?? 'Sin detalles'}");
      }
    } catch (e) {
      debugPrint("Excepción en la petición: $e");
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
            initialCameraPosition: CameraPosition(
              target: _puntoOrigen,
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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
                            Icon(Icons.directions_car, color: Colors.green),
                            SizedBox(width: 8),
                            Text('Distancia Total:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                          ],
                        ),
                        Text(_distanciaTotal, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
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
                            Text('Tiempo Estimado:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                          ],
                        ),
                        Text(_tiempoTotal, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
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