import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'menu_drawer.dart';
import 'models/movimiento_inventario.dart';
import 'models/producto_inventario.dart';
import 'models/stock_repartidor_inventario.dart';
import 'services/inventario_service.dart';
import 'widgets/campana_notificaciones_admin.dart';
import 'widgets/menu_perfil_appbar.dart';

class PantallaInventario extends StatefulWidget {
  const PantallaInventario({super.key});

  @override
  State<PantallaInventario> createState() => _PantallaInventarioState();
}

class _PantallaInventarioState extends State<PantallaInventario> {
  static const List<String> _categorias = [
    'Bidones',
    'Botellas',
    'Accesorios',
    'Otros',
  ];

  static const List<String> _tiposMovimiento = [
    'Entrada',
    'Salida',
    'Devolucion',
    'Dano',
    'Perdida',
    'Ajuste',
  ];

  static const List<String> _unidades = ['unidad', 'pack', 'caja'];

  final InventarioService _inventarioService = InventarioService();

  String _mensajeErrorAmigable(Object error) {
    final texto = error.toString();
    if (texto.contains('cloud_firestore') ||
        texto.contains('Unable to establish connection on channel')) {
      return 'No se pudo conectar con la base de datos. Se guardara localmente si estas probando en este equipo.';
    }

    return texto;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        actions: [CampanaNotificacionesAdmin(), const MenuPerfilAppBar()],
      ),
      drawer: const AppMenuDrawer(currentRoute: '/inventario'),
      body: StreamBuilder<List<ProductoInventario>>(
        stream: _inventarioService.observarProductos(),
        builder: (context, productosSnapshot) {
          if (productosSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (productosSnapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No se pudo cargar el inventario: ${_mensajeErrorAmigable(productosSnapshot.error!)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          final productos =
              productosSnapshot.data ?? const <ProductoInventario>[];

          return StreamBuilder<List<StockRepartidorInventario>>(
            stream: _inventarioService.observarStockRepartidores(),
            builder: (context, stockSnapshot) {
              if (stockSnapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No se pudo cargar el stock por repartidor: ${_mensajeErrorAmigable(stockSnapshot.error!)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                );
              }

              return StreamBuilder<List<MovimientoInventario>>(
                stream: _inventarioService.obtenerUltimosMovimientos(
                  limite: 12,
                ),
                builder: (context, movimientosSnapshot) {
                  if (movimientosSnapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No se pudieron cargar los movimientos: ${_mensajeErrorAmigable(movimientosSnapshot.error!)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    );
                  }

                  final stockRepartidores =
                      stockSnapshot.data ?? const <StockRepartidorInventario>[];
                  final movimientos =
                      movimientosSnapshot.data ??
                      const <MovimientoInventario>[];

                  return RefreshIndicator(
                    onRefresh: () async {
                      setState(() {});
                    },
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 980),
                        child: _InventarioContenido(
                          productos: productos,
                          stockRepartidores: stockRepartidores,
                          movimientos: movimientos,
                          cargandoStock:
                              stockSnapshot.connectionState ==
                              ConnectionState.waiting,
                          cargandoMovimientos:
                              movimientosSnapshot.connectionState ==
                              ConnectionState.waiting,
                          onCrearProducto: () => _abrirFormularioProducto(),
                          onEditar: _abrirFormularioProducto,
                          onEliminar: _confirmarEliminarProducto,
                          onGuardarStock: _abrirFormularioStockRepartidor,
                          onRegistrarMovimiento: () =>
                              _abrirFormularioMovimiento(productos),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormularioProducto(),
        icon: const Icon(Icons.add),
        label: const Text('Producto'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
      ),
    );
  }

  Future<void> _abrirFormularioProducto([ProductoInventario? producto]) async {
    final nombreController = TextEditingController(text: producto?.nombre);
    final descripcionController = TextEditingController(
      text: producto?.descripcion,
    );
    final stockActualController = TextEditingController(
      text: producto?.stockActual.toString(),
    );
    final stockMinimoController = TextEditingController(
      text: producto?.stockMinimo.toString(),
    );

    String? categoriaSeleccionada = _categorias.contains(producto?.categoria)
        ? producto?.categoria
        : null;
    String? unidadSeleccionada = _unidades.contains(producto?.unidad)
        ? producto?.unidad
        : null;
    var guardando = false;
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      barrierDismissible: !guardando,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> guardar() async {
              if (!(formKey.currentState?.validate() ?? false)) {
                return;
              }

              setDialogState(() => guardando = true);

              final stockActual = int.parse(stockActualController.text.trim());
              final stockMinimo = int.parse(stockMinimoController.text.trim());
              final productoGuardado = ProductoInventario(
                id: producto?.id ?? '',
                nombre: nombreController.text.trim(),
                categoria: categoriaSeleccionada!,
                descripcion: descripcionController.text.trim(),
                stockActual: stockActual,
                stockMinimo: stockMinimo,
                unidad: unidadSeleccionada!,
                estado: '',
                creadoEn: producto?.creadoEn,
                actualizadoEn: producto?.actualizadoEn,
              );

              try {
                if (producto == null) {
                  await _inventarioService.crearProducto(productoGuardado);
                } else {
                  await _inventarioService.actualizarProducto(productoGuardado);
                }

                if (!dialogContext.mounted) {
                  return;
                }

                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      producto == null
                          ? 'Producto creado correctamente'
                          : 'Producto actualizado correctamente',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (!dialogContext.mounted) {
                  return;
                }

                setDialogState(() => guardando = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'No se pudo guardar el producto: ${_mensajeErrorAmigable(e)}',
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }

            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              title: Text(
                producto == null ? 'Nuevo producto' : 'Editar producto',
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nombreController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Nombre',
                            prefixIcon: Icon(Icons.inventory_2_outlined),
                          ),
                          validator: _validarTextoObligatorio,
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: categoriaSeleccionada,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Categoria',
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                          items: _categorias.map((categoria) {
                            return DropdownMenuItem<String>(
                              value: categoria,
                              child: Text(categoria),
                            );
                          }).toList(),
                          onChanged: guardando
                              ? null
                              : (valor) {
                                  setDialogState(
                                    () => categoriaSeleccionada = valor,
                                  );
                                },
                          validator: _validarTextoObligatorio,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: descripcionController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Descripcion',
                            prefixIcon: Icon(Icons.notes_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _CamposCantidades(
                          campos: [
                            _CampoCantidadConfig(
                              controller: stockActualController,
                              label: 'Stock actual',
                              icon: Icons.water_drop_outlined,
                            ),
                            _CampoCantidadConfig(
                              controller: stockMinimoController,
                              label: 'Stock minimo',
                              icon: Icons.warning_amber,
                            ),
                          ],
                          validator: _validarNumeroNoNegativo,
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: unidadSeleccionada,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Unidad',
                            prefixIcon: Icon(Icons.straighten),
                          ),
                          items: _unidades.map((unidad) {
                            return DropdownMenuItem<String>(
                              value: unidad,
                              child: Text(unidad),
                            );
                          }).toList(),
                          onChanged: guardando
                              ? null
                              : (valor) {
                                  setDialogState(
                                    () => unidadSeleccionada = valor,
                                  );
                                },
                          validator: _validarTextoObligatorio,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              actions: [
                TextButton(
                  onPressed: guardando
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  onPressed: guardando ? null : guardar,
                  icon: guardando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Guardar'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green[800],
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    nombreController.dispose();
    descripcionController.dispose();
    stockActualController.dispose();
    stockMinimoController.dispose();
  }

  Future<void> _abrirFormularioStockRepartidor([
    StockRepartidorInventario? stock,
  ]) async {
    final nombreController = TextEditingController(text: stock?.nombre);
    final emailController = TextEditingController(text: stock?.email);
    final cargadosController = TextEditingController(
      text: stock?.bidonesCargados.toString(),
    );
    final entregadosController = TextEditingController(
      text: stock?.bidonesEntregados.toString(),
    );
    final retornadosController = TextEditingController(
      text: stock?.bidonesRetornados.toString(),
    );
    final danadosController = TextEditingController(
      text: stock?.bidonesDanados.toString(),
    );

    var guardando = false;
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      barrierDismissible: !guardando,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> guardar() async {
              if (!(formKey.currentState?.validate() ?? false)) {
                return;
              }

              setDialogState(() => guardando = true);

              final stockGuardado = StockRepartidorInventario(
                id: stock?.id ?? '',
                nombre: nombreController.text.trim(),
                email: emailController.text.trim().toLowerCase(),
                bidonesCargados: int.parse(cargadosController.text.trim()),
                bidonesEntregados: int.parse(entregadosController.text.trim()),
                bidonesRetornados: int.parse(retornadosController.text.trim()),
                bidonesDanados: int.parse(danadosController.text.trim()),
                actualizadoEn: stock?.actualizadoEn,
              );

              try {
                await _inventarioService.guardarStockRepartidor(stockGuardado);

                if (!dialogContext.mounted) {
                  return;
                }

                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Stock del repartidor guardado'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (!dialogContext.mounted) {
                  return;
                }

                setDialogState(() => guardando = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'No se pudo guardar el stock: ${_mensajeErrorAmigable(e)}',
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }

            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              title: Text(
                stock == null
                    ? 'Stock por repartidor'
                    : 'Actualizar stock del repartidor',
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nombreController,
                          decoration: const InputDecoration(
                            labelText: 'Nombre',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: _validarTextoObligatorio,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (valor) {
                            final texto = valor?.trim() ?? '';
                            if (texto.isEmpty) {
                              return 'Campo obligatorio';
                            }

                            if (!texto.contains('@')) {
                              return 'Ingresa un email valido';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        _CamposCantidades(
                          campos: [
                            _CampoCantidadConfig(
                              controller: cargadosController,
                              label: 'Cargados',
                              icon: Icons.local_shipping_outlined,
                            ),
                            _CampoCantidadConfig(
                              controller: entregadosController,
                              label: 'Entregados',
                              icon: Icons.check_circle_outline,
                            ),
                            _CampoCantidadConfig(
                              controller: retornadosController,
                              label: 'Retornados',
                              icon: Icons.keyboard_return,
                            ),
                            _CampoCantidadConfig(
                              controller: danadosController,
                              label: 'Danados',
                              icon: Icons.report_problem_outlined,
                            ),
                          ],
                          validator: _validarNumeroNoNegativo,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              actions: [
                TextButton(
                  onPressed: guardando
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  onPressed: guardando ? null : guardar,
                  icon: guardando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Guardar'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green[800],
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    nombreController.dispose();
    emailController.dispose();
    cargadosController.dispose();
    entregadosController.dispose();
    retornadosController.dispose();
    danadosController.dispose();
  }

  Future<void> _abrirFormularioMovimiento(
    List<ProductoInventario> productos,
  ) async {
    if (productos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero registra un producto para crear movimientos'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final cantidadController = TextEditingController();
    final responsableController = TextEditingController();
    final emailController = TextEditingController();
    final observacionController = TextEditingController();

    ProductoInventario? productoSeleccionado = productos.first;
    String tipoSeleccionado = _tiposMovimiento.first;
    var guardando = false;
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      barrierDismissible: !guardando,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> guardar() async {
              if (!(formKey.currentState?.validate() ?? false)) {
                return;
              }

              setDialogState(() => guardando = true);
              final producto = productoSeleccionado!;

              final movimiento = MovimientoInventario(
                id: '',
                productoId: producto.id,
                productoNombre: producto.nombre,
                tipo: tipoSeleccionado,
                cantidad: int.parse(cantidadController.text.trim()),
                responsable: responsableController.text.trim(),
                email: emailController.text.trim().toLowerCase(),
                observacion: observacionController.text.trim(),
              );

              try {
                await _inventarioService.registrarMovimiento(movimiento);

                if (!dialogContext.mounted) {
                  return;
                }

                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Movimiento registrado'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (!dialogContext.mounted) {
                  return;
                }

                setDialogState(() => guardando = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'No se pudo registrar el movimiento: ${_mensajeErrorAmigable(e)}',
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }

            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              title: const Text('Registrar movimiento'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<ProductoInventario>(
                          initialValue: productoSeleccionado,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Producto',
                            prefixIcon: Icon(Icons.inventory_2_outlined),
                          ),
                          items: productos.map((producto) {
                            return DropdownMenuItem<ProductoInventario>(
                              value: producto,
                              child: Text(producto.nombre),
                            );
                          }).toList(),
                          onChanged: guardando
                              ? null
                              : (valor) {
                                  setDialogState(
                                    () => productoSeleccionado = valor,
                                  );
                                },
                          validator: (valor) =>
                              valor == null ? 'Campo obligatorio' : null,
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: tipoSeleccionado,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Tipo',
                            prefixIcon: Icon(Icons.swap_horiz),
                          ),
                          items: _tiposMovimiento.map((tipo) {
                            return DropdownMenuItem<String>(
                              value: tipo,
                              child: Text(tipo),
                            );
                          }).toList(),
                          onChanged: guardando
                              ? null
                              : (valor) {
                                  if (valor == null) {
                                    return;
                                  }
                                  setDialogState(
                                    () => tipoSeleccionado = valor,
                                  );
                                },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: cantidadController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            labelText: tipoSeleccionado == 'Ajuste'
                                ? 'Nuevo stock'
                                : 'Cantidad',
                            prefixIcon: const Icon(Icons.numbers),
                          ),
                          validator: _validarNumeroNoNegativo,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: responsableController,
                          decoration: const InputDecoration(
                            labelText: 'Responsable',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: _validarTextoObligatorio,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (valor) {
                            final texto = valor?.trim() ?? '';
                            if (texto.isEmpty) {
                              return 'Campo obligatorio';
                            }

                            if (!texto.contains('@')) {
                              return 'Ingresa un email valido';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: observacionController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Observacion',
                            prefixIcon: Icon(Icons.notes_outlined),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              actions: [
                TextButton(
                  onPressed: guardando
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  onPressed: guardando ? null : guardar,
                  icon: guardando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_task_outlined),
                  label: const Text('Registrar'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green[800],
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    cantidadController.dispose();
    responsableController.dispose();
    emailController.dispose();
    observacionController.dispose();
  }

  Future<void> _confirmarEliminarProducto(ProductoInventario producto) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Eliminar producto'),
          content: Text(
            'Seguro que quieres eliminar "${producto.nombre}" del inventario?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Eliminar'),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
            ),
          ],
        );
      },
    );

    if (confirmar != true) {
      return;
    }

    try {
      await _inventarioService.eliminarProducto(producto.id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Producto eliminado correctamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo eliminar el producto: ${_mensajeErrorAmigable(e)}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String? _validarTextoObligatorio(String? valor) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Campo obligatorio';
    }

    return null;
  }

  String? _validarNumeroNoNegativo(String? valor) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Campo obligatorio';
    }

    final numero = int.tryParse(valor.trim());
    if (numero == null || numero < 0) {
      return 'Ingresa un numero valido';
    }

    return null;
  }
}

class _InventarioContenido extends StatelessWidget {
  const _InventarioContenido({
    required this.productos,
    required this.stockRepartidores,
    required this.movimientos,
    required this.cargandoStock,
    required this.cargandoMovimientos,
    required this.onCrearProducto,
    required this.onEditar,
    required this.onEliminar,
    required this.onGuardarStock,
    required this.onRegistrarMovimiento,
  });

  final List<ProductoInventario> productos;
  final List<StockRepartidorInventario> stockRepartidores;
  final List<MovimientoInventario> movimientos;
  final bool cargandoStock;
  final bool cargandoMovimientos;
  final VoidCallback onCrearProducto;
  final ValueChanged<ProductoInventario> onEditar;
  final ValueChanged<ProductoInventario> onEliminar;
  final ValueChanged<StockRepartidorInventario?> onGuardarStock;
  final VoidCallback onRegistrarMovimiento;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _ResumenInventario(productos: productos),
        const SizedBox(height: 16),
        _AccionesInventario(
          onCrearProducto: onCrearProducto,
          onGuardarStock: () => onGuardarStock(null),
          onRegistrarMovimiento: onRegistrarMovimiento,
        ),
        const SizedBox(height: 20),
        _TituloSeccion(
          titulo: 'Stock por repartidor',
          accion: FilledButton.icon(
            onPressed: () => onGuardarStock(null),
            icon: const Icon(Icons.add),
            label: const Text('Stock'),
            style: FilledButton.styleFrom(backgroundColor: Colors.green[800]),
          ),
        ),
        const SizedBox(height: 12),
        if (cargandoStock)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (stockRepartidores.isEmpty)
          const _EstadoVacio(
            icon: Icons.local_shipping_outlined,
            mensaje: 'No hay stock registrado por repartidor',
          )
        else
          ...stockRepartidores.map(
            (stock) => _StockRepartidorCard(
              stock: stock,
              onEditar: () => onGuardarStock(stock),
            ),
          ),
        const SizedBox(height: 20),
        Text(
          'Productos',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (productos.isEmpty)
          const _EstadoVacio(
            icon: Icons.inventory_2_outlined,
            mensaje: 'No hay productos registrados',
          )
        else
          ...productos.map(
            (producto) => _ProductoInventarioCard(
              producto: producto,
              onEditar: () => onEditar(producto),
              onEliminar: () => onEliminar(producto),
            ),
          ),
        const SizedBox(height: 20),
        _TituloSeccion(
          titulo: 'Historial de movimientos',
          accion: FilledButton.icon(
            onPressed: onRegistrarMovimiento,
            icon: const Icon(Icons.add_task_outlined),
            label: const Text('Movimiento'),
            style: FilledButton.styleFrom(backgroundColor: Colors.green[800]),
          ),
        ),
        const SizedBox(height: 12),
        if (cargandoMovimientos)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (movimientos.isEmpty)
          const _EstadoVacio(
            icon: Icons.swap_horiz,
            mensaje: 'No hay movimientos registrados',
          )
        else
          ...movimientos.map(
            (movimiento) => _MovimientoInventarioCard(movimiento: movimiento),
          ),
      ],
    );
  }
}

class _ResumenInventario extends StatelessWidget {
  const _ResumenInventario({required this.productos});

  final List<ProductoInventario> productos;

  @override
  Widget build(BuildContext context) {
    final totalProductos = productos.length;
    final stockTotal = productos.fold<int>(
      0,
      (total, producto) => total + producto.stockActual,
    );
    final stockBajo = productos
        .where((producto) => producto.stockActual <= producto.stockMinimo)
        .length;
    final sinStock = productos
        .where((producto) => producto.stockActual == 0)
        .length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columnas = constraints.maxWidth >= 720 ? 4 : 2;

        return GridView.count(
          crossAxisCount: columnas,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: constraints.maxWidth >= 720 ? 1.45 : 1.35,
          children: [
            _ResumenCard(
              icon: Icons.inventory_2_outlined,
              titulo: 'Productos',
              valor: totalProductos.toString(),
              color: const Color(0xFF166534),
            ),
            _ResumenCard(
              icon: Icons.water_drop_outlined,
              titulo: 'Stock total',
              valor: stockTotal.toString(),
              color: const Color(0xFF2563EB),
            ),
            _ResumenCard(
              icon: Icons.warning_amber,
              titulo: 'Stock bajo',
              valor: stockBajo.toString(),
              color: const Color(0xFFF97316),
            ),
            _ResumenCard(
              icon: Icons.remove_shopping_cart_outlined,
              titulo: 'Sin stock',
              valor: sinStock.toString(),
              color: const Color(0xFFDC2626),
            ),
          ],
        );
      },
    );
  }
}

class _ResumenCard extends StatelessWidget {
  const _ResumenCard({
    required this.icon,
    required this.titulo,
    required this.valor,
    required this.color,
  });

  final IconData icon;
  final String titulo;
  final String valor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fondo = Color.alphaBlend(
      color.withValues(alpha: 0.12),
      Theme.of(context).cardTheme.color ??
          Theme.of(context).colorScheme.surface,
    );

    return Card(
      elevation: 2,
      color: fondo,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: color.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 28),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  valor,
                  style: TextStyle(
                    color: color,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  titulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AccionesInventario extends StatelessWidget {
  const _AccionesInventario({
    required this.onCrearProducto,
    required this.onGuardarStock,
    required this.onRegistrarMovimiento,
  });

  final VoidCallback onCrearProducto;
  final VoidCallback onGuardarStock;
  final VoidCallback onRegistrarMovimiento;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        FilledButton.icon(
          onPressed: onCrearProducto,
          icon: const Icon(Icons.add),
          label: const Text('Producto'),
          style: FilledButton.styleFrom(backgroundColor: Colors.green[800]),
        ),
        OutlinedButton.icon(
          onPressed: onGuardarStock,
          icon: const Icon(Icons.local_shipping_outlined),
          label: const Text('Stock repartidor'),
        ),
        OutlinedButton.icon(
          onPressed: onRegistrarMovimiento,
          icon: const Icon(Icons.swap_horiz),
          label: const Text('Movimiento'),
        ),
      ],
    );
  }
}

class _TituloSeccion extends StatelessWidget {
  const _TituloSeccion({required this.titulo, this.accion});

  final String titulo;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            titulo,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        ?accion,
      ],
    );
  }
}

class _StockRepartidorCard extends StatelessWidget {
  const _StockRepartidorCard({required this.stock, required this.onEditar});

  final StockRepartidorInventario stock;
  final VoidCallback onEditar;

  @override
  Widget build(BuildContext context) {
    final pendiente = stock.stockPendiente;
    final colorPendiente = pendiente < 0
        ? const Color(0xFFDC2626)
        : const Color(0xFF2563EB);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: Theme.of(context).cardTheme.color,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFF111111), width: 0.6),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.green.withValues(alpha: 0.12),
                  foregroundColor: Colors.green[800],
                  child: const Icon(Icons.local_shipping_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stock.nombre,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        stock.email,
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Editar stock',
                  onPressed: onEditar,
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: Icons.inventory_outlined,
                  label: 'Cargados: ${stock.bidonesCargados}',
                ),
                _InfoChip(
                  icon: Icons.check_circle_outline,
                  label: 'Entregados: ${stock.bidonesEntregados}',
                ),
                _InfoChip(
                  icon: Icons.keyboard_return,
                  label: 'Retornados: ${stock.bidonesRetornados}',
                ),
                _InfoChip(
                  icon: Icons.report_problem_outlined,
                  label: 'Danados: ${stock.bidonesDanados}',
                ),
                Chip(
                  avatar: Icon(
                    Icons.pending_actions_outlined,
                    size: 16,
                    color: colorPendiente,
                  ),
                  label: Text('Pendiente: $pendiente'),
                  labelStyle: TextStyle(
                    color: colorPendiente,
                    fontWeight: FontWeight.w700,
                  ),
                  backgroundColor: colorPendiente.withValues(alpha: 0.1),
                  side: BorderSide(
                    color: colorPendiente.withValues(alpha: 0.18),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MovimientoInventarioCard extends StatelessWidget {
  const _MovimientoInventarioCard({required this.movimiento});

  final MovimientoInventario movimiento;

  @override
  Widget build(BuildContext context) {
    final color = _colorMovimiento(movimiento.tipo);
    final fecha = _formatearFecha(movimiento.fecha?.toDate());
    final observacion = movimiento.observacion.trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: Theme.of(context).cardTheme.color,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFF111111), width: 0.6),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          foregroundColor: color,
          child: Icon(_iconoMovimiento(movimiento.tipo)),
        ),
        title: Text(
          movimiento.productoNombre,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Responsable: ${movimiento.responsable}'),
              Text('Fecha: $fecha'),
              if (observacion.isNotEmpty) Text('Observacion: $observacion'),
            ],
          ),
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              movimiento.tipo,
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
            Text(
              movimiento.cantidad.toString(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Color _colorMovimiento(String tipo) {
    if (tipo == 'Entrada' || tipo == 'Devolucion') {
      return const Color(0xFF16A34A);
    }

    if (tipo == 'Ajuste') {
      return const Color(0xFF2563EB);
    }

    return const Color(0xFFDC2626);
  }

  IconData _iconoMovimiento(String tipo) {
    if (tipo == 'Entrada' || tipo == 'Devolucion') {
      return Icons.add_circle_outline;
    }

    if (tipo == 'Ajuste') {
      return Icons.tune;
    }

    return Icons.remove_circle_outline;
  }

  String _formatearFecha(DateTime? fecha) {
    if (fecha == null) {
      return 'No registrada';
    }

    String dosDigitos(int numero) => numero.toString().padLeft(2, '0');
    return '${dosDigitos(fecha.day)}/${dosDigitos(fecha.month)}/${fecha.year} '
        '${dosDigitos(fecha.hour)}:${dosDigitos(fecha.minute)}';
  }
}

class _ProductoInventarioCard extends StatelessWidget {
  const _ProductoInventarioCard({
    required this.producto,
    required this.onEditar,
    required this.onEliminar,
  });

  final ProductoInventario producto;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    final estado = producto.estadoCalculado;
    final colorEstado = _colorEstado(estado);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: Theme.of(context).cardTheme.color,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFF111111), width: 0.6),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.green.withValues(alpha: 0.12),
                  foregroundColor: Colors.green[800],
                  child: const Icon(Icons.water_drop_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        producto.nombre,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        producto.descripcion.trim().isEmpty
                            ? 'Sin descripcion'
                            : producto.descripcion,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Acciones',
                  onSelected: (accion) {
                    if (accion == 'editar') {
                      onEditar();
                    } else if (accion == 'eliminar') {
                      onEliminar();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem<String>(
                      value: 'editar',
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Editar'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'eliminar',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline, color: Colors.red),
                        title: Text('Eliminar'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _InfoChip(
                  icon: Icons.category_outlined,
                  label: producto.categoria,
                ),
                _InfoChip(
                  icon: Icons.inventory_outlined,
                  label: 'Actual: ${producto.stockActual}',
                ),
                _InfoChip(
                  icon: Icons.warning_amber,
                  label: 'Minimo: ${producto.stockMinimo}',
                ),
                _InfoChip(icon: Icons.straighten, label: producto.unidad),
                Chip(
                  avatar: Icon(
                    _iconoEstado(estado),
                    size: 16,
                    color: colorEstado,
                  ),
                  label: Text(estado),
                  labelStyle: TextStyle(
                    color: colorEstado,
                    fontWeight: FontWeight.w700,
                  ),
                  backgroundColor: colorEstado.withValues(alpha: 0.1),
                  side: BorderSide(color: colorEstado.withValues(alpha: 0.18)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _colorEstado(String estado) {
    if (estado == 'No disponible') {
      return const Color(0xFFDC2626);
    }

    if (estado == 'Stock bajo') {
      return const Color(0xFFF97316);
    }

    return const Color(0xFF16A34A);
  }

  IconData _iconoEstado(String estado) {
    if (estado == 'No disponible') {
      return Icons.block_outlined;
    }

    if (estado == 'Stock bajo') {
      return Icons.warning_amber;
    }

    return Icons.check_circle_outline;
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16, color: Colors.grey[700]),
      label: Text(label),
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      backgroundColor: const Color(0xFFF8FAF9),
      side: const BorderSide(color: Color(0xFFE5E7EB)),
    );
  }
}

class _CampoCantidadConfig {
  const _CampoCantidadConfig({
    required this.controller,
    required this.label,
    required this.icon,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
}

class _CamposCantidades extends StatelessWidget {
  const _CamposCantidades({required this.campos, required this.validator});

  final List<_CampoCantidadConfig> campos;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    final widgets = campos.map(_campo).toList();

    return Column(
      children: [
        for (var i = 0; i < widgets.length; i++) ...[
          widgets[i],
          if (i != widgets.length - 1) const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _campo(_CampoCantidadConfig config) {
    return TextFormField(
      controller: config.controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: config.label,
        prefixIcon: Icon(config.icon),
      ),
      validator: validator,
    );
  }
}

class _EstadoVacio extends StatelessWidget {
  const _EstadoVacio({required this.icon, required this.mensaje});

  final IconData icon;
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      color: Theme.of(context).cardTheme.color,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFF111111), width: 0.6),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 46, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }
}
