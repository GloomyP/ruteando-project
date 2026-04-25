import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart'; // Asegúrate de que este archivo exista por el CLI

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
      title: 'Ruteando MVP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      // StreamBuilder escucha automáticamente si Firebase tiene un usuario activo
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            return const PantallaPrincipal();
          }
          return const PantallaLogin();
        },
      ),
    );
  }
}

// ==========================================
// PANTALLA PRINCIPAL CON MENU HAMBURGUESA
// ==========================================
class PantallaPrincipal extends StatelessWidget {
  const PantallaPrincipal({super.key});

  // Usa Navigator para abrir una pantalla simple de modulo pendiente.
  void _abrirModuloEnDesarrollo(BuildContext context, String titulo) {
    Navigator.pop(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PantallaModuloEnDesarrollo(titulo: titulo),
      ),
    );
  }

  // Usa Navigator para abrir la pantalla de seleccion de criterio de rutas.
  void _abrirRutas(BuildContext context) {
    Navigator.pop(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const PantallaCriterioOptimizacion(),
      ),
    );
  }

  // Abre la pantalla de perfil desde el icono superior derecho.
  void _abrirPerfil(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => const PantallaPerfil()),
    );
  }

  Future<void> _cerrarSesion(BuildContext context) async {
    Navigator.pop(context);

    // Al cerrar sesion, el StreamBuilder principal detecta el cambio y vuelve
    // automaticamente a la pantalla de login.
    await FirebaseAuth.instance.signOut();
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
            onPressed: () => _abrirPerfil(context),
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
                    const Text(
                      'Ruteando',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.people_alt_outlined),
                title: const Text('Repartidores'),
                onTap: () => _abrirModuloEnDesarrollo(context, 'Repartidores'),
              ),
              ListTile(
                leading: const Icon(Icons.alt_route),
                title: const Text('Rutas'),
                onTap: () => _abrirRutas(context),
              ),
              ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: const Text('Inventario'),
                onTap: () => _abrirModuloEnDesarrollo(context, 'Inventario'),
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
              ],
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
      ),
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
                    etiqueta: 'Name',
                    valor: nombre,
                  ),
                  _DatoPerfil(
                    icono: Icons.email_outlined,
                    etiqueta: 'Email',
                    valor: email,
                  ),
                  const _DatoPerfil(
                    icono: Icons.phone_outlined,
                    etiqueta: 'Phone',
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
                    etiqueta: 'Address',
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
                            builder: (context) =>
                                const PantallaCriterioOptimizacion(),
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
// PANTALLA CRITERIO DE OPTIMIZACION
// ==========================================

// Enum usado para permitir solo un criterio seleccionado a la vez.
enum CriterioOptimizacion {
  tiempoRapido,
  menorDistancia,
  menorConsumoCombustible,
}

// Modelo simple para mostrar cada opcion en la interfaz.
class OpcionOptimizacion {
  const OpcionOptimizacion({
    required this.criterio,
    required this.titulo,
    required this.icono,
  });

  final CriterioOptimizacion criterio;
  final String titulo;
  final IconData icono;
}

class PantallaCriterioOptimizacion extends StatefulWidget {
  const PantallaCriterioOptimizacion({super.key});

  @override
  State<PantallaCriterioOptimizacion> createState() =>
      _PantallaCriterioOptimizacionState();
}

class _PantallaCriterioOptimizacionState
    extends State<PantallaCriterioOptimizacion> {
  CriterioOptimizacion? _criterioSeleccionado;

  // Lista centralizada para construir las 3 opciones solicitadas.
  final List<OpcionOptimizacion> _opciones = const [
    OpcionOptimizacion(
      criterio: CriterioOptimizacion.tiempoRapido,
      titulo: 'Tiempo más rápido',
      icono: Icons.speed,
    ),
    OpcionOptimizacion(
      criterio: CriterioOptimizacion.menorDistancia,
      titulo: 'Menor distancia',
      icono: Icons.straighten,
    ),
    OpcionOptimizacion(
      criterio: CriterioOptimizacion.menorConsumoCombustible,
      titulo: 'Menor consumo de combustible',
      icono: Icons.local_gas_station,
    ),
  ];

  void _optimizarRuta() {
    final criterio = _criterioSeleccionado;

    // Si no hay seleccion, se muestra un mensaje de error visible.
    if (criterio == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes seleccionar un criterio de optimización.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final opcionSeleccionada = _opciones.firstWhere(
      (opcion) => opcion.criterio == criterio,
    );

    // Simulacion del envio del criterio a consola durante desarrollo.
    debugPrint('Criterio seleccionado: ${opcionSeleccionada.titulo}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Optimización de ruta'),
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
                  const Icon(Icons.alt_route, size: 72, color: Colors.green),
                  const SizedBox(height: 24),
                  const Text(
                    'Selecciona criterio de optimización',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: RadioGroup<CriterioOptimizacion>(
                      groupValue: _criterioSeleccionado,
                      onChanged: (valor) {
                        setState(() => _criterioSeleccionado = valor);
                      },
                      child: Column(
                        children: _opciones.map((opcion) {
                          return RadioListTile<CriterioOptimizacion>(
                            value: opcion.criterio,
                            secondary: Icon(opcion.icono, color: Colors.green),
                            title: Text(opcion.titulo),
                            activeColor: Colors.green[700],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _optimizarRuta,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text(
                      'Optimizar Ruta',
                      style: TextStyle(fontSize: 16),
                    ),
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

// Pantalla de destino simple para demostrar que el criterio se envia.
class PantallaRutaOptimizada extends StatelessWidget {
  const PantallaRutaOptimizada({super.key, required this.criterio});

  final String criterio;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ruta optimizada'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, size: 80, color: Colors.green),
              const SizedBox(height: 24),
              const Text(
                'Criterio enviado correctamente',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                criterio,
                style: const TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
            ],
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
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Usuario ${_nameController.text} registrado en Firebase.",
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
          const Icon(Icons.person_add_alt_1, size: 72, color: Colors.green),
          const SizedBox(height: 24),
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
