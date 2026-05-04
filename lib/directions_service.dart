import 'package:google_maps_flutter/google_maps_flutter.dart';

class RutaGoogle {
  const RutaGoogle({
    required this.distanciaMetros,
    required this.duracionSegundos,
    required this.puntos,
    this.ordenParadas = const [],
    this.puntosParadas = const [],
  });

  final int distanciaMetros;
  final int duracionSegundos;
  final List<LatLng> puntos;
  final List<int> ordenParadas;
  final List<LatLng> puntosParadas;

  double get consumoEstimado {
    final distanciaKm = distanciaMetros / 1000;
    final duracionHoras = duracionSegundos / 3600;
    return (distanciaKm * 0.11) + (duracionHoras * 0.65);
  }
}

Future<List<RutaGoogle>> obtenerRutasGoogle({
  required String origen,
  required String destino,
  List<String> paradas = const [],
}) {
  throw UnsupportedError(
    'La consulta de rutas en este proyecto esta implementada para web.',
  );
}
