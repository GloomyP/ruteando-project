import 'dart:async';

import 'package:firebase_core/firebase_core.dart';

import '../models/notificacion_interna.dart';
import '../models/producto_inventario.dart';
import '../persistencia_rutas.dart';
import 'inventario_service.dart';

class NotificacionesService {
  NotificacionesService({InventarioService? inventarioService})
    : _inventarioService = inventarioService;

  final InventarioService? _inventarioService;

  InventarioService get _inventarioServiceActivo =>
      _inventarioService ?? InventarioService();

  Stream<List<NotificacionInterna>> escucharNotificacionesAdmin() {
    if (Firebase.apps.isEmpty) {
      return Stream.fromFuture(cargarNotificacionesAdmin());
    }

    final controller = StreamController<List<NotificacionInterna>>();
    List<Map<String, dynamic>> persistidas = const [];
    List<ProductoInventario> alertasInventario = const [];
    var internasListas = false;
    var inventarioListo = false;

    void emitir() {
      if (!internasListas || !inventarioListo || controller.isClosed) {
        return;
      }
      controller.add(_combinarNotificaciones(persistidas, alertasInventario));
    }

    final internasSub = escucharNotificacionesInternas().listen((
      notificaciones,
    ) {
      persistidas = notificaciones;
      internasListas = true;
      emitir();
    }, onError: controller.addError);

    final inventarioSub = _inventarioServiceActivo.obtenerAlertasStock().listen(
      (alertas) {
        alertasInventario = alertas;
        inventarioListo = true;
        emitir();
      },
      onError: (_) {
        alertasInventario = const [];
        inventarioListo = true;
        emitir();
      },
    );

    controller.onCancel = () async {
      await internasSub.cancel();
      await inventarioSub.cancel();
    };

    return controller.stream;
  }

  Future<List<NotificacionInterna>> cargarNotificacionesAdmin() async {
    final persistidas = await cargarNotificacionesInternas();
    if (Firebase.apps.isEmpty) {
      return _combinarNotificaciones(persistidas, const []);
    }

    try {
      final alertas = await _inventarioServiceActivo
          .obtenerAlertasStock()
          .first;
      return _combinarNotificaciones(persistidas, alertas);
    } catch (_) {
      return _combinarNotificaciones(persistidas, const []);
    }
  }

  Future<void> crearNotificacionEntrega({
    required String nombreRepartidor,
    required String emailRepartidor,
    required String direccion,
    String? rutaId,
    DateTime? fecha,
  }) async {
    final fechaNotificacion = fecha ?? DateTime.now();
    final nombre = nombreRepartidor.trim().isEmpty
        ? 'Repartidor'
        : nombreRepartidor.trim();
    final direccionEntrega = direccion.trim().isEmpty
        ? 'parada sin direccion registrada'
        : direccion.trim();
    final notificacion = NotificacionInterna(
      id: 'entrega_${emailRepartidor.toLowerCase().trim()}_${fechaNotificacion.microsecondsSinceEpoch}',
      titulo: 'Entrega realizada',
      mensaje: '$nombre entrego en $direccionEntrega.',
      nombreRepartidor: nombre,
      emailRepartidor: emailRepartidor.trim(),
      direccion: direccionEntrega,
      rutaId: rutaId?.trim().isEmpty == true ? null : rutaId?.trim(),
      fecha: fechaNotificacion,
      leida: false,
      tipo: 'entrega',
    );

    final actuales = await cargarNotificacionesAdmin();
    await guardarNotificacionesInternas([
      notificacion.toMap(),
      ...actuales.map((n) => n.toMap()),
    ]);
  }

  Future<void> marcarComoLeida(String id) async {
    final persistidas = await cargarNotificacionesInternas();
    final actuales = await cargarNotificacionesAdmin();
    NotificacionInterna? objetivo;
    for (final notificacion in actuales) {
      if (notificacion.id == id) {
        objetivo = notificacion;
        break;
      }
    }
    if (objetivo == null) {
      return;
    }

    var existe = false;
    final actualizadas = persistidas.map((data) {
      final notificacion = NotificacionInterna.fromMap(data);
      if (notificacion.id != id) {
        return data;
      }
      existe = true;
      return notificacion.copyWith(leida: true).toMap();
    }).toList();

    if (!existe) {
      actualizadas.add(objetivo.copyWith(leida: true).toMap());
    }

    await guardarNotificacionesInternas(actualizadas);
  }

  Future<void> marcarTodasComoLeidas() async {
    final persistidas = await cargarNotificacionesInternas();
    final actuales = await cargarNotificacionesAdmin();
    final porId = {
      for (final data in persistidas)
        NotificacionInterna.fromMap(data).id: NotificacionInterna.fromMap(data),
    };

    for (final notificacion in actuales) {
      porId[notificacion.id] = notificacion.copyWith(leida: true);
    }

    await guardarNotificacionesInternas(
      porId.values.map((n) => n.toMap()).toList(),
    );
  }

  List<NotificacionInterna> _combinarNotificaciones(
    List<Map<String, dynamic>> persistidas,
    List<ProductoInventario> alertasInventario,
  ) {
    final internasPersistidas = persistidas
        .map(NotificacionInterna.fromMap)
        .where((notificacion) => notificacion.id.isNotEmpty)
        .toList();
    final leidasPorId = {
      for (final notificacion in internasPersistidas)
        notificacion.id: notificacion.leida,
    };
    final alertas = alertasInventario.map((producto) {
      final estado = producto.estadoCalculado == 'No disponible'
          ? 'sin_stock'
          : 'stock_bajo';
      final id = 'inventario_${producto.id}_$estado';
      final titulo = estado == 'sin_stock'
          ? 'Producto sin stock'
          : 'Stock bajo';
      final mensaje = estado == 'sin_stock'
          ? '${producto.nombre} no tiene stock disponible.'
          : '${producto.nombre} tiene ${producto.stockActual} ${producto.unidad} disponibles.';

      return NotificacionInterna(
        id: id,
        titulo: titulo,
        mensaje: mensaje,
        nombreRepartidor: '',
        emailRepartidor: '',
        direccion: producto.nombre,
        fecha: producto.actualizadoEn?.toDate() ?? DateTime.now(),
        leida: leidasPorId[id] ?? false,
        tipo: estado,
      );
    });

    final ordenadas = [
      ...internasPersistidas.where(
        (notificacion) =>
            !notificacion.tipo.startsWith('stock_') &&
            notificacion.tipo != 'sin_stock',
      ),
      ...alertas,
    ]..sort((a, b) => b.fecha.compareTo(a.fecha));
    return ordenadas;
  }
}
