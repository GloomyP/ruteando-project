class NotificacionInterna {
  const NotificacionInterna({
    required this.id,
    required this.titulo,
    required this.mensaje,
    required this.nombreRepartidor,
    required this.emailRepartidor,
    required this.direccion,
    required this.fecha,
    required this.leida,
    required this.tipo,
    this.rutaId,
  });

  final String id;
  final String titulo;
  final String mensaje;
  final String nombreRepartidor;
  final String emailRepartidor;
  final String direccion;
  final String? rutaId;
  final DateTime fecha;
  final bool leida;
  final String tipo;

  NotificacionInterna copyWith({bool? leida}) {
    return NotificacionInterna(
      id: id,
      titulo: titulo,
      mensaje: mensaje,
      nombreRepartidor: nombreRepartidor,
      emailRepartidor: emailRepartidor,
      direccion: direccion,
      rutaId: rutaId,
      fecha: fecha,
      leida: leida ?? this.leida,
      tipo: tipo,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'titulo': titulo,
      'mensaje': mensaje,
      'nombreRepartidor': nombreRepartidor,
      'emailRepartidor': emailRepartidor,
      'direccion': direccion,
      'parada': direccion,
      if (rutaId != null && rutaId!.isNotEmpty) 'rutaId': rutaId,
      'fecha': fecha.toIso8601String(),
      'leida': leida,
      'tipo': tipo,
    };
  }

  factory NotificacionInterna.fromMap(Map<String, dynamic> data) {
    final fechaRaw = data['fecha']?.toString();
    return NotificacionInterna(
      id: data['id']?.toString() ?? '',
      titulo: data['titulo']?.toString() ?? '',
      mensaje: data['mensaje']?.toString() ?? '',
      nombreRepartidor: data['nombreRepartidor']?.toString() ?? '',
      emailRepartidor: data['emailRepartidor']?.toString() ?? '',
      direccion:
          data['direccion']?.toString() ?? data['parada']?.toString() ?? '',
      rutaId: data['rutaId']?.toString(),
      fecha: fechaRaw == null
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.tryParse(fechaRaw) ??
                DateTime.fromMillisecondsSinceEpoch(0),
      leida: data['leida'] == true,
      tipo: data['tipo']?.toString() ?? '',
    );
  }
}
