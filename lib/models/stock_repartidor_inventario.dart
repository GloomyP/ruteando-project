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
  final DateTime? actualizadoEn;

  int get stockPendiente {
    return bidonesCargados - bidonesEntregados - bidonesDanados;
  }

  factory StockRepartidorInventario.fromMap(Map<String, dynamic> data) {
    return StockRepartidorInventario(
      id: data['id']?.toString() ?? '',
      nombre: data['nombre']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      bidonesCargados: _leerEntero(data['bidonesCargados']),
      bidonesEntregados: _leerEntero(data['bidonesEntregados']),
      bidonesRetornados: _leerEntero(data['bidonesRetornados']),
      bidonesDanados: _leerEntero(data['bidonesDanados']),
      actualizadoEn: _leerFecha(data['actualizadoEn'] ?? data['actualizado']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'email': email,
      'bidonesCargados': bidonesCargados,
      'bidonesEntregados': bidonesEntregados,
      'bidonesRetornados': bidonesRetornados,
      'bidonesDanados': bidonesDanados,
      'stockPendiente': stockPendiente,
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
