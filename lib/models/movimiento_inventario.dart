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
  final DateTime? fecha;

  factory MovimientoInventario.fromMap(Map<String, dynamic> data) {
    return MovimientoInventario(
      id: data['id']?.toString() ?? '',
      productoId: data['productoId']?.toString() ?? '',
      productoNombre: data['productoNombre']?.toString() ?? '',
      tipo: data['tipo']?.toString() ?? '',
      cantidad: _leerEntero(data['cantidad']),
      responsable: data['responsable']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      observacion: data['observacion']?.toString() ?? '',
      fecha: _leerFecha(data['fecha']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productoId': productoId,
      'productoNombre': productoNombre,
      'tipo': tipo,
      'cantidad': cantidad,
      'responsable': responsable,
      'email': email,
      'observacion': observacion,
      'fecha': fecha?.toIso8601String(),
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
