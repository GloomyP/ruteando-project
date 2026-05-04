class UbicacionActual {
  const UbicacionActual({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  String get comoOrigenGoogle => '$latitude,$longitude';
}

Future<UbicacionActual> obtenerUbicacionActual() {
  throw UnsupportedError(
    'La ubicacion actual esta implementada para la version web.',
  );
}
