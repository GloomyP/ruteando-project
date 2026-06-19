import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/movimiento_inventario.dart';
import '../models/producto_inventario.dart';
import '../models/stock_repartidor_inventario.dart';
import '../persistencia_rutas.dart';

class InventarioService {
  InventarioService({FirebaseFirestore? firestore})
    : _firestore =
          firestore ?? FirebaseFirestore.instanceFor(app: Firebase.app());

  final FirebaseFirestore _firestore;

  static final StreamController<void> _localCambiosController =
      StreamController<void>.broadcast();

  String get _productosLocalKey =>
      '${empresaUsuarioKey()}_inventario_productos';
  String get _stockLocalKey =>
      '${empresaUsuarioKey()}_inventario_stock_repartidores';
  String get _movimientosLocalKey =>
      '${empresaUsuarioKey()}_inventario_movimientos';

  CollectionReference<Map<String, dynamic>> get _productosRef =>
      _firestore.collection('inventario_productos');

  CollectionReference<Map<String, dynamic>> get _stockRepartidoresRef =>
      _firestore.collection('inventario_stock_repartidores');

  CollectionReference<Map<String, dynamic>> get _movimientosRef =>
      _firestore.collection('inventario_movimientos');

  Stream<List<ProductoInventario>> observarProductos() async* {
    if (kIsWeb) {
      yield await _cargarProductosLocales();
      yield* _localCambiosController.stream.asyncMap(
        (_) => _cargarProductosLocales(),
      );
      return;
    }

    yield const <ProductoInventario>[];

    try {
      yield* _productosRef
          .orderBy('nombre')
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map(ProductoInventario.fromFirestore)
                .toList(growable: false);
          })
          .handleError((Object error, StackTrace stackTrace) {
            debugPrint('Error observando productos de inventario: $error');
          });
    } catch (error) {
      debugPrint('Error inicializando inventario de productos: $error');
    }
  }

  Stream<List<StockRepartidorInventario>> observarStockRepartidores() async* {
    if (kIsWeb) {
      yield await _cargarStockLocales();
      yield* _localCambiosController.stream.asyncMap(
        (_) => _cargarStockLocales(),
      );
      return;
    }

    yield const <StockRepartidorInventario>[];

    try {
      yield* _stockRepartidoresRef
          .orderBy('nombre')
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map(StockRepartidorInventario.fromFirestore)
                .toList(growable: false);
          })
          .handleError((Object error, StackTrace stackTrace) {
            debugPrint('Error observando stock por repartidor: $error');
          });
    } catch (error) {
      debugPrint('Error inicializando stock por repartidor: $error');
    }
  }

  Stream<List<MovimientoInventario>> obtenerUltimosMovimientos({
    int limite = 8,
  }) async* {
    if (kIsWeb) {
      yield (await _cargarMovimientosLocales()).take(limite).toList();
      yield* _localCambiosController.stream.asyncMap((_) async {
        return (await _cargarMovimientosLocales()).take(limite).toList();
      });
      return;
    }

    yield const <MovimientoInventario>[];

    try {
      yield* _movimientosRef
          .orderBy('fecha', descending: true)
          .limit(limite)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map(MovimientoInventario.fromFirestore)
                .toList(growable: false);
          })
          .handleError((Object error, StackTrace stackTrace) {
            debugPrint('Error observando movimientos de inventario: $error');
          });
    } catch (error) {
      debugPrint('Error inicializando movimientos de inventario: $error');
    }
  }

  Stream<List<MovimientoInventario>> observarUltimosMovimientos({
    int limite = 8,
  }) {
    return obtenerUltimosMovimientos(limite: limite);
  }

  Stream<List<ProductoInventario>> obtenerAlertasStock() {
    return observarProductos().map((productos) {
      final alertas = productos
          .where((producto) => producto.stockActual <= producto.stockMinimo)
          .toList(growable: false);
      return alertas;
    });
  }

  Future<List<Map<String, String>>> cargarRepartidoresVinculados() {
    return cargarConductoresVinculados();
  }

  Future<void> crearProducto(ProductoInventario producto) async {
    if (kIsWeb) {
      await _guardarProductoLocal(producto);
      return;
    }

    final docRef = _productosRef.doc();
    final productoConId = producto.copyWith(id: docRef.id);

    await docRef.set({
      ...productoConId.toFirestore(),
      'creadoEn': FieldValue.serverTimestamp(),
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }

  Future<void> actualizarProducto(ProductoInventario producto) async {
    if (kIsWeb) {
      await _guardarProductoLocal(producto);
      return;
    }

    await _productosRef.doc(producto.id).set({
      ...producto.toFirestore(),
      'actualizadoEn': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> eliminarProducto(String id) async {
    if (kIsWeb) {
      final productos = await _cargarProductosLocales();
      productos.removeWhere((producto) => producto.id == id);
      await _guardarListaProductosLocales(productos);
      return;
    }

    await _productosRef.doc(id).delete();
  }

  Future<void> guardarStockRepartidor(StockRepartidorInventario stock) async {
    if (kIsWeb) {
      await _guardarStockLocal(stock);
      return;
    }

    final id = stock.id.isNotEmpty
        ? stock.id
        : _normalizarDocumento(stock.email);
    final docRef = id.isNotEmpty
        ? _stockRepartidoresRef.doc(id)
        : _stockRepartidoresRef.doc();
    final stockConId = StockRepartidorInventario(
      id: docRef.id,
      nombre: stock.nombre,
      email: stock.email.toLowerCase().trim(),
      bidonesCargados: stock.bidonesCargados,
      bidonesEntregados: stock.bidonesEntregados,
      bidonesRetornados: stock.bidonesRetornados,
      bidonesDanados: stock.bidonesDanados,
      actualizadoEn: stock.actualizadoEn,
    );

    await docRef.set({
      ...stockConId.toFirestore(),
      'actualizadoEn': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> registrarMovimiento(MovimientoInventario movimiento) async {
    if (kIsWeb) {
      await _registrarMovimientoLocal(movimiento);
      return;
    }

    final movimientoRef = _movimientosRef.doc();
    final productoRef = _productosRef.doc(movimiento.productoId);

    await _firestore.runTransaction((transaction) async {
      final productoDoc = await transaction.get(productoRef);
      final producto = productoDoc.data();
      if (!productoDoc.exists || producto == null) {
        throw StateError('El producto seleccionado no existe.');
      }

      final stockActual = _leerEntero(producto['stockActual']);
      final stockMinimo = _leerEntero(producto['stockMinimo']);
      final nuevoStock = _calcularNuevoStock(
        stockActual: stockActual,
        tipo: movimiento.tipo,
        cantidad: movimiento.cantidad,
      );

      if (nuevoStock < 0) {
        throw StateError('El movimiento dejaria el stock en negativo.');
      }

      transaction.update(productoRef, {
        'stockActual': nuevoStock,
        'estado': _estadoParaStock(nuevoStock, stockMinimo),
        'actualizadoEn': FieldValue.serverTimestamp(),
      });

      transaction.set(movimientoRef, {
        ...movimiento.toFirestore(),
        'id': movimientoRef.id,
        'fecha': FieldValue.serverTimestamp(),
      });
    });
  }

  int _calcularNuevoStock({
    required int stockActual,
    required String tipo,
    required int cantidad,
  }) {
    if (tipo == 'Entrada' || tipo == 'Devolucion') {
      return stockActual + cantidad;
    }

    if (tipo == 'Salida' || tipo == 'Dano' || tipo == 'Perdida') {
      return stockActual - cantidad;
    }

    return cantidad;
  }

  String _estadoParaStock(int stockActual, int stockMinimo) {
    if (stockActual == 0) {
      return 'No disponible';
    }

    if (stockActual <= stockMinimo) {
      return 'Stock bajo';
    }

    return 'Disponible';
  }

  String _normalizarDocumento(String valor) {
    return valor.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9._-]'), '_');
  }

  int _leerEntero(dynamic valor) {
    if (valor is int) {
      return valor;
    }

    if (valor is num) {
      return valor.toInt();
    }

    return int.tryParse(valor?.toString() ?? '') ?? 0;
  }

  Future<List<ProductoInventario>> _cargarProductosLocales() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_productosLocalKey);
    if (data == null) {
      return [];
    }

    final decoded = jsonDecode(data);
    if (decoded is! List) {
      return [];
    }

    return decoded
        .map(_productoDesdeLocal)
        .whereType<ProductoInventario>()
        .toList()
      ..sort((a, b) => a.nombre.compareTo(b.nombre));
  }

  Future<void> _guardarListaProductosLocales(
    List<ProductoInventario> productos,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _productosLocalKey,
      jsonEncode(productos.map(_productoALocal).toList()),
    );
    _localCambiosController.add(null);
  }

  Future<void> _guardarProductoLocal(ProductoInventario producto) async {
    final productos = await _cargarProductosLocales();
    final id = producto.id.isNotEmpty
        ? producto.id
        : 'producto_${DateTime.now().microsecondsSinceEpoch}';
    final guardado = producto.copyWith(id: id);
    final index = productos.indexWhere((item) => item.id == id);
    if (index >= 0) {
      productos[index] = guardado;
    } else {
      productos.add(guardado);
    }
    await _guardarListaProductosLocales(productos);
  }

  ProductoInventario? _productoDesdeLocal(dynamic item) {
    if (item is! Map) {
      return null;
    }

    return ProductoInventario(
      id: item['id']?.toString() ?? '',
      nombre: item['nombre']?.toString() ?? '',
      categoria: item['categoria']?.toString() ?? '',
      descripcion: item['descripcion']?.toString() ?? '',
      stockActual: _leerEntero(item['stockActual']),
      stockMinimo: _leerEntero(item['stockMinimo']),
      unidad: item['unidad']?.toString() ?? '',
      estado: item['estado']?.toString() ?? '',
    );
  }

  Map<String, dynamic> _productoALocal(ProductoInventario producto) {
    return {
      'id': producto.id,
      'nombre': producto.nombre,
      'categoria': producto.categoria,
      'descripcion': producto.descripcion,
      'stockActual': producto.stockActual,
      'stockMinimo': producto.stockMinimo,
      'unidad': producto.unidad,
      'estado': producto.estadoCalculado,
    };
  }

  Future<List<StockRepartidorInventario>> _cargarStockLocales() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_stockLocalKey);
    if (data == null) {
      return [];
    }

    final decoded = jsonDecode(data);
    if (decoded is! List) {
      return [];
    }

    return decoded
        .map(_stockDesdeLocal)
        .whereType<StockRepartidorInventario>()
        .toList()
      ..sort((a, b) => a.nombre.compareTo(b.nombre));
  }

  Future<void> _guardarListaStockLocales(
    List<StockRepartidorInventario> stock,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _stockLocalKey,
      jsonEncode(stock.map(_stockALocal).toList()),
    );
    _localCambiosController.add(null);
  }

  Future<void> _guardarStockLocal(StockRepartidorInventario stock) async {
    final lista = await _cargarStockLocales();
    final id = stock.id.isNotEmpty
        ? stock.id
        : _normalizarDocumento(stock.email);
    final guardado = StockRepartidorInventario(
      id: id.isNotEmpty ? id : 'stock_${DateTime.now().microsecondsSinceEpoch}',
      nombre: stock.nombre,
      email: stock.email,
      bidonesCargados: stock.bidonesCargados,
      bidonesEntregados: stock.bidonesEntregados,
      bidonesRetornados: stock.bidonesRetornados,
      bidonesDanados: stock.bidonesDanados,
      actualizadoEn: stock.actualizadoEn,
    );
    final index = lista.indexWhere((item) => item.id == guardado.id);
    if (index >= 0) {
      lista[index] = guardado;
    } else {
      lista.add(guardado);
    }
    await _guardarListaStockLocales(lista);
  }

  StockRepartidorInventario? _stockDesdeLocal(dynamic item) {
    if (item is! Map) {
      return null;
    }

    return StockRepartidorInventario(
      id: item['id']?.toString() ?? '',
      nombre: item['nombre']?.toString() ?? '',
      email: item['email']?.toString() ?? '',
      bidonesCargados: _leerEntero(item['bidonesCargados']),
      bidonesEntregados: _leerEntero(item['bidonesEntregados']),
      bidonesRetornados: _leerEntero(item['bidonesRetornados']),
      bidonesDanados: _leerEntero(item['bidonesDanados']),
    );
  }

  Map<String, dynamic> _stockALocal(StockRepartidorInventario stock) {
    return {
      'id': stock.id,
      'nombre': stock.nombre,
      'email': stock.email,
      'bidonesCargados': stock.bidonesCargados,
      'bidonesEntregados': stock.bidonesEntregados,
      'bidonesRetornados': stock.bidonesRetornados,
      'bidonesDanados': stock.bidonesDanados,
    };
  }

  Future<List<MovimientoInventario>> _cargarMovimientosLocales() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_movimientosLocalKey);
    if (data == null) {
      return [];
    }

    final decoded = jsonDecode(data);
    if (decoded is! List) {
      return [];
    }

    return decoded
        .map(_movimientoDesdeLocal)
        .whereType<MovimientoInventario>()
        .toList();
  }

  Future<void> _guardarListaMovimientosLocales(
    List<MovimientoInventario> movimientos,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _movimientosLocalKey,
      jsonEncode(movimientos.map(_movimientoALocal).toList()),
    );
    _localCambiosController.add(null);
  }

  Future<void> _registrarMovimientoLocal(
    MovimientoInventario movimiento,
  ) async {
    final productos = await _cargarProductosLocales();
    final index = productos.indexWhere(
      (producto) => producto.id == movimiento.productoId,
    );
    if (index < 0) {
      throw StateError('El producto seleccionado no existe.');
    }

    final producto = productos[index];
    final nuevoStock = _calcularNuevoStock(
      stockActual: producto.stockActual,
      tipo: movimiento.tipo,
      cantidad: movimiento.cantidad,
    );
    if (nuevoStock < 0) {
      throw StateError('El movimiento dejaria el stock en negativo.');
    }

    productos[index] = producto.copyWith(
      stockActual: nuevoStock,
      estado: _estadoParaStock(nuevoStock, producto.stockMinimo),
    );
    final movimientos = await _cargarMovimientosLocales();
    final guardado = MovimientoInventario(
      id: 'movimiento_${DateTime.now().microsecondsSinceEpoch}',
      productoId: movimiento.productoId,
      productoNombre: movimiento.productoNombre,
      tipo: movimiento.tipo,
      cantidad: movimiento.cantidad,
      responsable: movimiento.responsable,
      email: movimiento.email,
      observacion: movimiento.observacion,
      fecha: Timestamp.fromDate(DateTime.now()),
    );
    movimientos.insert(0, guardado);
    await _guardarListaProductosLocales(productos);
    await _guardarListaMovimientosLocales(movimientos);
  }

  MovimientoInventario? _movimientoDesdeLocal(dynamic item) {
    if (item is! Map) {
      return null;
    }

    final fechaTexto = item['fecha']?.toString();
    final fecha = fechaTexto == null ? null : DateTime.tryParse(fechaTexto);
    return MovimientoInventario(
      id: item['id']?.toString() ?? '',
      productoId: item['productoId']?.toString() ?? '',
      productoNombre: item['productoNombre']?.toString() ?? '',
      tipo: item['tipo']?.toString() ?? '',
      cantidad: _leerEntero(item['cantidad']),
      responsable: item['responsable']?.toString() ?? '',
      email: item['email']?.toString() ?? '',
      observacion: item['observacion']?.toString() ?? '',
      fecha: fecha == null ? null : Timestamp.fromDate(fecha),
    );
  }

  Map<String, dynamic> _movimientoALocal(MovimientoInventario movimiento) {
    return {
      'id': movimiento.id,
      'productoId': movimiento.productoId,
      'productoNombre': movimiento.productoNombre,
      'tipo': movimiento.tipo,
      'cantidad': movimiento.cantidad,
      'responsable': movimiento.responsable,
      'email': movimiento.email,
      'observacion': movimiento.observacion,
      'fecha': movimiento.fecha?.toDate().toIso8601String(),
    };
  }
}
