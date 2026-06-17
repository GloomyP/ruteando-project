import 'package:cloud_firestore/cloud_firestore.dart';

class StockRepartidorInventario {
  const StockRepartidorInventario({
    required this.id,
    required this.nombre,
    required this.email,
    required this.bidonesCargados,
    required this.bidonesEntregados,
    required this.bidonesRetornados,
    required this.bidonesDanados,
    this.actualizadoEn,
  });

  final String id;
  final String nombre;
  final String email;
  final int bidonesCargados;
  final int bidonesEntregados;
  final int bidonesRetornados;
  final int bidonesDanados;
  final Timestamp? actualizadoEn;

  int get stockPendiente {
    return bidonesCargados - bidonesEntregados - bidonesDanados;
  }

  factory StockRepartidorInventario.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};

    return StockRepartidorInventario(
      id: data['id']?.toString() ?? doc.id,
      nombre: data['nombre']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      bidonesCargados: _leerEntero(data['bidonesCargados']),
      bidonesEntregados: _leerEntero(data['bidonesEntregados']),
      bidonesRetornados: _leerEntero(data['bidonesRetornados']),
      bidonesDanados: _leerEntero(data['bidonesDanados']),
      actualizadoEn: data['actualizadoEn'] is Timestamp
          ? data['actualizadoEn'] as Timestamp
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'nombre': nombre,
      'email': email,
      'bidonesCargados': bidonesCargados,
      'bidonesEntregados': bidonesEntregados,
      'bidonesRetornados': bidonesRetornados,
      'bidonesDanados': bidonesDanados,
      'stockPendiente': stockPendiente,
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
