import 'package:cloud_firestore/cloud_firestore.dart';

class MovimientoInventario {
  const MovimientoInventario({
    required this.id,
    required this.productoId,
    required this.productoNombre,
    required this.tipo,
    required this.cantidad,
    required this.responsable,
    required this.email,
    required this.observacion,
    this.fecha,
  });

  final String id;
  final String productoId;
  final String productoNombre;
  final String tipo;
  final int cantidad;
  final String responsable;
  final String email;
  final String observacion;
  final Timestamp? fecha;

  factory MovimientoInventario.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};

    return MovimientoInventario(
      id: data['id']?.toString() ?? doc.id,
      productoId: data['productoId']?.toString() ?? '',
      productoNombre: data['productoNombre']?.toString() ?? '',
      tipo: data['tipo']?.toString() ?? '',
      cantidad: _leerEntero(data['cantidad']),
      responsable: data['responsable']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      observacion: data['observacion']?.toString() ?? '',
      fecha: data['fecha'] is Timestamp ? data['fecha'] as Timestamp : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'productoId': productoId,
      'productoNombre': productoNombre,
      'tipo': tipo,
      'cantidad': cantidad,
      'responsable': responsable,
      'email': email,
      'observacion': observacion,
      'fecha': fecha,
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
