// Nombre del archivo: lib/views/admin_inventario_screen.dart

import 'package:flutter/material.dart';
import '../services/database_service.dart';
import 'contaduria_screen.dart';

class AdminInventarioScreen extends StatefulWidget {
  const AdminInventarioScreen({super.key});

  @override
  State<AdminInventarioScreen> createState() => _AdminInventarioScreenState();
}

class _AdminInventarioScreenState extends State<AdminInventarioScreen> {
  final DatabaseService _dbService = DatabaseService.instance;

  List _listaProductos = [];
  List<String> _categoriasDisponibles = ['General'];
  List _listaUsuarios = [];
  bool _cargando = false;
  String _passwordAdminActual = 'admin';
  bool _moduloContaduriaActivo = true;

  // Configuración del Negocio en Memoria
  Map<String, String> _configNegocio = {
    'nombre_negocio': 'AScafe',
    'direccion_negocio': 'Riberalta, Beni - Bolivia',
    'celular_negocio': '+591 70000000',
    'logo_path': '',
    'modulo_contaduria_activo': 'true',
  };

  @override
  void initState() {
    super.initState();
    _cargarDatosDB();
  }

  String _obtenerEmojiCategoria(String categoria) {
    final catLower = categoria.trim().toLowerCase();
    if (catLower.contains('salteña') || catLower.contains('saltena')) return '🥟';
    if (catLower.contains('alimento') || catLower.contains('comida')) return '🍽️';
    if (catLower.contains('bebida') || catLower.contains('refresco')) return '🥤';
    if (catLower.contains('postre') || catLower.contains('dulce')) return '🍰';
    if (catLower.contains('café') || catLower.contains('cafe')) return '☕';
    if (catLower.contains('snack') || catLower.contains('aperitivo')) return '🍿';
    if (catLower.contains('lácteo') || catLower.contains('lacteo')) return '🥛';
    return '📦';
  }

  Future<void> _cargarDatosDB() async {
    if (!mounted) return;
    setState(() => _cargando = true);
    try {
      final cats = await _dbService.obtenerCategorias();
      final productosDB = await _dbService.obtenerProductos();
      final usuariosDB = await _dbService.obtenerUsuarios();
      final configDB = await _dbService.obtenerConfiguracionNegocio();
      final contaduriaActiva = await _dbService.estaModuloContaduriaActivo();

      String passAdm = configDB['admin_password'] ?? 'admin';
      for (final u in usuariosDB) {
        if (u is Map) {
          if ((u['rol']?.toString().toLowerCase() == 'admin') ||
              (u['nombre']?.toString().toLowerCase() == 'administrador')) {
            passAdm = u['password']?.toString() ?? passAdm;
            break;
          }
        }
      }

      final List<String> catsLimpias = [];
      for (var c in cats) {
        final s = c.toString().trim();
        if (s.isNotEmpty && !catsLimpias.contains(s)) {
          catsLimpias.add(s);
        }
      }
      if (catsLimpias.isEmpty) {
        catsLimpias.add('General');
      }

      final List tempLista = [];
      for (var e in productosDB) {
        if (e is Map) {
          final mapa = Map<String, dynamic>.from(e);
          final catProd = mapa['categoria']?.toString().trim() ?? 'General';
          if (catProd.isNotEmpty && !catsLimpias.contains(catProd)) {
            catsLimpias.add(catProd);
          }
          tempLista.add(mapa);
        }
      }

      if (mounted) {
        setState(() {
          _categoriasDisponibles = catsLimpias;
          _listaProductos = tempLista;
          _listaUsuarios = usuariosDB;
          _configNegocio = Map<String, String>.from(configDB);
          _passwordAdminActual = passAdm;
          _moduloContaduriaActivo = contaduriaActiva;
          _cargando = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  Future<void> _alternarModuloContaduriaLicencia() async {
    final nuevoEstado = !_moduloContaduriaActivo;
    await _dbService.configurarModuloContaduriaPorLicencia(nuevoEstado);
    await _cargarDatosDB();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: nuevoEstado ? Colors.green : Colors.orangeAccent,
        content: Text(
          nuevoEstado
              ? '✅ Módulo de Contaduría ACTIVADO en la licencia actual.'
              : '🔒 Módulo de Contaduría DESACTIVADO (Modo Licencia Básica).',
        ),
      ),
    );
  }

  void _mostrarDialogoCambiarPasswordAdmin() {
    final ctrlNueva = TextEditingController(text: _passwordAdminActual);
    final ctrlConfirmar = TextEditingController(text: _passwordAdminActual);
    bool ocultar = true;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0E1626),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFFFFAB00), width: 1.5),
              ),
              title: const Row(
                children: [
                  Icon(Icons.security, color: Color(0xFFFFAB00)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cambiar Contraseña del Administrador',
                      style: TextStyle(
                        color: Color(0xFFFFAB00),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: ctrlNueva,
                      obscureText: ocultar,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Nueva Contraseña de Administrador',
                        labelStyle: const TextStyle(color: Color(0xFF00E5FF)),
                        prefixIcon: const Icon(Icons.key, color: Color(0xFFFFAB00)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            ocultar ? Icons.visibility_off : Icons.visibility,
                            color: Colors.white54,
                          ),
                          onPressed: () => setStateDialog(() => ocultar = !ocultar),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF131C31),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: ctrlConfirmar,
                      obscureText: ocultar,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Confirmar Nueva Contraseña',
                        labelStyle: const TextStyle(color: Color(0xFF00E5FF)),
                        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF00E5FF)),
                        filled: true,
                        fillColor: const Color(0xFF131C31),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFAB00),
                    foregroundColor: Colors.black,
                  ),
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text(
                    'Guardar Contraseña',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () async {
                    final p1 = ctrlNueva.text.trim();
                    final p2 = ctrlConfirmar.text.trim();
                    if (p1.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: Colors.redAccent,
                          content: Text('⚠️ La contraseña no puede estar vacía.'),
                        ),
                      );
                      return;
                    }
                    if (p1 != p2) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: Colors.redAccent,
                          content: Text('⚠️ Las contraseñas no coinciden.'),
                        ),
                      );
                      return;
                    }

                    final nav = Navigator.of(dialogContext);
                    final messenger = ScaffoldMessenger.of(context);
                    await _dbService.cambiarPasswordAdministradorGlobal(p1);
                    nav.pop();
                    await _cargarDatosDB();
                    if (!mounted) return;
                    messenger.showSnackBar(
                      const SnackBar(
                        backgroundColor: Colors.green,
                        content: Text('✅ Contraseña del Administrador actualizada correctamente.'),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _mostrarDialogoGestionarCajeros({Map<String, dynamic>? usuarioExistente}) {
    final bool esEdicion = usuarioExistente != null;
    final ctrlNombreCajero = TextEditingController(
      text: esEdicion ? (usuarioExistente['nombre']?.toString() ?? '') : '',
    );
    final ctrlNombreCaja = TextEditingController(
      text: esEdicion ? (usuarioExistente['nombre_caja']?.toString() ?? 'Caja 2 - Ventas') : 'Caja 2 - Ventas',
    );
    final ctrlPasswordCajero = TextEditingController(
      text: esEdicion ? (usuarioExistente['password']?.toString() ?? '') : '',
    );
    String rolSeleccionado = esEdicion ? (usuarioExistente['rol']?.toString() ?? 'cajero') : 'cajero';
    bool ocultarPass = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (sbContext, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0E1626),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFFFFAB00), width: 1.5),
              ),
              title: Text(
                esEdicion ? '🔑 Editar Usuario: ${usuarioExistente['nombre']}' : '🧑‍💼 Registrar Nuevo Cajero',
                style: const TextStyle(color: Color(0xFFFFAB00), fontWeight: FontWeight.bold, fontSize: 17),
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!esEdicion) ...[
                        const Text(
                          'Usuarios registrados para ingresar al sistema:',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 140,
                          decoration: BoxDecoration(
                            color: const Color(0xFF131C31),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: ListView.builder(
                            itemCount: _listaUsuarios.length,
                            itemBuilder: (context, index) {
                              final u = _listaUsuarios[index] as Map;
                              final id = (u['id'] as num).toInt();
                              final nom = u['nombre']?.toString() ?? '';
                              final caja = u['nombre_caja']?.toString() ?? '';
                              final pass = u['password']?.toString() ?? '';
                              final esAdminUser = u['rol']?.toString() == 'admin';

                              return ListTile(
                                dense: true,
                                leading: Text(esAdminUser ? '👑' : '🧑‍💼', style: const TextStyle(fontSize: 20)),
                                title: Text(
                                  '$nom  —  🖥️ $caja',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  'Contraseña: $pass  |  Rol: ${esAdminUser ? "Administrador" : "Cajero"}',
                                  style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Color(0xFFFFAB00), size: 18),
                                      tooltip: 'Editar / Cambiar Clave',
                                      onPressed: () {
                                        Navigator.of(dialogContext).pop();
                                        _mostrarDialogoGestionarCajeros(usuarioExistente: Map<String, dynamic>.from(u));
                                      },
                                    ),
                                    if (!(esAdminUser && nom == 'Administrador'))
                                      IconButton(
                                        icon: const Icon(Icons.delete_forever, color: Colors.redAccent, size: 18),
                                        onPressed: () async {
                                          await _dbService.eliminarUsuario(id);
                                          await _cargarDatosDB();
                                          setStateDialog(() {});
                                        },
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const Divider(color: Colors.white24, height: 22),
                      ],
                      Text(
                        esEdicion ? 'Modificar Datos de Usuario:' : '➕ Crear Nuevo Cajero:',
                        style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: ctrlNombreCajero,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Nombre del Cajero',
                          labelStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: const Color(0xFF131C31),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: ctrlNombreCaja,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Nombre de su Caja',
                          labelStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: const Color(0xFF131C31),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: ctrlPasswordCajero,
                              obscureText: ocultarPass,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Contraseña',
                                labelStyle: const TextStyle(color: Colors.white70),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    ocultarPass ? Icons.visibility_off : Icons.visibility,
                                    color: Colors.white54,
                                  ),
                                  onPressed: () => setStateDialog(() => ocultarPass = !ocultarPass),
                                ),
                                filled: true,
                                fillColor: const Color(0xFF131C31),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF131C31),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFFFAB00)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: rolSeleccionado,
                                  dropdownColor: const Color(0xFF131C31),
                                  isExpanded: true,
                                  style: const TextStyle(color: Colors.white),
                                  items: const [
                                    DropdownMenuItem(value: 'cajero', child: Text('🧑‍💼 Cajero')),
                                    DropdownMenuItem(value: 'admin', child: Text('👑 Administrador')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setStateDialog(() => rolSeleccionado = val);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cerrar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFAB00),
                    foregroundColor: Colors.black,
                  ),
                  icon: const Icon(Icons.save, size: 18),
                  label: Text(esEdicion ? 'Guardar Cambios' : 'Guardar Cajero', style: const TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    final nom = ctrlNombreCajero.text.trim();
                    final caja = ctrlNombreCaja.text.trim();
                    final pass = ctrlPasswordCajero.text.trim();
                    if (nom.isEmpty || caja.isEmpty || pass.isEmpty) return;

                    final navigator = Navigator.of(dialogContext);
                    final messenger = ScaffoldMessenger.of(context);
                    await _dbService.crearActualizarUsuario(
                      id: esEdicion ? (usuarioExistente['id'] as num).toInt() : null,
                      nombre: nom,
                      nombreCaja: caja,
                      password: pass,
                      rol: rolSeleccionado,
                    );
                    await _cargarDatosDB();
                    navigator.pop();
                    messenger.showSnackBar(
                      SnackBar(
                        backgroundColor: Colors.green,
                        content: Text('✅ Usuario "$nom" guardado con éxito.'),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmarRestaurarDeFabrica() {
    final ctrlConfirmacion = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0E1626),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Colors.redAccent, width: 2),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
              SizedBox(width: 8),
              Text(
                'Restaurar Sistema de Fábrica',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '⚠️ ATENCIÓN: Esta acción borrará TODAS las ventas, recibos, sesiones de caja, retiros, lotes de producción y productos.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Escriba FABRICA para confirmar:',
                  style: TextStyle(color: Color(0xFFFFAB00), fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: ctrlConfirmacion,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'FABRICA',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: const Color(0xFF131C31),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.restore),
              label: const Text('BORRAR TODO Y VOLVER A FÁBRICA', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () async {
                if (ctrlConfirmacion.text.trim().toUpperCase() != 'FABRICA') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: Colors.orangeAccent,
                      content: Text('Debe escribir exactamente FABRICA para confirmar.'),
                    ),
                  );
                  return;
                }

                final navigator = Navigator.of(dialogContext);
                final messenger = ScaffoldMessenger.of(context);

                await _dbService.restaurarValoresDeFabrica();
                await _cargarDatosDB();

                navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(
                    backgroundColor: Colors.green,
                    content: Text('♻️ Sistema restaurado a valores de fábrica.'),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _mostrarDialogoGestionarCategorias() {
    final ctrlNuevaCat = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (sbContext, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0E1626),
              title: const Text('🗂️ Gestión Global de Categorías', style: TextStyle(color: Color(0xFFFFAB00))),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Categorías registradas:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 160,
                      child: ListView.builder(
                        itemCount: _categoriasDisponibles.length,
                        itemBuilder: (context, index) {
                          final cat = _categoriasDisponibles[index];
                          final em = _obtenerEmojiCategoria(cat);
                          return ListTile(
                            dense: true,
                            leading: Text(em, style: const TextStyle(fontSize: 18)),
                            title: Text(cat, style: const TextStyle(color: Colors.white)),
                            trailing: cat == 'General'
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18),
                                    onPressed: () async {
                                      await _dbService.eliminarCategoriaDB(cat);
                                      await _cargarDatosDB();
                                      setStateDialog(() {});
                                    },
                                  ),
                          );
                        },
                      ),
                    ),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 8),
                    TextField(
                      controller: ctrlNuevaCat,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Nueva Categoría',
                        labelStyle: TextStyle(color: Color(0xFF00E5FF)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cerrar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFAB00),
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () async {
                    final nueva = ctrlNuevaCat.text.trim();
                    if (nueva.isNotEmpty) {
                      final messenger = ScaffoldMessenger.of(context);
                      await _dbService.insertarCategoria(nueva);
                      await _cargarDatosDB();
                      ctrlNuevaCat.clear();
                      setStateDialog(() {});
                      messenger.showSnackBar(
                        const SnackBar(content: Text('¡Categoría guardada!')),
                      );
                    }
                  },
                  child: const Text('Añadir y Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _mostrarDialogoNuevoProducto() {
    final ctrlNombre = TextEditingController();
    final ctrlPrecio = TextEditingController(text: '10.0');
    final ctrlStock = TextEditingController(text: '50');
    String categoriaSeleccionada = _categoriasDisponibles.isNotEmpty ? _categoriasDisponibles.first : 'General';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (sbContext, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0E1626),
              title: const Text('➕ Crear Nuevo Producto', style: TextStyle(color: Color(0xFFFFAB00))),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: ctrlNombre,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Nombre del Producto',
                      labelStyle: TextStyle(color: Color(0xFF00E5FF)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ctrlPrecio,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Precio Unitario (Bs.)',
                      labelStyle: TextStyle(color: Color(0xFF00E5FF)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ctrlStock,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Stock Inicial',
                      labelStyle: TextStyle(color: Color(0xFF00E5FF)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Categoría:',
                    style: TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131C31),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFAB00), width: 1),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: categoriaSeleccionada,
                        dropdownColor: const Color(0xFF131C31),
                        isExpanded: true,
                        style: const TextStyle(color: Colors.white),
                        items: _categoriasDisponibles.map((String cat) {
                          final em = _obtenerEmojiCategoria(cat);
                          return DropdownMenuItem<String>(
                            value: cat,
                            child: Text('$em $cat', style: const TextStyle(color: Colors.white)),
                          );
                        }).toList(),
                        onChanged: (String? nuevaCat) {
                          if (nuevaCat != null) {
                            setStateDialog(() {
                              categoriaSeleccionada = nuevaCat;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFAB00),
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () async {
                    final nombre = ctrlNombre.text.trim();
                    if (nombre.isEmpty) return;

                    final precio = double.tryParse(ctrlPrecio.text.trim()) ?? 10.0;
                    final stock = int.tryParse(ctrlStock.text.trim()) ?? 0;

                    final navigator = Navigator.of(dialogContext);
                    final messenger = ScaffoldMessenger.of(context);

                    final db = await _dbService.database;
                    await _dbService.insertarCategoria(categoriaSeleccionada);
                    final List catRows = await db.query(
                      'categorias',
                      where: 'nombre = ?',
                      whereArgs: [categoriaSeleccionada],
                    );
                    final int catId = catRows.isNotEmpty ? (catRows.first['id'] as num).toInt() : 1;

                    await db.insert('productos', {
                      'categoria_id': catId,
                      'nombre': nombre,
                      'precio': precio,
                      'stock_actual': stock,
                    });

                    await _cargarDatosDB();
                    navigator.pop();
                    messenger.showSnackBar(
                      const SnackBar(content: Text('¡Nuevo producto creado!')),
                    );
                  },
                  child: const Text('Guardar Producto'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmarEliminarProducto(Map producto) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0E1626),
          title: Text('Eliminar: ${producto['nombre']}', style: const TextStyle(color: Colors.redAccent)),
          content: const Text(
            '¿Está seguro de eliminar este producto?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final navigator = Navigator.of(dialogContext);
                final messenger = ScaffoldMessenger.of(context);
                final id = (producto['id'] as num).toInt();

                await _dbService.eliminarProducto(id);
                await _cargarDatosDB();

                navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(
                    backgroundColor: Colors.redAccent,
                    content: Text('¡Producto eliminado!'),
                  ),
                );
              },
              child: const Text('Sí, Eliminar'),
            ),
          ],
        );
      },
    );
  }

  void _mostrarDialogoEditarStock(Map producto) {
    final ctrlStock = TextEditingController(text: producto['stock']?.toString() ?? '10');
    final ctrlPrecio = TextEditingController(text: producto['precio']?.toString() ?? '0.0');

    String categoriaSeleccionada = producto['categoria']?.toString() ?? 'General';
    if (!_categoriasDisponibles.contains(categoriaSeleccionada)) {
      _categoriasDisponibles.add(categoriaSeleccionada);
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (sbContext, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0E1626),
              title: Text('Gestionar: ${producto['nombre']}', style: const TextStyle(color: Color(0xFFFFAB00))),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: ctrlStock,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Cantidad en Stock',
                      labelStyle: TextStyle(color: Color(0xFF00E5FF)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ctrlPrecio,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Precio Unitario (Bs.)',
                      labelStyle: TextStyle(color: Color(0xFF00E5FF)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Categoría:',
                    style: TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131C31),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFAB00), width: 1),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: categoriaSeleccionada,
                        dropdownColor: const Color(0xFF131C31),
                        isExpanded: true,
                        style: const TextStyle(color: Colors.white),
                        items: _categoriasDisponibles.map((String cat) {
                          final em = _obtenerEmojiCategoria(cat);
                          return DropdownMenuItem<String>(
                            value: cat,
                            child: Text('$em $cat', style: const TextStyle(color: Colors.white)),
                          );
                        }).toList(),
                        onChanged: (String? nuevaCat) {
                          if (nuevaCat != null) {
                            setStateDialog(() {
                              categoriaSeleccionada = nuevaCat;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFAB00),
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () async {
                    final navigator = Navigator.of(dialogContext);
                    final messenger = ScaffoldMessenger.of(context);

                    final nuevoStock = int.tryParse(ctrlStock.text.trim()) ?? (producto['stock'] ?? 10);
                    final nuevoPrecio = double.tryParse(ctrlPrecio.text.trim()) ?? (producto['precio'] ?? 0.0);
                    final id = (producto['id'] as num).toInt();

                    await _dbService.actualizarProducto(id, nuevoPrecio, nuevoStock, categoriaSeleccionada);
                    await _cargarDatosDB();

                    navigator.pop();
                    messenger.showSnackBar(
                      const SnackBar(content: Text('¡Actualizado con éxito!')),
                    );
                  },
                  child: const Text('Guardar Cambios'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      appBar: AppBar(
        title: Text('👑 Panel: ${_configNegocio['nombre_negocio']} (Admin)'),
        backgroundColor: const Color(0xFF0E1626),
        actions: [
          if (_moduloContaduriaActivo) ...[
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ContaduriaScreen()),
                );
                await _cargarDatosDB();
              },
              icon: const Icon(Icons.bar_chart_rounded, size: 18),
              label: const Text('Contaduría', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
          ],
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: _moduloContaduriaActivo ? Colors.greenAccent : Colors.grey,
              side: BorderSide(
                color: _moduloContaduriaActivo ? Colors.greenAccent : Colors.white24,
              ),
            ),
            onPressed: _alternarModuloContaduriaLicencia,
            icon: Icon(
              _moduloContaduriaActivo ? Icons.verified_user : Icons.lock_outline,
              size: 16,
            ),
            label: Text(
              _moduloContaduriaActivo ? 'Lic. Contaduría: ON' : 'Lic. Contaduría: OFF',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFAB00),
              foregroundColor: Colors.black,
            ),
            onPressed: () => _mostrarDialogoCambiarPasswordAdmin(),
            icon: const Icon(Icons.security, size: 18),
            label: Text('Clave Admin: $_passwordAdminActual', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purpleAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => _mostrarDialogoGestionarCajeros(),
            icon: const Icon(Icons.badge, size: 18),
            label: const Text('Cajeros & Claves', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: _confirmarRestaurarDeFabrica,
            icon: const Icon(Icons.restore, size: 18),
            label: const Text('Fábrica', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.greenAccent),
            onPressed: _mostrarDialogoNuevoProducto,
            tooltip: 'Agregar Producto',
          ),
          IconButton(
            icon: const Icon(Icons.category, color: Color(0xFFFFAB00)),
            onPressed: _mostrarDialogoGestionarCategorias,
            tooltip: 'Categorías',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF00E5FF)),
            onPressed: _cargarDatosDB,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFAB00)))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView.builder(
                itemCount: _listaProductos.length,
                itemBuilder: (context, index) {
                  final prod = _listaProductos[index] as Map<String, dynamic>;
                  final stockActual = (prod['stock'] as num?)?.toInt() ?? 15;
                  final bool stockBajo = stockActual <= 5;
                  final catProd = prod['categoria']?.toString() ?? 'General';
                  final emCat = _obtenerEmojiCategoria(catProd);
                  final int numeroCorrelativo = index + 1;

                  return Card(
                    color: const Color(0xFF131C31),
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: stockBajo ? Colors.redAccent : Colors.green,
                        child: Text(
                          '$numeroCorrelativo',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        prod['nombre']?.toString() ?? 'Producto',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      subtitle: Text(
                        'Categoría: $emCat $catProd | Precio: Bs. ${prod['precio'] ?? 0.0}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: stockBajo ? Colors.red.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Stock: $stockActual',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: stockBajo ? Colors.redAccent : Colors.greenAccent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFAB00),
                              foregroundColor: Colors.black,
                            ),
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text('Modificar'),
                            onPressed: () => _mostrarDialogoEditarStock(prod),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent),
                            tooltip: 'Eliminar producto',
                            onPressed: () => _confirmarEliminarProducto(prod),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}