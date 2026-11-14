// Nombre del archivo: lib/main.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'constants.dart';
import 'services/database_service.dart';
import 'services/license_service.dart';
import 'views/pos_screen.dart';
import 'views/admin_inventario_screen.dart';
import 'views/contaduria_screen.dart';

final ValueNotifier<String> globalLogoNotifier = ValueNotifier<String>('');

class EventoPagoYape {
  final String id;
  final String origen;
  final String empresa;
  final double monto;
  final String moneda;
  final String pagador;
  final String titulo;
  final String mensaje;
  final DateTime fechaHora;

  const EventoPagoYape({
    required this.id,
    required this.origen,
    required this.empresa,
    required this.monto,
    required this.moneda,
    required this.pagador,
    required this.titulo,
    required this.mensaje,
    required this.fechaHora,
  });

  factory EventoPagoYape.desdeMapa(Map mapa) {
    final num montoNum = (mapa['monto'] is num)
        ? (mapa['monto'] as num)
        : (double.tryParse(mapa['monto']?.toString() ?? '0') ?? 0.0);

    final String tsTexto = mapa['timestamp']?.toString() ?? '';
    final DateTime fecha = DateTime.tryParse(tsTexto) ?? DateTime.now();

    return EventoPagoYape(
      id: mapa['id']?.toString() ?? 'YAPE-${DateTime.now().millisecondsSinceEpoch}',
      origen: mapa['origen']?.toString() ?? 'YAPE_BOLIVIA',
      empresa: mapa['empresa']?.toString() ?? 'Avrora Soft - Vibola LLC',
      monto: montoNum.toDouble(),
      moneda: mapa['moneda']?.toString() ?? 'BOB',
      pagador: mapa['pagador']?.toString() ?? 'Cliente Yape QR',
      titulo: mapa['titulo']?.toString() ?? 'Pago QR Recibido',
      mensaje: mapa['mensaje']?.toString() ?? '',
      fechaHora: fecha,
    );
  }
}

class YapeUdpReceptor {
  static final YapeUdpReceptor instance = YapeUdpReceptor._interno();
  YapeUdpReceptor._interno();

  RawDatagramSocket? _socket;
  final StreamController _controladorPagos = StreamController.broadcast();
  final Map _idsProcesados = {};
  bool _escuchando = false;
  int _puertoActivo = 45455;

  bool get estaEscuchando => _escuchando;
  int get puertoActivo => _puertoActivo;
  Stream get flujoPagos => _controladorPagos.stream;

  Future iniciarEscucha({int puerto = 45455}) async {
    if (_escuchando && _socket != null) return;
    _puertoActivo = puerto;

    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _puertoActivo,
        reuseAddress: true,
      );
      _socket!.broadcastEnabled = true;
      _escuchando = true;

      _socket!.listen(
        (RawSocketEvent evento) {
          if (evento == RawSocketEvent.read) {
            final Datagram? datagrama = _socket?.receive();
            if (datagrama != null) {
              _procesarDatagrama(datagrama);
            }
          }
        },
        onError: (Object error) {
          debugPrint('Error en socket UDP de AScafe: $error');
        },
        onDone: () {
          _escuchando = false;
        },
      );
    } catch (e) {
      _escuchando = false;
      debugPrint('No se pudo abrir el puerto UDP $_puertoActivo: $e');
    }
  }

  void _procesarDatagrama(Datagram datagrama) {
    try {
      final String textoJson = utf8.decode(datagrama.data, allowMalformed: true).trim();
      if (textoJson.isEmpty) return;

      final dynamic decodificado = jsonDecode(textoJson);
      if (decodificado is! Map) return;

      final EventoPagoYape pago = EventoPagoYape.desdeMapa(decodificado);

      final DateTime ahora = DateTime.now();
      _idsProcesados.removeWhere((dynamic _, dynamic fechaGuardada) {
        final DateTime f = fechaGuardada as DateTime;
        return ahora.difference(f).inSeconds.compareTo(90) == 1;
      });

      if (_idsProcesados.containsKey(pago.id)) return;
      _idsProcesados[pago.id] = ahora;

      _controladorPagos.add(pago);
    } catch (e) {
      debugPrint('Datagrama UDP descartado: $e');
    }
  }

  StreamSubscription esperarPagoExacto({
    required double montoEsperado,
    required void Function(EventoPagoYape pagoConfirmado) alConfirmarPago,
  }) {
    if (!_escuchando) {
      iniciarEscucha(puerto: _puertoActivo);
    }

    return flujoPagos.listen((dynamic evento) {
      final EventoPagoYape pago = evento as EventoPagoYape;
      final double diferencia = (pago.monto - montoEsperado).abs();
      if (diferencia.compareTo(0.015) == -1) {
        alConfirmarPago(pago);
      }
    });
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Iniciar receptor UDP local para Yape de manera automática
  YapeUdpReceptor.instance.iniciarEscucha(puerto: 45455);

  try {
    await DatabaseService.instance.database;
    final config = await DatabaseService.instance.obtenerConfiguracionNegocio();
    globalLogoNotifier.value = config['logo_path']?.toString() ?? '';
  } catch (_) {}

  runApp(const AScafeApp());
}

class AScafeApp extends StatelessWidget {
  const AScafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '${AppConstants.empresaNombre} - Administración y Gestión de Café',
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
      home: const VerificadorLicenciaInit(),
    );
  }
}

class VerificadorLicenciaInit extends StatefulWidget {
  const VerificadorLicenciaInit({super.key});

  @override
  State<VerificadorLicenciaInit> createState() => _VerificadorLicenciaInitState();
}

class _VerificadorLicenciaInitState extends State<VerificadorLicenciaInit> {
  bool _licenciado = false;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _chequearLicencia();
  }

  Future<void> _chequearLicencia() async {
    try {
      final config = await DatabaseService.instance.obtenerConfiguracionNegocio();
      String contenidoLicencia = config['serial_activacion']?.toString() ?? '';
      String uidActual = await LicenseService.instance.obtenerUIDPlacaBase();

      bool esValido = LicenseService.instance.validarLicenciaArchivo(contenidoLicencia, uidActual);

      if (esValido) {
        final incluyeContaduria = LicenseService.instance.licenciaIncluyeContaduria(contenidoLicencia);
        await DatabaseService.instance.configurarModuloContaduriaPorLicencia(incluyeContaduria);
      }

      setState(() {
        _licenciado = esValido;
        _cargando = false;
      });
    } catch (_) {
      setState(() {
        _licenciado = false;
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0F1D),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFFAB00))),
      );
    }

    if (_licenciado) {
      return const MainShellScreen();
    } else {
      return ActivacionScreen(
        onLicenciaAceptada: () {
          setState(() {
            _licenciado = true;
          });
        },
      );
    }
  }
}

class ActivacionScreen extends StatefulWidget {
  final VoidCallback onLicenciaAceptada;

  const ActivacionScreen({super.key, required this.onLicenciaAceptada});

  @override
  State<ActivacionScreen> createState() => _ActivacionScreenState();
}

class _ActivacionScreenState extends State<ActivacionScreen> {
  String _uidHardware = 'Leyendo hardware...';
  bool _cargandoUid = true;

  @override
  void initState() {
    super.initState();
    _cargarUID();
  }

  Future<void> _cargarUID() async {
    String uid = await LicenseService.instance.obtenerUIDPlacaBase();
    setState(() {
      _uidHardware = uid;
      _cargandoUid = false;
    });
  }

  Future<void> _enviarWhatsApp() async {
    const String telefonoEmpresa = '59173995224';
    String mensaje = Uri.encodeComponent(
      'Hola, necesito activar el sistema AScafe de ${AppConstants.empresaNombre}.\nMi UID de placa base es: *$_uidHardware*',
    );

    final Uri url = Uri.parse('https://wa.me/$telefonoEmpresa?text=$mensaje');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _importarArchivoLicencia() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['av'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        String filePath = result.files.single.path!;
        File archivo = File(filePath);
        String contenidoLicencia = await archivo.readAsString();

        bool esValida = LicenseService.instance.validarLicenciaArchivo(contenidoLicencia, _uidHardware);

        if (esValida) {
          final incluyeContaduria = LicenseService.instance.licenciaIncluyeContaduria(contenidoLicencia);
          final detalles = LicenseService.instance.obtenerDetallesLicencia(contenidoLicencia);
          final clienteNeg = detalles?['cliente']?.toString().trim() ?? '';

          final Map<String, String> datosGuardar = {
            'serial_activacion': contenidoLicencia.trim(),
            'modulo_contaduria_activo': incluyeContaduria ? 'true' : 'false',
          };
          if (clienteNeg.isNotEmpty) {
            datosGuardar['nombre_negocio'] = clienteNeg;
          }

          await DatabaseService.instance.guardarConfiguracionNegocio(datosGuardar);

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.green,
              content: Text(
                incluyeContaduria
                    ? '✅ ¡Licencia .av activada con éxito! (Módulo de Contaduría INCLUIDO)'
                    : '✅ ¡Licencia .av Estándar activada con éxito!',
              ),
            ),
          );
          widget.onLicenciaAceptada();
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.redAccent,
              content: Text('❌ El archivo de licencia no es válido o pertenece a otra PC.'),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Error al procesar el archivo de licencia: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      body: Center(
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF0E1626),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFAB00), width: 1.5),
          ),
          child: _cargandoUid
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFAB00)))
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      '🔒 Activación de Licencia - AScafe',
                      style: TextStyle(color: Color(0xFFFFAB00), fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      AppConstants.empresaNombre,
                      style: TextStyle(color: Color(0xFF00E5FF), fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Este sistema está vinculado al hardware de su PC. Copie su UID o envíelo por WhatsApp para obtener su archivo license.av.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'UID de la Placa Base (Hardware ID):',
                        style: TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131C31),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _uidHardware,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                letterSpacing: 1.1,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, color: Color(0xFFFFAB00), size: 20),
                            tooltip: 'Copiar UID',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _uidHardware));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('UID copiado al portapapeles'),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 45),
                      ),
                      onPressed: _enviarWhatsApp,
                      icon: const Icon(Icons.chat),
                      label: const Text(
                        'Enviar UID por WhatsApp (+591 73995224)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Divider(color: Colors.white24, height: 30),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E5FF),
                        foregroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      onPressed: _importarArchivoLicencia,
                      icon: const Icon(Icons.folder_open, size: 20),
                      label: const Text(
                        'Importar Archivo de Licencia (.av)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
        ),
      ),
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
  bool _moduloContaduriaLicenciado = true;

  bool get esAdmin => (_usuarioAutenticado?['rol']?.toString() ?? '') == 'admin';
  String get nombreCajeroActivo => _usuarioAutenticado?['nombre']?.toString() ?? 'Cajero';
  String get nombreCajaActiva => _usuarioAutenticado?['nombre_caja']?.toString() ?? 'Caja 1';
  int get idUsuarioActivo => (_usuarioAutenticado?['id'] as num?)?.toInt() ?? 1;

  @override
  void initState() {
    super.initState();
    _cargarUsuariosParaLogin();
    _cargarConfiguracionLogo();
    actualizarMetricasGlobales();
    _verificarAlertaExpiracion();
  }

  @override
  void dispose() {
    _ctrlPasswordLogin.dispose();
    super.dispose();
  }

  Future<void> _verificarAlertaExpiracion() async {
    try {
      final config = await _dbService.obtenerConfiguracionNegocio();
      String contenidoLicencia = config['serial_activacion']?.toString() ?? '';
      final detalles = LicenseService.instance.obtenerDetallesLicencia(contenidoLicencia);

      if (detalles != null) {
        final expiracion = detalles['expiracion']?.toString() ?? '';
        int diasRestantes = LicenseService.instance.calcularDiasRestantes(expiracion);

        if (diasRestantes <= 15 && diasRestantes >= 0) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.orangeAccent,
              duration: const Duration(seconds: 8),
              content: Text('⚠️ Su licencia vence en $diasRestantes días. Contacte a soporte para su renovación.'),
            ),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _cargarConfiguracionLogo() async {
    try {
      final config = await _dbService.obtenerConfiguracionNegocio();
      globalLogoNotifier.value = config['logo_path']?.toString() ?? '';
    } catch (_) {}
  }

  Future<void> forzarActualizacionLogo() async {
    await _cargarConfiguracionLogo();
  }

  Future<void> _cargarUsuariosParaLogin() async {
    setState(() => _cargandoLogin = true);
    try {
      final usuarios = await _dbService.obtenerUsuarios();
      final contActiva = await _dbService.estaModuloContaduriaActivo();
      if (mounted) {
        setState(() {
          _listaUsuariosLogin = usuarios;
          _moduloContaduriaLicenciado = contActiva;
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
      final contActiva = await _dbService.estaModuloContaduriaActivo();
      setState(() {
        _usuarioAutenticado = user;
        _moduloContaduriaLicenciado = contActiva;
        _indiceSeleccionado = 0;
        _ctrlPasswordLogin.clear();
      });
      await _cargarConfiguracionLogo();
      await actualizarMetricasGlobales();
      await _verificarAlertaExpiracion();
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
      final contActiva = await _dbService.estaModuloContaduriaActivo();

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
          _moduloContaduriaLicenciado = contActiva;
        });
      }
    } catch (_) {}
  }

  void cambiarPantalla(int nuevoIndice) {
    if (!esAdmin && nuevoIndice >= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('🔒 Área restringida: Solo el Administrador puede ingresar a esta sección.'),
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
        if (!esAdmin) {
          return PosScreen(parentState: this);
        }
        return const AdminInventarioScreen(
          key: ValueKey('inventario_view'),
        );
      case 2:
        if (!esAdmin || !_moduloContaduriaLicenciado) {
          return PosScreen(parentState: this);
        }
        return ContaduriaScreen(
          key: const ValueKey('contaduria_view'),
          cajeroActivo: nombreCajeroActivo,
          cajaActiva: nombreCajaActiva,
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
                          Text('☕', style: TextStyle(fontSize: 40)),
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
    if (_usuarioAutenticado == null) {
      return _construirPantallaLoginObligatorio();
    }

    final List<NavigationRailDestination> destinosPermitidos = [
      const NavigationRailDestination(
        icon: Icon(Icons.point_of_sale_outlined),
        selectedIcon: Icon(Icons.point_of_sale),
        label: Text('🛒 Caja y Ventas'),
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
          label: const Text('👑 Admin y Configuración'),
        ),
      if (esAdmin && _moduloContaduriaLicenciado)
        const NavigationRailDestination(
          icon: Icon(Icons.bar_chart_outlined),
          selectedIcon: Icon(Icons.bar_chart_rounded),
          label: Text('📊 Contaduría'),
        ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _menuExpandido ? 240 : 84,
            decoration: const BoxDecoration(
              color: Color(0xFF0E1626),
              border: Border(
                right: BorderSide(color: Colors.white12, width: 1),
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF131C31),
                    border: Border(
                      bottom: BorderSide(color: Colors.white12, width: 1),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: _menuExpandido ? MainAxisAlignment.spaceBetween : MainAxisAlignment.center,
                        children: [
                          if (_menuExpandido)
                            ValueListenableBuilder<String>(
                              valueListenable: globalLogoNotifier,
                              builder: (context, logoPath, _) {
                                return Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0A0F1D),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFFFFAB00), width: 2),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: logoPath.isNotEmpty && File(logoPath).existsSync()
                                        ? Image.file(File(logoPath), fit: BoxFit.cover)
                                        : const Icon(Icons.store, color: Color(0xFFFFAB00), size: 32),
                                  ),
                                );
                              },
                            ),
                          IconButton(
                            icon: Icon(
                              _menuExpandido ? Icons.menu_open : Icons.menu,
                              color: const Color(0xFF00E5FF),
                              size: 28,
                            ),
                            tooltip: _menuExpandido ? 'Contraer Menú' : 'Expandir Menú',
                            onPressed: () {
                              setState(() {
                                _menuExpandido = !_menuExpandido;
                              });
                            },
                          ),
                        ],
                      ),
                      if (_menuExpandido) ...[
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '🖥️ $nombreCajaActiva',
                            style: const TextStyle(
                              color: Color(0xFFFFAB00),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '👤 $nombreCajeroActivo (${esAdmin ? "Admin" : "Cajero"})',
                            style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: NavigationRail(
                    extended: _menuExpandido,
                    minExtendedWidth: 240,
                    minWidth: 84,
                    backgroundColor: const Color(0xFF0E1626),
                    selectedIndex: _indiceSeleccionado >= destinosPermitidos.length ? 0 : _indiceSeleccionado,
                    selectedIconTheme: const IconThemeData(color: Color(0xFFFFAB00), size: 28),
                    unselectedIconTheme: const IconThemeData(color: Colors.white60, size: 24),
                    selectedLabelTextStyle: const TextStyle(
                      color: Color(0xFFFFAB00),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
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
                    padding: const EdgeInsets.all(12),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent.withOpacity(0.85),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(216, 44),
                      ),
                      onPressed: cerrarSesion,
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Cambiar Cajero / Salir', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: IconButton(
                      icon: const Icon(Icons.logout, color: Colors.redAccent, size: 26),
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