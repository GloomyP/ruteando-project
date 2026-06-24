import 'package:flutter/material.dart';

import '../models/notificacion_interna.dart';
import '../services/app_settings_service.dart';
import '../services/notificaciones_service.dart';

class CampanaNotificacionesAdmin extends StatefulWidget {
  const CampanaNotificacionesAdmin({super.key});

  @override
  State<CampanaNotificacionesAdmin> createState() =>
      _CampanaNotificacionesAdminState();
}

class _CampanaNotificacionesAdminState
    extends State<CampanaNotificacionesAdmin> {
  final NotificacionesService _notificacionesService;

  _CampanaNotificacionesAdminState()
    : _notificacionesService = NotificacionesService();

  Future<void> _marcarComoLeida(BuildContext popupContext, String id) async {
    Navigator.of(popupContext).pop();
    await _notificacionesService.marcarComoLeida(id);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _marcarTodasComoLeidas(BuildContext popupContext) async {
    Navigator.of(popupContext).pop();
    await _notificacionesService.marcarTodasComoLeidas();
    if (!mounted) return;
    setState(() {});
  }

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
                        enabled: false,
                        child: _ItemNotificacion(
                          notificacion: notificacion,
                          onMarcarComoLeida: notificacion.leida
                              ? null
                              : () =>
                                    _marcarComoLeida(context, notificacion.id),
                        ),
                      );
                    }),
                    if (noLeidas > 0) ...[
                      const PopupMenuDivider(),
                      PopupMenuItem<String>(
                        enabled: false,
                        child: TextButton.icon(
                          onPressed: () => _marcarTodasComoLeidas(context),
                          icon: const Icon(Icons.done_all_outlined, size: 18),
                          label: const Text('Marcar todas como leidas'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF0B0F0D),
                            padding: EdgeInsets.zero,
                            alignment: Alignment.centerLeft,
                          ),
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
  const _ItemNotificacion({
    required this.notificacion,
    required this.onMarcarComoLeida,
  });

  final NotificacionInterna notificacion;
  final VoidCallback? onMarcarComoLeida;

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
                if (notificacion.leida)
                  Text(
                    _formatearFecha(notificacion.fecha),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                  )
                else
                  TextButton(
                    onPressed: onMarcarComoLeida,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.green[800],
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 24),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      alignment: Alignment.centerLeft,
                    ),
                    child: const Text(
                      'Marcar como leida',
                      style: TextStyle(fontWeight: FontWeight.w700),
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
