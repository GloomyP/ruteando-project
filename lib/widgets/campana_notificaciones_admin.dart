import 'package:flutter/material.dart';

import '../models/notificacion_interna.dart';
import '../services/app_settings_service.dart';
import '../services/notificaciones_service.dart';

class CampanaNotificacionesAdmin extends StatelessWidget {
  CampanaNotificacionesAdmin({super.key})
    : _notificacionesService = NotificacionesService();

  final NotificacionesService _notificacionesService;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppSettingsState>(
      valueListenable: appSettingsService,
      builder: (context, settings, _) {
        if (!settings.notificacionesInternasActivas) {
          return PopupMenuButton<String>(
            tooltip: 'Notificaciones',
            icon: const Icon(Icons.notifications_off_outlined),
            itemBuilder: (_) => const [
              PopupMenuItem<String>(
                enabled: false,
                child: Text('Notificaciones internas desactivadas'),
              ),
            ],
          );
        }

        return StreamBuilder<List<NotificacionInterna>>(
          stream: _notificacionesService.escucharNotificacionesAdmin(),
          builder: (context, snapshot) {
            final notificaciones =
                snapshot.data ?? const <NotificacionInterna>[];
            final recientes = notificaciones.take(8).toList();
            final noLeidas = notificaciones.where((n) => !n.leida).length;

            return PopupMenuButton<String>(
              tooltip: 'Notificaciones',
              offset: const Offset(0, 12),
              constraints: const BoxConstraints(minWidth: 320, maxWidth: 380),
              onSelected: (value) async {
                if (value == '__marcar_todas__') {
                  await _notificacionesService.marcarTodasComoLeidas();
                  return;
                }
                await _notificacionesService.marcarComoLeida(value);
              },
              itemBuilder: (context) {
                return [
                  PopupMenuItem<String>(
                    enabled: false,
                    child: _EncabezadoNotificaciones(noLeidas: noLeidas),
                  ),
                  const PopupMenuDivider(),
                  if (recientes.isEmpty)
                    const PopupMenuItem<String>(
                      enabled: false,
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('No hay notificaciones pendientes'),
                      ),
                    )
                  else ...[
                    ...recientes.map((notificacion) {
                      return PopupMenuItem<String>(
                        value: notificacion.leida ? null : notificacion.id,
                        enabled: !notificacion.leida,
                        child: _ItemNotificacion(notificacion: notificacion),
                      );
                    }),
                    if (noLeidas > 0) ...[
                      const PopupMenuDivider(),
                      const PopupMenuItem<String>(
                        value: '__marcar_todas__',
                        child: Row(
                          children: [
                            Icon(Icons.done_all_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Marcar todas como leidas'),
                          ],
                        ),
                      ),
                    ],
                  ],
                ];
              },
              icon: _IconoCampana(noLeidas: noLeidas),
            );
          },
        );
      },
    );
  }
}

class _EncabezadoNotificaciones extends StatelessWidget {
  const _EncabezadoNotificaciones({required this.noLeidas});

  final int noLeidas;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.notifications_active_outlined, color: Colors.green[800]),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'Notificaciones',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$noLeidas no leidas',
            style: TextStyle(
              color: Colors.green[800],
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ItemNotificacion extends StatelessWidget {
  const _ItemNotificacion({required this.notificacion});

  final NotificacionInterna notificacion;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: notificacion.leida
                ? Colors.grey.withValues(alpha: 0.12)
                : Colors.green.withValues(alpha: 0.12),
            foregroundColor: notificacion.leida
                ? Colors.grey[700]
                : Colors.green[800],
            child: Icon(
              notificacion.leida
                  ? Icons.mark_email_read_outlined
                  : Icons.mark_email_unread_outlined,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notificacion.titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: notificacion.leida
                        ? FontWeight.w500
                        : FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  notificacion.mensaje,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 3),
                Text(
                  notificacion.leida
                      ? _formatearFecha(notificacion.fecha)
                      : 'Marcar como leida',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: notificacion.leida
                        ? Colors.grey[700]
                        : Colors.green[800],
                    fontWeight: notificacion.leida
                        ? FontWeight.w400
                        : FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatearFecha(DateTime fecha) {
    String dosDigitos(int valor) => valor.toString().padLeft(2, '0');
    return '${dosDigitos(fecha.day)}/${dosDigitos(fecha.month)}/${fecha.year} '
        '${dosDigitos(fecha.hour)}:${dosDigitos(fecha.minute)}';
  }
}

class _IconoCampana extends StatelessWidget {
  const _IconoCampana({required this.noLeidas});

  final int noLeidas;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.notifications_outlined),
        if (noLeidas > 0)
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: Colors.red[700],
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.center,
              child: Text(
                noLeidas > 99 ? '99+' : '$noLeidas',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
