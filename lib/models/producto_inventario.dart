class ProductoInventario {
  const ProductoInventario({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.descripcion,
    required this.stockActual,
    required this.stockMinimo,
    required this.unidad,
    required this.estado,
    this.creadoEn,
    this.actualizadoEn,
  });

  final String id;
  final String nombre;
  final String categoria;
  final String descripcion;
  final int stockActual;
  final int stockMinimo;
  final String unidad;
  final String estado;
  final DateTime? creadoEn;
  final DateTime? actualizadoEn;

  String get estadoCalculado {
    if (stockActual == 0) {
      return 'No disponible';
    }

    if (stockActual <= stockMinimo) {
      return 'Stock bajo';
    }

    return 'Disponible';
  }

  ProductoInventario copyWith({
    String? id,
    String? nombre,
    String? categoria,
    String? descripcion,
    int? stockActual,
    int? stockMinimo,
    String? unidad,
    String? estado,
    DateTime? creadoEn,
    DateTime? actualizadoEn,
  }) {
    return ProductoInventario(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      categoria: categoria ?? this.categoria,
      descripcion: descripcion ?? this.descripcion,
      stockActual: stockActual ?? this.stockActual,
      stockMinimo: stockMinimo ?? this.stockMinimo,
      unidad: unidad ?? this.unidad,
      estado: estado ?? this.estado,
      creadoEn: creadoEn ?? this.creadoEn,
      actualizadoEn: actualizadoEn ?? this.actualizadoEn,
    );
  }

  factory ProductoInventario.fromMap(Map<String, dynamic> data) {
    return ProductoInventario(
      id: data['id']?.toString() ?? '',
      nombre: data['nombre']?.toString() ?? '',
      categoria: data['categoria']?.toString() ?? '',
      descripcion: data['descripcion']?.toString() ?? '',
      stockActual: _leerEntero(data['stockActual']),
      stockMinimo: _leerEntero(data['stockMinimo']),
      unidad: data['unidad']?.toString() ?? '',
      estado: data['estado']?.toString() ?? '',
      creadoEn: _leerFecha(data['creadoEn']),
      actualizadoEn: _leerFecha(data['actualizadoEn'] ?? data['actualizado']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'categoria': categoria,
      'descripcion': descripcion,
      'stockActual': stockActual,
      'stockMinimo': stockMinimo,
      'unidad': unidad,
      'estado': estadoCalculado,
      'creadoEn': creadoEn?.toIso8601String(),
      'actualizadoEn': actualizadoEn?.toIso8601String(),
    };
  }

  static int _leerEntero(dynamic valor) {
    if (valor is int) {
      return valor;
    }

    if (valor is num) {
      return valor.toInt();
    }

    return int.tryParse(valor?.toString() ?? '') ?? 0;
  }

  static DateTime? _leerFecha(dynamic valor) {
    if (valor is DateTime) {
      return valor;
    }

    return DateTime.tryParse(valor?.toString() ?? '');
  }
}
