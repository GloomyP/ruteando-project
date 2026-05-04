import 'package:google_maps_flutter/google_maps_flutter.dart';

class RutaGoogle {
  const RutaGoogle({
    required this.distanciaMetros,
    required this.duracionSegundos,
    required this.puntos,
  });

  final int distanciaMetros;
  final int duracionSegundos;
  final List<LatLng> puntos;

  double get consumoEstimado {
    final distanciaKm = distanciaMetros / 1000;
    final duracionHoras = duracionSegundos / 3600;
    return (distanciaKm * 0.11) + (duracionHoras * 0.65);
  }
}

Future<List<RutaGoogle>> obtenerRutasGoogle({
  required String origen,
  required String destino,
}) {
  throw UnsupportedError(
    'La consulta de rutas en este proyecto esta implementada para web.',
  );
}
