// Nombre del archivo: main.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'services/database_service.dart';
import 'views/pos_screen.dart';
import 'views/lotes_screen.dart';
import 'views/admin_inventario_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  try {
    await DatabaseService.instance.database;
  } catch (_) {}

  runApp(const AScafeApp());
}

class AScafeApp extends StatelessWidget {
  const AScafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AScafe - Sistema POS & Control de Producción',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0F1D),
        primaryColor: const Color(0xFFFFAB00),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFAB00),
          secondary: Color(0xFF00E5FF),
          surface: Color(0xFF0E1626),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0E1626),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      home: const MainShellScreen(),
    );
  }
}

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => MainShellScreenState();
}

class MainShellScreenState extends State<MainShellScreen> {
  final DatabaseService _dbService = DatabaseService.instance;

  // Estado de Autenticación Obligatoria
  Map? _usuarioAutenticado;
  List _listaUsuariosLogin = [];
  String _nombreUsuarioSeleccionado = '';
  final TextEditingController _ctrlPasswordLogin = TextEditingController();
  bool _cargandoLogin = true;

  int _indiceSeleccionado = 0;
  bool _menuExpandido = true;

  int _totalProductosCatalogo = 0;
  int _totalCategoriasActivas = 0;
  int _alertasStockBajo = 0;

  bool get esAdmin => (_usuarioAutenticado?['rol']?.toString() ?? '') == 'admin';
  String get nombreCajeroActivo => _usuarioAutenticado?['nombre']?.toString() ?? 'Cajero';
  String get nombreCajaActiva => _usuarioAutenticado?['nombre_caja']?.toString() ?? 'Caja 1';
  int get idUsuarioActivo => (_usuarioAutenticado?['id'] as num?)?.toInt() ?? 1;

  @override
  void initState() {
    super.initState();
    _cargarUsuariosParaLogin();
    actualizarMetricasGlobales();
  }

  @override
  void dispose() {
    _ctrlPasswordLogin.dispose();
    super.dispose();
  }

  Future<void> _cargarUsuariosParaLogin() async {
    setState(() => _cargandoLogin = true);
    try {
      final usuarios = await _dbService.obtenerUsuarios();
      if (mounted) {
        setState(() {
          _listaUsuariosLogin = usuarios;
          if (_listaUsuariosLogin.isNotEmpty) {
            final primero = _listaUsuariosLogin.first as Map;
            _nombreUsuarioSeleccionado = primero['nombre']?.toString() ?? '';
          }
          _cargandoLogin = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _cargandoLogin = false);
      }
    }
  }

  Future<void> _iniciarSesion() async {
    final pass = _ctrlPasswordLogin.text.trim();
    if (_nombreUsuarioSeleccionado.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('⚠️ Seleccione su usuario e ingrese su contraseña.'),
        ),
      );
      return;
    }

    final user = await _dbService.autenticarUsuario(_nombreUsuarioSeleccionado, pass);
    if (!mounted) return;

    if (user != null) {
      setState(() {
        _usuarioAutenticado = user;
        _indiceSeleccionado = 0;
        _ctrlPasswordLogin.clear();
      });
      await actualizarMetricasGlobales();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('❌ Contraseña incorrecta. Acceso denegado.'),
        ),
      );
    }
  }

  void cerrarSesion() {
    setState(() {
      _usuarioAutenticado = null;
      _indiceSeleccionado = 0;
      _ctrlPasswordLogin.clear();
    });
    _cargarUsuariosParaLogin();
  }

  Future<void> actualizarMetricasGlobales() async {
    try {
      final cats = await _dbService.obtenerCategorias();
      final prods = await _dbService.obtenerProductos();

      int bajos = 0;
      for (final p in prods) {
        if (p is Map) {
          final st = (p['stock'] as num?)?.toInt() ?? (p['stock_actual'] as num?)?.toInt() ?? 0;
          if (st <= 5) {
            bajos++;
          }
        }
      }

      if (mounted) {
        setState(() {
          _totalCategoriasActivas = cats.length;
          _totalProductosCatalogo = prods.length;
          _alertasStockBajo = bajos;
        });
      }
    } catch (_) {}
  }

  void cambiarPantalla(int nuevoIndice) {
    if (!esAdmin && nuevoIndice == 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('🔒 Área restringida: Solo el Administrador puede ingresar a Catálogo y Configuración.'),
        ),
      );
      return;
    }
    setState(() {
      _indiceSeleccionado = nuevoIndice;
    });
    actualizarMetricasGlobales();
  }

  Widget _construirPantallaActual() {
    switch (_indiceSeleccionado) {
      case 0:
        return PosScreen(
          key: ValueKey('pos_${idUsuarioActivo}_${_totalProductosCatalogo}_$_totalCategoriasActivas'),
          parentState: this,
        );
      case 1:
        return LotesScreen(
          key: const ValueKey('lotes_view'),
          parentState: this,
        );
      case 2:
        if (!esAdmin) {
          return PosScreen(parentState: this);
        }
        return const AdminInventarioScreen(
          key: ValueKey('inventario_view'),
        );
      default:
        return PosScreen(parentState: this);
    }
  }

  Widget _construirPantallaLoginObligatorio() {
    String cajaDelSeleccionado = '';
    String rolDelSeleccionado = '';
    for (final u in _listaUsuariosLogin) {
      if (u is Map && u['nombre']?.toString() == _nombreUsuarioSeleccionado) {
        cajaDelSeleccionado = u['nombre_caja']?.toString() ?? '';
        rolDelSeleccionado = u['rol']?.toString() == 'admin' ? 'ADMINISTRADOR GENERAL' : 'CAJERO DE TURNO';
        break;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      body: Center(
        child: _cargandoLogin
            ? const CircularProgressIndicator(color: Color(0xFFFFAB00))
            : Container(
                width: 430,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFF131C31),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFAB00), width: 1.8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Column(
                        children: [
                          Text('☕ 🥟', style: TextStyle(fontSize: 40)),
                          SizedBox(height: 8),
                          Text(
                            'AScafe - Control de Acceso',
                            style: TextStyle(
                              color: Color(0xFFFFAB00),
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Avrora Soft - Vibola LLC | Ingreso Obligatorio con Credenciales',
                            style: TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white24, height: 28),
                    const Text(
                      '👤 Seleccione su Usuario / Cajero:',
                      style: TextStyle(
                        color: Color(0xFF00E5FF),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A0F1D),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFFAB00)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _nombreUsuarioSeleccionado.isNotEmpty ? _nombreUsuarioSeleccionado : null,
                          dropdownColor: const Color(0xFF0E1626),
                          isExpanded: true,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          items: _listaUsuariosLogin.map((u) {
                            final mapa = u as Map;
                            final nom = mapa['nombre']?.toString() ?? '';
                            final rol = mapa['rol']?.toString() == 'admin' ? '👑 Admin' : '🧑‍💼 Cajero';
                            return DropdownMenuItem<String>(
                              value: nom,
                              child: Text('$rol - $nom'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _nombreUsuarioSeleccionado = val;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E1626),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🖥️ Caja Asignada: $cajaDelSeleccionado',
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '🛡️ Nivel de Acceso: $rolDelSeleccionado',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _ctrlPasswordLogin,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      onSubmitted: (_) => _iniciarSesion(),
                      decoration: InputDecoration(
                        labelText: '🔑 Contraseña de Usuario',
                        labelStyle: const TextStyle(color: Color(0xFF00E5FF)),
                        filled: true,
                        fillColor: const Color(0xFF0A0F1D),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 22),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFAB00),
                        foregroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _iniciarSesion,
                      icon: const Icon(Icons.login),
                      label: const Text(
                        'INGRESAR AL SISTEMA',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Bloqueo estricto: Si no hay sesión autenticada, solo se muestra el Login
    if (_usuarioAutenticado == null) {
      return _construirPantallaLoginObligatorio();
    }

    final List<NavigationRailDestination> destinosPermitidos = [
      const NavigationRailDestination(
        icon: Icon(Icons.point_of_sale_outlined),
        selectedIcon: Icon(Icons.point_of_sale),
        label: Text('🛒 Punto de Venta'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.local_fire_department_outlined),
        selectedIcon: Icon(Icons.local_fire_department),
        label: Text('🔥 Lotes y Horno'),
      ),
      if (esAdmin)
        NavigationRailDestination(
          icon: Badge(
            isLabelVisible: _alertasStockBajo > 0,
            label: Text('$_alertasStockBajo'),
            backgroundColor: Colors.redAccent,
            child: const Icon(Icons.admin_panel_settings_outlined),
          ),
          selectedIcon: Badge(
            isLabelVisible: _alertasStockBajo > 0,
            label: Text('$_alertasStockBajo'),
            backgroundColor: Colors.redAccent,
            child: const Icon(Icons.admin_panel_settings),
          ),
          label: const Text('👑 Admin y Cajeros'),
        ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      body: Row(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0E1626),
              border: Border(
                right: BorderSide(color: Colors.white12, width: 1),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: _menuExpandido ? 220 : 72,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFF131C31),
                    border: Border(
                      bottom: BorderSide(color: Colors.white12, width: 1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment:
                        _menuExpandido ? MainAxisAlignment.spaceBetween : MainAxisAlignment.center,
                    children: [
                      if (_menuExpandido)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '🖥️ $nombreCajaActiva',
                                style: const TextStyle(
                                  color: Color(0xFFFFAB00),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '👤 $nombreCajeroActivo (${esAdmin ? "Admin" : "Cajero"})',
                                style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      IconButton(
                        icon: Icon(
                          _menuExpandido ? Icons.menu_open : Icons.menu,
                          color: const Color(0xFF00E5FF),
                        ),
                        onPressed: () {
                          setState(() {
                            _menuExpandido = !_menuExpandido;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: NavigationRail(
                    extended: _menuExpandido,
                    minExtendedWidth: 220,
                    minWidth: 72,
                    backgroundColor: const Color(0xFF0E1626),
                    selectedIndex: _indiceSeleccionado >= destinosPermitidos.length ? 0 : _indiceSeleccionado,
                    selectedIconTheme: const IconThemeData(color: Color(0xFFFFAB00), size: 26),
                    unselectedIconTheme: const IconThemeData(color: Colors.white60, size: 22),
                    selectedLabelTextStyle: const TextStyle(
                      color: Color(0xFFFFAB00),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    unselectedLabelTextStyle: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                    onDestinationSelected: cambiarPantalla,
                    destinations: destinosPermitidos,
                  ),
                ),
                if (_menuExpandido)
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent.withOpacity(0.85),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(195, 42),
                      ),
                      onPressed: cerrarSesion,
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Cambiar Cajero / Salir', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: IconButton(
                      icon: const Icon(Icons.logout, color: Colors.redAccent),
                      tooltip: 'Cerrar Sesión',
                      onPressed: cerrarSesion,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _construirPantallaActual(),
          ),
        ],
      ),
    );
  }
}