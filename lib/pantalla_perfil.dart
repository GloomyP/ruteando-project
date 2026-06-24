import 'package:flutter/material.dart';

import 'cierre_sesion.dart';
import 'perfil_usuario.dart';
import 'widgets/telefono_form_field.dart';

const Map<String, List<String>> regionesComunas = {
  'Valparaíso': [
    'Algarrobo',
    'Cabildo',
    'Calle Larga',
    'Cartagena',
    'Casablanca',
    'Catemu',
    'Concón',
    'El Quisco',
    'El Tabo',
    'Hijuelas',
    'Isla de Pascua',
    'Juan Fernández',
    'La Calera',
    'La Cruz',
    'La Ligua',
    'Limache',
    'Llaillay',
    'Los Andes',
    'Nogales',
    'Olmué',
    'Panquehue',
    'Papudo',
    'Petorca',
    'Puchuncaví',
    'Putaendo',
    'Quillota',
    'Quilpué',
    'Quintero',
    'Rinconada',
    'San Antonio',
    'San Esteban',
    'San Felipe',
    'Santa María',
    'Santo Domingo',
    'Valparaíso',
    'Villa Alemana',
    'Viña del Mar',
    'Zapallar',
  ],
};

class PantallaPerfil extends StatefulWidget {
  const PantallaPerfil({super.key});

  @override
  State<PantallaPerfil> createState() => _PantallaPerfilState();
}

class _PantallaPerfilState extends State<PantallaPerfil> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _direccionController = TextEditingController();

  PerfilUsuario? _perfil;
  String? _regionSeleccionada;
  String? _comunaSeleccionada;
  bool _cargando = true;
  bool _editando = false;
  bool _guardando = false;
  String? _mensajeError;
  String? _mensajeExito;

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    super.dispose();
  }

  Future<void> _cargarPerfil() async {
    final perfil = await cargarPerfilUsuario();

    if (!mounted) {
      return;
    }

    setState(() {
      _perfil = perfil;
      _nombreController.text = perfil.nombre;
      _telefonoController.text = TelefonoFormatter.formatearParaMostrar(
        perfil.telefono,
      );
      _regionSeleccionada = _regionValida(perfil.region);
      _comunaSeleccionada = _comunaValida(
        region: _regionSeleccionada,
        comuna: perfil.comuna,
      );
      _direccionController.text = perfil.direccion;
      _cargando = false;
    });
  }

  String? _validarRequerido(String? valor) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Campo obligatorio';
    }

    return null;
  }

  Future<void> _guardarPerfil() async {
    if (!_formKey.currentState!.validate() || _perfil == null) {
      return;
    }

    setState(() {
      _guardando = true;
      _mensajeError = null;
      _mensajeExito = null;
    });

    final perfilActualizado = PerfilUsuario(
      nombre: _nombreController.text.trim(),
      email: _perfil!.email,
      telefono: TelefonoFormatter.normalizar(_telefonoController.text),
      region: _regionSeleccionada?.trim() ?? '',
      comuna: _comunaSeleccionada?.trim() ?? '',
      direccion: _direccionController.text.trim(),
    );

    try {
      await guardarPerfilUsuario(perfilActualizado);

      if (!mounted) {
        return;
      }

      setState(() {
        _perfil = perfilActualizado;
        _editando = false;
        _guardando = false;
        _mensajeExito = 'Perfil actualizado correctamente.';
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _guardando = false;
        _mensajeError = 'Error: $e';
      });
    }
  }

  Future<void> _cerrarSesion(BuildContext context) async {
    await confirmarYCerrarSesion(context);
  }

  @override
  Widget build(BuildContext context) {
    final perfil = _perfil;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: _cargando
                  ? const Center(child: CircularProgressIndicator())
                  : Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Icon(
                            Icons.account_circle,
                            size: 96,
                            color: Colors.green[700],
                          ),
                          const SizedBox(height: 24),
                          if (_editando)
                            _buildFormulario(perfil)
                          else
                            _buildResumen(perfil),
                          const SizedBox(height: 24),
                          if (_mensajeError != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                _mensajeError!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          if (_mensajeExito != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                _mensajeExito!,
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          if (_editando) ...[
                            FilledButton.icon(
                              onPressed: _guardando ? null : _guardarPerfil,
                              icon: _guardando
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: const Text('Guardar cambios'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                backgroundColor: Colors.green[700],
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: _guardando
                                  ? null
                                  : () {
                                      setState(() {
                                        _editando = false;
                                        _mensajeError = null;
                                      });
                                      _cargarPerfil();
                                    },
                              child: const Text('Cancelar'),
                            ),
                          ] else
                            FilledButton.icon(
                              onPressed: () => _cerrarSesion(context),
                              icon: const Icon(Icons.logout),
                              label: const Text('Cerrar sesion'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                backgroundColor: Colors.green[700],
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormulario(PerfilUsuario? perfil) {
    final comunas = _regionSeleccionada == null
        ? const <String>[]
        : regionesComunas[_regionSeleccionada] ?? const <String>[];

    return Column(
      children: [
        TextFormField(
          controller: _nombreController,
          decoration: const InputDecoration(
            labelText: 'Nombre completo',
            prefixIcon: Icon(Icons.person_outline),
          ),
          validator: _validarRequerido,
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: perfil?.email.isNotEmpty == true
              ? perfil!.email
              : 'Email no registrado',
          decoration: const InputDecoration(
            labelText: 'Correo',
            prefixIcon: Icon(Icons.email_outlined),
          ),
          readOnly: true,
        ),
        const SizedBox(height: 12),
        TelefonoFormField(
          controller: _telefonoController,
          labelText: 'Telefono',
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _regionSeleccionada,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Region',
            prefixIcon: Icon(Icons.public),
          ),
          items: regionesComunas.keys.map((region) {
            return DropdownMenuItem<String>(value: region, child: Text(region));
          }).toList(),
          onChanged: _guardando
              ? null
              : (region) {
                  setState(() {
                    _regionSeleccionada = region;
                    _comunaSeleccionada = null;
                  });
                },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _comunaSeleccionada,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Comuna',
            prefixIcon: Icon(Icons.map_outlined),
          ),
          items: comunas.map((comuna) {
            return DropdownMenuItem<String>(value: comuna, child: Text(comuna));
          }).toList(),
          onChanged: _guardando || _regionSeleccionada == null
              ? null
              : (comuna) {
                  setState(() => _comunaSeleccionada = comuna);
                },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _direccionController,
          decoration: const InputDecoration(
            labelText: 'Direccion',
            prefixIcon: Icon(Icons.home_outlined),
          ),
        ),
      ],
    );
  }

  Widget _buildResumen(PerfilUsuario? perfil) {
    return Column(
      children: [
        _DatoPerfil(
          icono: Icons.person_outline,
          etiqueta: 'Nombre',
          valor: _valorPerfil(perfil?.nombre, 'Nombre no registrado'),
          onEditar: () => setState(() => _editando = true),
        ),
        _DatoPerfil(
          icono: Icons.email_outlined,
          etiqueta: 'Correo',
          valor: _valorPerfil(perfil?.email, 'Email no registrado'),
        ),
        _DatoPerfil(
          icono: Icons.phone_outlined,
          etiqueta: 'Telefono',
          valor: _valorPerfil(perfil?.telefono, 'No registrado'),
          onEditar: () => setState(() => _editando = true),
        ),
        _DatoPerfil(
          icono: Icons.public,
          etiqueta: 'Region',
          valor: _valorPerfil(perfil?.region, 'No registrada'),
          onEditar: () => setState(() => _editando = true),
        ),
        _DatoPerfil(
          icono: Icons.map_outlined,
          etiqueta: 'Comuna',
          valor: _valorPerfil(perfil?.comuna, 'No registrada'),
          onEditar: () => setState(() => _editando = true),
        ),
        _DatoPerfil(
          icono: Icons.home_outlined,
          etiqueta: 'Direccion',
          valor: _valorPerfil(perfil?.direccion, 'No registrada'),
          onEditar: () => setState(() => _editando = true),
        ),
      ],
    );
  }

  String _valorPerfil(String? valor, String fallback) {
    final limpio = valor?.trim();
    return limpio == null || limpio.isEmpty ? fallback : limpio;
  }

  String? _regionValida(String? region) {
    final limpia = region?.trim();
    if (limpia == null || limpia.isEmpty) {
      return null;
    }

    for (final disponible in regionesComunas.keys) {
      if (_normalizar(disponible) == _normalizar(limpia)) {
        return disponible;
      }
    }

    return null;
  }

  String? _comunaValida({required String? region, required String? comuna}) {
    final limpia = comuna?.trim();
    if (region == null || limpia == null || limpia.isEmpty) {
      return null;
    }

    for (final disponible in regionesComunas[region] ?? const <String>[]) {
      if (_normalizar(disponible) == _normalizar(limpia)) {
        return disponible;
      }
    }

    return null;
  }

  String _normalizar(String valor) {
    return valor
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u');
  }
}

class _DatoPerfil extends StatelessWidget {
  const _DatoPerfil({
    required this.icono,
    required this.etiqueta,
    required this.valor,
    this.onEditar,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;
  final VoidCallback? onEditar;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icono, color: Colors.green),
        title: Text(etiqueta),
        subtitle: Text(valor),
        trailing: onEditar == null
            ? null
            : IconButton(
                tooltip: 'Editar $etiqueta',
                onPressed: onEditar,
                icon: const Icon(Icons.edit_outlined),
              ),
      ),
    );
  }
}
