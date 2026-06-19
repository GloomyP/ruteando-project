import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../models/movimiento_inventario.dart';
import '../models/producto_inventario.dart';
import '../models/stock_repartidor_inventario.dart';
import '../persistencia_rutas.dart';

class InventarioService {
  InventarioService({FirebaseFirestore? firestore})
    : _firestore =
          firestore ??
          FirebaseFirestore.instanceFor(
            app: Firebase.app(),
            databaseId: 'ruteando',
          );

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _productosRef =>
      _firestore.collection('inventario_productos');

  CollectionReference<Map<String, dynamic>> get _stockRepartidoresRef =>
      _firestore.collection('inventario_stock_repartidores');

  CollectionReference<Map<String, dynamic>> get _movimientosRef =>
      _firestore.collection('inventario_movimientos');

  Stream<List<ProductoInventario>> observarProductos() async* {
    yield const <ProductoInventario>[];

    if (kIsWeb) {
      return;
    }

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
    yield const <StockRepartidorInventario>[];

    if (kIsWeb) {
      return;
    }

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
    yield const <MovimientoInventario>[];

    if (kIsWeb) {
      return;
    }

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
    final docRef = _productosRef.doc();
    final productoConId = producto.copyWith(id: docRef.id);

    await docRef.set({
      ...productoConId.toFirestore(),
      'creadoEn': FieldValue.serverTimestamp(),
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }

  Future<void> actualizarProducto(ProductoInventario producto) async {
    await _productosRef.doc(producto.id).set({
      ...producto.toFirestore(),
      'actualizadoEn': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> eliminarProducto(String id) async {
    await _productosRef.doc(id).delete();
  }

  Future<void> guardarStockRepartidor(StockRepartidorInventario stock) async {
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
}
