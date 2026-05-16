import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PantallaPerfil extends StatelessWidget {
  const PantallaPerfil({super.key});

  Future<void> _cerrarSesion(BuildContext context) async {
    await FirebaseAuth.instance.signOut();

    if (!context.mounted) return;

    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
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
                    label: const Text('Cerrar sesion'),
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
