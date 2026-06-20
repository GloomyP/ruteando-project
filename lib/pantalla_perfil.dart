import 'package:flutter/material.dart';

import 'cierre_sesion.dart';
import 'perfil_usuario.dart';

class PantallaPerfil extends StatefulWidget {
  const PantallaPerfil({super.key});

  @override
  State<PantallaPerfil> createState() => _PantallaPerfilState();
}

class _PantallaPerfilState extends State<PantallaPerfil> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _regionController = TextEditingController();
  final _comunaController = TextEditingController();
  final _direccionController = TextEditingController();

  PerfilUsuario? _perfil;
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
    _regionController.dispose();
    _comunaController.dispose();
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
      _telefonoController.text = perfil.telefono;
      _regionController.text = perfil.region;
      _comunaController.text = perfil.comuna;
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
      telefono: _telefonoController.text.trim(),
      region: _regionController.text.trim(),
      comuna: _comunaController.text.trim(),
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
        TextFormField(
          controller: _telefonoController,
          decoration: const InputDecoration(
            labelText: 'Telefono',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _regionController,
          decoration: const InputDecoration(
            labelText: 'Region',
            prefixIcon: Icon(Icons.public),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _comunaController,
          decoration: const InputDecoration(
            labelText: 'Comuna',
            prefixIcon: Icon(Icons.map_outlined),
          ),
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
