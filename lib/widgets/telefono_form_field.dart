import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TelefonoPais {
  const TelefonoPais({
    required this.codigo,
    required this.nombre,
    required this.prefijo,
    required this.digitosLocales,
  });

  final String codigo;
  final String nombre;
  final String prefijo;
  final int digitosLocales;

  String get etiqueta => '$codigo $prefijo';
}

const List<TelefonoPais> paisesTelefono = [
  TelefonoPais(
    codigo: 'CL',
    nombre: 'Chile',
    prefijo: '+569',
    digitosLocales: 8,
  ),
  TelefonoPais(
    codigo: 'AR',
    nombre: 'Argentina',
    prefijo: '+549',
    digitosLocales: 10,
  ),
  TelefonoPais(codigo: 'PE', nombre: 'Peru', prefijo: '+51', digitosLocales: 9),
  TelefonoPais(
    codigo: 'CO',
    nombre: 'Colombia',
    prefijo: '+57',
    digitosLocales: 10,
  ),
  TelefonoPais(
    codigo: 'MX',
    nombre: 'Mexico',
    prefijo: '+52',
    digitosLocales: 10,
  ),
  TelefonoPais(
    codigo: 'US',
    nombre: 'Estados Unidos',
    prefijo: '+1',
    digitosLocales: 10,
  ),
  TelefonoPais(
    codigo: 'BR',
    nombre: 'Brasil',
    prefijo: '+55',
    digitosLocales: 11,
  ),
  TelefonoPais(
    codigo: 'ES',
    nombre: 'Espana',
    prefijo: '+34',
    digitosLocales: 9,
  ),
  TelefonoPais(
    codigo: 'UY',
    nombre: 'Uruguay',
    prefijo: '+598',
    digitosLocales: 8,
  ),
];

class TelefonoFormatter {
  const TelefonoFormatter._();

  static TelefonoPais get paisPorDefecto => paisesTelefono.first;

  static TelefonoPais paisDesdeTelefono(String telefono) {
    final digitos = _soloDigitos(telefono);
    return paisesTelefono.firstWhere(
      (pais) => digitos.startsWith(_soloDigitos(pais.prefijo)),
      orElse: () => paisPorDefecto,
    );
  }

  static String normalizar(String telefono, {TelefonoPais? pais}) {
    final paisActivo = pais ?? paisDesdeTelefono(telefono);
    final local = digitosLocales(telefono, pais: paisActivo);
    return local.isEmpty ? '' : '${paisActivo.prefijo}$local';
  }

  static String formatearParaMostrar(String telefono, {TelefonoPais? pais}) {
    final paisActivo = pais ?? paisDesdeTelefono(telefono);
    final local = digitosLocales(telefono, pais: paisActivo);
    return _formatear(paisActivo, local);
  }

  static String formatearLocal(String local, {required TelefonoPais pais}) {
    final limitado = local.length > pais.digitosLocales
        ? local.substring(0, pais.digitosLocales)
        : local;
    return _formatear(pais, limitado);
  }

  static bool esValido(String telefono, {TelefonoPais? pais}) {
    final paisActivo = pais ?? paisDesdeTelefono(telefono);
    return digitosLocales(telefono, pais: paisActivo).length ==
        paisActivo.digitosLocales;
  }

  static String digitosLocales(String telefono, {TelefonoPais? pais}) {
    final paisActivo = pais ?? paisDesdeTelefono(telefono);
    var digitos = _soloDigitos(telefono);
    final prefijoActivo = _soloDigitos(paisActivo.prefijo);

    if (digitos.startsWith(prefijoActivo)) {
      digitos = digitos.substring(prefijoActivo.length);
    } else {
      for (final paisDisponible in paisesTelefono) {
        final prefijo = _soloDigitos(paisDisponible.prefijo);
        if (digitos.startsWith(prefijo)) {
          digitos = digitos.substring(prefijo.length);
          break;
        }
      }
    }

    if (digitos.length > paisActivo.digitosLocales) {
      return digitos.substring(0, paisActivo.digitosLocales);
    }

    return digitos;
  }

  static String _formatear(TelefonoPais pais, String local) {
    if (local.isEmpty) {
      return pais.prefijo;
    }

    return '${pais.prefijo} ${_agrupar(local)}';
  }

  static String _agrupar(String digitos) {
    final grupos = <String>[];
    for (var inicio = 0; inicio < digitos.length; inicio += 4) {
      final fin = inicio + 4 > digitos.length ? digitos.length : inicio + 4;
      grupos.add(digitos.substring(inicio, fin));
    }
    return grupos.join(' ');
  }

  static String _soloDigitos(String valor) {
    return valor.replaceAll(RegExp(r'[^0-9]'), '');
  }
}

class TelefonoInputFormatter extends TextInputFormatter {
  TelefonoInputFormatter({required this.pais});

  final TelefonoPais pais;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final local = TelefonoFormatter.digitosLocales(newValue.text, pais: pais);
    final formateado = TelefonoFormatter.formatearLocal(local, pais: pais);

    return TextEditingValue(
      text: formateado,
      selection: TextSelection.collapsed(offset: formateado.length),
    );
  }
}

class TelefonoFormField extends StatefulWidget {
  const TelefonoFormField({
    super.key,
    required this.controller,
    required this.labelText,
    this.prefixIcon = Icons.phone_outlined,
    this.textInputAction,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String labelText;
  final IconData prefixIcon;
  final TextInputAction? textInputAction;
  final bool enabled;

  @override
  State<TelefonoFormField> createState() => _TelefonoFormFieldState();
}

class _TelefonoFormFieldState extends State<TelefonoFormField> {
  late TelefonoPais _paisSeleccionado;

  @override
  void initState() {
    super.initState();
    _paisSeleccionado = TelefonoFormatter.paisDesdeTelefono(
      widget.controller.text,
    );
    widget.controller.addListener(_sincronizarPaisDesdeTexto);
    _actualizarTexto();
  }

  @override
  void didUpdateWidget(covariant TelefonoFormField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_sincronizarPaisDesdeTexto);
      widget.controller.addListener(_sincronizarPaisDesdeTexto);
      _paisSeleccionado = TelefonoFormatter.paisDesdeTelefono(
        widget.controller.text,
      );
      _actualizarTexto();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sincronizarPaisDesdeTexto);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 132,
          child: DropdownButtonFormField<TelefonoPais>(
            initialValue: _paisSeleccionado,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Pais',
              prefixIcon: Icon(widget.prefixIcon),
            ),
            items: paisesTelefono.map((pais) {
              return DropdownMenuItem<TelefonoPais>(
                value: pais,
                child: Text(pais.etiqueta),
              );
            }).toList(),
            onChanged: widget.enabled
                ? (pais) {
                    if (pais == null) {
                      return;
                    }

                    setState(() {
                      final local = TelefonoFormatter.digitosLocales(
                        widget.controller.text,
                        pais: _paisSeleccionado,
                      );
                      _paisSeleccionado = pais;
                      widget.controller.text = TelefonoFormatter.formatearLocal(
                        local,
                        pais: _paisSeleccionado,
                      );
                    });
                  }
                : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            controller: widget.controller,
            decoration: InputDecoration(labelText: widget.labelText),
            enabled: widget.enabled,
            keyboardType: TextInputType.phone,
            textInputAction: widget.textInputAction,
            inputFormatters: [TelefonoInputFormatter(pais: _paisSeleccionado)],
            validator: _validarTelefono,
          ),
        ),
      ],
    );
  }

  String? _validarTelefono(String? valor) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Campo obligatorio';
    }

    if (!TelefonoFormatter.esValido(valor, pais: _paisSeleccionado)) {
      return 'Ingresa ${_paisSeleccionado.digitosLocales} digitos despues de ${_paisSeleccionado.prefijo}';
    }

    return null;
  }

  void _actualizarTexto() {
    widget.controller.text = TelefonoFormatter.formatearParaMostrar(
      widget.controller.text,
      pais: _paisSeleccionado,
    );
  }

  void _sincronizarPaisDesdeTexto() {
    final paisDetectado = TelefonoFormatter.paisDesdeTelefono(
      widget.controller.text,
    );

    if (paisDetectado == _paisSeleccionado || !mounted) {
      return;
    }

    setState(() => _paisSeleccionado = paisDetectado);
  }
}
