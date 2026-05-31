import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'menu_drawer.dart';
import 'persistencia_rutas.dart';
import 'pantalla_ruta.dart';
import 'pantalla_asignacion_ruta.dart';
import 'roles.dart';
import 'pantalla_monitoreo_entregas.dart';
import 'pantalla_perfil.dart';
import 'perfil_usuario.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

String _empresaUsuarioKey() => empresaUsuarioKey();

class _EstadoSesion {
  const _EstadoSesion({required this.rol, required this.debeCambiarContrasena});

  final RolUsuario rol;
  final bool debeCambiarContrasena;
}

Future<_EstadoSesion> _cargarEstadoSesion(User user) async {
  final rol = await cargarRolUsuario(user: user);
  final requiereCambio = rol == RolUsuario.repartidor
      ? await debeCambiarContrasena(user: user)
      : false;

  return _EstadoSesion(rol: rol, debeCambiarContrasena: requiereCambio);
}

// Inicializamos la instancia conectada a tu base de datos específica "ruteando"
final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
  app: Firebase.app(),
  databaseId: 'ruteando',
);

Future<Map<String, String>?> _cargarEmpresaVinculada() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    final identificador = user?.email?.toLowerCase().trim() ?? user?.uid;

    if (identificador != null) {
      // 1. Intentar cargar los datos desde la nube (Firestore)
      final doc = await _firestore
          .collection('empresas_usuarios')
          .doc(identificador)
          .get();
      if (doc.exists && doc.data() != null) {
        final Map<String, dynamic> data = doc.data()!;
        final Map<String, String> empresa = data.map(
          (key, value) => MapEntry(key, value.toString()),
        );

        // Actualizamos el respaldo en SharedPreferences por si acaso
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_empresaUsuarioKey(), jsonEncode(empresa));

        return empresa;
      }
    }
  } catch (_) {
    // Si no hay red o falla Firestore, el flujo cae al respaldo de SharedPreferences
  }

  // 2. Respaldo local tradicional con SharedPreferences
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
  // 1. Guardar localmente en SharedPreferences para acceso rápido inmediato
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_empresaUsuarioKey(), jsonEncode(empresa));

  // 2. Guardar en la nube (Firestore) para persistencia real multiusuario
  try {
    final user = FirebaseAuth.instance.currentUser;
    final identificador = user?.email?.toLowerCase().trim() ?? user?.uid;

    if (identificador != null) {
      await _firestore
          .collection('empresas_usuarios')
          .doc(identificador)
          .set(empresa, SetOptions(merge: true));
    }
  } catch (e) {
    debugPrint('Error al guardar la empresa en Firestore: $e');
  }
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
        '/asignacion-rutas': (context) =>
            const PantallaProtegidaAdmin(pantalla: PantallaAsignacionRuta()),
        '/monitoreo-entregas': (context) =>
            const PantallaProtegidaAdmin(pantalla: PantallaMonitoreoEntregas()),
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
            return FutureBuilder<_EstadoSesion>(
              future: _cargarEstadoSesion(user),
              builder: (context, estadoSnapshot) {
                if (estadoSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                final estado =
                    estadoSnapshot.data ??
                    const _EstadoSesion(
                      rol: RolUsuario.admin,
                      debeCambiarContrasena: false,
                    );

                if (estado.rol == RolUsuario.repartidor) {
                  return estado.debeCambiarContrasena
                      ? const PantallaCambioContrasenaObligatorio()
                      : const PantallaRutaAsignada();
                }

                return const PantallaPrincipal();
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

Widget _buildMenuDrawer(BuildContext context, {String? currentRoute}) {
  return AppMenuDrawer(currentRoute: currentRoute);
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
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cerrar sesion'),
          content: const Text('¿Quieres cerrar tu sesion?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesion'),
            ),
          ],
        );
      },
    );

    if (confirmar != true || !context.mounted) {
      return;
    }

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
                title: const Text('Asignación de Ruta'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => const PantallaAsignacionRuta(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.monitor_heart_outlined),
                title: const Text('Monitoreo de Entregas'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => const PantallaMonitoreoEntregas(),
                    ),
                  );
                },
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
  Map<String, String> _contrasenasVisibles = {};
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

  String _normalizarCorreo(String correo) {
    return correo.toLowerCase().trim();
  }

  String _generarContrasenaTemporal(String nombre) {
    final nombreClave = nombre.trim().toLowerCase().replaceAll(
      RegExp(r'\s+'),
      '',
    );
    return '${nombreClave}123';
  }

  Future<void> _crearCuentaRepartidor({
    required String nombre,
    required String correo,
    required String contrasena,
  }) async {
    if (Firebase.apps.isEmpty) {
      return;
    }

    final app = await Firebase.initializeApp(
      name:
          'ruteando-creacion-repartidor-${DateTime.now().microsecondsSinceEpoch}',
      options: DefaultFirebaseOptions.currentPlatform,
    );

    try {
      final auth = FirebaseAuth.instanceFor(app: app);
      final credential = await auth.createUserWithEmailAndPassword(
        email: correo,
        password: contrasena,
      );
      await credential.user?.updateDisplayName(nombre);
      await auth.signOut();
    } finally {
      await app.delete();
    }
  }

  Future<Map<String, String>> _cargarContrasenasVisibles(
    List<Map<String, String>> conductores,
  ) async {
    if (Firebase.apps.isEmpty) {
      return {};
    }

    final contrasenas = <String, String>{};

    for (final conductor in conductores) {
      final correo = _normalizarCorreo(conductor['correo'] ?? '');
      if (correo.isEmpty) {
        continue;
      }

      try {
        final doc = await _firestore
            .collection('roles_usuarios')
            .doc(correo)
            .get();
        final visible = doc.data()?['contrasenaTemporalVisible']?.toString();
        if (visible != null && visible.isNotEmpty) {
          contrasenas[correo] = visible;
        }
      } catch (_) {}
    }

    return contrasenas;
  }

  Future<void> _cargarDatos() async {
    final empresa = await _cargarEmpresaVinculada();
    final conductores = await cargarConductoresVinculados();
    final contrasenas = await _cargarContrasenasVisibles(conductores);

    if (!mounted) {
      return;
    }

    setState(() {
      _empresa = empresa;
      _conductores = conductores;
      _contrasenasVisibles = contrasenas;
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

    final nombre = _nombreController.text.trim();
    final correo = _normalizarCorreo(_correoController.text);
    final contrasenaTemporal = _generarContrasenaTemporal(nombre);

    final conductor = {
      'nombre': nombre,
      'rut': _rutController.text.trim(),
      'correo': correo,
      'telefono': _telefonoController.text.trim(),
      'empresa': _empresa?['rut'] ?? _empresaUsuarioKey(),
      'rol': RolUsuario.repartidor.valor,
      'contrasenaTemporal': contrasenaTemporal,
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

    try {
      await _crearCuentaRepartidor(
        nombre: nombre,
        correo: correo,
        contrasena: contrasenaTemporal,
      );
      if (Firebase.apps.isNotEmpty) {
        await guardarCambioContrasenaRequerido(
          email: correo,
          contrasenaTemporal: contrasenaTemporal,
        );
      }
      if (Firebase.apps.isNotEmpty) {
        await guardarConductoresVinculados(conductoresActualizados);
        await actualizarTelefonoPerfilPorAdmin(
          email: correo,
          nombre: nombre,
          telefono: _telefonoController.text.trim(),
        );
      }
    } on FirebaseException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _mensajeError = 'Error: ${e.message}';
        _mensajeExito = null;
      });
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _conductores = conductoresActualizados;
      _contrasenasVisibles[correo] = contrasenaTemporal;
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
                      'contrasenaTemporal':
                          repartidor['contrasenaTemporal'] ??
                          _contrasenasVisibles[_normalizarCorreo(
                            repartidor['correo'] ?? '',
                          )] ??
                          '****',
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
    if (Firebase.apps.isNotEmpty) {
      await guardarConductoresVinculados(repartidoresActualizados);
      await actualizarTelefonoPerfilPorAdmin(
        email: repartidorActualizado['correo'] ?? '',
        nombre: repartidorActualizado['nombre'] ?? '',
        telefono: repartidorActualizado['telefono'] ?? '',
      );
    }

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
      drawer: _buildMenuDrawer(context, currentRoute: '/repartidores'),
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
          final correo = _normalizarCorreo(conductor['correo'] ?? '');
          final contrasenaVisible =
              _contrasenasVisibles[correo] ??
              conductor['contrasenaTemporal'] ??
              '****';
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.person_outline, color: Colors.green),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          conductor['nombre'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${conductor['rut'] ?? ''}\n'
                          '${conductor['correo'] ?? ''}\n'
                          '${conductor['telefono'] ?? ''}\n'
                          'Rol: ${conductor['rol'] ?? RolUsuario.repartidor.valor}\n'
                          'Contrasena: $contrasenaVisible',
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Editar repartidor',
                    onPressed: () => _editarRepartidor(index),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
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
      drawer: _buildMenuDrawer(context, currentRoute: '/empresa'),
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

  Map<String, dynamic>? _rutaAsignada;
  Map<String, dynamic>? _notificacionRuta;
  bool _cargando = true;

  String get _driverEmail {
    try {
      final user = FirebaseAuth.instance.currentUser;
      return user?.email ?? 'local';
    } catch (_) {
      return 'local';
    }
  }

  @override
  void initState() {
    super.initState();
    _cargarRuta();
  }

  Future<void> _cargarRuta() async {
    setState(() => _cargando = true);
    final email = _driverEmail;
    final ruta = await cargarRutaAsignada(email);
    final notificacion = await cargarNotificacionRuta(email);

    if (!mounted) return;
    setState(() {
      _rutaAsignada = ruta;
      _notificacionRuta = notificacion;
      _cargando = false;
    });
  }

  Future<void> _abrirRutaDesdeNotificacion() async {
    final email = _driverEmail;
    await marcarNotificacionRutaLeida(email);
    final notificacionActualizada = await cargarNotificacionRuta(email);

    if (!mounted) return;
    setState(() {
      _notificacionRuta = notificacionActualizada;
    });

    await _cargarRuta();
  }

  Future<void> _actualizarEstado(int index, String nuevoEstado) async {
    if (_rutaAsignada == null) return;

    // Crear copias mutables de las paradas
    final paradas = List<Map<String, dynamic>>.from(
      (_rutaAsignada!['paradas'] as List).map(
        (p) => Map<String, dynamic>.from(p as Map),
      ),
    );

    paradas[index]['estado'] = nuevoEstado;
    _rutaAsignada!['paradas'] = paradas;

    final email = _driverEmail;

    // Guardar localmente la asignación actualizada
    await guardarRutaAsignada(email, _rutaAsignada!);

    // Sincronizar en la lista global de asignaciones para el administrador
    final globalAssignments = await cargarAsignacionesGlobales();
    final idx = globalAssignments.indexWhere(
      (a) => a['repartidorEmail'] == email,
    );
    if (idx != -1) {
      globalAssignments[idx] = _rutaAsignada!;
    } else {
      globalAssignments.add(_rutaAsignada!);
    }
    await guardarAsignacionesGlobales(globalAssignments);

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {}

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi ruta asignada'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        actions: _accionesPerfil(context),
      ),
      drawer: _buildMenuDrawer(context, currentRoute: '/mi-ruta'),
      body: SafeArea(
        child: Center(
          child: _cargando
              ? const CircularProgressIndicator()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_notificacionRuta != null &&
                            _notificacionRuta!['leida'] != true) ...[
                          _buildNotificacionRuta(),
                          const SizedBox(height: 16),
                        ],
                        _rutaAsignada == null
                            ? _buildEmptyState()
                            : _buildDetalleRuta(user),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.route_outlined, size: 96, color: Colors.grey),
        const SizedBox(height: 24),
        const Text(
          'No tienes rutas asignadas',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        const Text(
          'Tu administrador de flota te asignará una ruta optimizada cuando esté disponible. Presiona Refrescar para comprobar.',
          style: TextStyle(fontSize: 15, color: Colors.black54),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Center(
          child: OutlinedButton.icon(
            onPressed: _cargarRuta,
            icon: const Icon(Icons.refresh),
            label: const Text('Refrescar'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificacionRuta() {
    final titulo =
        _notificacionRuta!['titulo']?.toString() ?? 'Nueva ruta asignada';
    final mensaje =
        _notificacionRuta!['mensaje']?.toString() ??
        'Tienes una ruta pendiente.';
    final origen =
        _notificacionRuta!['origen']?.toString() ?? 'Origen no especificado';
    final paradas = _notificacionRuta!['paradas']?.toString() ?? '0';
    final distancia = _notificacionRuta!['distancia']?.toString() ?? 'N/A';
    final tiempo = _notificacionRuta!['tiempo']?.toString() ?? 'N/A';
    final criterio = _notificacionRuta!['criterio']?.toString() ?? 'N/A';

    return Card(
      elevation: 3,
      color: Colors.green[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.green.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.notifications_active, color: Colors.green[800]),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(mensaje, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Text(
              'Origen: $origen',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Text('Paradas: $paradas', style: const TextStyle(fontSize: 12)),
                Text(
                  'Distancia: $distancia',
                  style: const TextStyle(fontSize: 12),
                ),
                Text('Tiempo: $tiempo', style: const TextStyle(fontSize: 12)),
                Text(
                  'Criterio: $criterio',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _abrirRutaDesdeNotificacion,
                icon: const Icon(Icons.route),
                label: const Text('Ver ruta'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green[700],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetalleRuta(User? user) {
    final origen = _rutaAsignada!['origen']?.toString() ?? 'No especificado';
    final paradas = _rutaAsignada!['paradas'] as List? ?? [];
    final distancia = _rutaAsignada!['distancia']?.toString() ?? 'N/A';
    final tiempo = _rutaAsignada!['tiempo']?.toString() ?? 'N/A';

    // Estadísticas
    final total = paradas.length;
    final entregados = paradas
        .where((p) => (p as Map)['estado'] == 'Entregado')
        .length;
    final porcentaje = total > 0 ? entregados / total : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.alt_route, size: 72, color: Colors.green),
        const SizedBox(height: 16),
        Text(
          user?.email ?? 'Repartidor',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 24),
        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Resumen del viaje',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.trip_origin,
                      size: 16,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Origen: $origen',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Distancia: $distancia',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Tiempo estimado: $tiempo',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Progreso de entregas',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$entregados / $total completadas',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: porcentaje,
                    minHeight: 6,
                    color: entregados == total ? Colors.green : Colors.orange,
                    backgroundColor: Colors.grey[200],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Paradas en ruta',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            IconButton(
              tooltip: 'Recargar ruta',
              onPressed: _cargarRuta,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...List.generate(total, (index) {
          final parada = paradas[index] as Map;
          final texto = parada['texto']?.toString() ?? '';
          final estado = parada['estado']?.toString() ?? 'Pendiente';

          Color estadoColor = Colors.grey;
          if (estado == 'En camino') estadoColor = Colors.blue;
          if (estado == 'Entregado') estadoColor = Colors.green;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: estadoColor.withValues(alpha: 0.1),
                foregroundColor: estadoColor,
                child: Text('${index + 1}'),
              ),
              title: Text(
                texto,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: DropdownButtonFormField<String>(
                  initialValue: estado,
                  decoration: InputDecoration(
                    labelText: 'Estado de entrega',
                    isDense: true,
                    labelStyle: TextStyle(color: estadoColor),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: estadoColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: estadoColor.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  items: _estados.map((est) {
                    return DropdownMenuItem<String>(
                      value: est,
                      child: Text(est),
                    );
                  }).toList(),
                  onChanged: (nuevoEst) {
                    if (nuevoEst == null) return;
                    _actualizarEstado(index, nuevoEst);
                  },
                ),
              ),
            ),
          );
        }),
      ],
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
      drawer: _buildMenuDrawer(context, currentRoute: '/inventario'),
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
class PantallaPerfilLegacy extends StatelessWidget {
  const PantallaPerfilLegacy({super.key});

  Future<void> _cerrarSesion(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cerrar sesion'),
          content: const Text('¿Quieres cerrar tu sesion?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesion'),
            ),
          ],
        );
      },
    );

    if (confirmar != true || !context.mounted) return;

    // Limpia las pantallas abiertas para dejar visible el login.
    Navigator.of(context).popUntil((route) => route.isFirst);
    await FirebaseAuth.instance.signOut();
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

class PantallaCambioContrasenaObligatorio extends StatefulWidget {
  const PantallaCambioContrasenaObligatorio({super.key});

  @override
  State<PantallaCambioContrasenaObligatorio> createState() =>
      _PantallaCambioContrasenaObligatorioState();
}

class _PantallaCambioContrasenaObligatorioState
    extends State<PantallaCambioContrasenaObligatorio> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _cambiarContrasena() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'no-current-user',
          message: 'No hay una sesion activa.',
        );
      }

      await user.updatePassword(_passwordController.text.trim());
      await marcarContrasenaCambiada(user: user);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacementNamed('/mi-ruta');
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isSaving = false;
        _errorMessage = 'Error: ${e.message}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cambiar contrasena'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.lock_reset, size: 72, color: Colors.green),
                  const SizedBox(height: 24),
                  const Text(
                    'Debes cambiar tu contrasena antes de continuar.',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Nueva contrasena',
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true,
                    validator: (v) => (v == null || v.trim().length < 6)
                        ? 'Minimo 6 caracteres'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration: const InputDecoration(
                      labelText: 'Confirmar contrasena',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                    validator: (v) => (v != _passwordController.text)
                        ? 'Las contrasenas no coinciden'
                        : null,
                  ),
                  const SizedBox(height: 20),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
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
                    onPressed: _isSaving ? null : _cambiarContrasena,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.green[700],
                    ),
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Guardar nueva contrasena',
                            style: TextStyle(fontSize: 16),
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
