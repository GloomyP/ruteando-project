import 'package:cloud_firestore/cloud_firestore.dart';

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
  final Timestamp? creadoEn;
  final Timestamp? actualizadoEn;

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
    Timestamp? creadoEn,
    Timestamp? actualizadoEn,
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

  factory ProductoInventario.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};

    return ProductoInventario(
      id: data['id']?.toString() ?? doc.id,
      nombre: data['nombre']?.toString() ?? '',
      categoria: data['categoria']?.toString() ?? '',
      descripcion: data['descripcion']?.toString() ?? '',
      stockActual: _leerEntero(data['stockActual']),
      stockMinimo: _leerEntero(data['stockMinimo']),
      unidad: data['unidad']?.toString() ?? '',
      estado: data['estado']?.toString() ?? '',
      creadoEn: data['creadoEn'] is Timestamp
          ? data['creadoEn'] as Timestamp
          : null,
      actualizadoEn: data['actualizadoEn'] is Timestamp
          ? data['actualizadoEn'] as Timestamp
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'nombre': nombre,
      'categoria': categoria,
      'descripcion': descripcion,
      'stockActual': stockActual,
      'stockMinimo': stockMinimo,
      'unidad': unidad,
      'estado': estadoCalculado,
      'creadoEn': creadoEn,
      'actualizadoEn': actualizadoEn,
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
}
