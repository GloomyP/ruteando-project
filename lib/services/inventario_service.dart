import 'dart:async';

import '../models/movimiento_inventario.dart';
import '../models/producto_inventario.dart';
import '../models/stock_repartidor_inventario.dart';
import '../persistencia_rutas.dart';
import 'supabase_rest_service.dart';

class InventarioService {
  static final StreamController<void> _cambiosController =
      StreamController<void>.broadcast();

  Stream<List<ProductoInventario>> observarProductos() async* {
    yield await _cargarProductos();
    yield* _cambiosController.stream.asyncMap((_) => _cargarProductos());
  }

  Stream<List<StockRepartidorInventario>> observarStockRepartidores() async* {
    yield await _cargarStockRepartidores();
    yield* _cambiosController.stream.asyncMap(
      (_) => _cargarStockRepartidores(),
    );
  }

  Stream<List<MovimientoInventario>> obtenerUltimosMovimientos({
    int limite = 8,
  }) async* {
    yield await _cargarMovimientos(limite: limite);
    yield* _cambiosController.stream.asyncMap(
      (_) => _cargarMovimientos(limite: limite),
    );
  }

  Stream<List<MovimientoInventario>> observarUltimosMovimientos({
    int limite = 8,
  }) {
    return obtenerUltimosMovimientos(limite: limite);
  }

  Stream<List<ProductoInventario>> obtenerAlertasStock() {
    return observarProductos().map((productos) {
      return productos
          .where((producto) => producto.stockActual <= producto.stockMinimo)
          .toList(growable: false);
    });
  }

  Future<List<Map<String, String>>> cargarRepartidoresVinculados() {
    return cargarConductoresVinculados();
  }

  Future<void> crearProducto(ProductoInventario producto) async {
    final id = producto.id.isNotEmpty
        ? producto.id
        : 'producto_${DateTime.now().microsecondsSinceEpoch}';
    final ahora = DateTime.now();
    final guardado = producto.copyWith(
      id: id,
      creadoEn: producto.creadoEn ?? ahora,
      actualizadoEn: ahora,
    );

    await _guardarProducto(guardado);
    _notificarCambios();
  }

  Future<void> actualizarProducto(ProductoInventario producto) async {
    await _guardarProducto(producto.copyWith(actualizadoEn: DateTime.now()));
    _notificarCambios();
  }

  Future<void> eliminarProducto(String id) async {
    await supabaseRest.delete(
      'inventario_productos',
      filters: {
        'empresa_key': SupabaseConfig.eq(await empresaOperativaKey()),
        'id': SupabaseConfig.eq(id),
      },
    );
    _notificarCambios();
  }

  Future<void> guardarStockRepartidor(StockRepartidorInventario stock) async {
    final id = stock.id.isNotEmpty
        ? stock.id
        : _normalizarDocumento(stock.email);
    final guardado = StockRepartidorInventario(
      id: id.isNotEmpty ? id : 'stock_${DateTime.now().microsecondsSinceEpoch}',
      nombre: stock.nombre,
      email: stock.email.toLowerCase().trim(),
      bidonesCargados: stock.bidonesCargados,
      bidonesEntregados: stock.bidonesEntregados,
      bidonesRetornados: stock.bidonesRetornados,
      bidonesDanados: stock.bidonesDanados,
      actualizadoEn: DateTime.now(),
    );

    await supabaseRest.upsert('inventario_stock_repartidores', {
      'empresa_key': await empresaOperativaKey(),
      ...guardado.toMap(),
      'actualizado': DateTime.now().toIso8601String(),
    }, onConflict: 'empresa_key,id');
    _notificarCambios();
  }

  Future<void> registrarMovimiento(MovimientoInventario movimiento) async {
    final productos = await _cargarProductos();
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

    await _guardarProducto(
      producto.copyWith(
        stockActual: nuevoStock,
        estado: _estadoParaStock(nuevoStock, producto.stockMinimo),
        actualizadoEn: DateTime.now(),
      ),
    );

    final guardado = MovimientoInventario(
      id: 'movimiento_${DateTime.now().microsecondsSinceEpoch}',
      productoId: movimiento.productoId,
      productoNombre: movimiento.productoNombre,
      tipo: movimiento.tipo,
      cantidad: movimiento.cantidad,
      responsable: movimiento.responsable,
      email: movimiento.email,
      observacion: movimiento.observacion,
      fecha: DateTime.now(),
    );

    await supabaseRest.insert('inventario_movimientos', {
      'empresa_key': await empresaOperativaKey(),
      ...guardado.toMap(),
    });
    _notificarCambios();
  }

  Future<List<ProductoInventario>> _cargarProductos() async {
    final rows = await supabaseRest.select(
      'inventario_productos',
      filters: {'empresa_key': SupabaseConfig.eq(await empresaOperativaKey())},
      order: 'nombre.asc',
    );
    return rows.map(ProductoInventario.fromMap).toList();
  }

  Future<List<StockRepartidorInventario>> _cargarStockRepartidores() async {
    final rows = await supabaseRest.select(
      'inventario_stock_repartidores',
      filters: {'empresa_key': SupabaseConfig.eq(await empresaOperativaKey())},
      order: 'nombre.asc',
    );
    return rows.map(StockRepartidorInventario.fromMap).toList();
  }

  Future<List<MovimientoInventario>> _cargarMovimientos({
    required int limite,
  }) async {
    final rows = await supabaseRest.select(
      'inventario_movimientos',
      filters: {'empresa_key': SupabaseConfig.eq(await empresaOperativaKey())},
      order: 'fecha.desc',
      limit: limite,
    );
    return rows.map(MovimientoInventario.fromMap).toList();
  }

  Future<void> _guardarProducto(ProductoInventario producto) async {
    await supabaseRest.upsert('inventario_productos', {
      'empresa_key': await empresaOperativaKey(),
      ...producto.toMap(),
      'actualizado': DateTime.now().toIso8601String(),
    }, onConflict: 'empresa_key,id');
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

  void _notificarCambios() {
    _cambiosController.add(null);
  }
}
