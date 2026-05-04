import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'directions_service.dart';

export 'directions_service.dart' show RutaGoogle;

@JS('google.maps.DirectionsService')
extension type _DirectionsService._(JSObject _) implements JSObject {
  external factory _DirectionsService();
  external void route(JSObject request, JSFunction callback);
}

@JS('google.maps.TravelMode.DRIVING')
external JSString get _drivingTravelMode;

Future<List<RutaGoogle>> obtenerRutasGoogle({
  required String origen,
  required String destino,
}) {
  final completer = Completer<List<RutaGoogle>>();
  final directionsService = _DirectionsService();
  final request =
      <String, Object?>{
            'origin': origen,
            'destination': destino,
            'travelMode': _drivingTravelMode,
            'provideRouteAlternatives': true,
          }.jsify()!
          as JSObject;

  directionsService.route(
    request,
    ((JSObject? response, JSString status) {
      if (status.toDart != 'OK') {
        completer.completeError(
          'Google Directions respondio: ${status.toDart}',
        );
        return;
      }

      final routes = response!
          .getProperty<JSArray<JSObject>>('routes'.toJS)
          .toDart;

      completer.complete(
        routes.map(_rutaDesdeJavascript).where((ruta) {
          return ruta.puntos.isNotEmpty;
        }).toList(),
      );
    }).toJS,
  );

  return completer.future;
}

RutaGoogle _rutaDesdeJavascript(JSObject route) {
  final legs = route.getProperty<JSArray<JSObject>>('legs'.toJS).toDart;
  int distanciaMetros = 0;
  int duracionSegundos = 0;

  for (final leg in legs) {
    final distance = leg.getProperty<JSObject>('distance'.toJS);
    final duration = leg.getProperty<JSObject>('duration'.toJS);
    distanciaMetros += distance
        .getProperty<JSNumber>('value'.toJS)
        .toDartDouble
        .round();
    duracionSegundos += duration
        .getProperty<JSNumber>('value'.toJS)
        .toDartDouble
        .round();
  }

  final overviewPath = route
      .getProperty<JSArray<JSObject>>('overview_path'.toJS)
      .toDart;
  final puntos = overviewPath.map((point) {
    final lat = point.callMethod<JSNumber>('lat'.toJS).toDartDouble;
    final lng = point.callMethod<JSNumber>('lng'.toJS).toDartDouble;
    return LatLng(lat, lng);
  }).toList();

  return RutaGoogle(
    distanciaMetros: distanciaMetros,
    duracionSegundos: duracionSegundos,
    puntos: puntos,
  );
}
