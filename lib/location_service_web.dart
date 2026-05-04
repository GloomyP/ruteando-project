import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'location_service.dart';

export 'location_service.dart' show UbicacionActual;

@JS('navigator.geolocation')
external _Geolocation? get _geolocation;

extension type _Geolocation._(JSObject _) implements JSObject {
  external void getCurrentPosition(JSFunction success, JSFunction error);
}

Future<UbicacionActual> obtenerUbicacionActual() {
  final geolocation = _geolocation;
  if (geolocation == null) {
    return Future.error('Este navegador no soporta geolocalizacion.');
  }

  final completer = Completer<UbicacionActual>();

  geolocation.getCurrentPosition(
    ((JSObject position) {
      final coords = position.getProperty<JSObject>('coords'.toJS);
      final latitude = coords
          .getProperty<JSNumber>('latitude'.toJS)
          .toDartDouble;
      final longitude = coords
          .getProperty<JSNumber>('longitude'.toJS)
          .toDartDouble;

      completer.complete(
        UbicacionActual(latitude: latitude, longitude: longitude),
      );
    }).toJS,
    ((JSObject error) {
      final message = error.getProperty<JSString?>('message'.toJS)?.toDart;
      completer.completeError(
        message ?? 'No se pudo obtener la ubicacion actual.',
      );
    }).toJS,
  );

  return completer.future;
}
