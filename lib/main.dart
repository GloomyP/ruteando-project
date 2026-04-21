import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RuteandoApp());
}

class RuteandoApp extends StatefulWidget {
  const RuteandoApp({super.key});

  @override
  State<RuteandoApp> createState() => _RuteandoAppState();
}

class _RuteandoAppState extends State<RuteandoApp> {
  late final Future<AuthSessionController> _authControllerFuture;

  @override
  void initState() {
    super.initState();
    _authControllerFuture = AuthSessionController.create();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AuthSessionController>(
      future: _authControllerFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return MaterialApp(
            title: 'Ruteando MVP',
            debugShowCheckedModeBanner: false,
            theme: _buildTheme(),
            home: const SessionLoadingScreen(),
          );
        }

        final authController = snapshot.data!;

        return AnimatedBuilder(
          animation: authController,
          builder: (context, _) {
            return MaterialApp(
              title: 'Ruteando MVP',
              debugShowCheckedModeBanner: false,
              theme: _buildTheme(),
              home: authController.isAuthenticated
                  ? PantallaDashboard(authController: authController)
                  : PantallaLogin(authController: authController),
            );
          },
        );
      },
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      useMaterial3: true,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );
  }
}

class SessionLoadingScreen extends StatelessWidget {
  const SessionLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

enum SessionEndReason { manual, expired }

class SessionPolicy {
  const SessionPolicy({
    required this.name,
    required this.maxInactivityDuration,
    required this.maxSessionDuration,
  });

  final String name;
  final Duration maxInactivityDuration;
  final Duration maxSessionDuration;

  static SessionPolicy forCurrentPlatform() {
    if (kIsWeb) {
      return const SessionPolicy(
        name: 'Web',
        maxInactivityDuration: Duration(minutes: 30),
        maxSessionDuration: Duration(hours: 8),
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return const SessionPolicy(
          name: 'Mobile',
          maxInactivityDuration: Duration(hours: 12),
          maxSessionDuration: Duration(days: 30),
        );
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return const SessionPolicy(
          name: 'Desktop',
          maxInactivityDuration: Duration(hours: 4),
          maxSessionDuration: Duration(days: 7),
        );
    }
  }

  String get summary {
    return 'Politica $name: inactividad maxima '
        '${_formatDuration(maxInactivityDuration)} y sesion maxima '
        '${_formatDuration(maxSessionDuration)}.';
  }

  static String _formatDuration(Duration duration) {
    if (duration.inDays >= 1) {
      return '${duration.inDays} dias';
    }
    if (duration.inHours >= 1) {
      return '${duration.inHours} horas';
    }
    return '${duration.inMinutes} minutos';
  }
}

class AuthSessionController extends ChangeNotifier {
  AuthSessionController._(this._storage, this.policy);

  static const String _sessionEmailKey = 'session_email';
  static const String _sessionCreatedAtKey = 'session_created_at_utc';
  static const String _sessionLastActivityKey = 'session_last_activity_utc';

  final SharedPreferences _storage;
  final SessionPolicy policy;

  bool _isAuthenticated = false;
  String? _email;
  DateTime? _sessionCreatedAtUtc;
  DateTime? _lastActivityAtUtc;
  SessionEndReason? _lastSessionEndReason;
  Timer? _expiryTimer;

  bool get isAuthenticated => _isAuthenticated;
  String? get email => _email;
  SessionEndReason? get lastSessionEndReason => _lastSessionEndReason;

  static Future<AuthSessionController> create() async {
    final storage = await SharedPreferences.getInstance();
    final controller = AuthSessionController._(
      storage,
      SessionPolicy.forCurrentPlatform(),
    );
    await controller._restoreSession();
    return controller;
  }

  Future<void> signIn(String email) async {
    final nowUtc = DateTime.now().toUtc();

    _isAuthenticated = true;
    _email = email;
    _sessionCreatedAtUtc = nowUtc;
    _lastActivityAtUtc = nowUtc;
    _lastSessionEndReason = null;

    await _persistSession();
    _scheduleSessionValidation();
    notifyListeners();
  }

  Future<void> signOut({
    SessionEndReason reason = SessionEndReason.manual,
  }) async {
    _expiryTimer?.cancel();

    _isAuthenticated = false;
    _email = null;
    _sessionCreatedAtUtc = null;
    _lastActivityAtUtc = null;
    _lastSessionEndReason = reason;

    await _clearPersistedSession();
    notifyListeners();
  }

  Future<void> refreshActivity() async {
    if (!_isAuthenticated) return;

    _lastActivityAtUtc = DateTime.now().toUtc();
    await _persistSession();
    _scheduleSessionValidation();
  }

  Future<void> validateSession() async {
    if (!_isAuthenticated) return;

    if (!_isSessionValid(DateTime.now().toUtc())) {
      await signOut(reason: SessionEndReason.expired);
      return;
    }

    _scheduleSessionValidation();
  }

  Future<void> _restoreSession() async {
    final storedEmail = _storage.getString(_sessionEmailKey);
    final storedCreatedAt = _parseUtc(_storage.getString(_sessionCreatedAtKey));
    final storedLastActivity = _parseUtc(
      _storage.getString(_sessionLastActivityKey),
    );

    if (storedEmail == null ||
        storedCreatedAt == null ||
        storedLastActivity == null) {
      await _clearPersistedSession();
      return;
    }

    _email = storedEmail;
    _sessionCreatedAtUtc = storedCreatedAt;
    _lastActivityAtUtc = storedLastActivity;
    _isAuthenticated = _isSessionValid(DateTime.now().toUtc());

    if (!_isAuthenticated) {
      await signOut(reason: SessionEndReason.expired);
      return;
    }

    _scheduleSessionValidation();
  }

  bool _isSessionValid(DateTime nowUtc) {
    if (_sessionCreatedAtUtc == null || _lastActivityAtUtc == null) {
      return false;
    }

    final sessionAge = nowUtc.difference(_sessionCreatedAtUtc!);
    final inactivityAge = nowUtc.difference(_lastActivityAtUtc!);

    return sessionAge <= policy.maxSessionDuration &&
        inactivityAge <= policy.maxInactivityDuration;
  }

  DateTime? _parseUtc(String? value) {
    if (value == null) return null;

    final parsed = DateTime.tryParse(value);
    return parsed?.toUtc();
  }

  Future<void> _persistSession() async {
    if (!_isAuthenticated ||
        _email == null ||
        _sessionCreatedAtUtc == null ||
        _lastActivityAtUtc == null) {
      return;
    }

    await _storage.setString(_sessionEmailKey, _email!);
    await _storage.setString(
      _sessionCreatedAtKey,
      _sessionCreatedAtUtc!.toIso8601String(),
    );
    await _storage.setString(
      _sessionLastActivityKey,
      _lastActivityAtUtc!.toIso8601String(),
    );
  }

  Future<void> _clearPersistedSession() async {
    await _storage.remove(_sessionEmailKey);
    await _storage.remove(_sessionCreatedAtKey);
    await _storage.remove(_sessionLastActivityKey);
  }

  void _scheduleSessionValidation() {
    _expiryTimer?.cancel();

    if (!_isAuthenticated ||
        _sessionCreatedAtUtc == null ||
        _lastActivityAtUtc == null) {
      return;
    }

    final nowUtc = DateTime.now().toUtc();
    final untilSessionExpiration =
        policy.maxSessionDuration - nowUtc.difference(_sessionCreatedAtUtc!);
    final untilInactivityExpiration =
        policy.maxInactivityDuration - nowUtc.difference(_lastActivityAtUtc!);

    final nextExpirationMs = min(
      untilSessionExpiration.inMilliseconds,
      untilInactivityExpiration.inMilliseconds,
    );

    if (nextExpirationMs <= 0) {
      Timer.run(() {
        unawaited(validateSession());
      });
      return;
    }

    _expiryTimer = Timer(
      Duration(milliseconds: nextExpirationMs + 1000),
      () {
        unawaited(validateSession());
      },
    );
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }
}

class PantallaDashboard extends StatefulWidget {
  const PantallaDashboard({
    super.key,
    required this.authController,
  });

  final AuthSessionController authController;

  @override
  State<PantallaDashboard> createState() => _PantallaDashboardState();
}

class _PantallaDashboardState extends State<PantallaDashboard>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(widget.authController.validateSession());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.authController.validateSession());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _registrarActividad() {
    unawaited(widget.authController.refreshActivity());
  }

  Future<void> _cerrarSesion() async {
    await widget.authController.signOut(reason: SessionEndReason.manual);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.authController.isAuthenticated) {
      return const SessionLoadingScreen();
    }

    final email = widget.authController.email ?? 'usuario';

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _registrarActividad(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ruteando - Dashboard'),
          backgroundColor: Colors.green[800],
          foregroundColor: Colors.white,
          actions: [
            TextButton.icon(
              onPressed: _cerrarSesion,
              icon: const Icon(Icons.logout, color: Colors.white),
              label: const Text(
                'Cerrar sesion',
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
                        'Sesion activa para: $email',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      Text(widget.authController.policy.summary),
                      const SizedBox(height: 20),
                      const Text(
                        'Los usuarios no autenticados son redirigidos '
                        'automaticamente al login.',
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _registrarActividad,
                        icon: const Icon(Icons.touch_app),
                        label: const Text('Registrar actividad'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PantallaLogin extends StatefulWidget {
  const PantallaLogin({
    super.key,
    required this.authController,
  });

  final AuthSessionController authController;

  @override
  State<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends State<PantallaLogin> {
  final _formKey = GlobalKey<FormState>();

  String _email = '';
  String _password = '';
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _iniciarSesion() async {
    if (!_formKey.currentState!.validate()) return;

    _formKey.currentState!.save();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    if (_email == 'admin@ruteando.cl' && _password == 'ruteando2026') {
      await widget.authController.signIn(_email);
      return;
    }

    setState(() {
      _isLoading = false;
      _errorMessage =
          'Credenciales no validas. Por favor, verifique su correo y contrasena.';
    });
  }

  void _abrirRegistro() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PantallaRegistro()));
  }

  @override
  Widget build(BuildContext context) {
    final sessionExpired =
        widget.authController.lastSessionEndReason == SessionEndReason.expired;

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
                  if (sessionExpired)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: const Text(
                        'Tu sesion expiro por seguridad. Inicia sesion nuevamente.',
                        style: TextStyle(color: Colors.black87),
                      ),
                    ),
                  const Icon(
                    Icons.local_shipping,
                    size: 80,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Correo electronico',
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'El correo es obligatorio';
                      }
                      if (!RegExp(
                        r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                      ).hasMatch(value.trim())) {
                        return 'Ingrese un formato de correo valido';
                      }
                      return null;
                    },
                    onSaved: (value) => _email = value!.trim(),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Contrasena',
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'La contrasena es obligatoria';
                      }
                      if (value.length < 6) {
                        return 'Debe tener al menos 6 caracteres';
                      }
                      return null;
                    },
                    onSaved: (value) => _password = value!,
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
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Iniciar Sesion',
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PantallaRegistro extends StatefulWidget {
  const PantallaRegistro({super.key});

  @override
  State<PantallaRegistro> createState() => _PantallaRegistroState();
}

class _PantallaRegistroState extends State<PantallaRegistro> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName es obligatorio';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final requiredError = _validateRequired(value, 'El correo electronico');
    if (requiredError != null) return requiredError;

    final email = value!.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Ingrese un formato de correo valido';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final requiredError = _validateRequired(value, 'La contrasena');
    if (requiredError != null) return requiredError;

    if (value!.length < 6) {
      return 'La contrasena debe tener al menos 6 caracteres';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    final requiredError = _validateRequired(value, 'Confirmar contrasena');
    if (requiredError != null) return requiredError;

    if (value != _passwordController.text) {
      return 'Las contrasenas no coinciden';
    }
    return null;
  }

  Future<void> registerUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final user = {
      'nombreCompleto': _nameController.text.trim(),
      'correoElectronico': _emailController.text.trim(),
      'telefono': _phoneController.text.trim().isEmpty
          ? 'No informado'
          : _phoneController.text.trim(),
    };

    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Usuario ${user['nombreCompleto']} registrado correctamente.",
        ),
        backgroundColor: Colors.green,
      ),
    );

    _formKey.currentState!.reset();
    _nameController.clear();
    _emailController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
    _phoneController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro de usuario'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.person_add_alt_1,
                    size: 72,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Crear cuenta',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo',
                      prefixIcon: Icon(Icons.person),
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (value) =>
                        _validateRequired(value, 'El nombre completo'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Correo electronico',
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Contrasena',
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                    validator: _validatePassword,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration: const InputDecoration(
                      labelText: 'Confirmar contrasena',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                    validator: _validateConfirmPassword,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Telefono (opcional)',
                      prefixIcon: Icon(Icons.phone),
                    ),
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isSaving ? null : registerUser,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.green[700],
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Registrarse',
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
