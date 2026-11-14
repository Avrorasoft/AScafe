// Nombre del archivo: lib/views/pos_screen.dart
import '../widgets/avrora_info_dialog.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../services/database_service.dart';
import '../services/email_listener_service.dart';
import '../models/email_config.dart';
import 'admin_inventario_screen.dart';
import '../main.dart';

class ItemCatalogo {
  final int id;
  final String nombre;
  final double precio;
  final String categoria;
  final int stock;
  final String? emojiPersonalizado;
  final String? imagenPath;

  ItemCatalogo(
    this.id,
    this.nombre,
    this.precio, {
    required this.categoria,
    required this.stock,
    this.emojiPersonalizado,
    this.imagenPath,
  });
}

class ItemCarrito {
  final ItemCatalogo producto;
  int cantidad;
  double precioUnitario;
  String nota;

  ItemCarrito({
    required this.producto,
    this.cantidad = 1,
    required this.precioUnitario,
    this.nota = '',
  });

  double get subtotal => cantidad * precioUnitario;
}

class PosScreen extends StatefulWidget {
  final dynamic parentState;

  const PosScreen({super.key, this.parentState});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final DatabaseService _dbService = DatabaseService.instance;
  EmailListenerService? _emailListenerService;
  StreamSubscription? _yapeUdpSubscription;
  bool _alertaQrAbierta = false;
  bool _modalEsperaYapeAbierto = false;
  bool _pantallaCompletaActiva = true;

  List<ItemCatalogo> products = [];
  List<String> categorias = ['Todos'];
  String categoriaSeleccionada = 'Todos';
  bool cargandoProductos = true;

  final TextEditingController _ctrlBusqueda = TextEditingController();
  String _filtroTexto = '';
  bool _soloConStock = false;

  final List<ItemCarrito> carrito = [];
  final TextEditingController _ctrlClienteNombre = TextEditingController(text: 'Cliente Casual');
  final TextEditingController _ctrlNitCi = TextEditingController(text: '0');
  final TextEditingController _ctrlMontoRecibido = TextEditingController();
  final TextEditingController _ctrlDescuento = TextEditingController(text: '0');

  String _metodoPagoSeleccionado = 'Efectivo';
  String _tipoPedido = 'Para Llevar';
  List<String> _listaMesas = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10'];
  String _numeroMesa = '1';

  int _cajaIdActual = 1;
  bool _cajaAbierta = true;
  double _montoInicialCaja = 0.0;
  String _fechaAperturaCaja = '';
  double _totalVentasTurno = 0.0;
  double _totalEfectivoTurno = 0.0;
  double _totalQrTurno = 0.0;
  double _recaudacionDiaAnteriorRef = 0.0;

  Map<String, dynamic>? _ultimoTicketGenerado;

  Timer? _relojTimer;
  String _horaActual = '';
  String _fechaActual = '';

  Map<String, String> _configNegocio = {
    'nombre_negocio': 'AScafe',
    'direccion_negocio': 'Riberalta, Beni - Bolivia',
    'celular_negocio': '+591 70000000',
    'logo_path': '',
    'imap_host': 'imap.gmail.com',
    'imap_port': '993',
    'imap_email': '',
    'imap_password': '',
    'lista_mesas': '1,2,3,4,5,6,7,8,9,10',
    'imagenes_productos_json': '{}',
    'emojis_productos_json': '{}',
  };

  final Map<String, String> _emojisProductosCustom = {};
  final Map<String, String> _imagenesProductosCustom = {};

  static const List<String> _paletaEmojisProductos = [
    '🥟', '🍗', '🥩', '🌶️', '🍯', '🧀', '🥚', '🥓',
    '🥤', '🍑', '🌾', '🟣', '🥮', '☕', '🍵', '🥛',
    '🍰', '🧁', '🍩', '🍪', '🍮', '🍦', '🥪', '🍔',
    '🍕', '🌭', '🍟', '🍿', '🥗', '🍲', '🍱', '🍽️'
  ];

  static const int _anchoColsEstandarPdf = 36;
  static const String _separadorEstandarPdf = '------------------------------------';

  bool get _esAdminActivo {
    try {
      return widget.parentState?.esAdmin == true;
    } catch (_) {
      return false;
    }
  }

  String get _nombreCajeroActivo {
    try {
      return widget.parentState?.nombreCajeroActivo?.toString() ?? 'Administrador';
    } catch (_) {
      return 'Administrador';
    }
  }

  String get _nombreCajaActiva {
    try {
      return widget.parentState?.nombreCajaActiva?.toString() ?? 'Caja 1 - Principal';
    } catch (_) {
      return 'Caja 1 - Principal';
    }
  }
  
  @override
  void initState() {
    super.initState();
    _actualizarReloj();
    _relojTimer = Timer.periodic(const Duration(seconds: 1), (_) => _actualizarReloj());
    _inicializarSistemaPOS();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_manejarAtajoTecladoF11);
    _relojTimer?.cancel();
    _emailListenerService?.detenerMonitoreo();
    _yapeUdpSubscription?.cancel();
    _ctrlBusqueda.dispose();
    _ctrlClienteNombre.dispose();
    _ctrlNitCi.dispose();
    _ctrlMontoRecibido.dispose();
    _ctrlDescuento.dispose();
    super.dispose();
  }

  bool _manejarAtajoTecladoF11(KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.f11) {
      _activarPantallaCompletaInmersiva(forzarMaximizado: false);
      return true;
    }
    return false;
  }

  Future<void> _activarPantallaCompletaInmersiva({bool forzarMaximizado = false}) async {
    try {
      if (forzarMaximizado) {
        _pantallaCompletaActiva = true;
      } else {
        _pantallaCompletaActiva = !_pantallaCompletaActiva;
      }

      if (Platform.isWindows) {
        final int pidActual = pid;
        final int modoSolapado = _pantallaCompletaActiva ? 1 : 0;

        // Solapa la barra de tareas dejándola en la capa inferior, manteniendo la barra superior de la app visible.
        final String scriptPs = '''
\$code = @"
using System;
using System.Runtime.InteropServices;

[StructLayout(LayoutKind.Sequential)]
public struct RECT {
    public int Left;
    public int Top;
    public int Right;
    public int Bottom;
}

public class Win32LayerOverlap {
    [DllImport("user32.dll")] public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
    [DllImport("user32.dll")] public static extern int GetSystemMetrics(int nIndex);
    [DllImport("user32.dll", SetLastError = true)] public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, ref RECT pvParam, uint fWinIni);
}
"@
Add-Type -TypeDefinition \$code -Language CSharp -ErrorAction SilentlyContinue

\$tray = [Win32LayerOverlap]::FindWindow("Shell_TrayWnd", \$null)
\$traySec = [Win32LayerOverlap]::FindWindow("Shell_SecondaryTrayWnd", \$null)

# La barra de tareas NUNCA se oculta; se mantiene visible en su capa inferior
if (\$tray -ne [IntPtr]::Zero) { [Win32LayerOverlap]::ShowWindow(\$tray, 5) | Out-Null }
if (\$traySec -ne [IntPtr]::Zero) { [Win32LayerOverlap]::ShowWindow(\$traySec, 5) | Out-Null }

\$w = [Win32LayerOverlap]::GetSystemMetrics(0)
\$h = [Win32LayerOverlap]::GetSystemMetrics(1)
\$SPI_SETWORKAREA = 0x002F
\$SWP_SHOWWINDOW = 0x0040

\$proc = Get-Process -Id $pidActual -ErrorAction SilentlyContinue
\$hWnd = if (\$proc) { \$proc.MainWindowHandle } else { [IntPtr]::Zero }

if ($modoSolapado -eq 1) {
    # Área de trabajo completa para que la app cubra hasta el borde, solapando la barra de tareas abajo
    \$rectFull = New-Object RECT
    \$rectFull.Left = 0; \$rectFull.Top = 0; \$rectFull.Right = \$w; \$rectFull.Bottom = \$h
    [Win32LayerOverlap]::SystemParametersInfo(\$SPI_SETWORKAREA, 0, [ref]\$rectFull, 2) | Out-Null

    if (\$hWnd -ne [IntPtr]::Zero) {
        [Win32LayerOverlap]::ShowWindow(\$hWnd, 9) | Out-Null
        [Win32LayerOverlap]::ShowWindow(\$hWnd, 3) | Out-Null
        [Win32LayerOverlap]::SetWindowPos(\$hWnd, [IntPtr]::Zero, 0, 0, \$w, \$h, \$SWP_SHOWWINDOW) | Out-Null
    }
} else {
    # Restaura el área de trabajo estándar dejando espacio para la barra de tareas
    \$rectWork = New-Object RECT
    \$rectWork.Left = 0; \$rectWork.Top = 0; \$rectWork.Right = \$w; \$rectWork.Bottom = \$h - 48
    [Win32LayerOverlap]::SystemParametersInfo(\$SPI_SETWORKAREA, 0, [ref]\$rectWork, 2) | Out-Null

    if (\$hWnd -ne [IntPtr]::Zero) {
        [Win32LayerOverlap]::ShowWindow(\$hWnd, 9) | Out-Null
        [Win32LayerOverlap]::ShowWindow(\$hWnd, 3) | Out-Null
    }
}
''';

        final bytesUtf16 = <int>[];
        for (final unit in scriptPs.codeUnits) {
          bytesUtf16.add(unit & 0xFF);
          bytesUtf16.add((unit >> 8) & 0xFF);
        }
        final encodedCmd = base64Encode(bytesUtf16);

        await Process.run('powershell', [
          '-NoProfile',
          '-NonInteractive',
          '-WindowStyle',
          'Hidden',
          '-EncodedCommand',
          encodedCmd,
        ]);
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Aviso al ajustar capa solapada: $e');
    }
  }

  void _actualizarReloj() {
    final ahora = DateTime.now();
    final h = ahora.hour.toString().padLeft(2, '0');
    final m = ahora.minute.toString().padLeft(2, '0');
    final s = ahora.second.toString().padLeft(2, '0');
    final d = ahora.day.toString().padLeft(2, '0');
    final mes = ahora.month.toString().padLeft(2, '0');
    final anio = ahora.year;

    if (mounted) {
      setState(() {
        _horaActual = '$h:$m:$s';
        _fechaActual = '$d/$mes/$anio';
      });
    }
  }

  Future<void> _guardarMesasYMultimediaEnConfiguracion() async {
    try {
      _configNegocio['lista_mesas'] = _listaMesas.join(',');
      _configNegocio['imagenes_productos_json'] = jsonEncode(_imagenesProductosCustom);
      _configNegocio['emojis_productos_json'] = jsonEncode(_emojisProductosCustom);
      await _dbService.guardarConfiguracionNegocio(_configNegocio);
    } catch (e) {
      debugPrint('Error al guardar configuración extendida: $e');
    }
  }

  Future<void> _agregarNuevaMesa() async {
    int maxNum = 0;
    for (final m in _listaMesas) {
      final n = int.tryParse(m.trim()) ?? 0;
      if (n > maxNum) maxNum = n;
    }
    final String nuevaMesa = (maxNum + 1).toString();
    setState(() {
      _listaMesas.add(nuevaMesa);
      _numeroMesa = nuevaMesa;
      _tipoPedido = 'Mesa';
    });
    await _guardarMesasYMultimediaEnConfiguracion();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
        content: Text('➕ Mesa $nuevaMesa agregada (Total: ${_listaMesas.length} mesas).'),
      ),
    );
  }

  Future<void> _eliminarMesaActual() async {
    if (_listaMesas.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orangeAccent,
          duration: Duration(seconds: 2),
          content: Text('⚠️ Debe quedar al menos 1 mesa disponible.'),
        ),
      );
      return;
    }

    final String mesaBorrada = _numeroMesa;
    setState(() {
      _listaMesas.remove(_numeroMesa);
      if (_listaMesas.isEmpty) {
        _listaMesas.add('1');
      }
      _numeroMesa = _listaMesas.last;
    });
    await _guardarMesasYMultimediaEnConfiguracion();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 1),
        content: Text('➖ Mesa $mesaBorrada eliminada (Quedan: ${_listaMesas.length} mesas).'),
      ),
    );
  }

  void _inicializarEscuchaDePagosPorUdpYape() {
    try {
      YapeUdpReceptor.instance.iniciarEscucha(puerto: 45455);
      _yapeUdpSubscription?.cancel();
      _yapeUdpSubscription = YapeUdpReceptor.instance.flujoPagos.listen((dynamic evt) {
        if (!mounted) return;
        if (evt is EventoPagoYape) {
          // Si el modal de espera de cobro QR está abierto, ese modal procesa y cierra la venta automáticamente
          if (_modalEsperaYapeAbierto) return;
          _mostrarAlertaPagoQrDetectado(evt.monto, evt.pagador, esViaUdpYape: true);
        }
      });
    } catch (e) {
      debugPrint('Error al inicializar escucha UDP Yape: $e');
    }
  }

  void _inicializarEscuchaDePagosPorCorreo() {
    try {
      _emailListenerService?.detenerMonitoreo();

      final host = (_configNegocio['imap_host'] ?? 'imap.gmail.com').trim();
      final port = int.tryParse((_configNegocio['imap_port'] ?? '993').trim()) ?? 993;
      final email = (_configNegocio['imap_email'] ?? '').trim();
      final password = (_configNegocio['imap_password'] ?? '').trim();

      if (email.isNotEmpty && password.isNotEmpty) {
        final config = EmailConfig(
          host: host.isEmpty ? 'imap.gmail.com' : host,
          port: port,
          email: email,
          password: password,
          useSsl: true,
        );

        _emailListenerService = EmailListenerService(
          onPagoDetectado: (monto, cliente, fecha) {
            if (!mounted) return;
            _mostrarAlertaPagoQrDetectado(monto, cliente);
          },
        );
        _emailListenerService?.iniciarMonitoreo(config);
      }
    } catch (e) {
      debugPrint('Error al inicializar escucha de correo: $e');
    }
  }

  void _mostrarAlertaPagoQrDetectado(double monto, String cliente, {bool esViaUdpYape = false}) {
    if (!mounted || _alertaQrAbierta || _modalEsperaYapeAbierto) return;
    _alertaQrAbierta = true;

    final String textoMonto = monto > 0
        ? 'Bs. ${monto.toStringAsFixed(2)}'
        : 'Pago QR recibido (Verificar importe)';

    final bool coincideConCarrito = carrito.isNotEmpty && (monto - totalCarrito).abs() < 0.015;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0E1626),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFFFAB00), width: 1.5),
        ),
        title: Row(
          children: [
            const Text('🔔 ', style: TextStyle(fontSize: 20)),
            Expanded(
              child: Text(
                esViaUdpYape
                    ? '¡Pago Yape QR Recibido en Tiempo Real (UDP)!'
                    : '¡Pago QR Confirmado por Correo!',
                style: const TextStyle(
                  color: Color(0xFFFFAB00),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Container(
          width: 380,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF131C31),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                esViaUdpYape
                    ? 'ASyape detectó un nuevo abono instantáneo por Wi-Fi:'
                    : 'Se ha detectado un nuevo ingreso bancario en tu bandeja:',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('💰 Monto: ', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  Expanded(
                    child: Text(
                      textoMonto,
                      style: const TextStyle(
                        color: Color(0xFF00E5FF),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('👤 Origen: ', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  Expanded(
                    child: Text(
                      cliente,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _alertaQrAbierta = false;
              Navigator.of(dialogContext, rootNavigator: true).pop();
            },
            child: const Text(
              'Cerrar',
              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFAB00),
              foregroundColor: Colors.black,
            ),
            icon: const Icon(Icons.qr_code_scanner, size: 18),
            label: Text(
              coincideConCarrito ? 'Cobrar e Imprimir Recibo Ahora' : 'Aplicar al Carrito (QR)',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              _alertaQrAbierta = false;
              Navigator.of(dialogContext, rootNavigator: true).pop();
              if (!mounted) return;
              setState(() {
                _metodoPagoSeleccionado = 'QR';
                if (cliente.isNotEmpty &&
                    !cliente.startsWith('Cliente vía QR') &&
                    !cliente.startsWith('Cliente Yape QR')) {
                  _ctrlClienteNombre.text = cliente;
                }
              });
              if (coincideConCarrito) {
                _ejecutarRegistroYReciboVenta();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.green,
                    content: Text(
                      '✅ Pago QR ($textoMonto) aplicado a la orden actual.',
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
    ).then((_) {
      _alertaQrAbierta = false;
    });
  }

  Future<void> _inicializarSistemaPOS() async {
    try {
      final rawConf = await _dbService.obtenerConfiguracionNegocio();
      final Map<String, String> conf = {
        'nombre_negocio': 'AScafe',
        'direccion_negocio': 'Riberalta, Beni - Bolivia',
        'celular_negocio': '+591 70000000',
        'logo_path': '',
        'imap_host': 'imap.gmail.com',
        'imap_port': '993',
        'imap_email': '',
        'imap_password': '',
        'lista_mesas': '1,2,3,4,5,6,7,8,9,10',
        'imagenes_productos_json': '{}',
        'emojis_productos_json': '{}',
      };
      if (rawConf is Map) {
        rawConf.forEach((key, value) {
          final valStr = value?.toString() ?? '';
          if (valStr.isNotEmpty || !conf.containsKey(key.toString())) {
            conf[key.toString()] = valStr;
          }
        });
      }

      final String rawMesas = conf['lista_mesas'] ?? '1,2,3,4,5,6,7,8,9,10';
      final List<String> mesasCargadas = rawMesas
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (mesasCargadas.isEmpty) {
        mesasCargadas.addAll(['1', '2', '3', '4', '5']);
      }

      try {
        final rawImgJson = conf['imagenes_productos_json'] ?? '{}';
        final decodedImg = jsonDecode(rawImgJson);
        if (decodedImg is Map) {
          _imagenesProductosCustom.clear();
          decodedImg.forEach((k, v) {
            final pathStr = v?.toString().trim() ?? '';
            if (pathStr.isNotEmpty) {
              _imagenesProductosCustom[k.toString()] = pathStr;
            }
          });
        }
      } catch (_) {}

      try {
        final rawEmJson = conf['emojis_productos_json'] ?? '{}';
        final decodedEm = jsonDecode(rawEmJson);
        if (decodedEm is Map) {
          _emojisProductosCustom.clear();
          decodedEm.forEach((k, v) {
            final emStr = v?.toString().trim() ?? '';
            if (emStr.isNotEmpty) {
              _emojisProductosCustom[k.toString()] = emStr;
            }
          });
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _configNegocio = conf;
          _listaMesas = mesasCargadas;
          if (!_listaMesas.contains(_numeroMesa)) {
            _numeroMesa = _listaMesas.first;
          }
        });
      }
      globalLogoNotifier.value = conf['logo_path']?.toString() ?? '';
      await _verificarEstadoCajaSQLite();
      await _cargarDatosDesdeSQLite();
      await _calcularResumenVentasTurno();
      _inicializarEscuchaDePagosPorCorreo();
      _inicializarEscuchaDePagosPorUdpYape();
    } catch (e) {
      debugPrint('Error al inicializar sistema POS: $e');
    }
  }

  String _obtenerEmojiCategoria(String categoria) {
    final catLower = categoria.trim().toLowerCase();
    if (catLower == 'todos') return '⭐';
    if (catLower.contains('salteña') || catLower.contains('saltena')) return '🥟';
    if (catLower.contains('alimento') || catLower.contains('comida')) return '🍽️';
    if (catLower.contains('bebida') || catLower.contains('refresco') || catLower.contains('jugo')) return '🥤';
    if (catLower.contains('postre') || catLower.contains('dulce') || catLower.contains('torta')) return '🍰';
    if (catLower.contains('café') || catLower.contains('cafe') || catLower.contains('caliente')) return '☕';
    if (catLower.contains('masita') || catLower.contains('pan') || catLower.contains('horneado')) return '🥐';
    if (catLower.contains('snack') || catLower.contains('aperitivo') || catLower.contains('pipoca')) return '🍿';
    if (catLower.contains('lácteo') || catLower.contains('lacteo') || catLower.contains('leche')) return '🥛';
    if (catLower.contains('helado') || catLower.contains('frío') || catLower.contains('frio')) return '🍦';
    if (catLower.contains('combo') || catLower.contains('promo') || catLower.contains('especial')) return '🔥';
    if (catLower.contains('general')) return '📦';
    return '🏷️';
  }

  String _obtenerEmojiProducto(ItemCatalogo prod) {
    if (prod.emojiPersonalizado != null && prod.emojiPersonalizado!.isNotEmpty) {
      return prod.emojiPersonalizado!;
    }
    if (_emojisProductosCustom.containsKey(prod.id.toString())) {
      return _emojisProductosCustom[prod.id.toString()]!;
    }
    final nombreLower = prod.nombre.trim().toLowerCase();
    final catLower = prod.categoria.trim().toLowerCase();

    if (nombreLower.contains('picante')) return '🌶️';
    if (nombreLower.contains('pollo')) return '🍗';
    if (nombreLower.contains('carne') || nombreLower.contains('res') || nombreLower.contains('charque')) return '🥩';
    if (nombreLower.contains('dulce') || nombreLower.contains('hoja')) return '🍯';
    if (nombreLower.contains('queso') || nombreLower.contains('pizza') || nombreLower.contains('cunape') || nombreLower.contains('cuñapé')) return '🧀';
    if (nombreLower.contains('jamón') || nombreLower.contains('jamon') || nombreLower.contains('tocino')) return '🥓';
    if (nombreLower.contains('huevo')) return '🥚';
    if (nombreLower.contains('mocochinchi') || nombreLower.contains('durazno')) return '🍑';
    if (nombreLower.contains('soya') || nombreLower.contains('linaza') || nombreLower.contains('somó') || nombreLower.contains('somo')) return '🌾';
    if (nombreLower.contains('api')) return '🟣';
    if (nombreLower.contains('pastel')) return '🥮';
    if (nombreLower.contains('café') || nombreLower.contains('cafe') || nombreLower.contains('capuchino') || nombreLower.contains('tinto')) return '☕';
    if (nombreLower.contains('té') || nombreLower.contains('te ') || nombreLower.contains('mate')) return '🍵';
    if (nombreLower.contains('coca') || nombreLower.contains('soda') || nombreLower.contains('gaseosa') || nombreLower.contains('refresco')) return '🥤';
    if (nombreLower.contains('agua')) return '💧';
    if (nombreLower.contains('jugo') || nombreLower.contains('zumo') || nombreLower.contains('naranja')) return '🧃';
    if (nombreLower.contains('torta') || nombreLower.contains('queque') || nombreLower.contains('pastelito')) return '🍰';
    if (nombreLower.contains('helado') || nombreLower.contains('bolo')) return '🍦';
    if (nombreLower.contains('empanada') || nombreLower.contains('salteña') || nombreLower.contains('saltena')) return '🥟';
    if (nombreLower.contains('sandwich') || nombreLower.contains('sándwich')) return '🥪';
    if (nombreLower.contains('hamburguesa')) return '🍔';

    if (catLower.contains('bebida') || catLower.contains('refresco')) return '🥤';
    if (catLower.contains('postre')) return '🍰';
    if (catLower.contains('café') || catLower.contains('cafe')) return '☕';
    return '🥟';
  }

  String? _obtenerRutaImagenProducto(ItemCatalogo prod) {
    final String? ruta = (prod.imagenPath != null && prod.imagenPath!.isNotEmpty)
        ? prod.imagenPath
        : _imagenesProductosCustom[prod.id.toString()];
    if (ruta != null && ruta.isNotEmpty && File(ruta).existsSync()) {
      return ruta;
    }
    return null;
  }

  Widget _construirIlustracionMiniaturaCarrito(ItemCatalogo prod) {
    final String? rutaFoto = _obtenerRutaImagenProducto(prod);
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFAB00).withOpacity(0.75), width: 1.2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.5),
        child: rutaFoto != null
            ? Image.file(
                File(rutaFoto),
                width: 38,
                height: 38,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                  child: Text(_obtenerEmojiProducto(prod), style: const TextStyle(fontSize: 20)),
                ),
              )
            : Center(
                child: Text(_obtenerEmojiProducto(prod), style: const TextStyle(fontSize: 20)),
              ),
      ),
    );
  }

  Widget _construirIlustracionCentralProminente(ItemCatalogo prod) {
    final String? rutaFoto = _obtenerRutaImagenProducto(prod);
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFFFAB00).withOpacity(0.85),
          width: 1.6,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.5),
        child: rutaFoto != null
            ? Image.file(
                File(rutaFoto),
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                  child: Text(
                    _obtenerEmojiProducto(prod),
                    style: const TextStyle(fontSize: 52),
                  ),
                ),
              )
            : Center(
                child: Text(
                  _obtenerEmojiProducto(prod),
                  style: const TextStyle(fontSize: 52),
                ),
              ),
      ),
    );
  }

  void _mostrarDialogoConfiguracionNegocio() {
    if (!_esAdminActivo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('🔒 Permiso denegado: Solo el Administrador puede modificar los datos y el logo del establecimiento.'),
        ),
      );
      return;
    }

    final ctrlNombre = TextEditingController(text: _configNegocio['nombre_negocio'] ?? 'Establecimiento');
    final ctrlDireccion = TextEditingController(text: _configNegocio['direccion_negocio'] ?? 'Dirección');
    final ctrlCelular = TextEditingController(text: _configNegocio['celular_negocio'] ?? '+591 70000000');
    final ctrlLogoPath = TextEditingController(text: _configNegocio['logo_path'] ?? '');

    final ctrlImapHost = TextEditingController(
      text: (_configNegocio['imap_host']?.isNotEmpty == true) ? _configNegocio['imap_host']! : 'imap.gmail.com',
    );
    final ctrlImapPort = TextEditingController(
      text: (_configNegocio['imap_port']?.isNotEmpty == true) ? _configNegocio['imap_port']! : '993',
    );
    final ctrlImapEmail = TextEditingController(text: _configNegocio['imap_email'] ?? '');
    final ctrlImapPassword = TextEditingController(text: _configNegocio['imap_password'] ?? '');
    bool ocultarPass = true;
    bool probandoImap = false;
    String? mensajeResultadoImap;
    bool exitoResultadoImap = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (sbContext, setStateDialog) {
            Future<void> seleccionarLogoGrafico() async {
              try {
                FilePickerResult? result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
                  allowMultiple: false,
                );

                if (result != null && result.files.single.path != null) {
                  setStateDialog(() {
                    ctrlLogoPath.text = result.files.single.path!;
                  });
                }
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(backgroundColor: Colors.red, content: Text('Error al seleccionar imagen: $e')),
                );
              }
            }

            Future<void> ejecutarPruebaImap() async {
              final host = ctrlImapHost.text.trim().isEmpty ? 'imap.gmail.com' : ctrlImapHost.text.trim();
              final port = int.tryParse(ctrlImapPort.text.trim()) ?? 993;
              final email = ctrlImapEmail.text.trim();
              final password = ctrlImapPassword.text.trim();

              if (email.isEmpty || password.isEmpty) {
                setStateDialog(() {
                  exitoResultadoImap = false;
                  mensajeResultadoImap = '⚠️ Ingresa tu correo electrónico y la contraseña de aplicación antes de probar.';
                });
                return;
              }

              setStateDialog(() {
                probandoImap = true;
                mensajeResultadoImap = null;
              });

              final res = await EmailListenerService.probarConexion(
                EmailConfig(
                  host: host,
                  port: port,
                  email: email,
                  password: password,
                  useSsl: true,
                ),
              );

              setStateDialog(() {
                probandoImap = false;
                exitoResultadoImap = res['exito'] == true;
                mensajeResultadoImap = res['mensaje']?.toString() ?? '';
              });
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF0E1626),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFFFFAB00), width: 1.5),
              ),
              title: const Row(
                children: [
                  Text('⚙️ ', style: TextStyle(fontSize: 22)),
                  Expanded(
                    child: Text(
                      'Configuración del Establecimiento y Pagos QR',
                      style: TextStyle(color: Color(0xFFFFAB00), fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Previsualización del Logo:',
                        style: TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: const Color(0xFF131C31),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFAB00), width: 2),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: ctrlLogoPath.text.isNotEmpty && File(ctrlLogoPath.text).existsSync()
                              ? Image.file(
                                  File(ctrlLogoPath.text),
                                  fit: BoxFit.cover,
                                  width: 70,
                                  height: 70,
                                )
                              : const Icon(Icons.store, size: 40, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 320,
                              child: TextField(
                                controller: ctrlLogoPath,
                                readOnly: true,
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                decoration: InputDecoration(
                                  labelText: 'Archivo de Logo Seleccionado',
                                  labelStyle: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11),
                                  filled: true,
                                  fillColor: const Color(0xFF131C31),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFAB00),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              ),
                              onPressed: seleccionarLogoGrafico,
                              icon: const Icon(Icons.folder_open, size: 16),
                              label: const Text('Examinar...', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: ctrlNombre,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Nombre Comercial / Negocio',
                          labelStyle: const TextStyle(color: Color(0xFF00E5FF)),
                          filled: true,
                          fillColor: const Color(0xFF131C31),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: ctrlDireccion,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Dirección',
                          labelStyle: const TextStyle(color: Color(0xFF00E5FF)),
                          filled: true,
                          fillColor: const Color(0xFF131C31),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: ctrlCelular,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Celular de Contacto',
                          labelStyle: const TextStyle(color: Color(0xFF00E5FF)),
                          filled: true,
                          fillColor: const Color(0xFF131C31),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Divider(color: Colors.white24),
                      const SizedBox(height: 6),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '📧 Correo Receptor para Alertas de Pagos QR (IMAP):',
                          style: TextStyle(color: Color(0xFFFFAB00), fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: ctrlImapHost,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: InputDecoration(
                                labelText: 'Servidor IMAP (Ej: imap.gmail.com)',
                                labelStyle: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11),
                                filled: true,
                                fillColor: const Color(0xFF131C31),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: TextField(
                              controller: ctrlImapPort,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: InputDecoration(
                                labelText: 'Puerto',
                                labelStyle: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11),
                                filled: true,
                                fillColor: const Color(0xFF131C31),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: ctrlImapEmail,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF00E5FF), size: 18),
                          labelText: 'Correo Electrónico de Notificaciones Bancarias',
                          labelStyle: const TextStyle(color: Color(0xFF00E5FF), fontSize: 12),
                          filled: true,
                          fillColor: const Color(0xFF131C31),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: ctrlImapPassword,
                        obscureText: ocultarPass,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.key, color: Color(0xFFFFAB00), size: 18),
                          suffixIcon: IconButton(
                            icon: Icon(
                              ocultarPass ? Icons.visibility_off : Icons.visibility,
                              color: Colors.white54,
                              size: 18,
                            ),
                            onPressed: () {
                              setStateDialog(() {
                                ocultarPass = !ocultarPass;
                              });
                            },
                          ),
                          labelText: 'Contraseña de Aplicación (App Password)',
                          labelStyle: const TextStyle(color: Color(0xFF00E5FF), fontSize: 12),
                          filled: true,
                          fillColor: const Color(0xFF131C31),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF00E5FF),
                            side: const BorderSide(color: Color(0xFF00E5FF), width: 1.4),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: probandoImap ? null : ejecutarPruebaImap,
                          icon: probandoImap
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF00E5FF),
                                  ),
                                )
                              : const Icon(Icons.wifi_tethering, size: 18),
                          label: Text(
                            probandoImap ? 'Probando conexión con el servidor IMAP...' : 'Probar Conexión IMAP',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                      if (mensajeResultadoImap != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: exitoResultadoImap
                                ? Colors.green.withOpacity(0.15)
                                : Colors.red.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: exitoResultadoImap ? Colors.greenAccent : Colors.redAccent,
                            ),
                          ),
                          child: Text(
                            mensajeResultadoImap!,
                            style: TextStyle(
                              color: exitoResultadoImap ? Colors.greenAccent : Colors.redAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                  icon: const Icon(Icons.restore, size: 16),
                  label: const Text('Volver a Fábrica'),
                  onPressed: () async {
                    final navigator = Navigator.of(dialogContext);
                    final scaffoldMessenger = ScaffoldMessenger.of(context);

                    await _dbService.restaurarValoresDeFabrica();

                    globalLogoNotifier.value = '';
                    navigator.pop();
                    await _inicializarSistemaPOS();

                    if (!mounted) return;
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        backgroundColor: Colors.orangeAccent,
                        content: Text('🔄 Sistema restaurado a fábrica.'),
                      ),
                    );
                  },
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFAB00),
                    foregroundColor: Colors.black,
                  ),
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text('Guardar Configuración', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    final navigator = Navigator.of(dialogContext);
                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    final nuevoLogo = ctrlLogoPath.text.trim();

                    await _dbService.guardarConfiguracionNegocio({
                      'nombre_negocio': ctrlNombre.text.trim(),
                      'direccion_negocio': ctrlDireccion.text.trim(),
                      'celular_negocio': ctrlCelular.text.trim(),
                      'logo_path': nuevoLogo,
                      'imap_host': ctrlImapHost.text.trim().isEmpty ? 'imap.gmail.com' : ctrlImapHost.text.trim(),
                      'imap_port': ctrlImapPort.text.trim().isEmpty ? '993' : ctrlImapPort.text.trim(),
                      'imap_email': ctrlImapEmail.text.trim(),
                      'imap_password': ctrlImapPassword.text.trim(),
                      'lista_mesas': _listaMesas.join(','),
                      'imagenes_productos_json': jsonEncode(_imagenesProductosCustom),
                      'emojis_productos_json': jsonEncode(_emojisProductosCustom),
                    });

                    globalLogoNotifier.value = nuevoLogo;
                    navigator.pop();
                    await _inicializarSistemaPOS();

                    if (!mounted) return;
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        backgroundColor: Colors.green,
                        content: Text('✨ Configuración, logo y correo QR actualizados exitosamente.'),
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

  String _limpiarTextoPdf(String input) {
    return input
        .replaceAll('(', '[')
        .replaceAll(')', ']')
        .replaceAll('\\', '/');
  }

  String _extraerTelefonoSinPais(String rawPhone) {
    String limpio = rawPhone.trim();
    limpio = limpio.replaceFirst(RegExp(r'^\+?591[\s\-]*'), '').trim();
    limpio = limpio.replaceAll(RegExp(r'\s+'), '');
    return limpio;
  }

  String _centrarLineaRecibo(String texto, [int ancho = _anchoColsEstandarPdf]) {
    final limpio = texto.trim();
    if (limpio.length >= ancho) return limpio;
    final espaciosIzq = ((ancho - limpio.length) / 2).floor();
    return (' ' * espaciosIzq) + limpio;
  }

  String _formatearTituloNegocioConTelefono({String? nombreCustom, String? celularCustom}) {
    final String nombreNeg = _limpiarTextoPdf(
      (nombreCustom?.isNotEmpty == true ? nombreCustom! : (_configNegocio['nombre_negocio'] ?? 'AScafe')),
    ).toUpperCase().trim();
    final String telSinPais = _limpiarTextoPdf(
      _extraerTelefonoSinPais(celularCustom?.isNotEmpty == true ? celularCustom! : (_configNegocio['celular_negocio'] ?? '')),
    );

    if (telSinPais.isEmpty) return nombreNeg;

    final String opcionCompleta = '$nombreNeg - Tel: $telSinPais';
    if (opcionCompleta.length <= _anchoColsEstandarPdf) {
      return opcionCompleta;
    }
    return '$nombreNeg - $telSinPais';
  }

  String _formatearModalidadTicket(Map<String, dynamic> ticket) {
    final String tipo = (ticket['tipo_pedido']?.toString() ?? 'Para Llevar').trim();
    final String mesa = (ticket['mesa']?.toString() ?? '1').trim();
    if (tipo.toLowerCase() == 'mesa') {
      return 'Mesa $mesa';
    }
    return tipo;
  }

  List<String> _construirLineasCompactasRecibo(Map<String, dynamic> ticket) {
    final List items = ticket['items'] as List;
    final String lineaTitulo = _formatearTituloNegocioConTelefono();
    final String dirNeg = _limpiarTextoPdf(_configNegocio['direccion_negocio'] ?? '');

    final String modalidadTexto = _limpiarTextoPdf(_formatearModalidadTicket(ticket));
    final String cajeroTexto = _limpiarTextoPdf(ticket['cajero']?.toString() ?? '');
    final String metodoPagoTexto = _limpiarTextoPdf(ticket['metodo_pago']?.toString() ?? '');

    final List<String> lineas = [];

    lineas.add(_centrarLineaRecibo(lineaTitulo, _anchoColsEstandarPdf));
    if (dirNeg.isNotEmpty) {
      lineas.add(_centrarLineaRecibo(dirNeg, _anchoColsEstandarPdf));
    }
    lineas.add(_separadorEstandarPdf);
    lineas.add('Recibo #${ticket['venta_id']} | ${ticket['fecha']}');
    lineas.add('Cajera: $cajeroTexto');
    lineas.add('Forma de Pago: $metodoPagoTexto');
    lineas.add('Pedido: $modalidadTexto');
    lineas.add(_separadorEstandarPdf);

    for (final it in items) {
      final m = it as Map;
      final cant = '${m['cantidad']}x'.padRight(4);
      final nom = _limpiarTextoPdf(m['nombre']?.toString() ?? '');
      final nomAjustado = nom.length > 20 ? nom.substring(0, 20) : nom.padRight(20);
      final sub = 'Bs.${(m['subtotal'] as num).toStringAsFixed(2)}'.padLeft(10);
      lineas.add('$cant $nomAjustado $sub');
    }

    lineas.add(_separadorEstandarPdf);
    final totalStr = 'Bs.${(ticket['total'] as num).toStringAsFixed(2)}'.padLeft(22);
    lineas.add('TOTAL PAGADO: $totalStr');

    return lineas;
  }

  List<int> _generarBytesPdfEstandarCompacto(List<String> lineas) {
    final int altoPagina = 32 + (lineas.length * 10);
    final StringBuffer contenidoStream = StringBuffer();
    contenidoStream.writeln('BT');
    contenidoStream.writeln('/F1 7.7 Tf');
    int yPos = altoPagina - 13;
    for (final l in lineas) {
      contenidoStream.writeln('8 $yPos Td');
      contenidoStream.writeln('($l) Tj');
      contenidoStream.writeln('-8 -$yPos Td');
      yPos -= 9;
    }
    contenidoStream.writeln('ET');

    final String streamStr = contenidoStream.toString();
    final List<int> streamBytes = latin1.encode(streamStr);

    final List<String> objetos = [
      '1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n',
      '2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n',
      '3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 226 $altoPagina] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>\nendobj\n',
      '4 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Courier /Encoding /WinAnsiEncoding >>\nendobj\n',
      '5 0 obj\n<< /Length ${streamBytes.length} >>\nstream\n$streamStr\nendstream\nendobj\n',
    ];

    final StringBuffer pdfBuffer = StringBuffer();
    pdfBuffer.write('%PDF-1.4\n');
    final List<int> offsets = [];
    for (final obj in objetos) {
      offsets.add(latin1.encode(pdfBuffer.toString()).length);
      pdfBuffer.write(obj);
    }
    final int xrefStart = latin1.encode(pdfBuffer.toString()).length;
    pdfBuffer.write('xref\n0 ${objetos.length + 1}\n');
    pdfBuffer.write('0000000000 65535 f \n');
    for (final off in offsets) {
      pdfBuffer.write('${off.toString().padLeft(10, '0')} 00000 n \n');
    }
    pdfBuffer.write('trailer\n<< /Size ${objetos.length + 1} /Root 1 0 R >>\n');
    pdfBuffer.write('startxref\n$xrefStart\n%%EOF');

    return latin1.encode(pdfBuffer.toString());
  }

  List<int> _construirBytesPdfRecibo(Map<String, dynamic> ticket) {
    final List<String> lineas = _construirLineasCompactasRecibo(ticket);
    return _generarBytesPdfEstandarCompacto(lineas);
  }

  Future<void> _generarEImprimirReciboPdf(Map<String, dynamic> ticket) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytesPdf = _construirBytesPdfRecibo(ticket);
      final dirTemp = Directory.systemTemp;
      final rutaPdf = p.join(dirTemp.path, 'recibo_venta_${ticket['venta_id']}.pdf');
      final archivoPdf = File(rutaPdf);
      await archivoPdf.writeAsBytes(bytesPdf, flush: true);

      final rutaTxt = p.join(dirTemp.path, 'recibo_termico_${ticket['venta_id']}.txt');
      final lineasCompactas = _construirLineasCompactasRecibo(ticket);
      await File(rutaTxt).writeAsString(
        '${lineasCompactas.join('\r\n')}\r\n',
        encoding: latin1,
        flush: true,
      );

      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', rutaPdf]);
        await Process.run('notepad.exe', ['/p', rutaTxt]);
      }

      messenger.showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text('🖨️ Recibo compacto generado e impreso: $rutaPdf'),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Error al generar/imprimir PDF: $e'),
        ),
      );
    }
  }

  Future<void> _generarInformeCajeroPdf() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final db = await _dbService.database;
      final List ventasCajero = await db.query(
        'ventas',
        where: 'caja_id = ? AND cajero_nombre = ?',
        whereArgs: [_cajaIdActual, _nombreCajeroActivo],
      );

      final String lineaTitulo = _formatearTituloNegocioConTelefono();
      final String dirNeg = _limpiarTextoPdf(_configNegocio['direccion_negocio'] ?? '');

      final List<String> lineas = [];
      lineas.add(_centrarLineaRecibo(lineaTitulo, _anchoColsEstandarPdf));
      if (dirNeg.isNotEmpty) {
        lineas.add(_centrarLineaRecibo(dirNeg, _anchoColsEstandarPdf));
      }
      lineas.add(_centrarLineaRecibo('INFORME INDIVIDUAL DE CAJERO', _anchoColsEstandarPdf));
      lineas.add(_separadorEstandarPdf);
      lineas.add('Turno #$_cajaIdActual | $_fechaActual $_horaActual');
      lineas.add('Cajera: ${_limpiarTextoPdf(_nombreCajeroActivo)}');
      lineas.add('Caja: ${_limpiarTextoPdf(_nombreCajaActiva)}');
      lineas.add('Ventas Registradas: ${ventasCajero.length}');
      lineas.add(_separadorEstandarPdf);

      double totalCajero = 0.0;
      double efectivoCajero = 0.0;
      double qrCajero = 0.0;

      for (final v in ventasCajero) {
        final m = v as Map;
        final t = (m['total'] as num?)?.toDouble() ?? 0.0;
        final met = m['metodo_pago']?.toString() ?? 'Efectivo';
        totalCajero += t;
        if (met.toUpperCase().contains('QR')) {
          qrCajero += t;
        } else {
          efectivoCajero += t;
        }
      }

      lineas.add('Forma de Pago Efectivo: Bs. ${efectivoCajero.toStringAsFixed(2)}');
      lineas.add('Forma de Pago QR:       Bs. ${qrCajero.toStringAsFixed(2)}');
      lineas.add('Fondo Base Inicial:     Bs. ${_montoInicialCaja.toStringAsFixed(2)}');
      lineas.add(_separadorEstandarPdf);
      lineas.add('TOTAL RECAUDADO:        Bs. ${totalCajero.toStringAsFixed(2)}');
      lineas.add('EFECTIVO EN GAVETA:     Bs. ${(_montoInicialCaja + efectivoCajero).toStringAsFixed(2)}');
      lineas.add(_separadorEstandarPdf);
      lineas.add('Firma: _____________________________');

      final bytesPdf = _generarBytesPdfEstandarCompacto(lineas);

      final dirTemp = Directory.systemTemp;
      final rutaPdf = p.join(dirTemp.path, 'informe_cajero_${_nombreCajeroActivo}_$_cajaIdActual.pdf');
      await File(rutaPdf).writeAsBytes(bytesPdf, flush: true);

      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', rutaPdf]);
      }

      messenger.showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text('📄 Informe individual en PDF generado: $rutaPdf'),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(backgroundColor: Colors.redAccent, content: Text('Error al generar informe PDF: $e')),
      );
    }
  }

  Future<void> _generarInformeGeneralCajaPdf() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final db = await _dbService.database;

      final rawConf = await _dbService.obtenerConfiguracionNegocio();
      final Map<String, String> conf = {};
      if (rawConf is Map) {
        rawConf.forEach((key, value) {
          conf[key.toString()] = value?.toString() ?? '';
        });
      }

      final nombreNeg = conf['nombre_negocio']?.isNotEmpty == true
          ? conf['nombre_negocio']!
          : (_configNegocio['nombre_negocio'] ?? 'AScafe');
      final dirNeg = _limpiarTextoPdf(
        conf['direccion_negocio']?.isNotEmpty == true
            ? conf['direccion_negocio']!
            : (_configNegocio['direccion_negocio'] ?? 'Riberalta, Beni - Bolivia'),
      );
      final celNeg = conf['celular_negocio']?.isNotEmpty == true
          ? conf['celular_negocio']!
          : (_configNegocio['celular_negocio'] ?? '+591 70000000');

      final String lineaTitulo = _formatearTituloNegocioConTelefono(
        nombreCustom: nombreNeg,
        celularCustom: celNeg,
      );

      final List todasLasVentas = await db.query('ventas');
      final List sesionesCaja = await db.query('caja_sesiones', orderBy: 'id DESC', limit: 5);

      final List<String> lineas = [];
      lineas.add(_centrarLineaRecibo(lineaTitulo, _anchoColsEstandarPdf));
      if (dirNeg.isNotEmpty) {
        lineas.add(_centrarLineaRecibo(dirNeg, _anchoColsEstandarPdf));
      }
      lineas.add(_centrarLineaRecibo('INFORME GENERAL DE CAJA Y VENTAS', _anchoColsEstandarPdf));
      lineas.add(_separadorEstandarPdf);
      lineas.add('Fecha: $_fechaActual $_horaActual');
      lineas.add('Transacciones: ${todasLasVentas.length} ventas');
      lineas.add(_separadorEstandarPdf);

      double totalGeneral = 0.0;
      double efectivoGeneral = 0.0;
      double qrGeneral = 0.0;

      final Map<String, Map<String, dynamic>> resumenPorCajero = {};

      for (final v in todasLasVentas) {
        final m = v as Map;
        final t = (m['total'] as num?)?.toDouble() ?? 0.0;
        final met = m['metodo_pago']?.toString() ?? 'Efectivo';
        final cajero = m['cajero_nombre']?.toString() ?? 'Administrador';

        totalGeneral += t;
        if (met.toUpperCase().contains('QR')) {
          qrGeneral += t;
        } else {
          efectivoGeneral += t;
        }

        if (!resumenPorCajero.containsKey(cajero)) {
          resumenPorCajero[cajero] = {
            'ventas': 0,
            'total': 0.0,
            'efectivo': 0.0,
            'qr': 0.0,
          };
        }
        resumenPorCajero[cajero]!['ventas'] += 1;
        resumenPorCajero[cajero]!['total'] += t;
        if (met.toUpperCase().contains('QR')) {
          resumenPorCajero[cajero]!['qr'] += t;
        } else {
          resumenPorCajero[cajero]!['efectivo'] += t;
        }
      }

      lineas.add('Forma de Pago Efectivo: Bs. ${efectivoGeneral.toStringAsFixed(2)}');
      lineas.add('Forma de Pago QR:       Bs. ${qrGeneral.toStringAsFixed(2)}');
      lineas.add('TOTAL ACUMULADO:        Bs. ${totalGeneral.toStringAsFixed(2)}');
      lineas.add(_separadorEstandarPdf);
      lineas.add('ULTIMOS TURNOS:');

      if (sesionesCaja.isEmpty) {
        lineas.add('Sin sesiones registradas.');
      } else {
        for (final s in sesionesCaja) {
          final sm = s as Map;
          final idS = sm['id'] ?? 0;
          final nomCajero = sm['cajero'] ?? sm['cajero_nombre'] ?? 'Administrador';
          final estado = sm['estado'] ?? 'Abierta';
          final base = (sm['monto_inicial'] as num?)?.toDouble() ?? 0.0;
          final finalArqueo = (sm['monto_final'] as num?)?.toDouble() ?? 0.0;

          lineas.add(
            '#$idS ${_limpiarTextoPdf(nomCajero.toString())} ($estado) B:${base.toStringAsFixed(0)} F:${finalArqueo.toStringAsFixed(0)}',
          );
        }
      }

      lineas.add(_separadorEstandarPdf);
      lineas.add('DETALLE POR CAJERA:');
      if (resumenPorCajero.isEmpty) {
        lineas.add('Sin ventas registradas.');
      } else {
        resumenPorCajero.forEach((cajero, datos) {
          lineas.add('Cajera: ${_limpiarTextoPdf(cajero)} (${datos['ventas']} vts)');
          lineas.add('Efectivo: Bs. ${(datos['efectivo'] as double).toStringAsFixed(2)}');
          lineas.add('Pago QR:  Bs. ${(datos['qr'] as double).toStringAsFixed(2)}');
          lineas.add('Total:    Bs. ${(datos['total'] as double).toStringAsFixed(2)}');
          lineas.add(_separadorEstandarPdf);
        });
      }

      final bytesPdf = _generarBytesPdfEstandarCompacto(lineas);

      final dirTemp = Directory.systemTemp;
      final rutaPdf = p.join(dirTemp.path, 'informe_general_caja_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await File(rutaPdf).writeAsBytes(bytesPdf, flush: true);

      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', rutaPdf]);
      }

      messenger.showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text('📄 Informe general generado correctamente: $rutaPdf'),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(backgroundColor: Colors.redAccent, content: Text('Error al generar informe general PDF: $e')),
      );
    }
  }

  Future<void> _verificarEstadoCajaSQLite() async {
    try {
      final db = await _dbService.database;
      final List sesionesAbiertas = await db.query(
        'caja_sesiones',
        where: "estado = 'Abierta' AND nombre_caja = ?",
        whereArgs: [_nombreCajaActiva],
        orderBy: 'id DESC',
        limit: 1,
      );

      final fechaHoyStr = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';

      final List sesionesAnteriores = await db.query(
        'caja_sesiones',
        where: "nombre_caja = ? AND fecha_apertura NOT LIKE ?",
        whereArgs: [_nombreCajaActiva, '$fechaHoyStr%'],
        orderBy: 'id DESC',
        limit: 1,
      );

      if (sesionesAnteriores.isNotEmpty) {
        final ultimaAnterior = sesionesAnteriores.first as Map;
        final idAnt = (ultimaAnterior['id'] as num).toInt();
        final List ventasAnt = await db.query('ventas', where: 'caja_id = ?', whereArgs: [idAnt]);
        double sumaRef = 0.0;
        for (final va in ventasAnt) {
          sumaRef += (va as Map)['total'] as num? ?? 0.0;
        }
        _recaudacionDiaAnteriorRef = sumaRef;
      }

      if (sesionesAbiertas.isNotEmpty) {
        final sesion = sesionesAbiertas.first as Map;
        final fechaAperturaSesion = sesion['fecha_apertura']?.toString() ?? '';

        bool esDeOtroDia = false;
        if (fechaAperturaSesion.isNotEmpty) {
          try {
            final dtApertura = DateTime.parse(fechaAperturaSesion);
            final ahora = DateTime.now();
            if (dtApertura.year != ahora.year || dtApertura.month != ahora.month || dtApertura.day != ahora.day) {
              esDeOtroDia = true;
            }
          } catch (_) {}
        }

        if (esDeOtroDia) {
          final idAntiguo = (sesion['id'] as num).toInt();
          await db.update(
            'caja_sesiones',
            {
              'fecha_cierre': DateTime.now().toIso8601String(),
              'estado': 'Cerrada',
            },
            where: 'id = ?',
            whereArgs: [idAntiguo],
          );
          await _abrirNuevoTurnoEnCero(db, fechaHoyStr);
        } else {
          if (mounted) {
            setState(() {
              _cajaIdActual = (sesion['id'] as num).toInt();
              _cajaAbierta = true;
              _montoInicialCaja = (sesion['monto_inicial'] as num?)?.toDouble() ?? 0.0;
              _fechaAperturaCaja = fechaAperturaSesion;
            });
          }
        }
      } else {
        await _abrirNuevoTurnoEnCero(db, DateTime.now().toIso8601String());
      }
    } catch (_) {}
  }

  Future<void> _abrirNuevoTurnoEnCero(dynamic db, String fechaIso) async {
    final int nuevoId = await db.insert('caja_sesiones', {
      'cajero_nombre': _nombreCajeroActivo,
      'nombre_caja': _nombreCajaActiva,
      'fecha_apertura': fechaIso,
      'monto_inicial': 0.0,
      'estado': 'Abierta',
    });
    if (mounted) {
      setState(() {
        _cajaIdActual = nuevoId;
        _cajaAbierta = true;
        _montoInicialCaja = 0.0;
        _totalVentasTurno = 0.0;
        _totalEfectivoTurno = 0.0;
        _totalQrTurno = 0.0;
        _fechaAperturaCaja = fechaIso;
      });
    }
  }

  Future<void> _calcularResumenVentasTurno() async {
    try {
      final db = await _dbService.database;
      final fechaHoyStr = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
      final List sesionesDelDia = await db.query(
        'caja_sesiones',
        where: "nombre_caja = ? AND fecha_apertura LIKE ?",
        whereArgs: [_nombreCajaActiva, '$fechaHoyStr%'],
      );

      final List<int> idsCajasDelDia = sesionesDelDia.map((s) => (s as Map)['id'] as int).toList();
      if (!idsCajasDelDia.contains(_cajaIdActual)) {
        idsCajasDelDia.add(_cajaIdActual);
      }

      double sumaTotal = 0.0;
      double sumaEfectivo = 0.0;
      double sumaQr = 0.0;

      for (final idCaja in idsCajasDelDia) {
        final List ventasRows = await db.query(
          'ventas',
          where: 'caja_id = ?',
          whereArgs: [idCaja],
        );

        for (final v in ventasRows) {
          final mapa = v as Map;
          final monto = (mapa['total'] as num?)?.toDouble() ?? 0.0;
          final metodo = mapa['metodo_pago']?.toString() ?? 'Efectivo';
          sumaTotal += monto;
          if (metodo.toUpperCase().contains('QR')) {
            sumaQr += monto;
          } else {
            sumaEfectivo += monto;
          }
        }
      }

      if (mounted) {
        setState(() {
          _totalVentasTurno = sumaTotal;
          _totalEfectivoTurno = sumaEfectivo;
          _totalQrTurno = sumaQr;
        });
      }
    } catch (_) {}
  }

  Future<void> _cargarDatosDesdeSQLite() async {
    if (!mounted) return;
    setState(() => cargandoProductos = true);

    try {
      final catsDB = await _dbService.obtenerCategorias();
      final filasProductos = await _dbService.obtenerProductos();

      final List<ItemCatalogo> tempProducts = [];
      for (final fila in filasProductos) {
        if (fila is Map) {
          final id = (fila['id'] as num?)?.toInt() ?? 0;
          final nombre = fila['nombre']?.toString() ?? 'Producto';
          final precio = (fila['precio'] as num?)?.toDouble() ?? 0.0;
          final cat = fila['categoria']?.toString() ?? 'General';
          final stock = (fila['stock'] as num?)?.toInt() ?? (fila['stock_actual'] as num?)?.toInt() ?? 0;

          tempProducts.add(
            ItemCatalogo(
              id,
              nombre,
              precio,
              categoria: cat,
              stock: stock,
              emojiPersonalizado: _emojisProductosCustom[id.toString()],
              imagenPath: _imagenesProductosCustom[id.toString()],
            ),
          );
        }
      }

      final List<String> tempCategorias = ['Todos'];
      for (final c in catsDB) {
        final catStr = c.toString().trim();
        if (catStr.isNotEmpty && !tempCategorias.contains(catStr)) {
          tempCategorias.add(catStr);
        }
      }

      for (final p in tempProducts) {
        final catStr = p.categoria.trim();
        if (catStr.isNotEmpty && !tempCategorias.contains(catStr)) {
          tempCategorias.add(catStr);
        }
      }

      if (mounted) {
        setState(() {
          products = tempProducts;
          categorias = tempCategorias;
          if (!categorias.contains(categoriaSeleccionada)) {
            categoriaSeleccionada = 'Todos';
          }
          cargandoProductos = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => cargandoProductos = false);
      }
    }
  }

  void _agregarAlCarrito(ItemCatalogo item) {
    if (!_cajaAbierta) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('⚠️ La caja está cerrada. Abra una sesión de caja para vender.'),
        ),
      );
      return;
    }

    if (item.stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('❌ "${item.nombre}" está agotado en inventario (Stock: 0).'),
        ),
      );
      return;
    }

    setState(() {
      final index = carrito.indexWhere((element) => element.producto.id == item.id);
      if (index >= 0) {
        if (carrito[index].cantidad < item.stock) {
          carrito[index].cantidad += 1;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.orangeAccent,
              content: Text('⚠️ Stock máximo disponible alcanzado para ${item.nombre} (${item.stock} unds).'),
            ),
          );
        }
      } else {
        carrito.add(
          ItemCarrito(
            producto: item,
            cantidad: 1,
            precioUnitario: item.precio,
          ),
        );
      }
    });
  }

  void _cambiarCantidadItem(int index, int delta) {
    setState(() {
      final item = carrito[index];
      final nuevaCantidad = item.cantidad + delta;
      if (nuevaCantidad <= 0) {
        carrito.removeAt(index);
      } else if (nuevaCantidad <= item.producto.stock) {
        item.cantidad = nuevaCantidad;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.orangeAccent,
            content: Text('⚠️ Solo quedan ${item.producto.stock} unidades de ${item.producto.nombre}.'),
          ),
        );
      }
    });
  }

  void _limpiarCarrito() {
    setState(() {
      carrito.clear();
      _ctrlDescuento.text = '0';
      _ctrlMontoRecibido.clear();
    });
  }

  double get subtotalCarrito {
    double suma = 0.0;
    for (final item in carrito) {
      suma += item.subtotal;
    }
    return suma;
  }

  double get descuentoAplicado {
    final d = double.tryParse(_ctrlDescuento.text.trim()) ?? 0.0;
    if (d < 0) return 0.0;
    if (d > subtotalCarrito) return subtotalCarrito;
    return d;
  }

  double get totalCarrito {
    final t = subtotalCarrito - descuentoAplicado;
    return t < 0 ? 0.0 : t;
  }

  double get montoRecibido {
    return double.tryParse(_ctrlMontoRecibido.text.trim()) ?? 0.0;
  }

  double get cambioVuelto {
    if (_metodoPagoSeleccionado != 'Efectivo') return 0.0;
    if (montoRecibido <= 0) return 0.0;
    final cambio = montoRecibido - totalCarrito;
    return cambio < 0 ? 0.0 : cambio;
  }

  int get totalUnidadesCarrito {
    int cant = 0;
    for (final item in carrito) {
      cant += item.cantidad;
    }
    return cant;
  }

  Future<void> _procesarPago() async {
    final messenger = ScaffoldMessenger.of(context);

    if (carrito.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('🛒 El carrito de ventas está vacío.'),
        ),
      );
      return;
    }

    if (_metodoPagoSeleccionado == 'Efectivo' &&
        _ctrlMontoRecibido.text.trim().isNotEmpty &&
        montoRecibido < totalCarrito) {
      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('⚠️ El monto recibido en efectivo es menor al total a pagar.'),
        ),
      );
      return;
    }

    // Si el método es QR, abrimos el modal de escucha en tiempo real por UDP (ASyape)
    if (_metodoPagoSeleccionado == 'QR') {
      await _abrirModalEsperaYapeQr();
      return;
    }

    await _ejecutarRegistroYReciboVenta();
  }

  Future<void> _abrirModalEsperaYapeQr() async {
    final double montoEsperado = totalCarrito;
    if (montoEsperado <= 0) return;

    _modalEsperaYapeAbierto = true;
    YapeUdpReceptor.instance.iniciarEscucha(puerto: 45455);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return DialogoCobroYapeRealtime(
          montoEsperado: montoEsperado,
          nombreNegocio: _configNegocio['nombre_negocio'] ?? 'AScafe',
          onPagoConfirmado: (EventoPagoYape pago) {
            _modalEsperaYapeAbierto = false;
            Navigator.of(dialogContext).pop();
            if (!mounted) return;
            setState(() {
              _metodoPagoSeleccionado = 'QR';
              if (pago.pagador.isNotEmpty &&
                  pago.pagador != 'Cliente Yape QR' &&
                  pago.pagador != 'Verificación Manual en Caja' &&
                  (_ctrlClienteNombre.text.trim().isEmpty ||
                      _ctrlClienteNombre.text.trim() == 'Cliente Casual')) {
                _ctrlClienteNombre.text = pago.pagador;
              }
            });
            _ejecutarRegistroYReciboVenta();
          },
          onCancelar: () {
            _modalEsperaYapeAbierto = false;
            Navigator.of(dialogContext).pop();
          },
        );
      },
    ).then((_) {
      _modalEsperaYapeAbierto = false;
    });
  }

  Future<void> _ejecutarRegistroYReciboVenta() async {
    final messenger = ScaffoldMessenger.of(context);
    if (carrito.isEmpty) return;

    try {
      final List detallesVenta = carrito.map((item) {
        return {
          'producto_id': item.producto.id,
          'nombre': item.producto.nombre,
          'cantidad': item.cantidad,
          'precio_unitario': item.precioUnitario,
          'subtotal': item.subtotal,
        };
      }).toList();

      final efectivoFinal = _metodoPagoSeleccionado == 'Efectivo'
          ? (montoRecibido > 0 ? montoRecibido : totalCarrito)
          : totalCarrito;

      final int ventaId = await _dbService.registrarVentaCompleta(
        cajaId: _cajaIdActual,
        total: totalCarrito,
        metodoPago: _metodoPagoSeleccionado,
        detalles: detallesVenta,
        cajeroNombre: _nombreCajeroActivo,
        nombreCaja: _nombreCajaActiva,
        clienteNombre: _ctrlClienteNombre.text.trim().isEmpty ? 'Cliente Casual' : _ctrlClienteNombre.text.trim(),
        nitCi: _ctrlNitCi.text.trim().isEmpty ? '0' : _ctrlNitCi.text.trim(),
        montoRecibido: efectivoFinal,
        cambio: cambioVuelto,
      );

      final db = await _dbService.database;
      for (final item in carrito) {
        final int nuevoStock = (item.producto.stock - item.cantidad) < 0
            ? 0
            : (item.producto.stock - item.cantidad);
        await db.update(
          'productos',
          {'stock_actual': nuevoStock},
          where: 'id = ?',
          whereArgs: [item.producto.id],
        );
      }

      final Map<String, dynamic> ticketData = {
        'venta_id': ventaId,
        'fecha': '$_fechaActual $_horaActual',
        'cajero': _nombreCajeroActivo,
        'nombre_caja': _nombreCajaActiva,
        'cliente': _ctrlClienteNombre.text.trim().isEmpty ? 'Cliente Casual' : _ctrlClienteNombre.text.trim(),
        'nit_ci': _ctrlNitCi.text.trim().isEmpty ? '0' : _ctrlNitCi.text.trim(),
        'tipo_pedido': _tipoPedido,
        'mesa': _numeroMesa,
        'metodo_pago': _metodoPagoSeleccionado,
        'subtotal': subtotalCarrito,
        'descuento': descuentoAplicado,
        'total': totalCarrito,
        'efectivo': efectivoFinal,
        'cambio': cambioVuelto,
        'items': detallesVenta,
      };

      if (mounted) {
        setState(() {
          _ultimoTicketGenerado = ticketData;
          carrito.clear();
          _ctrlDescuento.text = '0';
          _ctrlMontoRecibido.clear();
        });
      }

      await _cargarDatosDesdeSQLite();
      await _calcularResumenVentasTurno();

      await _generarEImprimirReciboPdf(ticketData);

      if (!mounted) return;
      _mostrarDialogoTicketVenta(ticketData);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Error al procesar la venta: $e'),
        ),
      );
    }
  }

  void _mostrarDialogoTicketVenta(Map<String, dynamic> ticket) {
    final List items = ticket['items'] as List;
    final String tituloCentrado = _formatearTituloNegocioConTelefono();
    final String dirNeg = _configNegocio['direccion_negocio'] ?? '';
    final String modalidadTexto = _formatearModalidadTicket(ticket);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0E1626),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFFFAB00), width: 1.5),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text('🧾 ', style: TextStyle(fontSize: 18)),
                  Text(
                    'Comprobante Compacto',
                    style: TextStyle(color: Color(0xFFFFAB00), fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '#${ticket['venta_id']}',
                  style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Container(
            width: 350,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0F1D),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white24),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    tituloCentrado,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (dirNeg.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        dirNeg,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 13.5),
                      ),
                    ),
                  const Divider(color: Colors.white24, height: 14),
                  Text(
                    'Recibo #${ticket['venta_id']} | ${ticket['fecha']}',
                    style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Cajera: ${ticket['cajero']}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13.5, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Forma de Pago: ${ticket['metodo_pago']}',
                    style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 13.5, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Pedido: $modalidadTexto',
                    style: const TextStyle(color: Color(0xFFFFAB00), fontSize: 13.5, fontWeight: FontWeight.bold),
                  ),
                  const Divider(color: Colors.white24, height: 14),
                  ...items.map((it) {
                    final m = it as Map;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${m['cantidad']}x ${m['nombre']}',
                              style: const TextStyle(color: Colors.white, fontSize: 13.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            'Bs. ${(m['subtotal'] as num).toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(color: Colors.white24, height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TOTAL PAGADO:',
                        style: TextStyle(
                          color: Color(0xFFFFAB00),
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Bs. ${(ticket['total'] as num).toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Color(0xFF00E5FF),
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
              ),
              onPressed: () => _generarEImprimirReciboPdf(ticket),
              icon: const Icon(Icons.picture_as_pdf, size: 16),
              label: const Text('Reimprimir PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFAB00),
                foregroundColor: Colors.black,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(),
              icon: const Icon(Icons.check_circle_outline, size: 16),
              label: const Text('Cerrar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        );
      },
    );
  }

  void _mostrarDialogoCrearEditarProducto({ItemCatalogo? productoExistente}) {
    if (!_esAdminActivo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('🔒 Permiso denegado: Solo el Administrador puede crear o modificar productos.'),
        ),
      );
      return;
    }

    final bool esEdicion = productoExistente != null;
    final ctrlNombre = TextEditingController(text: esEdicion ? productoExistente.nombre : '');
    final ctrlPrecio = TextEditingController(text: esEdicion ? productoExistente.precio.toStringAsFixed(2) : '10.00');
    final ctrlStock = TextEditingController(text: esEdicion ? productoExistente.stock.toString() : '50');

    final List<String> listaCategoriasSelector = categorias.where((c) => c != 'Todos').toList();
    if (listaCategoriasSelector.isEmpty) {
      listaCategoriasSelector.add('General');
    }

    String catSeleccionada = esEdicion && listaCategoriasSelector.contains(productoExistente.categoria)
        ? productoExistente.categoria
        : listaCategoriasSelector.first;

    String emojiElegido = esEdicion ? _obtenerEmojiProducto(productoExistente) : '🥟';
    String rutaImagenElegida = esEdicion
        ? (_imagenesProductosCustom[productoExistente.id.toString()] ?? productoExistente.imagenPath ?? '')
        : '';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (sbContext, setStateDialog) {
            Future<void> seleccionarFotografiaProducto() async {
              try {
                FilePickerResult? result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'bmp'],
                  allowMultiple: false,
                );
                if (result != null && result.files.single.path != null) {
                  setStateDialog(() {
                    rutaImagenElegida = result.files.single.path!;
                  });
                }
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.redAccent,
                    content: Text('Error al seleccionar fotografía: $e'),
                  ),
                );
              }
            }

            final bool tieneFotoValida =
                rutaImagenElegida.trim().isNotEmpty && File(rutaImagenElegida.trim()).existsSync();

            return AlertDialog(
              backgroundColor: const Color(0xFF0E1626),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFFFFAB00), width: 1.5),
              ),
              title: Text(
                esEdicion ? '✏️ Editar Producto: ${productoExistente.nombre}' : '➕ Nuevo Producto en Catálogo',
                style: const TextStyle(color: Color(0xFFFFAB00), fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '📷 Fotografía Central del Producto (Opcional - Prioritaria sobre Emoji):',
                        style: TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131C31),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0A0F1D),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFFAB00), width: 1.5),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: tieneFotoValida
                                    ? Image.file(
                                        File(rutaImagenElegida),
                                        fit: BoxFit.cover,
                                        width: 72,
                                        height: 72,
                                      )
                                    : Center(
                                        child: Text(emojiElegido, style: const TextStyle(fontSize: 34)),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tieneFotoValida
                                        ? p.basename(rutaImagenElegida)
                                        : 'Usando Emoji ($emojiElegido)',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFFFAB00),
                                          foregroundColor: Colors.black,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        ),
                                        onPressed: seleccionarFotografiaProducto,
                                        icon: const Icon(Icons.add_a_photo, size: 15),
                                        label: const Text(
                                          'Subir Foto...',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      if (tieneFotoValida)
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.redAccent,
                                            side: const BorderSide(color: Colors.redAccent),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          ),
                                          onPressed: () {
                                            setStateDialog(() {
                                              rutaImagenElegida = '';
                                            });
                                          },
                                          icon: const Icon(Icons.close, size: 15),
                                          label: const Text(
                                            'Quitar Foto',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'O selecciona un Emoji para el Producto:',
                        style: TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 98,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131C31),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 8,
                            mainAxisSpacing: 6,
                            crossAxisSpacing: 6,
                          ),
                          itemCount: _paletaEmojisProductos.length,
                          itemBuilder: (context, i) {
                            final em = _paletaEmojisProductos[i];
                            final activo = emojiElegido == em;
                            return InkWell(
                              onTap: () {
                                setStateDialog(() => emojiElegido = em);
                              },
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: activo ? const Color(0xFFFFAB00) : const Color(0xFF0A0F1D),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(em, style: const TextStyle(fontSize: 20)),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: ctrlNombre,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          prefixText: '$emojiElegido  ',
                          labelText: 'Nombre del Producto',
                          labelStyle: const TextStyle(color: Color(0xFF00E5FF)),
                          filled: true,
                          fillColor: const Color(0xFF131C31),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: ctrlPrecio,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Precio Unitario (Bs.)',
                                labelStyle: const TextStyle(color: Color(0xFF00E5FF)),
                                filled: true,
                                fillColor: const Color(0xFF131C31),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: ctrlStock,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Stock Disponible',
                                labelStyle: const TextStyle(color: Color(0xFF00E5FF)),
                                filled: true,
                                fillColor: const Color(0xFF131C31),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
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
                          border: Border.all(color: const Color(0xFFFFAB00)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: catSeleccionada,
                            dropdownColor: const Color(0xFF131C31),
                            isExpanded: true,
                            style: const TextStyle(color: Colors.white),
                            items: listaCategoriasSelector.map((String c) {
                              final emCat = _obtenerEmojiCategoria(c);
                              return DropdownMenuItem<String>(
                                value: c,
                                child: Text('$emCat  $c', style: const TextStyle(color: Colors.white)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setStateDialog(() => catSeleccionada = val);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                if (esEdicion)
                  TextButton.icon(
                    onPressed: () async {
                      final navigator = Navigator.of(dialogContext);
                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      _imagenesProductosCustom.remove(productoExistente.id.toString());
                      _emojisProductosCustom.remove(productoExistente.id.toString());
                      await _guardarMesasYMultimediaEnConfiguracion();
                      await _dbService.eliminarProducto(productoExistente.id);
                      navigator.pop();
                      await _cargarDatosDesdeSQLite();
                      if (!mounted) return;
                      scaffoldMessenger.showSnackBar(
                        const SnackBar(
                          backgroundColor: Colors.redAccent,
                          content: Text('🗑️ Producto eliminado de la base de datos.'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                    label: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
                  ),
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
                  label: Text(esEdicion ? 'Guardar Cambios' : 'Crear Producto', style: const TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    final nombre = ctrlNombre.text.trim();
                    final precio = double.tryParse(ctrlPrecio.text.trim()) ?? 10.0;
                    final stock = int.tryParse(ctrlStock.text.trim()) ?? 0;

                    if (nombre.isEmpty) return;

                    final navigator = Navigator.of(dialogContext);
                    final scaffoldMessenger = ScaffoldMessenger.of(context);

                    int idFinalProducto = esEdicion ? productoExistente.id : 0;

                    if (esEdicion) {
                      await _dbService.actualizarProducto(
                        productoExistente.id,
                        precio,
                        stock,
                        catSeleccionada,
                      );
                      final db = await _dbService.database;
                      await db.update(
                        'productos',
                        {'nombre': nombre},
                        where: 'id = ?',
                        whereArgs: [productoExistente.id],
                      );
                    } else {
                      final db = await _dbService.database;
                      await _dbService.insertarCategoria(catSeleccionada);
                      final List catRows = await db.query(
                        'categorias',
                        where: 'nombre = ?',
                        whereArgs: [catSeleccionada],
                      );
                      final int catId = catRows.isNotEmpty ? (catRows.first['id'] as num).toInt() : 1;

                      idFinalProducto = await db.insert('productos', {
                        'categoria_id': catId,
                        'nombre': nombre,
                        'precio': precio,
                        'stock_actual': stock,
                      });
                    }

                    _emojisProductosCustom[idFinalProducto.toString()] = emojiElegido;
                    if (rutaImagenElegida.trim().isNotEmpty) {
                      _imagenesProductosCustom[idFinalProducto.toString()] = rutaImagenElegida.trim();
                    } else {
                      _imagenesProductosCustom.remove(idFinalProducto.toString());
                    }

                    await _guardarMesasYMultimediaEnConfiguracion();

                    navigator.pop();
                    await _cargarDatosDesdeSQLite();

                    if (!mounted) return;
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        backgroundColor: Colors.green,
                        content: Text('✅ "$nombre" guardado con su ilustración correctamente.'),
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

  void _mostrarDialogoControlCaja() {
    final ctrlMontoInicial = TextEditingController(text: _montoInicialCaja.toStringAsFixed(2));
    final aperturaCorta = _fechaAperturaCaja.isNotEmpty
        ? _fechaAperturaCaja.split('T').first
        : _fechaActual;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (contextDialog, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0E1626),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFFFFAB00), width: 1.5),
              ),
              title: Row(
                children: [
                  const Text('💰 ', style: TextStyle(fontSize: 22)),
                  Expanded(
                    child: Text(
                      _cajaAbierta ? 'Arqueo de Caja: $_nombreCajaActiva (#$_cajaIdActual)' : 'Abrir Turno: $_nombreCajaActiva',
                      style: const TextStyle(color: Color(0xFFFFAB00), fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 410,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131C31),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Cajero Responsable:', style: TextStyle(color: Colors.white70)),
                                Text(_nombreCajeroActivo, style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Fecha Apertura:', style: TextStyle(color: Colors.white70)),
                                Text(aperturaCorta, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Recaudación Día Anterior (Ref):', style: TextStyle(color: Colors.grey)),
                                Text('Bs. ${_recaudacionDiaAnteriorRef.toStringAsFixed(2)}', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Ventas en Efectivo:', style: TextStyle(color: Colors.white70)),
                                Text('Bs. ${_totalEfectivoTurno.toStringAsFixed(2)}', style: const TextStyle(color: Colors.greenAccent)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Ventas por QR:', style: TextStyle(color: Colors.white70)),
                                Text('Bs. ${_totalQrTurno.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF00E5FF))),
                              ],
                            ),
                            const Divider(color: Colors.white24, height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('EFECTIVO EN GAVETA:', style: TextStyle(color: Color(0xFFFFAB00), fontWeight: FontWeight.bold)),
                                Text(
                                  'Bs. ${(_montoInicialCaja + _totalEfectivoTurno).toStringAsFixed(2)}',
                                  style: const TextStyle(color: Color(0xFFFFAB00), fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: ctrlMontoInicial,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: '💵 Monto Base Inicial / Fondo de Cambio (Bs.)',
                          labelStyle: const TextStyle(color: Color(0xFF00E5FF), fontSize: 12),
                          filled: true,
                          fillColor: const Color(0xFF131C31),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00E5FF),
                            foregroundColor: Colors.black,
                          ),
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            _generarInformeCajeroPdf();
                          },
                          icon: const Icon(Icons.picture_as_pdf, size: 18),
                          label: const Text('Imprimir Mi Informe Individual (PDF)', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFAB00),
                            foregroundColor: Colors.black,
                          ),
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            _generarInformeGeneralCajaPdf();
                          },
                          icon: const Icon(Icons.assessment, size: 18),
                          label: const Text('Imprimir Informe General de Caja (PDF)', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cerrar Ventana', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFAB00),
                    foregroundColor: Colors.black,
                  ),
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text('Actualizar Base', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    final nuevoMontoBase = double.tryParse(ctrlMontoInicial.text.trim()) ?? 0.0;
                    final navigator = Navigator.of(dialogContext);
                    final db = await _dbService.database;

                    await db.update(
                      'caja_sesiones',
                      {'monto_inicial': nuevoMontoBase},
                      where: 'id = ?',
                      whereArgs: [_cajaIdActual],
                    );

                    if (mounted) {
                      setState(() {
                        _montoInicialCaja = nuevoMontoBase;
                      });
                    }

                    navigator.pop();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: Colors.green,
                        content: Text('✅ Base inicial actualizada a Bs. ${nuevoMontoBase.toStringAsFixed(2)}'),
                      ),
                    );
                  },
                ),
                if (_cajaAbierta)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.lock_clock, size: 18),
                    label: const Text('Cerrar Turno'),
                    onPressed: () async {
                      final navigator = Navigator.of(dialogContext);
                      final db = await _dbService.database;
                      await db.update(
                        'caja_sesiones',
                        {
                          'fecha_cierre': DateTime.now().toIso8601String(),
                          'monto_final': _montoInicialCaja + _totalVentasTurno,
                          'estado': 'Cerrada',
                        },
                        where: 'id = ?',
                        whereArgs: [_cajaIdActual],
                      );
                      if (mounted) {
                        setState(() => _cajaAbierta = false);
                      }
                      navigator.pop();
                    },
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
    final List<ItemCatalogo> productosFiltrados = products.where((p) {
      final coincideCategoria = categoriaSeleccionada == 'Todos' ||
          p.categoria.trim().toLowerCase() == categoriaSeleccionada.trim().toLowerCase();
      final coincideTexto = _filtroTexto.isEmpty ||
          p.nombre.toLowerCase().contains(_filtroTexto.toLowerCase()) ||
          p.categoria.toLowerCase().contains(_filtroTexto.toLowerCase());
      final coincideStock = !_soloConStock || p.stock > 0;
      return coincideCategoria && coincideTexto && coincideStock;
    }).toList();

    final nombreNeg = _configNegocio['nombre_negocio'] ?? 'AScafe';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E1626),
        elevation: 2,
        toolbarHeight: 65,
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$nombreNeg | $_nombreCajaActiva',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '👤 Cajero: $_nombreCajeroActivo',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _cajaAbierta ? Colors.green.withOpacity(0.18) : Colors.red.withOpacity(0.18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _cajaAbierta ? Colors.greenAccent : Colors.redAccent),
              ),
              child: Text(
                _cajaAbierta ? '🟢 Turno #$_cajaIdActual | Bs. ${_totalVentasTurno.toStringAsFixed(2)}' : '🔴 Caja Cerrada',
                style: TextStyle(
                  color: _cajaAbierta ? Colors.greenAccent : Colors.redAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '📅 $_fechaActual 🕒 $_horaActual',
              style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Información Avrora Soft',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const AvroraInfoDialog(),
              );
            },
            icon: const Icon(Icons.info_outline, color: Colors.white),
          ),
          if (_ultimoTicketGenerado != null)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: Color(0xFF00E5FF)),
              tooltip: 'Ver / Imprimir Último Recibo PDF',
              onPressed: () => _mostrarDialogoTicketVenta(_ultimoTicketGenerado!),
            ),
          if (_esAdminActivo) ...[
            IconButton(
              icon: const Icon(Icons.store, color: Color(0xFFFFAB00)),
              tooltip: 'Configurar Establecimiento, Logo y Correo QR',
              onPressed: _mostrarDialogoConfiguracionNegocio,
            ),
            IconButton(
              icon: const Icon(Icons.add_box, color: Colors.greenAccent),
              tooltip: 'Crear Nuevo Producto (Solo Admin)',
              onPressed: () => _mostrarDialogoCrearEditarProducto(),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.point_of_sale, color: Colors.white),
            tooltip: 'Configurar Base y Arqueo de Caja',
            onPressed: _mostrarDialogoControlCaja,
          ),
          if (_esAdminActivo)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings, color: Color(0xFFFFAB00)),
              tooltip: 'Gestionar Cajeros, Contraseñas e Inventario',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminInventarioScreen()),
                );
                await _inicializarSistemaPOS();
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF00E5FF)),
            tooltip: 'Sincronizar Catálogo',
            onPressed: _cargarDatosDesdeSQLite,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 7,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                  color: const Color(0xFF0E1626),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: TextField(
                            controller: _ctrlBusqueda,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            onChanged: (val) => setState(() => _filtroTexto = val),
                            decoration: InputDecoration(
                              hintText: '🔍 Buscar producto o categoría...',
                              hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                              filled: true,
                              fillColor: const Color(0xFF131C31),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                              suffixIcon: _filtroTexto.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, color: Colors.grey, size: 16),
                                      onPressed: () {
                                        _ctrlBusqueda.clear();
                                        setState(() => _filtroTexto = '');
                                      },
                                    )
                                  : null,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilterChip(
                        label: const Text('Solo con Stock', style: TextStyle(fontSize: 12)),
                        selected: _soloConStock,
                        selectedColor: const Color(0xFFFFAB00),
                        backgroundColor: const Color(0xFF131C31),
                        labelStyle: TextStyle(
                          color: _soloConStock ? Colors.black : Colors.white70,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (val) => setState(() => _soloConStock = val),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 54,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  color: const Color(0xFF0E1626),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: categorias.map((cat) {
                      final bool seleccionado = categoriaSeleccionada == cat;
                      final String emojiCat = _obtenerEmojiCategoria(cat);

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Tooltip(
                          message: cat,
                          child: ChoiceChip(
                            label: Text(
                              emojiCat,
                              style: const TextStyle(fontSize: 18),
                            ),
                            selected: seleccionado,
                            selectedColor: const Color(0xFFFFAB00),
                            backgroundColor: const Color(0xFF131C31),
                            onSelected: (_) {
                              setState(() {
                                categoriaSeleccionada = cat;
                              });
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Expanded(
                  child: cargandoProductos
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFAB00)))
                      : productosFiltrados.isEmpty
                          ? const Center(
                              child: Text(
                                'No hay productos en esta categoría.',
                                style: TextStyle(color: Colors.grey, fontSize: 14),
                              ),
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.all(12),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                childAspectRatio: 0.96,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemCount: productosFiltrados.length,
                              itemBuilder: (context, index) {
                                final producto = productosFiltrados[index];
                                final sinStock = producto.stock <= 0;
                                final stockBajo = producto.stock > 0 && producto.stock <= 5;

                                return InkWell(
                                  onTap: () => _agregarAlCarrito(producto),
                                  onLongPress: _esAdminActivo
                                      ? () => _mostrarDialogoCrearEditarProducto(productoExistente: producto)
                                      : null,
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: sinStock
                                          ? const Color(0xFF131C31).withOpacity(0.45)
                                          : const Color(0xFF131C31),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: sinStock
                                            ? Colors.redAccent.withOpacity(0.4)
                                            : const Color(0xFFFFAB00).withOpacity(0.55),
                                        width: 1.3,
                                      ),
                                    ),
                                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                producto.nombre,
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (_esAdminActivo)
                                              InkWell(
                                                onTap: () => _mostrarDialogoCrearEditarProducto(
                                                  productoExistente: producto,
                                                ),
                                                child: const Padding(
                                                  padding: EdgeInsets.only(left: 4),
                                                  child: Icon(
                                                    Icons.edit_note,
                                                    color: Colors.white54,
                                                    size: 18,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 6),
                                            child: _construirIlustracionCentralProminente(producto),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Bs. ${producto.precio.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                color: Color(0xFF00E5FF),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: sinStock
                                                    ? Colors.red.withOpacity(0.2)
                                                    : stockBajo
                                                        ? Colors.orange.withOpacity(0.2)
                                                        : Colors.green.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                sinStock ? 'AGOTADO' : 'Stock: ${producto.stock}',
                                                style: TextStyle(
                                                  color: sinStock
                                                      ? Colors.redAccent
                                                      : stockBajo
                                                          ? Colors.orangeAccent
                                                          : Colors.greenAccent,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),

          const VerticalDivider(width: 1, color: Colors.white12),
          Expanded(
            flex: 5,
            child: Container(
              color: const Color(0xFF0E1626),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '🛒 Orden Actual ($totalUnidadesCarrito unds)',
                        style: const TextStyle(
                          color: Color(0xFFFFAB00),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (carrito.isNotEmpty)
                        TextButton.icon(
                          onPressed: _limpiarCarrito,
                          icon: const Icon(Icons.delete_sweep, color: Colors.redAccent, size: 18),
                          label: const Text('Vaciar', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                        ),
                    ],
                  ),
                  Row(
                    children: ['Para Llevar', 'Mesa', 'Delivery'].map((modo) {
                      final sel = _tipoPedido == modo;
                      final icono = modo == 'Para Llevar'
                          ? '🛍️'
                          : modo == 'Mesa'
                              ? '🍽️'
                              : '🛵';
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: ChoiceChip(
                            label: Text('$icono $modo', style: const TextStyle(fontSize: 11)),
                            selected: sel,
                            selectedColor: const Color(0xFF00E5FF),
                            backgroundColor: const Color(0xFF131C31),
                            labelStyle: TextStyle(
                              color: sel ? Colors.black : Colors.white70,
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (_) {
                              setState(() {
                                _tipoPedido = modo;
                                if (!_listaMesas.contains(_numeroMesa) && _listaMesas.isNotEmpty) {
                                  _numeroMesa = _listaMesas.first;
                                }
                              });
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131C31),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _tipoPedido == 'Mesa'
                            ? const Color(0xFFFFAB00)
                            : Colors.white24,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          '🍽️ N° Mesa:',
                          style: TextStyle(
                            color: Color(0xFFFFAB00),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            height: 30,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0A0F1D),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _listaMesas.contains(_numeroMesa) ? _numeroMesa : _listaMesas.first,
                                dropdownColor: const Color(0xFF131C31),
                                isExpanded: true,
                                icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFFFAB00), size: 18),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                items: _listaMesas.map((String numM) {
                                  return DropdownMenuItem<String>(
                                    value: numM,
                                    child: Text('Mesa $numM'),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _numeroMesa = val;
                                      _tipoPedido = 'Mesa';
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: 'Aumentar Mesa (+)',
                          child: InkWell(
                            onTap: _agregarNuevaMesa,
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              height: 30,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.greenAccent),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.add, color: Colors.greenAccent, size: 16),
                                  SizedBox(width: 2),
                                  Text(
                                    'Mesa',
                                    style: TextStyle(
                                      color: Colors.greenAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Tooltip(
                          message: 'Borrar / Disminuir Mesa (-)',
                          child: InkWell(
                            onTap: _eliminarMesaActual,
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              height: 30,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.redAccent),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.remove, color: Colors.redAccent, size: 16),
                                  SizedBox(width: 2),
                                  Text(
                                    'Borrar',
                                    style: TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: SizedBox(
                          height: 36,
                          child: TextField(
                            controller: _ctrlClienteNombre,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            decoration: InputDecoration(
                              labelText: '👤 Cliente / Razón Social',
                              labelStyle: const TextStyle(color: Colors.white60, fontSize: 11),
                              filled: true,
                              fillColor: const Color(0xFF131C31),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 36,
                          child: TextField(
                            controller: _ctrlNitCi,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            decoration: InputDecoration(
                              labelText: '🪪 NIT / CI',
                              labelStyle: const TextStyle(color: Colors.white60, fontSize: 11),
                              filled: true,
                              fillColor: const Color(0xFF131C31),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 14),
                  Expanded(
                    child: carrito.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('🥟 ☕ 🥤', style: TextStyle(fontSize: 32)),
                                SizedBox(height: 6),
                                Text(
                                  'Haz clic en cualquier producto para agregarlo a la venta',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: carrito.length,
                            itemBuilder: (context, index) {
                              final item = carrito[index];
                              return Card(
                                color: const Color(0xFF131C31),
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  child: Row(
                                    children: [
                                      _construirIlustracionMiniaturaCarrito(item.producto),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.producto.nombre,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                            Text(
                                              'Bs. ${item.precioUnitario.toStringAsFixed(2)} c/u',
                                              style: const TextStyle(color: Colors.grey, fontSize: 11),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline, color: Colors.orangeAccent, size: 20),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () => _cambiarCantidadItem(index, -1),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        child: Text(
                                          '${item.cantidad}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline, color: Colors.greenAccent, size: 20),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () => _cambiarCantidadItem(index, 1),
                                      ),
                                      const SizedBox(width: 10),
                                      SizedBox(
                                        width: 68,
                                        child: Text(
                                          'Bs. ${item.subtotal.toStringAsFixed(2)}',
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(
                                            color: Color(0xFF00E5FF),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const Divider(color: Colors.white24, height: 14),
                  Row(
                    children: ['Efectivo', 'QR'].map((metodo) {
                      final sel = _metodoPagoSeleccionado == metodo;
                      final em = metodo == 'Efectivo' ? '💵' : '📱';
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: InkWell(
                            onTap: () => setState(() => _metodoPagoSeleccionado = metodo),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: sel ? const Color(0xFFFFAB00) : const Color(0xFF131C31),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: sel ? const Color(0xFFFFAB00) : Colors.white24,
                                ),
                              ),
                              child: Text(
                                '$em Pago en $metodo',
                                style: TextStyle(
                                  color: sel ? Colors.black : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (_metodoPagoSeleccionado == 'Efectivo')
                        Expanded(
                          child: SizedBox(
                            height: 38,
                            child: TextField(
                              controller: _ctrlMontoRecibido,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                labelText: '💵 Efectivo Recibido (Bs.)',
                                labelStyle: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11),
                                filled: true,
                                fillColor: const Color(0xFF131C31),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ),
                      if (_metodoPagoSeleccionado == 'Efectivo') const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 38,
                          child: TextField(
                            controller: _ctrlDescuento,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              labelText: '🏷️ Descuento (Bs.)',
                              labelStyle: const TextStyle(color: Colors.orangeAccent, fontSize: 11),
                              filled: true,
                              fillColor: const Color(0xFF131C31),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A0F1D),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('TOTAL A COBRAR:', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                            Text(
                              'Bs. ${totalCarrito.toStringAsFixed(2)}',
                              style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        if (_metodoPagoSeleccionado == 'Efectivo' && montoRecibido > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Cambio / Vuelto al Cliente:', style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
                                Text(
                                  'Bs. ${cambioVuelto.toStringAsFixed(2)}',
                                  style: const TextStyle(color: Colors.greenAccent, fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFAB00),
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _procesarPago,
                    icon: const Icon(Icons.picture_as_pdf, size: 20),
                    label: const Text(
                      'COBRAR E IMPRIMIR RECIBO PDF',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DialogoCobroYapeRealtime extends StatefulWidget {
  final double montoEsperado;
  final String nombreNegocio;
  final void Function(EventoPagoYape pago) onPagoConfirmado;
  final VoidCallback onCancelar;

  const DialogoCobroYapeRealtime({
    super.key,
    required this.montoEsperado,
    required this.nombreNegocio,
    required this.onPagoConfirmado,
    required this.onCancelar,
  });

  @override
  State<DialogoCobroYapeRealtime> createState() => _DialogoCobroYapeRealtimeState();
}

class _DialogoCobroYapeRealtimeState extends State<DialogoCobroYapeRealtime> {
  StreamSubscription? _suscripcionUdp;
  String _estadoMensaje = 'Escuchando red Wi-Fi local (Puerto UDP 45455)...';
  Color _colorEstado = Colors.white70;

  @override
  void initState() {
    super.initState();
    _iniciarEscuchaUdp();
  }

  void _iniciarEscuchaUdp() {
    YapeUdpReceptor.instance.iniciarEscucha(puerto: 45455);

    _suscripcionUdp = YapeUdpReceptor.instance.flujoPagos.listen((dynamic evento) {
      if (evento is EventoPagoYape) {
        final double diferencia = (evento.monto - widget.montoEsperado).abs();

        if (diferencia < 0.015) {
          _suscripcionUdp?.cancel();
          widget.onPagoConfirmado(evento);
        } else {
          if (mounted) {
            setState(() {
              _colorEstado = Colors.orangeAccent;
              _estadoMensaje =
                  'Abono detectado de ${evento.pagador} por Bs. ${evento.monto.toStringAsFixed(2)} (Esperando Bs. ${widget.montoEsperado.toStringAsFixed(2)})';
            });
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _suscripcionUdp?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0E1626),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFFFAB00), width: 1.5),
      ),
      title: Row(
        children: [
          const Icon(Icons.qr_code_scanner, color: Color(0xFF00E5FF), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Esperando Pago Yape QR en Tiempo Real',
                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.nombreNegocio,
                  style: const TextStyle(color: Color(0xFFFFAB00), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 430,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'El comprobante se emitirá e imprimirá automáticamente apenas el celular detecte el abono exacto de Yape.',
              style: TextStyle(color: Colors.white70, fontSize: 12.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF131C31),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFAB00)),
              ),
              child: Column(
                children: [
                  const Text(
                    'TOTAL EXACTO A RECIBIR',
                    style: TextStyle(fontSize: 11, color: Colors.white54, letterSpacing: 1),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Bs. ${widget.montoEsperado.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00E5FF),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(color: Color(0xFFFFAB00)),
            const SizedBox(height: 14),
            Text(
              _estadoMensaje,
              textAlign: TextAlign.center,
              style: TextStyle(color: _colorEstado, fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            _suscripcionUdp?.cancel();
            widget.onCancelar();
          },
          child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            _suscripcionUdp?.cancel();
            widget.onPagoConfirmado(
              EventoPagoYape(
                id: 'MANUAL-${DateTime.now().millisecondsSinceEpoch}',
                origen: 'CAJA_MANUAL',
                empresa: 'Avrora Soft - Vibola LLC',
                monto: widget.montoEsperado,
                moneda: 'BOB',
                pagador: 'Verificación Manual en Caja',
                titulo: 'Aprobación Manual',
                mensaje: 'Aprobado directamente por cajero',
                fechaHora: DateTime.now(),
              ),
            );
          },
          icon: const Icon(Icons.check_circle_outline, size: 18),
          label: const Text(
            'Confirmar Manualmente',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}