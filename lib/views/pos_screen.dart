// Nombre del archivo: pos_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../services/database_service.dart';
import 'admin_inventario_screen.dart';

class ItemCatalogo {
  final int id;
  final String nombre;
  final double precio;
  final String categoria;
  final int stock;
  final String? emojiPersonalizado;

  ItemCatalogo(
    this.id,
    this.nombre,
    this.precio, {
    required this.categoria,
    required this.stock,
    this.emojiPersonalizado,
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
  final String _numeroMesa = '1';

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
  };

  final Map<String, String> _emojisProductosCustom = {};

  static const List<String> _paletaEmojisProductos = [
    '🥟', '🍗', '🥩', '🌶️', '🍯', '🧀', '🥚', '🥓',
    '🥤', '🍑', '🌾', '🟣', '🥮', '☕', '🍵', '🥛',
    '🍰', '🧁', '🍩', '🍪', '🍮', '🍦', '🥪', '🍔',
    '🍕', '🌭', '🍟', '🍿', '🥗', '🍲', '🍱', '🍽️'
  ];

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
    _relojTimer?.cancel();
    _ctrlBusqueda.dispose();
    _ctrlClienteNombre.dispose();
    _ctrlNitCi.dispose();
    _ctrlMontoRecibido.dispose();
    _ctrlDescuento.dispose();
    super.dispose();
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

  Future<void> _inicializarSistemaPOS() async {
    final conf = await _dbService.obtenerConfiguracionNegocio();
    setState(() {
      _configNegocio = conf;
    });
    await _verificarEstadoCajaSQLite();
    await _cargarDatosDesdeSQLite();
    await _calcularResumenVentasTurno();
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

  void _mostrarDialogoConfiguracionNegocio() {
    if (!_esAdminActivo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('🔒 Permiso denegado: Solo el Administrador puede modificar los datos y el logo del negocio.'),
        ),
      );
      return;
    }

    final ctrlNombre = TextEditingController(text: _configNegocio['nombre_negocio'] ?? 'AScafe');
    final ctrlDireccion = TextEditingController(text: _configNegocio['direccion_negocio'] ?? 'Riberalta, Beni - Bolivia');
    final ctrlCelular = TextEditingController(text: _configNegocio['celular_negocio'] ?? '+591 70000000');
    final ctrlLogoPath = TextEditingController(text: _configNegocio['logo_path'] ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (sbContext, setStateDialog) {
            Future<void> seleccionarLogoGrafico() async {
              try {
                FilePickerResult? result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['png', 'jpg', 'jpeg'],
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

            return AlertDialog(
              backgroundColor: const Color(0xFF0E1626),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFFFFAB00), width: 1.5),
              ),
              title: const Row(
                children: [
                  Text('⚙️ ', style: TextStyle(fontSize: 22)),
                  Text(
                    'Configuración del Establecimiento y Logo',
                    style: TextStyle(color: Color(0xFFFFAB00), fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Previsualización del Logo Grande:',
                        style: TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: const Color(0xFF131C31),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFFFAB00), width: 3),
                        ),
                        child: ClipOval(
                          child: ctrlLogoPath.text.isNotEmpty && File(ctrlLogoPath.text).existsSync()
                              ? Image.file(
                                  File(ctrlLogoPath.text),
                                  fit: BoxFit.cover,
                                  width: 70,
                                  height: 70,
                                )
                              : const Icon(Icons.store, size: 60, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
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
                    ],
                  ),
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
                  label: const Text('Guardar Configuración', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    final navigator = Navigator.of(dialogContext);
                    final scaffoldMessenger = ScaffoldMessenger.of(context);

                    await _dbService.guardarConfiguracionNegocio({
                      'nombre_negocio': ctrlNombre.text.trim(),
                      'direccion_negocio': ctrlDireccion.text.trim(),
                      'celular_negocio': ctrlCelular.text.trim(),
                      'logo_path': ctrlLogoPath.text.trim(),
                    });

                    navigator.pop();
                    await _inicializarSistemaPOS();

                    if (!mounted) return;
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        backgroundColor: Colors.green,
                        content: Text('✨ Configuración y logo actualizados exitosamente.'),
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
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('ñ', 'n')
        .replaceAll('Ñ', 'N')
        .replaceAll('(', '[')
        .replaceAll(')', ']')
        .replaceAll('\\', '/');
  }

  List<int> _construirBytesPdfRecibo(Map<String, dynamic> ticket) {
    final List items = ticket['items'] as List;
    final nombreNeg = _configNegocio['nombre_negocio'] ?? 'AScafe';
    final dirNeg = _configNegocio['direccion_negocio'] ?? '';
    final celNeg = _configNegocio['celular_negocio'] ?? '';

    final List<String> lineas = [];
    lineas.add('======================================');
    lineas.add('       ${_limpiarTextoPdf(nombreNeg).toUpperCase()}        ');
    if (dirNeg.isNotEmpty) lineas.add('   ${_limpiarTextoPdf(dirNeg)}   ');
    if (celNeg.isNotEmpty) lineas.add('   Celular: ${_limpiarTextoPdf(celNeg)}   ');
    lineas.add('======================================');
    lineas.add('RECIBO DE VENTA NRO: #${ticket['venta_id']}');
    lineas.add('FECHA Y HORA: ${ticket['fecha']}');
    lineas.add('CAJA: ${_limpiarTextoPdf(ticket['nombre_caja']?.toString() ?? '')}');
    lineas.add('CAJERO: ${_limpiarTextoPdf(ticket['cajero']?.toString() ?? '')}');
    lineas.add('CLIENTE: ${_limpiarTextoPdf(ticket['cliente']?.toString() ?? '')}');
    lineas.add('NIT / CI: ${_limpiarTextoPdf(ticket['nit_ci']?.toString() ?? '0')}');
    lineas.add('MODALIDAD: ${_limpiarTextoPdf(ticket['tipo_pedido']?.toString() ?? '')}');
    lineas.add('FORMA DE PAGO: ${_limpiarTextoPdf(ticket['metodo_pago']?.toString() ?? '')}');
    lineas.add('--------------------------------------');
    lineas.add('CANT  DESCRIPCION             SUBTOTAL');
    lineas.add('--------------------------------------');

    for (final it in items) {
      final m = it as Map;
      final cant = '${m['cantidad']}x'.padRight(5);
      final nom = _limpiarTextoPdf(m['nombre']?.toString() ?? '').padRight(20);
      final nomCorto = nom.length > 20 ? nom.substring(0, 20) : nom;
      final sub = 'Bs.${(m['subtotal'] as num).toStringAsFixed(2)}'.padLeft(11);
      lineas.add('$cant $nomCorto $sub');
    }

    lineas.add('--------------------------------------');
    lineas.add('SUBTOTAL:          Bs. ${(ticket['subtotal'] as num).toStringAsFixed(2)}');
    if ((ticket['descuento'] as num) > 0) {
      lineas.add('DESCUENTO:       - Bs. ${(ticket['descuento'] as num).toStringAsFixed(2)}');
    }
    lineas.add('TOTAL PAGADO:      Bs. ${(ticket['total'] as num).toStringAsFixed(2)}');
    if (ticket['metodo_pago'] == 'Efectivo') {
      lineas.add('EFECTIVO RECIBIDO: Bs. ${(ticket['efectivo'] as num).toStringAsFixed(2)}');
      lineas.add('CAMBIO / VUELTO:   Bs. ${(ticket['cambio'] as num).toStringAsFixed(2)}');
    } else {
      lineas.add('PAGO MEDIANTE TRANSFERENCIA QR EXACTO');
    }
    lineas.add('======================================');
    lineas.add('     GRACIAS POR SU PREFERENCIA!      ');

    final int altoPagina = 180 + (lineas.length * 14);
    final StringBuffer contenidoStream = StringBuffer();
    contenidoStream.writeln('BT');
    contenidoStream.writeln('/F1 8.5 Tf');
    int yPos = altoPagina - 25;
    for (final l in lineas) {
      contenidoStream.writeln('12 $yPos Td');
      contenidoStream.writeln('($l) Tj');
      contenidoStream.writeln('-12 -$yPos Td');
      yPos -= 13;
    }
    contenidoStream.writeln('ET');

    final String streamStr = contenidoStream.toString();
    final List<String> objetos = [
      '1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n',
      '2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n',
      '3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 226 $altoPagina] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>\nendobj\n',
      '4 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Courier >>\nendobj\n',
      '5 0 obj\n<< /Length ${streamStr.length} >>\nstream\n$streamStr\nendstream\nendobj\n',
    ];

    final StringBuffer pdfBuffer = StringBuffer();
    pdfBuffer.write('%PDF-1.4\n');
    final List<int> offsets = [];
    for (final obj in objetos) {
      offsets.add(pdfBuffer.toString().length);
      pdfBuffer.write(obj);
    }
    final int xrefStart = pdfBuffer.toString().length;
    pdfBuffer.write('xref\n0 ${objetos.length + 1}\n');
    pdfBuffer.write('0000000000 65535 f \n');
    for (final off in offsets) {
      pdfBuffer.write('${off.toString().padLeft(10, '0')} 00000 n \n');
    }
    pdfBuffer.write('trailer\n<< /Size ${objetos.length + 1} /Root 1 0 R >>\n');
    pdfBuffer.write('startxref\n$xrefStart\n%%EOF');

    return latin1.encode(pdfBuffer.toString());
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
      final nombreNeg = _configNegocio['nombre_negocio'] ?? 'AScafe';
      final StringBuffer sbTxt = StringBuffer();
      sbTxt.writeln('======================================');
      sbTxt.writeln('       ${nombreNeg.toUpperCase()}        ');
      sbTxt.writeln('======================================');
      sbTxt.writeln('RECIBO NRO: #${ticket['venta_id']}');
      sbTxt.writeln('FECHA Y HORA: ${ticket['fecha']}');
      sbTxt.writeln('CAJA: ${ticket['nombre_caja']}');
      sbTxt.writeln('CAJERO: ${ticket['cajero']}');
      sbTxt.writeln('CLIENTE: ${ticket['cliente']} | NIT/CI: ${ticket['nit_ci']}');
      sbTxt.writeln('FORMA DE PAGO: ${ticket['metodo_pago']}');
      sbTxt.writeln('--------------------------------------');
      for (final it in (ticket['items'] as List)) {
        final m = it as Map;
        sbTxt.writeln('${m['cantidad']}x ${m['nombre']} -> Bs. ${(m['subtotal'] as num).toStringAsFixed(2)}');
      }
      sbTxt.writeln('--------------------------------------');
      sbTxt.writeln('TOTAL A PAGAR: Bs. ${(ticket['total'] as num).toStringAsFixed(2)}');
      if (ticket['metodo_pago'] == 'Efectivo') {
        sbTxt.writeln('RECIBIDO: Bs. ${(ticket['efectivo'] as num).toStringAsFixed(2)} | CAMBIO: Bs. ${(ticket['cambio'] as num).toStringAsFixed(2)}');
      }
      sbTxt.writeln('======================================');
      await File(rutaTxt).writeAsString(sbTxt.toString(), flush: true);

      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', rutaPdf]);
        await Process.run('notepad.exe', ['/p', rutaTxt]);
      }

      messenger.showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text('🖨️ Recibo PDF generado e impreso: $rutaPdf'),
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

      final nombreNeg = _configNegocio['nombre_negocio'] ?? 'AScafe';
      final List<String> lineas = [];
      lineas.add('======================================');
      lineas.add('      INFORME INDIVIDUAL DE CAJERO    ');
      lineas.add('       ${_limpiarTextoPdf(nombreNeg).toUpperCase()}        ');
      lineas.add('======================================');
      lineas.add('CAJERO: ${_limpiarTextoPdf(_nombreCajeroActivo)}');
      lineas.add('CAJA: ${_limpiarTextoPdf(_nombreCajaActiva)}');
      lineas.add('FECHA: $_fechaActual');
      lineas.add('TURNO ID: #$_cajaIdActual');
      lineas.add('--------------------------------------');
      lineas.add('VENTAS REGISTRADAS: ${ventasCajero.length}');
      
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

      lineas.add('TOTAL RECAUDADO: Bs. ${totalCajero.toStringAsFixed(2)}');
      lineas.add(' - Efectivo: Bs. ${efectivoCajero.toStringAsFixed(2)}');
      lineas.add(' - Pagos QR: Bs. ${qrCajero.toStringAsFixed(2)}');
      lineas.add('BASE INICIAL (FONDO): Bs. ${_montoInicialCaja.toStringAsFixed(2)}');
      lineas.add('EFECTIVO EN GAVETA: Bs. ${(_montoInicialCaja + efectivoCajero).toStringAsFixed(2)}');
      lineas.add('======================================');
      lineas.add('FIRMA CAJERO: ________________________');

      final int altoPagina = 180 + (lineas.length * 14);
      final StringBuffer contenidoStream = StringBuffer();
      contenidoStream.writeln('BT');
      contenidoStream.writeln('/F1 8.5 Tf');
      int yPos = altoPagina - 25;
      for (final l in lineas) {
        contenidoStream.writeln('12 $yPos Td');
        contenidoStream.writeln('($l) Tj');
        contenidoStream.writeln('-12 -$yPos Td');
        yPos -= 13;
      }
      contenidoStream.writeln('ET');

      final String streamStr = contenidoStream.toString();
      final List<String> objetos = [
        '1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n',
        '2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n',
        '3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 226 $altoPagina] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>\nendobj\n',
        '4 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Courier >>\nendobj\n',
        '5 0 obj\n<< /Length ${streamStr.length} >>\nstream\n$streamStr\nendstream\nendobj\n',
      ];

      final StringBuffer pdfBuffer = StringBuffer();
      pdfBuffer.write('%PDF-1.4\n');
      final List<int> offsets = [];
      for (final obj in objetos) {
        offsets.add(pdfBuffer.toString().length);
        pdfBuffer.write(obj);
      }
      final int xrefStart = pdfBuffer.toString().length;
      pdfBuffer.write('xref\n0 ${objetos.length + 1}\n');
      pdfBuffer.write('0000000000 65535 f \n');
      for (final off in offsets) {
        pdfBuffer.write('${off.toString().padLeft(10, '0')} 00000 n \n');
      }
      pdfBuffer.write('trailer\n<< /Size ${objetos.length + 1} /Root 1 0 R >>\n');
      pdfBuffer.write('startxref\n$xrefStart\n%%EOF');

      final dirTemp = Directory.systemTemp;
      final rutaPdf = p.join(dirTemp.path, 'informe_cajero_${_nombreCajeroActivo}_$_cajaIdActual.pdf');
      await File(rutaPdf).writeAsBytes(latin1.encode(pdfBuffer.toString()), flush: true);

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
    final nombreNeg = _configNegocio['nombre_negocio'] ?? 'AScafe';

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
                  Text('🧾 ', style: TextStyle(fontSize: 22)),
                  Text(
                    'Nota de Venta / Recibo PDF',
                    style: TextStyle(color: Color(0xFFFFAB00), fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Recibo #${ticket['venta_id']}',
                  style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Container(
            width: 390,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0F1D),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white24),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      '☕ $nombreNeg 🥟',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  Center(
                    child: Text(
                      _configNegocio['direccion_negocio'] ?? '',
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ),
                  const Divider(color: Colors.white24, height: 18),
                  Text('📅 Fecha y Hora: ${ticket['fecha']}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  Text('🖥️ Caja: ${ticket['nombre_caja']}', style: const TextStyle(color: Color(0xFFFFAB00), fontSize: 12, fontWeight: FontWeight.bold)),
                  Text('👤 Cajero: ${ticket['cajero']}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  Text('🪪 Cliente: ${ticket['cliente']} | NIT/CI: ${ticket['nit_ci']}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  Text(
                    '💳 Forma de Pago: ${ticket['metodo_pago']}',
                    style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const Divider(color: Colors.white24, height: 18),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(flex: 5, child: Text('PRODUCTO', style: TextStyle(color: Color(0xFFFFAB00), fontSize: 11, fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text('CANT', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFFFAB00), fontSize: 11, fontWeight: FontWeight.bold))),
                      Expanded(flex: 3, child: Text('SUBTOTAL', textAlign: TextAlign.right, style: TextStyle(color: Color(0xFFFFAB00), fontSize: 11, fontWeight: FontWeight.bold))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...items.map((it) {
                    final m = it as Map;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            flex: 5,
                            child: Text(
                              '${m['nombre']}',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'x${m['cantidad']}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              'Bs. ${(m['subtotal'] as num).toStringAsFixed(2)}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(color: Colors.white24, height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TOTAL PAGADO:', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 15, fontWeight: FontWeight.bold)),
                      Text('Bs. ${(ticket['total'] as num).toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  if (ticket['metodo_pago'] == 'Efectivo') ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Efectivo Recibido:', style: TextStyle(color: Colors.white60, fontSize: 12)),
                        Text('Bs. ${(ticket['efectivo'] as num).toStringAsFixed(2)}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Cambio / Vuelto:', style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('Bs. ${(ticket['cambio'] as num).toStringAsFixed(2)}', style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
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
              icon: const Icon(Icons.picture_as_pdf, size: 18),
              label: const Text('Reimprimir PDF', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFAB00),
                foregroundColor: Colors.black,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(),
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Cerrar', style: TextStyle(fontWeight: FontWeight.bold)),
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
                esEdicion ? '✏️ Editar Producto: ${productoExistente.nombre}' : '➕ Nuevo Producto en Catálogo',
                style: const TextStyle(color: Color(0xFFFFAB00), fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Selecciona un Emoji para el Producto:',
                        style: TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 110,
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
                      const SizedBox(height: 14),
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

                    if (esEdicion) {
                      _emojisProductosCustom[productoExistente.id.toString()] = emojiElegido;
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

                      final int nuevoId = await db.insert('productos', {
                        'categoria_id': catId,
                        'nombre': nombre,
                        'precio': precio,
                        'stock_actual': stock,
                      });
                      _emojisProductosCustom[nuevoId.toString()] = emojiElegido;
                    }

                    navigator.pop();
                    await _cargarDatosDesdeSQLite();

                    if (!mounted) return;
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        backgroundColor: Colors.green,
                        content: Text('$emojiElegido "$nombre" guardado correctamente.'),
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
          if (_ultimoTicketGenerado != null)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: Color(0xFF00E5FF)),
              tooltip: 'Ver / Imprimir Último Recibo PDF',
              onPressed: () => _mostrarDialogoTicketVenta(_ultimoTicketGenerado!),
            ),
          if (_esAdminActivo) ...[
            IconButton(
              icon: const Icon(Icons.store, color: Color(0xFFFFAB00)),
              tooltip: 'Configurar Establecimiento y Logo',
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
              tooltip: 'Panel de Administración, Cajeros y Fábrica',
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  color: const Color(0xFF0E1626),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: categorias.length,
                    itemBuilder: (context, index) {
                      final cat = categorias[index];
                      final bool seleccionado = categoriaSeleccionada == cat;
                      final String emojiCat = _obtenerEmojiCategoria(cat);
                      final int cantidadEnCat = cat == 'Todos'
                          ? products.length
                          : products.where((p) => p.categoria.trim().toLowerCase() == cat.trim().toLowerCase()).length;

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text('$emojiCat $cat ($cantidadEnCat)'),
                          selected: seleccionado,
                          selectedColor: const Color(0xFFFFAB00),
                          backgroundColor: const Color(0xFF131C31),
                          labelStyle: TextStyle(
                            color: seleccionado ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          onSelected: (_) {
                            setState(() {
                              categoriaSeleccionada = cat;
                            });
                          },
                        ),
                      );
                    },
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
                                childAspectRatio: 1.25,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                              itemCount: productosFiltrados.length,
                              itemBuilder: (context, index) {
                                final producto = productosFiltrados[index];
                                final emojiProd = _obtenerEmojiProducto(producto);
                                final sinStock = producto.stock <= 0;
                                final stockBajo = producto.stock > 0 && producto.stock <= 5;

                                return InkWell(
                                  onTap: () => _agregarAlCarrito(producto),
                                  onLongPress: _esAdminActivo
                                      ? () => _mostrarDialogoCrearEditarProducto(productoExistente: producto)
                                      : null,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: sinStock
                                          ? const Color(0xFF131C31).withOpacity(0.45)
                                          : const Color(0xFF131C31),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: sinStock
                                            ? Colors.redAccent.withOpacity(0.4)
                                            : const Color(0xFFFFAB00).withOpacity(0.45),
                                        width: 1.2,
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(10),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF0A0F1D),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(emojiProd, style: const TextStyle(fontSize: 24)),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    producto.nombre,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 13,
                                                    ),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    producto.categoria,
                                                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (_esAdminActivo)
                                              InkWell(
                                                onTap: () => _mostrarDialogoCrearEditarProducto(productoExistente: producto),
                                                child: const Padding(
                                                  padding: EdgeInsets.all(2),
                                                  child: Icon(Icons.edit_note, color: Colors.white54, size: 18),
                                                ),
                                              ),
                                          ],
                                        ),
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
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['Para Llevar', 'Mesa', 'Delivery'].map((modo) {
                        final sel = _tipoPedido == modo;
                        final icono = modo == 'Para Llevar'
                            ? '🛍️'
                            : modo == 'Mesa'
                                ? '🍽️'
                                : '🛵';
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text('$icono $modo', style: const TextStyle(fontSize: 11)),
                            selected: sel,
                            selectedColor: const Color(0xFF00E5FF),
                            backgroundColor: const Color(0xFF131C31),
                            labelStyle: TextStyle(
                              color: sel ? Colors.black : Colors.white70,
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (_) => setState(() => _tipoPedido = modo),
                          ),
                        );
                      }).toList(),
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
                  const Divider(color: Colors.white24, height: 16),
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
                              final em = _obtenerEmojiProducto(item.producto);
                              return Card(
                                color: const Color(0xFF131C31),
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  child: Row(
                                    children: [
                                      Text(em, style: const TextStyle(fontSize: 20)),
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