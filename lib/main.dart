import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'pantalla_ruta.dart';
import 'roles.dart';

const _empresaUsuarioLocalKey = 'empresa_vinculada_usuario_local';

String _empresaUsuarioKey() {
  try {
    final user = FirebaseAuth.instance.currentUser;
    final identificador = user?.uid ?? user?.email;

    if (identificador != null && identificador.trim().isNotEmpty) {
      return 'empresa_vinculada_usuario_$identificador';
    }
  } catch (_) {
    // Los tests de widgets pueden correr sin Firebase inicializado.
  }

  return _empresaUsuarioLocalKey;
}

Future<Map<String, String>?> _cargarEmpresaVinculada() async {
  final prefs = await SharedPreferences.getInstance();
  final data = prefs.getString(_empresaUsuarioKey());

  if (data == null) {
    return null;
  }

  final decoded = jsonDecode(data);
  if (decoded is! Map<String, dynamic>) {
    return null;
  }

  return decoded.map((key, value) => MapEntry(key, value.toString()));
}

Future<void> _guardarEmpresaVinculada(Map<String, String> empresa) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_empresaUsuarioKey(), jsonEncode(empresa));
}

String _conductoresUsuarioKey() {
  return 'conductores_${_empresaUsuarioKey()}';
}

Future<List<Map<String, String>>> _cargarConductoresVinculados() async {
  final prefs = await SharedPreferences.getInstance();
  final data = prefs.getString(_conductoresUsuarioKey());

  if (data == null) {
    return [];
  }

  final decoded = jsonDecode(data);
  if (decoded is! List) {
    return [];
  }

  return decoded.whereType<Map<String, dynamic>>().map((conductor) {
    return conductor.map((key, value) => MapEntry(key, value.toString()));
  }).toList();
}

Future<void> _guardarConductoresVinculados(
  List<Map<String, String>> conductores,
) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_conductoresUsuarioKey(), jsonEncode(conductores));
}

class _RutInputFormatter extends TextInputFormatter {
  static final _caracteresValidos = RegExp(r'[^0-9kK]');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final limpio = newValue.text
        .replaceAll(_caracteresValidos, '')
        .toUpperCase();

    if (limpio.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final limitado = limpio.length > 9 ? limpio.substring(0, 9) : limpio;
    final formateado = _formatearRut(limitado);

    return TextEditingValue(
      text: formateado,
      selection: TextSelection.collapsed(offset: formateado.length),
    );
  }

  String _formatearRut(String valor) {
    if (valor.length <= 1) {
      return valor;
    }

    final cuerpo = valor.substring(0, valor.length - 1);
    final digitoVerificador = valor.substring(valor.length - 1);
    final grupos = <String>[];

    for (var fin = cuerpo.length; fin > 0; fin -= 3) {
      final inicio = fin - 3 < 0 ? 0 : fin - 3;
      grupos.insert(0, cuerpo.substring(inicio, fin));
    }

    return '${grupos.join('.')}-$digitoVerificador';
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Inicializamos Firebase al arrancar la app
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const RuteandoApp());
}

class RuteandoApp extends StatelessWidget {
  const RuteandoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ruteando',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      // StreamBuilder escucha automáticamente si Firebase tiene un usuario activo
      routes: {
        '/inicio': (context) =>
            const PantallaProtegidaAdmin(pantalla: PantallaPrincipal()),
        '/repartidores': (context) =>
            const PantallaProtegidaAdmin(pantalla: PantallaConductores()),
        '/rutas': (context) =>
            const PantallaProtegidaAdmin(pantalla: PantallaRuta()),
        '/asignacion-rutas': (context) => const PantallaProtegidaAdmin(
          pantalla: PantallaModuloEnDesarrollo(titulo: 'Asignacion de Ruta'),
        ),
        '/monitoreo-entregas': (context) => const PantallaProtegidaAdmin(
          pantalla: PantallaModuloEnDesarrollo(titulo: 'Monitoreo de Entregas'),
        ),
        '/inventario': (context) => const PantallaProtegidaAdmin(
          pantalla: PantallaModuloEnDesarrollo(titulo: 'Inventario'),
        ),
        '/empresa': (context) =>
            const PantallaProtegidaAdmin(pantalla: PantallaRegistroEmpresa()),
        '/mi-ruta': (context) => const PantallaRutaAsignada(),
      },
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final user = snapshot.data;
          if (user != null) {
            return FutureBuilder<RolUsuario>(
              future: cargarRolUsuario(user: user),
              builder: (context, rolSnapshot) {
                if (rolSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                final rol = rolSnapshot.data ?? RolUsuario.admin;
                return rol == RolUsuario.repartidor
                    ? const PantallaRutaAsignada()
                    : const PantallaPrincipal();
              },
            );
          }
          return const PantallaLogin();
        },
      ),
    );
  }
}

class PantallaProtegidaAdmin extends StatelessWidget {
  const PantallaProtegidaAdmin({super.key, required this.pantalla});

  final Widget pantalla;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RolUsuario>(
      future: cargarRolUsuario(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final rol = snapshot.data ?? RolUsuario.admin;
        return puedeAdministrar(rol) ? pantalla : const PantallaRutaAsignada();
      },
    );
  }
}

Widget _buildMenuDrawer(BuildContext context) {
  Future<void> cerrarSesion() async {
    Navigator.pop(context);
    await FirebaseAuth.instance.signOut();
  }

  void abrir(Widget pantalla) {
    Navigator.pop(context);
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute<void>(builder: (context) => pantalla));
  }

  return _DrawerPorRol(abrir: abrir, cerrarSesion: cerrarSesion);
}

class _DrawerPorRol extends StatelessWidget {
  const _DrawerPorRol({required this.abrir, required this.cerrarSesion});

  final void Function(Widget pantalla) abrir;
  final Future<void> Function() cerrarSesion;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: FutureBuilder<RolUsuario>(
          future: cargarRolUsuario(),
          builder: (context, snapshot) {
            final rol = snapshot.data ?? RolUsuario.admin;
            final esAdmin = puedeAdministrar(rol);

            return Column(
              children: [
                DrawerHeader(
                  margin: EdgeInsets.zero,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.green[100],
                        child: Icon(
                          Icons.local_shipping,
                          color: Colors.green[800],
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Bienvenido, ${nombreUsuarioActual()}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                if (esAdmin) ...[
                  ListTile(
                    leading: const Icon(Icons.home_outlined),
                    title: const Text('Inicio'),
                    onTap: () => abrir(const PantallaPrincipal()),
                  ),
                  ListTile(
                    leading: const Icon(Icons.alt_route),
                    title: const Text('Rutas'),
                    onTap: () => abrir(const PantallaRuta()),
                  ),
                  ListTile(
                    leading: const Icon(Icons.assignment_outlined),
                    title: const Text('Asignacion de Ruta'),
                    onTap: () => abrir(
                      const PantallaModuloEnDesarrollo(
                        titulo: 'Asignacion de Ruta',
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.monitor_heart_outlined),
                    title: const Text('Monitoreo de Entregas'),
                    onTap: () => abrir(
                      const PantallaModuloEnDesarrollo(
                        titulo: 'Monitoreo de Entregas',
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.people_alt_outlined),
                    title: const Text('Repartidores'),
                    onTap: () => abrir(const PantallaConductores()),
                  ),
                  ListTile(
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: const Text('Inventario'),
                    onTap: () => abrir(
                      const PantallaModuloEnDesarrollo(titulo: 'Inventario'),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.business_outlined),
                    title: const Text('Empresas'),
                    onTap: () => abrir(const PantallaRegistroEmpresa()),
                  ),
                ] else ...[
                  ListTile(
                    leading: const Icon(Icons.route_outlined),
                    title: const Text('Mi ruta asignada'),
                    onTap: () => abrir(const PantallaRutaAsignada()),
                  ),
                  ListTile(
                    leading: const Icon(Icons.fact_check_outlined),
                    title: const Text('Estado de entregas'),
                    onTap: () => abrir(const PantallaRutaAsignada()),
                  ),
                ],
                const Spacer(),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Cerrar sesion'),
                  onTap: cerrarSesion,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

List<Widget> _accionesPerfil(BuildContext context) {
  return [
    IconButton(
      tooltip: 'Perfil',
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (context) => const PantallaPerfil()),
        );
      },
      icon: const Icon(Icons.account_circle),
    ),
  ];
}

// ==========================================
// PANTALLA PRINCIPAL CON MENU HAMBURGUESA
// ==========================================
class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  late Future<Map<String, String>?> _empresaFuture;

  @override
  void initState() {
    super.initState();
    _empresaFuture = _cargarEmpresaVinculada();
  }

  void _abrirModuloEnDesarrollo(BuildContext context, String titulo) {
    Navigator.pop(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PantallaModuloEnDesarrollo(titulo: titulo),
      ),
    );
  }

  void _abrirConductores(BuildContext context) {
    Navigator.pop(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const PantallaConductores(),
      ),
    );
  }

  void _abrirRutas(BuildContext context) {
    Navigator.pop(context);
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (context) => const PantallaRuta()));
  }

  Future<void> _abrirRegistroEmpresa(BuildContext context) async {
    Navigator.pop(context);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const PantallaRegistroEmpresa(),
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _empresaFuture = _cargarEmpresaVinculada();
    });
  }

  Future<void> _cerrarSesion(BuildContext context) async {
    Navigator.pop(context);
    await FirebaseAuth.instance.signOut();
  }

  void _abrirPerfilSuperior(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => const PantallaPerfil()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ruteando'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Perfil',
            onPressed: () => _abrirPerfilSuperior(context),
            icon: const Icon(Icons.account_circle),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              DrawerHeader(
                margin: EdgeInsets.zero,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.green[100],
                      child: Icon(
                        Icons.local_shipping,
                        color: Colors.green[800],
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Bienvenido, ${nombreUsuarioActual()}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.home_outlined),
                title: const Text('Inicio'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.alt_route),
                title: const Text('Rutas'),
                onTap: () => _abrirRutas(context),
              ),
              ListTile(
                leading: const Icon(Icons.assignment_outlined),
                title: const Text('Asignacion de Ruta'),
                onTap: () =>
                    _abrirModuloEnDesarrollo(context, 'Asignacion de Ruta'),
              ),
              ListTile(
                leading: const Icon(Icons.monitor_heart_outlined),
                title: const Text('Monitoreo de Entregas'),
                onTap: () =>
                    _abrirModuloEnDesarrollo(context, 'Monitoreo de Entregas'),
              ),
              ListTile(
                leading: const Icon(Icons.people_alt_outlined),
                title: const Text('Repartidores'),
                onTap: () => _abrirConductores(context),
              ),
              ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: const Text('Inventario'),
                onTap: () => _abrirModuloEnDesarrollo(context, 'Inventario'),
              ),
              ListTile(
                leading: const Icon(Icons.business_outlined),
                title: const Text('Empresas'),
                onTap: () => _abrirRegistroEmpresa(context),
              ),
              const Spacer(),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Cerrar sesión'),
                onTap: () => _cerrarSesion(context),
              ),
            ],
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_shipping, size: 90, color: Colors.green[700]),
                const SizedBox(height: 24),
                const Text(
                  'Bienvenido a Ruteando',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Gestiona tus operaciones de reparto desde aquí',
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FutureBuilder<Map<String, String>?>(
                  future: _empresaFuture,
                  builder: (context, snapshot) {
                    final empresa = snapshot.data;

                    if (empresa == null) {
                      return const SizedBox.shrink();
                    }

                    return _EmpresaVinculadaCard(empresa: empresa);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmpresaVinculadaCard extends StatelessWidget {
  const _EmpresaVinculadaCard({required this.empresa});

  final Map<String, String> empresa;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.business_outlined, color: Colors.green[700]),
                const SizedBox(width: 8),
                const Text(
                  'Empresa vinculada',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _DatoEmpresa(etiqueta: 'Nombre', valor: empresa['nombre'] ?? ''),
            _DatoEmpresa(etiqueta: 'RUT', valor: empresa['rut'] ?? ''),
            _DatoEmpresa(etiqueta: 'Correo', valor: empresa['correo'] ?? ''),
            _DatoEmpresa(
              etiqueta: 'Telefono',
              valor: empresa['telefono'] ?? '',
            ),
          ],
        ),
      ),
    );
  }
}

class _DatoEmpresa extends StatelessWidget {
  const _DatoEmpresa({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              etiqueta,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(valor.isEmpty ? 'No registrado' : valor)),
        ],
      ),
    );
  }
}

class PantallaConductores extends StatefulWidget {
  const PantallaConductores({super.key});

  @override
  State<PantallaConductores> createState() => _PantallaConductoresState();
}

class _PantallaConductoresState extends State<PantallaConductores> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _rutController = TextEditingController();
  final _correoController = TextEditingController();
  final _telefonoController = TextEditingController();
  Timer? _mensajeExitoTimer;

  Map<String, String>? _empresa;
  List<Map<String, String>> _conductores = [];
  bool _cargando = true;
  String? _mensajeError;
  String? _mensajeExito;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _mensajeExitoTimer?.cancel();
    _nombreController.dispose();
    _rutController.dispose();
    _correoController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  void _mostrarMensajeExitoTemporal(String mensaje) {
    _mensajeExitoTimer?.cancel();
    setState(() {
      _mensajeError = null;
      _mensajeExito = mensaje;
    });

    _mensajeExitoTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) {
        return;
      }

      setState(() {
        if (_mensajeExito == mensaje) {
          _mensajeExito = null;
        }
      });
    });
  }

  String? _validarRequerido(String? valor) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Campo obligatorio';
    }

    return null;
  }

  String? _validarRut(String? valor) {
    final requerido = _validarRequerido(valor);
    if (requerido != null) {
      return requerido;
    }

    final rutValido = RegExp(
      r'^\d{1,2}\.\d{3}\.\d{3}-[\dK]$',
    ).hasMatch(valor!.trim().toUpperCase());

    if (!rutValido) {
      return 'El RUT debe tener formato XX.XXX.XXX-X o X.XXX.XXX-X';
    }

    return null;
  }

  String? _validarCorreo(String? valor) {
    final requerido = _validarRequerido(valor);
    if (requerido != null) {
      return requerido;
    }

    final correo = valor!.trim();
    final partes = correo.split('@');

    if (partes.length != 2 ||
        partes.any((parte) => parte.isEmpty) ||
        correo.contains(' ')) {
      return 'Ingresa un correo con un solo dominio valido';
    }

    final dominioValido = RegExp(
      r'^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$',
    ).hasMatch(partes.last);

    if (!dominioValido) {
      return 'Ingresa un correo con un solo dominio valido';
    }

    return null;
  }

  Future<void> _cargarDatos() async {
    final empresa = await _cargarEmpresaVinculada();
    final conductores = await _cargarConductoresVinculados();

    if (!mounted) {
      return;
    }

    setState(() {
      _empresa = empresa;
      _conductores = conductores;
      _cargando = false;
    });
  }

  Future<void> _registrarConductor() async {
    if (!_formKey.currentState!.validate()) {
      setState(() {
        _mensajeError = 'Debe completar todos los campos obligatorios.';
        _mensajeExito = null;
      });
      return;
    }

    final conductor = {
      'nombre': _nombreController.text.trim(),
      'rut': _rutController.text.trim(),
      'correo': _correoController.text.trim(),
      'telefono': _telefonoController.text.trim(),
      'empresa': _empresa?['rut'] ?? _empresaUsuarioKey(),
      'rol': RolUsuario.repartidor.valor,
    };

    final confirmarAsociacion = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Asociar persona'),
          content: const Text('¿Quieres agregar a esta persona a tu empresa?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );

    if (confirmarAsociacion != true) {
      return;
    }

    final conductoresActualizados = [..._conductores, conductor];

    await _guardarConductoresVinculados(conductoresActualizados);

    if (!mounted) {
      return;
    }

    setState(() {
      _conductores = conductoresActualizados;
      _nombreController.clear();
      _rutController.clear();
      _correoController.clear();
      _telefonoController.clear();
    });
    _mostrarMensajeExitoTemporal('Persona asociada correctamente a la empresa');
  }

  Future<void> _editarRepartidor(int index) async {
    final repartidor = _conductores[index];
    final nombreController = TextEditingController(
      text: repartidor['nombre'] ?? '',
    );
    final rutController = TextEditingController(text: repartidor['rut'] ?? '');
    final correoController = TextEditingController(
      text: repartidor['correo'] ?? '',
    );
    final telefonoController = TextEditingController(
      text: repartidor['telefono'] ?? '',
    );
    final formKey = GlobalKey<FormState>();
    var rolSeleccionado = RolUsuario.desdeValor(repartidor['rol']);

    final repartidorActualizado = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Editar repartidor'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nombreController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre completo',
                        ),
                        validator: _validarRequerido,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: rutController,
                        decoration: const InputDecoration(labelText: 'RUT'),
                        inputFormatters: [_RutInputFormatter()],
                        validator: _validarRut,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: correoController,
                        decoration: const InputDecoration(
                          labelText: 'Correo electronico',
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: _validarCorreo,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: telefonoController,
                        decoration: const InputDecoration(
                          labelText: 'Telefono',
                        ),
                        keyboardType: TextInputType.phone,
                        validator: _validarRequerido,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<RolUsuario>(
                        initialValue: rolSeleccionado,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Rol'),
                        items: RolUsuario.values.map((rol) {
                          return DropdownMenuItem<RolUsuario>(
                            value: rol,
                            child: Text(rol.etiqueta),
                          );
                        }).toList(),
                        onChanged: (rol) {
                          if (rol == null) {
                            return;
                          }

                          setDialogState(() => rolSeleccionado = rol);
                        },
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setDialogState(() {
                              rolSeleccionado =
                                  rolSeleccionado == RolUsuario.admin
                                  ? RolUsuario.repartidor
                                  : RolUsuario.admin;
                            });
                          },
                          icon: const Icon(Icons.swap_horiz),
                          label: const Text('Cambiar rol'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }

                    Navigator.of(dialogContext).pop({
                      'nombre': nombreController.text.trim(),
                      'rut': rutController.text.trim(),
                      'correo': correoController.text.trim(),
                      'telefono': telefonoController.text.trim(),
                      'empresa': repartidor['empresa'] ?? _empresaUsuarioKey(),
                      'rol': rolSeleccionado.valor,
                    });
                  },
                  child: const Text('Guardar cambios'),
                ),
              ],
            );
          },
        );
      },
    );

    if (repartidorActualizado == null) {
      return;
    }

    final repartidoresActualizados = [..._conductores];
    repartidoresActualizados[index] = repartidorActualizado;
    await _guardarConductoresVinculados(repartidoresActualizados);

    if (!mounted) {
      return;
    }

    setState(() {
      _conductores = repartidoresActualizados;
    });
    _mostrarMensajeExitoTemporal('Repartidor actualizado correctamente.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Repartidores'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        actions: _accionesPerfil(context),
      ),
      drawer: _buildMenuDrawer(context),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: _cargando
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.people_alt_outlined,
                          size: 72,
                          color: Colors.green,
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Registro de repartidores',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Empresa: ${_empresa?['nombre'] ?? 'Usuario autenticado'}',
                          style: const TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 16),
                        _buildFormulario(),
                        const SizedBox(height: 24),
                        _buildListaConductores(),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormulario() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _nombreController,
            decoration: const InputDecoration(
              labelText: 'Nombre completo',
              prefixIcon: Icon(Icons.person_outline),
            ),
            textInputAction: TextInputAction.next,
            validator: _validarRequerido,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _rutController,
            decoration: const InputDecoration(
              labelText: 'RUT',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            inputFormatters: [_RutInputFormatter()],
            textInputAction: TextInputAction.next,
            validator: _validarRut,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _correoController,
            decoration: const InputDecoration(
              labelText: 'Correo electronico',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: _validarCorreo,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _telefonoController,
            decoration: const InputDecoration(
              labelText: 'Telefono',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            keyboardType: TextInputType.phone,
            validator: _validarRequerido,
          ),
          const SizedBox(height: 20),
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
          FilledButton.icon(
            onPressed: _registrarConductor,
            icon: const Icon(Icons.save_outlined),
            label: const Text(
              'Registrar repartidor',
              style: TextStyle(fontSize: 16),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.green[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListaConductores() {
    if (_conductores.isEmpty) {
      return const Text(
        'No hay repartidores registrados.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.black54),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Repartidores registrados',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        ..._conductores.asMap().entries.map((entry) {
          final index = entry.key;
          final conductor = entry.value;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const Icon(Icons.person_outline, color: Colors.green),
              title: Text(conductor['nombre'] ?? ''),
              subtitle: Text(
                '${conductor['rut'] ?? ''}\n${conductor['correo'] ?? ''}\n${conductor['telefono'] ?? ''}\nRol: ${conductor['rol'] ?? RolUsuario.repartidor.valor}',
              ),
              isThreeLine: true,
              trailing: IconButton(
                tooltip: 'Editar repartidor',
                onPressed: () => _editarRepartidor(index),
                icon: const Icon(Icons.edit_outlined),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class PantallaRegistroEmpresa extends StatefulWidget {
  const PantallaRegistroEmpresa({super.key});

  @override
  State<PantallaRegistroEmpresa> createState() =>
      _PantallaRegistroEmpresaState();
}

class _PantallaRegistroEmpresaState extends State<PantallaRegistroEmpresa> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _rutController = TextEditingController();
  final _correoController = TextEditingController();
  final _telefonoController = TextEditingController();

  Map<String, String>? _empresaGuardada;
  String? _mensajeError;
  String? _mensajeExito;
  bool _cargandoEmpresa = true;
  bool _editandoEmpresa = false;

  @override
  void initState() {
    super.initState();
    _cargarEmpresaRegistrada();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _rutController.dispose();
    _correoController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  String? _validarRequerido(String? valor) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Campo obligatorio';
    }

    return null;
  }

  String? _validarRut(String? valor) {
    final requerido = _validarRequerido(valor);
    if (requerido != null) {
      return requerido;
    }

    final rutValido = RegExp(
      r'^\d{1,2}\.\d{3}\.\d{3}-[\dK]$',
    ).hasMatch(valor!.trim().toUpperCase());

    if (!rutValido) {
      return 'El RUT debe tener formato XX.XXX.XXX-X o X.XXX.XXX-X';
    }

    return null;
  }

  String? _validarCorreo(String? valor) {
    final requerido = _validarRequerido(valor);
    if (requerido != null) {
      return requerido;
    }

    final correo = valor!.trim();
    final partes = correo.split('@');

    if (partes.length != 2 ||
        partes.any((parte) => parte.isEmpty) ||
        correo.contains(' ')) {
      return 'Ingresa un correo con un solo dominio valido';
    }

    final dominioValido = RegExp(
      r'^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$',
    ).hasMatch(partes.last);

    if (!dominioValido) {
      return 'Ingresa un correo con un solo dominio valido';
    }

    return null;
  }

  Future<void> _cargarEmpresaRegistrada() async {
    final empresa = await _cargarEmpresaVinculada();

    if (!mounted) {
      return;
    }

    setState(() {
      _cargandoEmpresa = false;
      _empresaGuardada = empresa;
      _editandoEmpresa = false;
      if (empresa == null) {
        return;
      }

      _nombreController.text = empresa['nombre'] ?? '';
      _rutController.text = empresa['rut'] ?? '';
      _correoController.text = empresa['correo'] ?? '';
      _telefonoController.text = empresa['telefono'] ?? '';
    });
  }

  Future<void> _registrarEmpresa() async {
    if (!_formKey.currentState!.validate()) {
      setState(() {
        _mensajeError = 'Debe completar todos los campos obligatorios.';
        _mensajeExito = null;
      });
      return;
    }

    final empresa = {
      'nombre': _nombreController.text.trim(),
      'rut': _rutController.text.trim(),
      'correo': _correoController.text.trim(),
      'telefono': _telefonoController.text.trim(),
    };

    await _guardarEmpresaVinculada(empresa);

    if (!mounted) {
      return;
    }

    setState(() {
      final esActualizacion = _empresaGuardada != null;
      _empresaGuardada = empresa;
      _editandoEmpresa = false;
      _mensajeError = null;
      _mensajeExito = esActualizacion
          ? 'Empresa actualizada correctamente.'
          : 'Empresa registrada correctamente.';
    });
  }

  void _editarEmpresa() {
    setState(() {
      _editandoEmpresa = true;
      _mensajeError = null;
      _mensajeExito = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mostrarFormulario = _empresaGuardada == null || _editandoEmpresa;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro de empresa'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        actions: _accionesPerfil(context),
      ),
      drawer: _buildMenuDrawer(context),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: _cargandoEmpresa
                  ? const Center(child: CircularProgressIndicator())
                  : mostrarFormulario
                  ? _buildFormularioEmpresa()
                  : _buildEmpresaRegistrada(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpresaRegistrada() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.business_outlined, size: 72, color: Colors.green),
        const SizedBox(height: 24),
        _EmpresaVinculadaCard(empresa: _empresaGuardada!),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _editarEmpresa,
          icon: const Icon(Icons.edit_outlined),
          label: const Text(
            'Editar informacion',
            style: TextStyle(fontSize: 16),
          ),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Colors.green[700],
          ),
        ),
      ],
    );
  }

  Widget _buildFormularioEmpresa() {
    final esEdicion = _empresaGuardada != null;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.business_outlined, size: 72, color: Colors.green),
          const SizedBox(height: 24),
          Text(
            esEdicion ? 'Editar empresa' : 'Datos de la empresa',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nombreController,
            decoration: const InputDecoration(
              labelText: 'Nombre de empresa',
              prefixIcon: Icon(Icons.apartment),
            ),
            textInputAction: TextInputAction.next,
            validator: _validarRequerido,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _rutController,
            decoration: const InputDecoration(
              labelText: 'RUT',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            inputFormatters: [_RutInputFormatter()],
            textInputAction: TextInputAction.next,
            validator: _validarRut,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _correoController,
            decoration: const InputDecoration(
              labelText: 'Correo de contacto',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: _validarCorreo,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _telefonoController,
            decoration: const InputDecoration(
              labelText: 'Telefono de contacto',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            keyboardType: TextInputType.phone,
            validator: _validarRequerido,
          ),
          const SizedBox(height: 20),
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
          FilledButton.icon(
            onPressed: _registrarEmpresa,
            icon: const Icon(Icons.save_outlined),
            label: Text(
              esEdicion ? 'Guardar cambios' : 'Registrar empresa',
              style: const TextStyle(fontSize: 16),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.green[700],
            ),
          ),
        ],
      ),
    );
  }
}

class PantallaRutaAsignada extends StatefulWidget {
  const PantallaRutaAsignada({super.key});

  @override
  State<PantallaRutaAsignada> createState() => _PantallaRutaAsignadaState();
}

class _PantallaRutaAsignadaState extends State<PantallaRutaAsignada> {
  static const _estados = ['Pendiente', 'En camino', 'Entregado'];
  static const _entregasBase = [
    'Retiro en bodega central',
    'Entrega cliente 1',
    'Entrega cliente 2',
  ];

  late Future<List<String>> _estadosFuture;

  String get _keyEstados {
    final user = FirebaseAuth.instance.currentUser;
    final identificador = user?.uid ?? user?.email ?? 'local';
    return 'estados_entregas_$identificador';
  }

  @override
  void initState() {
    super.initState();
    _estadosFuture = _cargarEstados();
  }

  Future<List<String>> _cargarEstados() async {
    final prefs = await SharedPreferences.getInstance();
    return List<String>.generate(_entregasBase.length, (index) {
      return prefs.getString('${_keyEstados}_$index') ?? _estados.first;
    });
  }

  Future<void> _actualizarEstado(int index, String estado) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_keyEstados}_$index', estado);

    if (!mounted) {
      return;
    }

    setState(() {
      _estadosFuture = _cargarEstados();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi ruta asignada'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        actions: _accionesPerfil(context),
      ),
      drawer: _buildMenuDrawer(context),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: FutureBuilder<List<String>>(
                future: _estadosFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final estados =
                      snapshot.data ??
                      List<String>.filled(_entregasBase.length, _estados.first);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.route_outlined,
                        size: 72,
                        color: Colors.green,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        user?.email ?? 'Repartidor',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Ruta asignada',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...List.generate(_entregasBase.length, (index) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.green[100],
                              foregroundColor: Colors.green[800],
                              child: Text('${index + 1}'),
                            ),
                            title: Text(_entregasBase[index]),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: DropdownButtonFormField<String>(
                                initialValue: estados[index],
                                decoration: const InputDecoration(
                                  labelText: 'Estado de entrega',
                                  isDense: true,
                                ),
                                items: _estados.map((estado) {
                                  return DropdownMenuItem<String>(
                                    value: estado,
                                    child: Text(estado),
                                  );
                                }).toList(),
                                onChanged: (estado) {
                                  if (estado == null) {
                                    return;
                                  }

                                  _actualizarEstado(index, estado);
                                },
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Pantalla reutilizable para modulos que aun no tienen funcionalidad.
class PantallaModuloEnDesarrollo extends StatelessWidget {
  const PantallaModuloEnDesarrollo({super.key, required this.titulo});

  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(titulo),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        actions: _accionesPerfil(context),
      ),
      drawer: _buildMenuDrawer(context),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Módulo en desarrollo',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

// ==========================================
// PANTALLA PERFIL
// ==========================================
class PantallaPerfil extends StatelessWidget {
  const PantallaPerfil({super.key});

  Future<void> _cerrarSesion(BuildContext context) async {
    await FirebaseAuth.instance.signOut();

    if (!context.mounted) return;

    // Limpia las pantallas abiertas para dejar visible el login.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // Firebase entrega nombre y correo si existen; los otros datos quedan
    // preparados como placeholders hasta conectar una base de datos de perfil.
    final nombre = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!
        : 'Nombre no registrado';
    final email = user?.email ?? 'Email no registrado';

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.account_circle,
                    size: 96,
                    color: Colors.green[700],
                  ),
                  const SizedBox(height: 24),
                  _DatoPerfil(
                    icono: Icons.person_outline,
                    etiqueta: 'Nombre',
                    valor: nombre,
                  ),
                  _DatoPerfil(
                    icono: Icons.email_outlined,
                    etiqueta: 'Correo',
                    valor: email,
                  ),
                  const _DatoPerfil(
                    icono: Icons.phone_outlined,
                    etiqueta: 'Telefono',
                    valor: 'No registrado',
                  ),
                  const _DatoPerfil(
                    icono: Icons.public,
                    etiqueta: 'Region',
                    valor: 'No registrada',
                  ),
                  const _DatoPerfil(
                    icono: Icons.map_outlined,
                    etiqueta: 'Comuna',
                    valor: 'No registrada',
                  ),
                  const _DatoPerfil(
                    icono: Icons.home_outlined,
                    etiqueta: 'Direccion',
                    valor: 'No registrada',
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _cerrarSesion(context),
                    icon: const Icon(Icons.logout),
                    label: const Text('Cerrar sesión'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.green[700],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Fila visual reutilizable para los datos del perfil.
class _DatoPerfil extends StatelessWidget {
  const _DatoPerfil({
    required this.icono,
    required this.etiqueta,
    required this.valor,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icono, color: Colors.green),
        title: Text(etiqueta),
        subtitle: Text(valor),
      ),
    );
  }
}

// ==========================================
// PANTALLA DASHBOARD (Mantenida del equipo)
// ==========================================
class PantallaDashboard extends StatelessWidget {
  const PantallaDashboard({super.key});

  Future<void> _cerrarSesion(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cerrar sesión'),
          content: const Text('¿Esta seguro del cierre de sesión?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Cerrar sesión'),
            ),
          ],
        );
      },
    );

    if (confirmar == true) {
      await FirebaseAuth.instance.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'usuario';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ruteando - Dashboard'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
            onPressed: () => _cerrarSesion(context),
            icon: const Icon(Icons.logout, color: Colors.white),
            label: const Text(
              'Cerrar sesión',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Acceso autorizado',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Sesión activa para: $email',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Gestión de sesión ahora controlada por Firebase Authentication.',
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) => const PantallaRuta(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.route),
                      label: const Text('Generar ruta'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
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
}

// ==========================================
// PANTALLA LOGIN (Mantenida y conectada a Firebase)
// ==========================================
class PantallaLogin extends StatefulWidget {
  const PantallaLogin({super.key});
  @override
  State<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends State<PantallaLogin> {
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';
  bool _isLoading = false;
  String? _errorMessage;

  PageRouteBuilder<void> _buildSlideRoute(Widget page) {
    return PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final offsetAnimation = Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation);

        return SlideTransition(position: offsetAnimation, child: child);
      },
    );
  }

  Future<void> _iniciarSesion() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Conexión real con Firebase
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email,
        password: _password,
      );
      // No necesitamos hacer Navigator.push, el StreamBuilder de main() detectará el cambio y mostrará el Dashboard.
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: ${e.message}';
      });
    }
  }

  void _abrirRegistro() {
    Navigator.of(context).push(_buildSlideRoute(const PantallaRegistro()));
  }

  void _abrirCrearContrasena() {
    Navigator.of(
      context,
    ).push(_buildSlideRoute(const PantallaCrearContrasena()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ruteando - Acceso Seguro'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.local_shipping,
                    size: 80,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => (v == null || !v.contains('@'))
                        ? 'Correo inválido'
                        : null,
                    onSaved: (v) => _email = v!.trim(),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true,
                    validator: (v) => (v == null || v.length < 6)
                        ? 'Mínimo 6 caracteres'
                        : null,
                    onSaved: (v) => _password = v!,
                  ),
                  const SizedBox(height: 24),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  FilledButton(
                    onPressed: _isLoading ? null : _iniciarSesion,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.green[700],
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Iniciar Sesión',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _abrirRegistro,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Registrarme',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _abrirCrearContrasena,
                    child: const Text(
                      '¿Olvidaste tu contraseña? Crear nueva contraseña',
                      style: TextStyle(color: Colors.green, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// PANTALLA CREAR CONTRASEÑA (Recuperación via enlace por correo)
// ==========================================
class PantallaCrearContrasena extends StatefulWidget {
  const PantallaCrearContrasena({super.key});
  @override
  State<PantallaCrearContrasena> createState() =>
      _PantallaCrearContrasenaState();
}

class _PantallaCrearContrasenaState extends State<PantallaCrearContrasena> {
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  bool _isLoading = false;
  bool _enviado = false;
  String? _errorMessage;

  Future<void> _enviarEnlace() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _email);
      setState(() {
        _enviado = true;
        _isLoading = false;
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: ${e.message}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear nueva contraseña'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _enviado ? _vistaMensajeExito() : _vistaFormulario(),
          ),
        ),
      ),
    );
  }

  Widget _vistaFormulario() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.lock_reset, size: 80, color: Colors.green),
          const SizedBox(height: 24),
          const Text(
            'Crear contraseña',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Ingresa tu correo electrónico y te enviaremos un enlace para crear o restablecer tu contraseña.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Correo electrónico',
              prefixIcon: Icon(Icons.email),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (v) => (v == null || !v.contains('@'))
                ? 'Ingresa un correo válido'
                : null,
            onSaved: (v) => _email = v!.trim(),
          ),
          const SizedBox(height: 24),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          FilledButton.icon(
            onPressed: _isLoading ? null : _enviarEnlace,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.send),
            label: const Text('Enviar enlace', style: TextStyle(fontSize: 16)),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.green[700],
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Volver al inicio de sesión'),
          ),
        ],
      ),
    );
  }

  Widget _vistaMensajeExito() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.mark_email_read_outlined,
          size: 90,
          color: Colors.green,
        ),
        const SizedBox(height: 24),
        const Text(
          '¡Enlace enviado!',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Hemos enviado un enlace a $_email.\nRevisa tu bandeja de entrada y sigue las instrucciones para crear tu nueva contraseña.',
          style: const TextStyle(fontSize: 15, color: Colors.black87),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
          label: const Text(
            'Volver al inicio de sesión',
            style: TextStyle(fontSize: 16),
          ),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Colors.green[700],
          ),
        ),
      ],
    );
  }
}

// ==========================================
// PANTALLA REGISTRO (Mantenida y conectada a Firebase)
// ==========================================
class PantallaRegistro extends StatefulWidget {
  const PantallaRegistro({super.key});
  @override
  State<PantallaRegistro> createState() => _PantallaRegistroState();
}

class _PantallaRegistroState extends State<PantallaRegistro> {
  final _personalFormKey = GlobalKey<FormState>();
  final _addressFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _regionController = TextEditingController();
  final _comunaController = TextEditingController();
  final _ciudadController = TextEditingController();
  final _calleController = TextEditingController();
  final _numeroController = TextEditingController();
  final _detallesController = TextEditingController();
  bool _isSaving = false;
  bool _showAddressStep = false;
  RolUsuario _rolSeleccionado = RolUsuario.admin;

  void _goToAddressStep() {
    if (!_personalFormKey.currentState!.validate()) return;
    setState(() => _showAddressStep = true);
  }

  void _goToPersonalStep() {
    setState(() => _showAddressStep = false);
  }

  Future<void> registerUser() async {
    if (!_addressFormKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );
      await credential.user?.updateDisplayName(_nameController.text.trim());
      await guardarRolUsuario(_rolSeleccionado, user: credential.user);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Usuario ${_nameController.text} registrado como ${_rolSeleccionado.valor}.",
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.message}"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro de usuario'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        leading: _showAddressStep
            ? IconButton(
                onPressed: _goToPersonalStep,
                icon: const Icon(Icons.arrow_back),
              )
            : null,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) {
                final offsetAnimation = Tween<Offset>(
                  begin: const Offset(0.08, 0),
                  end: Offset.zero,
                ).animate(animation);

                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: offsetAnimation,
                    child: child,
                  ),
                );
              },
              child: _showAddressStep
                  ? _buildAddressStep()
                  : _buildPersonalInfoStep(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalInfoStep() {
    return Form(
      key: _personalFormKey,
      child: Column(
        key: const ValueKey('personal-step'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.person_add_alt_1, size: 56, color: Colors.green),
          const SizedBox(height: 16),
          const Text(
            'Información personal',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nombre completo',
              prefixIcon: Icon(Icons.person),
            ),
            validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Correo electrónico',
              prefixIcon: Icon(Icons.email),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (v) =>
                (v == null || !v.contains('@')) ? 'Correo inválido' : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<RolUsuario>(
            initialValue: _rolSeleccionado,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Rol',
              prefixIcon: Icon(Icons.admin_panel_settings_outlined),
            ),
            items: RolUsuario.values.map((rol) {
              return DropdownMenuItem<RolUsuario>(
                value: rol,
                child: Text(rol.etiqueta),
              );
            }).toList(),
            onChanged: (rol) {
              if (rol == null) {
                return;
              }

              setState(() => _rolSeleccionado = rol);
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: 'Contraseña',
              prefixIcon: Icon(Icons.lock),
            ),
            obscureText: true,
            validator: (v) =>
                (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmPasswordController,
            decoration: const InputDecoration(
              labelText: 'Confirmar contraseña',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            obscureText: true,
            validator: (v) => (v != _passwordController.text)
                ? 'Las contraseñas no coinciden'
                : null,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _goToAddressStep,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.green[700],
            ),
            child: const Text('Siguiente', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressStep() {
    return Form(
      key: _addressFormKey,
      child: Column(
        key: const ValueKey('address-step'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.home_work_outlined, size: 72, color: Colors.green),
          const SizedBox(height: 24),
          const Text(
            'Dirección',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _regionController,
            decoration: const InputDecoration(
              labelText: 'Región',
              prefixIcon: Icon(Icons.public),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _comunaController,
            decoration: const InputDecoration(
              labelText: 'Comuna',
              prefixIcon: Icon(Icons.map),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _ciudadController,
            decoration: const InputDecoration(
              labelText: 'Ciudad',
              prefixIcon: Icon(Icons.location_city),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _calleController,
            decoration: const InputDecoration(
              labelText: 'Calle',
              prefixIcon: Icon(Icons.signpost),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _numeroController,
            decoration: const InputDecoration(
              labelText: 'Número',
              prefixIcon: Icon(Icons.pin),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _detallesController,
            decoration: const InputDecoration(
              labelText: 'Detalles',
              prefixIcon: Icon(Icons.notes),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isSaving ? null : registerUser,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.green[700],
            ),
            child: _isSaving
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Registrarse', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _isSaving ? null : _goToPersonalStep,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Volver', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
